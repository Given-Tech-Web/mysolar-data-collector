#!/bin/bash

# Solar Data Collector 관리 스크립트
# 사용법: ./scripts/manage-app.sh [status|stop|restart]

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Solar Data Collector 프로세스 찾기
find_solar_processes() {
    # dist/index.js를 실행하는 프로세스 찾기
    ps aux | grep "node.*dist/index.js" | grep -v grep
}

# 상태 확인
status() {
    echo -e "${YELLOW}=== Solar Data Collector 상태 확인 ===${NC}\n"

    # 프로세스 확인
    local processes=$(find_solar_processes)

    if [ -z "$processes" ]; then
        echo -e "${RED}❌ 실행 중인 프로세스가 없습니다${NC}\n"
    else
        echo -e "${GREEN}✅ 실행 중인 프로세스:${NC}"
        echo "$processes" | awk '{print "   PID:", $2, "| 메모리:", $6, "| 시작:", $9}'
        echo ""
    fi

    # 로그 파일 확인
    if [ -f "$PROJECT_DIR/logs/combined1.log" ]; then
        local last_log=$(tail -1 "$PROJECT_DIR/logs/combined1.log" 2>/dev/null | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$last_log" ]; then
            echo -e "${GREEN}📝 마지막 로그:${NC} $last_log"
        fi
    fi

    # 최근 에러 확인
    if [ -f "$PROJECT_DIR/logs/error.log" ]; then
        local error_count=$(tail -100 "$PROJECT_DIR/logs/error.log" 2>/dev/null | wc -l)
        if [ "$error_count" -gt 0 ]; then
            echo -e "${YELLOW}⚠️  최근 100줄 에러 로그:${NC} $error_count 건"
        else
            echo -e "${GREEN}✅ 최근 에러 없음${NC}"
        fi
    fi
}

# 프로세스 중지
stop() {
    echo -e "${YELLOW}=== Solar Data Collector 중지 ===${NC}\n"

    local processes=$(find_solar_processes)

    if [ -z "$processes" ]; then
        echo -e "${RED}❌ 중지할 프로세스가 없습니다${NC}"
        return 1
    fi

    echo "$processes" | while read line; do
        local pid=$(echo "$line" | awk '{print $2}')
        echo -e "🛑 프로세스 중지 중: PID $pid"
        kill "$pid" 2>/dev/null

        # 프로세스가 종료될 때까지 대기 (최대 5초)
        for i in {1..5}; do
            if ! ps -p "$pid" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ 프로세스 $pid 중지 완료${NC}"
                break
            fi
            sleep 1
        done

        # 여전히 실행 중이면 강제 종료
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  강제 종료 중: PID $pid${NC}"
            kill -9 "$pid" 2>/dev/null
        fi
    done

    echo -e "\n${GREEN}✅ 모든 프로세스 중지 완료${NC}"
}

# 재시작
restart() {
    echo -e "${YELLOW}=== Solar Data Collector 재시작 ===${NC}\n"

    # 중지
    stop

    echo ""
    sleep 2

    # 시작
    echo -e "${YELLOW}🚀 애플리케이션 시작 중...${NC}"
    cd "$PROJECT_DIR"
    npm start > /dev/null 2>&1 &

    sleep 3

    # 상태 확인
    status
}

# 메인
case "${1:-status}" in
    status)
        status
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    *)
        echo "사용법: $0 {status|stop|restart}"
        echo ""
        echo "  status   - 현재 실행 상태 확인 (기본값)"
        echo "  stop     - 실행 중인 프로세스 중지"
        echo "  restart  - 프로세스 재시작"
        exit 1
        ;;
esac

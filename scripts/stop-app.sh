#!/bin/bash

echo "🛑 Solar Data Collector 중지 중..."
echo ""

# Node.js 프로세스 찾기 (여러 패턴 시도)
PIDS=$(ps aux | grep -E "node.*(dist/index|src/index|solar)" | grep -v grep | awk '{print $2}')

if [ -z "$PIDS" ]; then
    echo "❌ 실행 중인 프로세스를 찾을 수 없습니다."
    echo ""
    echo "💡 다른 방법 시도:"
    echo "   tasklist | findstr node.exe"
    echo "   taskkill /IM node.exe /F"
    exit 1
fi

echo "발견된 프로세스:"
ps aux | grep -E "node.*(dist/index|src/index|solar)" | grep -v grep
echo ""

for PID in $PIDS; do
    echo "종료 중: PID $PID"
    kill $PID 2>/dev/null
    
    # 프로세스가 종료될 때까지 대기
    for i in {1..5}; do
        if ! ps -p $PID > /dev/null 2>&1; then
            echo "✅ PID $PID 종료 완료"
            break
        fi
        sleep 1
    done
    
    # 여전히 실행 중이면 강제 종료
    if ps -p $PID > /dev/null 2>&1; then
        echo "⚠️  강제 종료: PID $PID"
        kill -9 $PID 2>/dev/null
        echo "✅ PID $PID 강제 종료 완료"
    fi
done

echo ""
echo "🎉 모든 프로세스 중지 완료!"

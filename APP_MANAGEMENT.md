# Solar Data Collector 관리 가이드

백그라운드에서 실행 중인 애플리케이션을 확인하고 관리하는 방법입니다.

## 📊 실행 상태 확인 방법

### 방법 1: 로그 파일 확인 (가장 쉬운 방법) ⭐

```bash
# 로그 파일 목록 및 최근 업데이트 시간 확인
ls -lt logs/

# 실시간 로그 모니터링
tail -f logs/combined1.log

# 최근 로그 확인
tail -20 logs/combined1.log
```

**로그가 계속 업데이트되면 앱이 실행 중입니다.**

### 방법 2: Node.js 프로세스 확인

```bash
# Windows에서 Node.js 프로세스 목록
tasklist | findstr node.exe

# Git Bash에서
ps aux | grep node | grep -v grep

# 상세 정보 포함
ps aux | grep -E "node|tsx" | grep -v grep
```

### 방법 3: 관리 스크립트 사용 (추천)

```bash
# 현재 상태 확인
./scripts/manage-app.sh status

# 또는 npm 스크립트 (추가 필요)
npm run app:status
```

## 🛑 앱 중지 방법

### 방법 1: 프로세스 ID로 중지 (권장)

```bash
# 1. Solar Data Collector 프로세스 찾기
ps aux | grep "node.*dist/index.js" | grep -v grep

# 2. PID 확인 (두 번째 컬럼)
# 예: 1234    1000    ...  /node dist/index.js
#     ^^^^
#     PID

# 3. 프로세스 종료
kill 1234  # PID를 실제 숫자로 변경

# 4. 강제 종료 (필요시)
kill -9 1234
```

### 방법 2: 관리 스크립트 사용

```bash
# 모든 Solar Data Collector 프로세스 중지
./scripts/manage-app.sh stop
```

### 방법 3: Windows taskkill 사용

```powershell
# PowerShell 또는 CMD에서
# 1. Node.js 프로세스 PID 확인
tasklist | findstr node.exe

# 2. 특정 PID 종료
taskkill /PID 1234 /F

# 3. 모든 node.exe 종료 (주의! 다른 Node 앱도 종료됨)
taskkill /IM node.exe /F
```

## 🔄 앱 재시작 방법

### 방법 1: 수동 재시작

```bash
# 1. 중지
kill <PID>

# 2. 빌드 (필요시)
npm run build

# 3. 시작
npm start &
# 또는
npm run dev &
```

### 방법 2: 관리 스크립트 사용

```bash
./scripts/manage-app.sh restart
```

## 🚀 앱 시작 방법

### 개발 모드 (자동 재시작)

```bash
npm run dev &
```

### 프로덕션 모드

```bash
# 빌드 (최신 변경사항 반영)
npm run build

# 실행
npm start &
```

### 백그라운드 실행 (nohup 사용)

```bash
# 터미널 종료 후에도 계속 실행
nohup npm start > output.log 2>&1 &

# PID 확인
echo $!
```

## 📝 로그 모니터링

### 실시간 로그 보기

```bash
# 전체 로그
tail -f logs/combined1.log

# 에러만
tail -f logs/error.log

# 특정 키워드 필터링
tail -f logs/combined1.log | grep "error"
```

### 로그 검색

```bash
# 오늘 에러 개수
grep "2025-10-17" logs/error.log | wc -l

# 특정 에러 검색
grep "ER_SP_DOES_NOT_EXIST" logs/error.log

# 성공 메시지 확인
grep "Successfully stored" logs/combined1.log | tail -10
```

## ⚙️ Windows 서비스로 등록 (프로덕션 환경 권장)

### PM2 사용 (권장)

```powershell
# PM2 설치
npm install -g pm2
npm install -g pm2-windows-startup

# Windows 시작 시 자동 실행 설정
pm2-startup install

# 애플리케이션 시작
pm2 start dist/index.js --name solar-collector

# 상태 확인
pm2 status

# 중지
pm2 stop solar-collector

# 재시작
pm2 restart solar-collector

# 로그 보기
pm2 logs solar-collector

# 서비스 제거
pm2 delete solar-collector
```

### NSSM 사용

```powershell
# NSSM 설치 (Chocolatey 사용)
choco install nssm

# 서비스 설치
nssm install SolarDataCollector "C:\Program Files\nodejs\node.exe" "C:\mysolar\solar-data-collector\dist\index.js"

# 작업 디렉토리 설정
nssm set SolarDataCollector AppDirectory "C:\mysolar\solar-data-collector"

# 서비스 시작
nssm start SolarDataCollector

# 서비스 상태
nssm status SolarDataCollector

# 서비스 중지
nssm stop SolarDataCollector

# 서비스 제거
nssm remove SolarDataCollector confirm
```

## 🔍 문제 해결

### 프로세스가 보이지 않는데 로그가 업데이트됨

```bash
# 모든 node 프로세스 확인
tasklist | findstr node.exe

# 특정 포트 사용 중인 프로세스 찾기
netstat -ano | findstr :3306  # MariaDB
netstat -ano | findstr :8883  # MQTT
```

### 앱이 중지되지 않음

```bash
# 강제 종료
kill -9 <PID>

# 또는 Windows에서
taskkill /PID <PID> /F
```

### 여러 인스턴스가 실행 중

```bash
# 모든 Solar Data Collector 프로세스 중지
ps aux | grep "dist/index.js" | grep -v grep | awk '{print $2}' | xargs kill

# Windows에서
tasklist | findstr node.exe
# 각 PID를 확인하고 필요한 것만 종료
```

## 📌 유용한 npm 스크립트 추가

`package.json`에 다음 스크립트를 추가할 수 있습니다:

```json
{
  "scripts": {
    "app:status": "bash scripts/manage-app.sh status",
    "app:stop": "bash scripts/manage-app.sh stop",
    "app:restart": "bash scripts/manage-app.sh restart"
  }
}
```

사용법:
```bash
npm run app:status
npm run app:stop
npm run app:restart
```

## 💡 팁

1. **로그 파일 크기 관리**: 로그 파일이 너무 커지면 회전(rotation) 설정
2. **자동 재시작**: PM2나 NSSM 사용 시 크래시 자동 재시작 가능
3. **모니터링**: PM2의 `pm2 monit` 명령으로 실시간 모니터링
4. **메모리 누수 확인**: `ps aux | grep node`로 메모리 사용량 모니터링

## 🆘 긴급 상황

모든 Node.js 프로세스를 중지해야 하는 경우:

```bash
# ⚠️ 주의: 모든 Node.js 앱이 종료됩니다!
taskkill /IM node.exe /F
```

이후 필요한 앱만 다시 시작하세요.

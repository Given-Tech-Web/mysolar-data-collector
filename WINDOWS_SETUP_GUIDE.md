# Windows 11 Solar Data Collector 설치 및 실행 가이드

## 📋 사전 준비사항

### 1. 필수 소프트웨어 설치

#### Node.js 설치 (v18.0 이상)
1. [Node.js 공식 사이트](https://nodejs.org/) 방문
2. Windows Installer (.msi) 64-bit 다운로드
3. 설치 시 "Add to PATH" 옵션 체크
4. 설치 확인:
```powershell
node --version
npm --version
```

#### Git 설치 (선택사항)
1. [Git for Windows](https://git-scm.com/download/win) 다운로드
2. 기본 옵션으로 설치
3. 설치 확인:
```powershell
git --version
```

### 2. PM2 설치 (프로세스 관리자)

```powershell
# 관리자 권한 PowerShell에서 실행
npm install -g pm2

# PM2 Windows 시작 설정
npm install -g pm2-windows-startup
pm2-startup install
```

### 3. 빌드 도구 설치 (필요시)

일부 npm 패키지는 Windows 빌드 도구가 필요합니다:

```powershell
# 관리자 권한 PowerShell에서 실행
npm install -g windows-build-tools
```

## 🚀 설치 및 실행 방법

### Step 1: 프로젝트 준비

```powershell
# 프로젝트 디렉토리로 이동
cd C:\mysolar\solar-data-collector

# 의존성 패키지 설치
npm install
```

### Step 2: 환경 설정

1. `.env` 파일 확인 및 수정:
```powershell
# .env 파일이 없으면 생성
copy .env.example .env

# 메모장으로 편집
notepad .env
```

2. 필수 환경 변수 확인:
```env
# HiveMQ Cloud Configuration
HIVEMQ_HOST=----
HIVEMQ_PORT=8883
HIVEMQ_USERNAME=your_username
HIVEMQ_PASSWORD=your_password

# MariaDB Configuration
MARIADB_HOST=----
MARIADB_PORT=3306
MARIADB_USER=----
MARIADB_PASSWORD=----
MARIADB_DATABASE=----
```

### Step 3: 데이터베이스 설정

```powershell
# 데이터베이스 테이블 및 프로시저 생성
node scripts\setup-database.js
```

### Step 4: 연결 테스트

```powershell
# MQTT 및 데이터베이스 연결 테스트
node scripts\test-connection.js
```

### Step 5: 빌드

```powershell
# TypeScript 컴파일
npm run build
```

## 🖥️ 실행 방법

### 방법 1: 개발 모드 (테스트용)

```powershell
# 개발 모드로 실행 (자동 재시작 기능)
npm run dev
```

### 방법 2: 일반 실행

```powershell
# 빌드 후 실행
npm start

# 또는 직접 실행
node dist\index.js
```

### 방법 3: PM2 사용 (권장 - 백그라운드 실행)

```powershell
# PM2로 시작
pm2 start ecosystem.config.js

# 로그 확인
pm2 logs solar-collector

# 상태 확인
pm2 status

# 중지
pm2 stop solar-collector

# 재시작
pm2 restart solar-collector

# 삭제
pm2 delete solar-collector
```

### 방법 4: Windows 서비스로 등록

#### PM2를 Windows 서비스로 등록

```powershell
# 관리자 권한 PowerShell에서 실행
pm2 start ecosystem.config.js
pm2 save

# Windows 시작 시 자동 실행 설정
pm2-startup install
```

#### 작업 스케줄러 사용 (대안)

1. Windows 작업 스케줄러 열기
   - `Win + R` → `taskschd.msc` 입력

2. 기본 작업 만들기
   - 이름: "Solar Data Collector"
   - 트리거: "컴퓨터 시작 시"
   - 동작: 프로그램 시작
   - 프로그램/스크립트: `node.exe`
   - 인수 추가: `C:\mysolar\solar-data-collector\dist\index.js`
   - 시작 위치: `C:\mysolar\solar-data-collector`

## 📊 모니터링 및 로그

### 로그 파일 위치
```
C:\mysolar\solar-data-collector\logs\
├── app.log           # 애플리케이션 로그
├── error.log         # 에러 로그
├── pm2-out.log       # PM2 표준 출력
└── pm2-error.log     # PM2 에러 로그
```

### 실시간 로그 확인

```powershell
# PM2 로그 실시간 확인
pm2 logs solar-collector --lines 100

# PowerShell로 로그 파일 모니터링
Get-Content logs\app.log -Wait -Tail 50
```

### 데이터 수집 확인

```powershell
# MySQL Command Line Client가 설치된 경우
mysql -h 118.45.181.229 -u root -p

# 또는 PowerShell에서 테스트 스크립트 실행
node -e "
const mysql = require('mysql2/promise');
(async () => {
  const conn = await mysql.createConnection({
    host: '118.45.181.229',
    user: 'root',
    password: 'Qusrud8545!!@@',
    database: 'mysolar'
  });
  const [rows] = await conn.execute(
    'SELECT COUNT(*) as count FROM raw_inverter_data WHERE timestamp > DATE_SUB(NOW(), INTERVAL 1 HOUR)'
  );
  console.log('Last hour data points:', rows[0].count);
  await conn.end();
})();
"
```

## 🔧 문제 해결

### 1. npm install 실패

**증상**: `node-gyp` 또는 빌드 에러

**해결**:
```powershell
# Visual Studio Build Tools 설치
npm install -g windows-build-tools

# 캐시 정리 후 재시도
npm cache clean --force
npm install
```

### 2. Permission Denied 에러

**증상**: 파일 접근 권한 에러

**해결**:
- PowerShell을 관리자 권한으로 실행
- 안티바이러스 예외 설정에 프로젝트 폴더 추가

### 3. PM2 시작 실패

**증상**: PM2가 자동으로 시작되지 않음

**해결**:
```powershell
# PM2 재설치
npm uninstall -g pm2
npm install -g pm2
pm2 update

# 저장된 프로세스 목록 초기화
pm2 save --force
```

### 4. 데이터베이스 연결 실패

**증상**: ECONNREFUSED 또는 타임아웃

**해결**:
- Windows Defender 방화벽에서 3306 포트 허용
- VPN 연결 상태 확인
- 네트워크 연결 확인: `ping 118.45.181.229`

### 5. MQTT 연결 실패

**증상**: Connection timeout

**해결**:
- 인터넷 연결 확인
- HiveMQ 자격 증명 확인
- Windows Defender 방화벽에서 8883 포트 허용

## 🛡️ 보안 설정

### 방화벽 규칙 추가

```powershell
# 관리자 권한 PowerShell
# Node.js 허용
New-NetFirewallRule -DisplayName "Node.js" -Direction Outbound -Program "C:\Program Files\nodejs\node.exe" -Action Allow

# MQTT 포트 허용
New-NetFirewallRule -DisplayName "MQTT SSL" -Direction Outbound -Protocol TCP -LocalPort 8883 -Action Allow

# MariaDB 포트 허용
New-NetFirewallRule -DisplayName "MariaDB" -Direction Outbound -Protocol TCP -LocalPort 3306 -Action Allow
```

## 📦 배치 파일 생성 (선택사항)

### start-collector.bat
```batch
@echo off
cd /d C:\mysolar\solar-data-collector
echo Starting Solar Data Collector...
call npm run build
call pm2 start ecosystem.config.js
echo Solar Data Collector started!
pause
```

### stop-collector.bat
```batch
@echo off
echo Stopping Solar Data Collector...
call pm2 stop solar-collector
echo Solar Data Collector stopped!
pause
```

### view-logs.bat
```batch
@echo off
echo Solar Data Collector Logs:
echo ========================
call pm2 logs solar-collector --lines 50
pause
```

## 📌 빠른 시작 체크리스트

- [ ] Node.js 18+ 설치 완료
- [ ] npm 패키지 설치 완료 (`npm install`)
- [ ] .env 파일 설정 완료
- [ ] 데이터베이스 설정 완료 (`node scripts\setup-database.js`)
- [ ] 연결 테스트 성공 (`node scripts\test-connection.js`)
- [ ] TypeScript 빌드 완료 (`npm run build`)
- [ ] PM2 설치 완료 (`npm install -g pm2`)
- [ ] 서비스 실행 확인 (`pm2 start ecosystem.config.js`)
- [ ] 로그 확인 (`pm2 logs solar-collector`)


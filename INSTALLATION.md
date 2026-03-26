# Solar Data Collector - Windows 설치 가이드

MySolar 태양광 모니터링 시스템의 데이터 수집기를 Windows 환경에 설치하는 방법입니다.

## 📋 시스템 요구사항

### 필수 소프트웨어
- **Windows 10/11** 또는 **Windows Server 2019+**
- **Node.js 18.x 이상** ([다운로드](https://nodejs.org/))
- **Git** ([다운로드](https://git-scm.com/download/win))
- **MariaDB 11.x** (원격 서버 접속 가능)

### 네트워크 요구사항
- HiveMQ Cloud 접속 가능 (포트 8883)
- MariaDB 서버 접속 가능 (포트 3306)

---

## 🚀 설치 단계

### 1. Git 저장소 복제

```powershell
# 설치할 디렉토리로 이동
cd C:\

# 저장소 복제
git clone https://github.com/utonics/mysolar-data-collector.git

# 프로젝트 디렉토리로 이동
cd mysolar-data-collector
```

### 2. Node.js 의존성 설치

```powershell
# npm 패키지 설치
npm install
```

### 3. 환경 변수 설정

프로젝트 루트에 `.env` 파일을 생성합니다:

```powershell
# .env 파일 생성
notepad .env
```

다음 내용을 입력하고 저장합니다:

```env
# Application Configuration
NODE_ENV=production
DEVICE_ID=solar_system_001

# HiveMQ Cloud Configuration
HIVEMQ_HOST=----
HIVEMQ_PORT=8883
HIVEMQ_USERNAME=h----
HIVEMQ_PASSWORD=----
HIVEMQ_WS_PORT=8884

# MariaDB Configuration
MARIADB_HOST=----
MARIADB_PORT=3306
MARIADB_USER=----
MARIADB_PASSWORD=----
MARIADB_DATABASE=----

# Data Retention (days)
RETENTION_RAW_DATA=60
RETENTION_MINUTE_DATA=90
RETENTION_FIVE_MINUTE_DATA=180
```

⚠️ **보안 주의사항**:
- 실제 운영 환경에서는 비밀번호를 변경하세요
- `.env` 파일은 Git에 커밋하지 마세요 (이미 .gitignore에 포함됨)

### 4. TypeScript 빌드

```powershell
# TypeScript를 JavaScript로 컴파일
npm run build
```

### 5. 데이터베이스 초기화

#### 5.1 Stored Procedures 생성

```powershell
npm run setup-procedures
```

예상 출력:
```
✅ Found 9 stored procedures in database:
   - sp_aggregate_minute_data
   - sp_aggregate_five_minute_data
   - sp_aggregate_hourly_data
   - sp_aggregate_daily_data
   - sp_aggregate_monthly_data
   - sp_run_all_aggregations
```

#### 5.2 Processing Log 테이블 생성

```powershell
npm run create-processing-log
```

예상 출력:
```
✅ Table verified
🎉 processing_log table created successfully!
```

---

## ▶️ 애플리케이션 실행

### 개발 모드 (자동 재시작)

```powershell
npm run dev
```

### 프로덕션 모드

```powershell
npm start
```

### 정상 실행 확인

다음 로그가 표시되면 정상 작동 중입니다:

```
✓ Configuration validated successfully
✓ Database connection established
✓ MQTT collector started
✓ Data retention manager started
✓ Aggregation scheduler started
✓ Solar Data Collector started successfully
```

---

## 🔧 Windows 서비스로 등록 (선택사항)

프로그램을 백그라운드 서비스로 실행하려면:

### 방법 1: NSSM 사용 (권장)

1. **NSSM 다운로드 및 설치**
   ```powershell
   # Chocolatey가 설치되어 있다면
   choco install nssm

   # 또는 수동 다운로드: https://nssm.cc/download
   ```

2. **서비스 설치**
   ```powershell
   # 관리자 권한으로 PowerShell 실행
   nssm install SolarDataCollector "C:\Program Files\nodejs\node.exe" "C:\mysolar-data-collector\dist\index.js"

   # 작업 디렉토리 설정
   nssm set SolarDataCollector AppDirectory "C:\mysolar-data-collector"

   # 환경 변수 설정
   nssm set SolarDataCollector AppEnvironmentExtra NODE_ENV=production

   # 서비스 시작
   nssm start SolarDataCollector
   ```

3. **서비스 관리**
   ```powershell
   # 서비스 상태 확인
   nssm status SolarDataCollector

   # 서비스 중지
   nssm stop SolarDataCollector

   # 서비스 재시작
   nssm restart SolarDataCollector

   # 서비스 제거
   nssm remove SolarDataCollector confirm
   ```

### 방법 2: PM2 사용

1. **PM2 설치**
   ```powershell
   npm install -g pm2
   npm install -g pm2-windows-startup

   # Windows 시작 시 자동 실행 설정
   pm2-startup install
   ```

2. **애플리케이션 시작**
   ```powershell
   # PM2로 애플리케이션 실행
   pm2 start dist/index.js --name solar-collector

   # 현재 프로세스 저장
   pm2 save
   ```

3. **PM2 관리 명령어**
   ```powershell
   # 상태 확인
   pm2 status
   pm2 monit

   # 로그 확인
   pm2 logs solar-collector

   # 재시작
   pm2 restart solar-collector

   # 중지
   pm2 stop solar-collector

   # 삭제
   pm2 delete solar-collector
   ```

---

## 📊 로그 확인

로그 파일 위치:
```
C:\mysolar-data-collector\logs\
  ├── combined.log      # 모든 로그
  ├── error.log         # 에러 로그만
  ├── combined1.log     # 로테이션된 로그
  └── error1.log        # 로테이션된 에러 로그
```

실시간 로그 보기:
```powershell
# PowerShell에서
Get-Content logs\combined.log -Wait -Tail 50

# 또는 Git Bash에서
tail -f logs/combined.log
```

---

## 🔍 문제 해결

### 1. MQTT 연결 실패

```
Error: Connection refused
```

**해결 방법**:
- 방화벽에서 포트 8883 허용 확인
- HiveMQ Cloud 자격 증명 확인
- 인터넷 연결 확인

### 2. 데이터베이스 연결 실패

```
Error: Access denied for user
```

**해결 방법**:
- MariaDB 호스트/포트 확인
- 사용자명/비밀번호 확인
- 방화벽에서 포트 3306 허용 확인
- MariaDB 서버에서 원격 접속 허용 설정 확인

### 3. Stored Procedure 에러

```
ER_SP_DOES_NOT_EXIST
```

**해결 방법**:
```powershell
npm run setup-procedures
npm run create-processing-log
```

### 4. 포트 충돌

다른 애플리케이션이 필요한 포트를 사용 중인 경우:

```powershell
# 포트 사용 확인
netstat -ano | findstr :3306
netstat -ano | findstr :8883

# 프로세스 종료 (PID는 위 명령어 결과에서 확인)
taskkill /PID <프로세스ID> /F
```

---

## 🔄 업데이트

새 버전으로 업데이트:

```powershell
# 현재 실행 중이면 중지
pm2 stop solar-collector
# 또는 Ctrl+C로 중지

# 최신 코드 가져오기
git pull origin main

# 의존성 업데이트
npm install

# 빌드
npm run build

# 데이터베이스 업데이트 (필요한 경우)
npm run setup-procedures

# 재시작
npm start
# 또는 pm2 restart solar-collector
```

---



## 📝 추가 스크립트

```powershell
# 전체 집계 수동 실행 (테스트용)
npm run migrate

# 린트 검사
npm run lint

# 빌드만 (실행 안 함)
npm run build
```

---

## ⚙️ 고급 설정

### 데이터 보관 기간 변경

`.env` 파일에서 수정:

```env
# 원시 데이터: 60일
RETENTION_RAW_DATA=60

# 분단위 집계: 90일
RETENTION_MINUTE_DATA=90

# 5분단위 집계: 180일
RETENTION_FIVE_MINUTE_DATA=180
```

### 로그 레벨 변경

`src/config/config.ts` 파일에서 수정:

```typescript
logLevel: 'info'  // 'error' | 'warn' | 'info' | 'debug'
```

---

## ✅ 설치 완료 체크리스트

- [ ] Node.js 18+ 설치 확인
- [ ] Git 설치 확인
- [ ] 저장소 복제 완료
- [ ] npm install 완료
- [ ] .env 파일 생성 및 설정
- [ ] npm run build 완료
- [ ] npm run setup-procedures 실행
- [ ] npm run create-processing-log 실행
- [ ] 애플리케이션 정상 실행 확인
- [ ] MQTT 데이터 수신 확인
- [ ] 데이터베이스 저장 확인
- [ ] 로그 정상 기록 확인
- [ ] (선택) Windows 서비스 등록

모든 체크리스트를 완료하면 설치가 완료됩니다! 🎉

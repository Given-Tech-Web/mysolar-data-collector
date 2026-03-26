# Solar Data Collector

MySolar 태양광 모니터링 시스템의 데이터 수집 및 처리 서비스

## 📋 개요

HiveMQ Cloud MQTT 브로커로부터 실시간 태양광 인버터 데이터를 수집하고 MariaDB에 저장하는 Node.js 기반 데이터 수집기입니다.

## 🚀 주요 기능

- ✅ MQTT 실시간 데이터 수집 (HiveMQ Cloud)
- ✅ MariaDB 데이터 저장 및 관리
- ✅ 자동 데이터 집계 (분/5분/시간/일/월 단위)
- ✅ 데이터 보관 주기 관리
- ✅ 에러 로깅 및 모니터링

## 📦 설치

자세한 설치 방법은 [INSTALLATION.md](INSTALLATION.md)를 참고하세요.

### 빠른 시작

```bash
# 1. 의존성 설치
npm install

# 2. 환경 변수 설정
cp .env.example .env
# .env 파일을 편집하여 설정

# 3. 데이터베이스 초기화
npm run setup-procedures
npm run create-processing-log

# 4. 빌드 및 실행
npm run build
npm start
```

## 🔧 관리 명령어

### 애플리케이션 관리

```bash
# 실행 상태 확인
npm run app:status

# 앱 중지
npm run app:stop

# 개발 모드 실행
npm run dev

# 프로덕션 실행
npm start
```

### 데이터베이스 관리

```bash
# 데이터베이스 연결 테스트
npm run test-db

# Stored Procedures 설치/재설치
npm run setup-procedures

# 데이터베이스 문제 해결
npm run fix-db-issues

# Processing Log 테이블 생성
npm run create-processing-log
```

## 📖 문서

- [INSTALLATION.md](INSTALLATION.md) - Windows 환경 설치 가이드
- [APP_MANAGEMENT.md](APP_MANAGEMENT.md) - 앱 관리 및 모니터링 가이드

## 🗂️ 프로젝트 구조

```
solar-data-collector/
├── src/
│   ├── index.ts              # 애플리케이션 진입점
│   ├── config/               # 설정 관리
│   ├── database/             # 데이터베이스 연결 및 마이그레이션
│   ├── mqtt/                 # MQTT 클라이언트
│   ├── processing/           # 데이터 처리 로직
│   └── services/             # 비즈니스 로직
├── scripts/                  # 유틸리티 스크립트
│   ├── setup-procedures.ts   # Stored Procedures 설치
│   ├── fix-db-issues.ts      # DB 문제 해결
│   ├── test-db-connection.ts # DB 연결 테스트
│   ├── manage-app.sh         # 앱 관리 스크립트
│   └── stop-app.sh           # 앱 중지 스크립트
├── migrations/               # 데이터베이스 마이그레이션
├── logs/                     # 로그 파일
└── dist/                     # 빌드 출력
```

## 🔍 모니터링

### 로그 확인

```bash
# 실시간 로그 모니터링
tail -f logs/combined1.log

# 에러 로그만
tail -f logs/error.log

# 최근 로그 확인
tail -20 logs/combined1.log
```

### 시스템 상태

```bash
# 앱 실행 상태
npm run app:status

# 데이터베이스 상태
npm run test-db
```

## ⚙️ 환경 변수

`.env` 파일 설정 예시:

```env
# HiveMQ Cloud 설정
HIVEMQ_HOST=your-cluster.hivemq.cloud
HIVEMQ_PORT=8883
HIVEMQ_USERNAME=your-username
HIVEMQ_PASSWORD=your-password

# MariaDB 설정
MARIADB_HOST=your-db-host
MARIADB_PORT=3306
MARIADB_USER=root
MARIADB_PASSWORD=your-password
MARIADB_DATABASE=mysolar

# 애플리케이션 설정
NODE_ENV=production
DEVICE_ID=solar_system_001
```

## 🛠️ 문제 해결

일반적인 문제 해결 방법은 [APP_MANAGEMENT.md](APP_MANAGEMENT.md)를 참고하세요.

### 자주 발생하는 문제

1. **데이터베이스 연결 실패**
   ```bash
   npm run test-db
   ```

2. **Stored Procedure 에러**
   ```bash
   npm run fix-db-issues
   npm run setup-procedures
   ```

3. **앱이 중지되지 않음**
   ```bash
   npm run app:stop
   # 또는 강제 종료
   taskkill /IM node.exe /F
   ```

## 📊 데이터 파이프라인

```
MQTT (HiveMQ Cloud)
    ↓
Raw Data Storage (raw_inverter_data)
    ↓
Aggregation (Stored Procedures)
    ├─ Minute Data
    ├─ 5-Minute Data
    ├─ Hourly Data
    ├─ Daily Data
    └─ Monthly Data
```

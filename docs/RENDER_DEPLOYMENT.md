# Render 배포 가이드

Solar Data Collector를 Render 플랫폼에 배포하는 방법입니다.

## 목차

- [개요](#개요)
- [사전 요구사항](#사전-요구사항)
- [배포 절차](#배포-절차)
- [환경 변수 설정](#환경-변수-설정)
- [데이터베이스 초기화](#데이터베이스-초기화)
- [배포 확인](#배포-확인)
- [모니터링](#모니터링)
- [트러블슈팅](#트러블슈팅)
- [비용](#비용)

---

## 개요

| 항목 | 값 |
|------|-----|
| 서비스 타입 | Background Worker |
| 런타임 | Docker |
| 리전 | Singapore (한국에서 가장 가까움) |
| 권장 플랜 | Starter ($7/월) |

### 왜 Render인가?

- **Background Worker 지원**: MQTT 수집기와 같은 웹 서버 없는 장기 실행 프로세스 지원
- **Docker 네이티브**: 기존 Dockerfile 그대로 사용
- **자동 배포**: GitHub 연동으로 푸시 시 자동 배포
- **합리적인 가격**: Starter 플랜 $7/월로 항시 실행

---

## 사전 요구사항

1. **Render 계정**: https://render.com 에서 가입
2. **GitHub 저장소**: 소스 코드가 GitHub에 있어야 함
3. **HiveMQ Cloud**: MQTT 브로커 설정 완료
4. **MariaDB**: 외부 접근 가능한 데이터베이스

---

## 배포 절차

### Step 1: Render 서비스 생성

1. [Render Dashboard](https://dashboard.render.com) 로그인
2. **New +** 버튼 클릭
3. **Background Worker** 선택
4. GitHub 저장소 연결

### Step 2: 서비스 설정

| 설정 | 값 |
|------|-----|
| Name | `solar-data-collector` |
| Region | `Singapore (Southeast Asia)` |
| Branch | `main` |
| Runtime | `Docker` |
| Dockerfile Path | `./Dockerfile` |
| Plan | `Starter` |

### Step 3: render.yaml 사용 (Blueprint)

저장소에 `render.yaml` 파일이 있으면 Render가 자동으로 설정을 인식합니다.

**Blueprint로 배포하기:**
1. Dashboard > **Blueprints** 탭
2. **New Blueprint Instance**
3. 저장소 선택
4. 환경 변수 설정 후 배포

---

## 환경 변수 설정

Render Dashboard > Service > **Environment** 탭에서 설정합니다.

### 필수 변수 (Secret)

```
HIVEMQ_HOST=your-cluster.hivemq.cloud
HIVEMQ_USERNAME=your-mqtt-username
HIVEMQ_PASSWORD=your-mqtt-password

MARIADB_HOST=your-db-host.com
MARIADB_USER=your-db-user
MARIADB_PASSWORD=your-db-password
```

### 선택 변수 (기본값 사용 가능)

`render.yaml`에 기본값이 정의되어 있어 별도 설정 불필요:

- `HIVEMQ_PORT`: 8883
- `MARIADB_PORT`: 3306
- `MARIADB_DATABASE`: mysolar
- `NODE_ENV`: production
- `LOG_LEVEL`: info

전체 목록은 `.env.render.example` 참조

---

## 데이터베이스 초기화

**최초 배포 전** 로컬에서 한 번 실행합니다.

### 1. 환경 변수 설정

```bash
export MARIADB_HOST=your-db-host
export MARIADB_PORT=3306
export MARIADB_USER=your-user
export MARIADB_PASSWORD=your-password
export MARIADB_DATABASE=mysolar
```

### 2. 테이블 및 프로시저 설치

```bash
# 저장 프로시저 설치
npm run setup-procedures

# processing_log 테이블 생성
npm run create-processing-log

# 연결 테스트
npm run test-db
```

### 3. 설치 확인

```sql
-- 테이블 확인
SHOW TABLES LIKE 'solar%';

-- 프로시저 확인
SHOW PROCEDURE STATUS WHERE Db = 'mysolar';
```

---

## 배포 확인

### 로그 확인

Render Dashboard > Service > **Logs** 탭

**정상 시작 로그:**
```
[INFO] Configuration loaded successfully
[INFO] Database connection established
[INFO] Connected to HiveMQ MQTT broker
[INFO] Subscribed to topics: solar/+/data, solar/+/status
[INFO] Data retention manager started
[INFO] Aggregation scheduler started
```

### 데이터 수집 확인

```sql
-- 최근 원시 데이터
SELECT * FROM solar_raw_data
ORDER BY created_at DESC LIMIT 5;

-- 최근 집계 데이터
SELECT * FROM solar_minute_data
ORDER BY timestamp DESC LIMIT 5;
```

---

## 모니터링

### Render 대시보드

- **Logs**: 실시간 로그 스트리밍
- **Metrics**: CPU, 메모리 사용량
- **Events**: 배포, 재시작 이벤트

### 헬스체크

Dockerfile에 정의된 헬스체크가 30초마다 실행됩니다:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD node -e "console.log('healthy')" || exit 1
```

### 알림 설정

Render Dashboard > Account Settings > **Notifications**에서 이메일/Slack 알림 설정

---

## 트러블슈팅

### MQTT 연결 실패

```
Error: Connection refused
```

**해결:**
1. `HIVEMQ_HOST`, `HIVEMQ_USERNAME`, `HIVEMQ_PASSWORD` 확인
2. HiveMQ Cloud 콘솔에서 자격 증명 확인
3. 포트 8883(TLS) 사용 확인

### 데이터베이스 연결 실패

```
Error: Access denied for user
```

**해결:**
1. `MARIADB_*` 환경 변수 확인
2. DB 서버의 외부 접근 허용 확인
3. 방화벽에서 Render IP 허용

### 메모리 부족

```
FATAL ERROR: CALL_AND_RETRY_LAST Allocation failed
```

**해결:**
1. 플랜 업그레이드 (Starter → Standard)
2. `BATCH_SIZE` 감소 (100 → 50)
3. 메모리 누수 확인

### 배포 실패

```
Build failed
```

**해결:**
1. 로컬에서 Docker 빌드 테스트: `docker build -t test .`
2. `package-lock.json` 커밋 확인
3. TypeScript 컴파일 오류 확인

---

## 비용

| 플랜 | 가격 | RAM | 특징 |
|------|------|-----|------|
| Free | $0 | 512MB | 750시간/월, 비활성 시 중지 |
| **Starter** | **$7/월** | **512MB** | **항시 실행, 권장** |
| Standard | $25/월 | 2GB | 대용량 처리 |

### 권장 플랜

**Starter ($7/월)** - MQTT 데이터 수집기는 항시 실행이 필요하므로 Free 플랜은 부적합합니다.

---

## 관련 문서

- [Docker 가이드](./DOCKER_GUIDE.md)
- [Railway 배포 가이드](./RAILWAY_DEPLOYMENT_GUIDE.md)
- [클라우드 배포 옵션](./CLOUD_DEPLOYMENT_OPTIONS.md)
- [Render 공식 문서](https://render.com/docs)

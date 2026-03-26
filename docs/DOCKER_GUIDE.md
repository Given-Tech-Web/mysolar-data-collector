# 🐳 Docker 배포 가이드

Solar Data Collector를 Docker 컨테이너로 실행하는 가이드입니다.

---

## 📋 목차

1. [사전 준비](#-사전-준비)
2. [빠른 시작](#-빠른-시작)
3. [상세 사용법](#-상세-사용법)
4. [클라우드 배포](#-클라우드-배포)
5. [문제 해결](#-문제-해결)

---

## 🔧 사전 준비

### Docker 설치

#### Windows
```powershell
# Docker Desktop 다운로드
https://www.docker.com/products/docker-desktop/

# 또는 winget으로 설치
winget install Docker.DockerDesktop
```

#### Linux (Ubuntu)
```bash
# Docker 설치
curl -fsSL https://get.docker.com | sh

# 현재 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER

# Docker Compose 설치 (최신 버전)
sudo apt install docker-compose-plugin
```

#### 설치 확인
```bash
docker --version
docker compose version
```

---

## ⚡ 빠른 시작

### 1. 환경 변수 설정

`.env` 파일이 설정되어 있는지 확인:

```bash
# .env 파일 확인
cat .env
```

### 2. Docker Compose로 실행

```bash
# 빌드 및 실행 (백그라운드)
docker compose up -d --build

# 로그 확인
docker compose logs -f

# 중지
docker compose down
```

### 3. 상태 확인

```bash
# 컨테이너 상태
docker compose ps

# 리소스 사용량
docker stats solar-data-collector
```

---

## 📖 상세 사용법

### Docker 명령어 (Compose 없이)

#### 이미지 빌드
```bash
docker build -t solar-data-collector:latest .
```

#### 컨테이너 실행
```bash
docker run -d \
  --name solar-collector \
  --restart unless-stopped \
  --env-file .env \
  -v $(pwd)/logs:/app/logs \
  solar-data-collector:latest
```

#### 컨테이너 관리
```bash
# 로그 확인
docker logs -f solar-collector

# 컨테이너 접속
docker exec -it solar-collector sh

# 중지
docker stop solar-collector

# 삭제
docker rm solar-collector
```

---

### Docker Compose 명령어

#### 기본 명령어
```bash
# 빌드 + 실행
docker compose up -d --build

# 로그 실시간 확인
docker compose logs -f

# 재시작
docker compose restart

# 중지 (컨테이너 유지)
docker compose stop

# 중지 + 삭제
docker compose down

# 중지 + 삭제 + 볼륨 삭제
docker compose down -v
```

#### 업데이트 배포
```bash
# 최신 코드로 재빌드
git pull
docker compose up -d --build
```

---

## ☁️ 클라우드 배포

### AWS / DigitalOcean / Vultr

#### 1. 서버에 Docker 설치
```bash
# Ubuntu 서버에서
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

#### 2. 프로젝트 복제
```bash
git clone https://github.com/your-repo/solar-data-collector.git
cd solar-data-collector
```

#### 3. 환경 변수 설정
```bash
cp .env.example .env
nano .env  # 또는 vim .env
```

#### 4. 실행
```bash
docker compose up -d --build
```

---

### Oracle Cloud Free Tier

#### 1. ARM 인스턴스 생성
- Shape: VM.Standard.A1.Flex
- OCPU: 1-4 (무료)
- Memory: 6-24GB (무료)
- OS: Ubuntu 22.04

#### 2. Docker 설치
```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker ubuntu
```

#### 3. 방화벽 설정
```bash
# iptables 규칙 (Oracle Cloud)
sudo iptables -I INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

#### 4. 배포
```bash
git clone https://github.com/your-repo/solar-data-collector.git
cd solar-data-collector
cp .env.example .env
nano .env
docker compose up -d --build
```

---

## 📊 모니터링

### 로그 확인
```bash
# 실시간 로그
docker compose logs -f

# 최근 100줄
docker compose logs --tail 100

# 특정 시간 이후
docker compose logs --since 1h
```

### 리소스 모니터링
```bash
# CPU, 메모리 사용량
docker stats solar-data-collector

# 상세 정보
docker inspect solar-data-collector
```

### 헬스체크 상태
```bash
docker inspect --format='{{.State.Health.Status}}' solar-data-collector
```

---

## 🛠️ 문제 해결

### 1. 빌드 실패

#### 증상: npm install 오류
```bash
# 캐시 없이 재빌드
docker compose build --no-cache
```

### 2. 컨테이너 즉시 종료

#### 확인 방법
```bash
# 종료 로그 확인
docker compose logs

# 컨테이너 상태 확인
docker compose ps -a
```

#### 일반적인 원인
- 환경 변수 누락 → `.env` 파일 확인
- MQTT 연결 실패 → HiveMQ 설정 확인
- DB 연결 실패 → MariaDB 접근 권한 확인

### 3. 메모리 부족

#### 해결 방법
```yaml
# docker-compose.yml에서 메모리 제한 조정
deploy:
  resources:
    limits:
      memory: 1G  # 증가
```

### 4. 네트워크 오류

#### 호스트 네트워크 모드 사용
```yaml
# docker-compose.yml
services:
  solar-collector:
    network_mode: host
```

---

## 📁 파일 구조

```
solar-data-collector/
├── Dockerfile          # Docker 이미지 정의
├── docker-compose.yml  # Compose 설정
├── .dockerignore       # 빌드 제외 파일
├── .env                # 환경 변수 (git 제외)
├── .env.example        # 환경 변수 예시
├── package.json
├── tsconfig.json
├── src/                # 소스 코드
├── dist/               # 빌드 결과 (컨테이너 내부)
└── logs/               # 로그 (볼륨 마운트)
```

---

## 🔄 자동 시작 설정

### Docker 서비스 자동 시작 (Linux)
```bash
sudo systemctl enable docker
```

### 컨테이너 자동 시작
`docker-compose.yml`에 이미 설정됨:
```yaml
restart: unless-stopped
```

---

## 💡 팁

### 이미지 크기 최적화
```bash
# 이미지 크기 확인
docker images solar-data-collector

# 멀티스테이지 빌드로 약 ~150MB 달성
```

### 로그 관리
```yaml
# docker-compose.yml의 로깅 설정
logging:
  driver: "json-file"
  options:
    max-size: "10m"   # 파일당 최대 10MB
    max-file: "3"     # 최대 3개 파일
```

### 프로덕션 체크리스트
- [ ] `.env` 파일에 실제 값 설정
- [ ] `restart: unless-stopped` 확인
- [ ] 로그 볼륨 마운트 확인
- [ ] 리소스 제한 설정
- [ ] 헬스체크 동작 확인


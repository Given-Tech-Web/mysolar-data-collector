# 🚀 Solar Data Collector - Windows 11 빠른 시작 가이드

## 1️⃣ 초간단 설치 (5분 소요)

### 필수 프로그램 설치
1. **Node.js 설치** (없는 경우만)
   - https://nodejs.org/ 에서 LTS 버전 다운로드
   - 설치 시 모든 기본 옵션 선택

### Solar Data Collector 설치

1. **Windows 탐색기**에서 폴더 열기:
   ```
   C:\mysolar\solar-data-collector
   ```

2. **setup-windows.bat** 더블클릭 실행
   - 자동으로 모든 설정 진행
   - .env 파일 편집 창이 뜨면 비밀번호 확인 후 저장

## 2️⃣ 실행 방법 (택 1)

### 방법 A: 간단 실행 (추천 ⭐)
1. `scripts` 폴더 열기
2. **start-collector.bat** 더블클릭
3. 검은 창이 뜨고 데이터 수집 시작

### 방법 B: 백그라운드 실행 (PM2)
1. `scripts` 폴더 열기
2. **start-pm2.bat** 더블클릭
3. 백그라운드에서 자동 실행

## 3️⃣ 동작 확인

### 로그 보기
- **view-logs.bat** 더블클릭
- 실시간 데이터 수집 로그 확인

### 정상 동작 메시지
```
✅ Connected to MQTT broker successfully
✅ Database connection established
📈 Processing batch of 100 inverter records
✅ Successfully stored 100 inverter records
```

## 4️⃣ 종료 방법

- **일반 실행**: 검은 창에서 `Ctrl + C`
- **PM2 실행**: **stop-collector.bat** 더블클릭

## ❓ 문제 해결

### "Node.js를 찾을 수 없습니다"
→ Node.js 설치 필요 (https://nodejs.org/)

### "연결 실패" 메시지
→ .env 파일의 비밀번호 확인
```
HIVEMQ_PASSWORD=여기에_정확한_비밀번호
MARIADB_PASSWORD=여기에_정확한_비밀번호
```

### "Permission Denied" 오류
→ 관리자 권한으로 실행
1. 배치 파일 우클릭
2. "관리자 권한으로 실행" 선택

## 📁 폴더 구조
```
solar-data-collector/
├── scripts/
│   ├── setup-windows.bat    ← 초기 설정 (처음 한번만)
│   ├── start-collector.bat  ← 실행
│   ├── stop-collector.bat   ← 중지
│   └── view-logs.bat        ← 로그 보기
├── .env                      ← 설정 파일
└── logs/                     ← 로그 파일 저장
```

## ✅ 체크리스트

- [ ] Node.js 설치 확인 (cmd에서 `node --version`)
- [ ] setup-windows.bat 실행 완료
- [ ] .env 파일 비밀번호 설정
- [ ] start-collector.bat 실행
- [ ] 로그에서 "Successfully stored" 메시지 확인

---

**도움말**: 문제가 있으면 `logs` 폴더의 로그 파일을 확인하세요.
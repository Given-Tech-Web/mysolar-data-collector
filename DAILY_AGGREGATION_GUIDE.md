# daily_inverter_stats 테이블 자동 업데이트 가이드

## 📊 개요

`daily_inverter_stats` 테이블은 일별 태양광 발전 통계를 저장하는 집계 테이블입니다.
이 테이블은 **자동으로 업데이트**되며, 필요시 수동으로도 실행할 수 있습니다.

## 🔄 자동 업데이트 프로세스

### 1. 업데이트 시점

**매일 새벽 00:05 (자정 5분 후)**
- 전날 데이터를 완전히 집계
- 오늘 데이터도 부분적으로 집계 (실시간 모니터링용)

### 2. 데이터 흐름

```
[raw_inverter_data] (실시간 30초 데이터)
       ↓
[매일 00:05 스케줄러 실행]
       ↓
[sp_aggregate_daily_data 프로시저 호출]
       ↓
[daily_inverter_stats 업데이트]
```

### 3. 집계 내용

| 필드 | 설명 | 계산 방법 |
|------|------|-----------|
| `avg_battery_capacity` | 평균 배터리 용량 | AVG(battery_capacity) |
| `max_pv1_charging_power` | 최대 발전 출력 | MAX(pv1_charging_power) |
| `total_energy_generated` | 총 발전량 (kWh) | SUM(pv1_charging_power) / 1000 / 120 |
| `total_carbon_reduction` | 탄소 절감량 (kg) | total_energy * 0.4781 |
| `generator_runtime_hours` | 발전기 가동 시간 | COUNT(ac_voltage > 200) / 120 |

## ✅ 자동 업데이트 확인

### Solar Data Collector가 실행 중일 때

1. **스케줄러 상태 확인**
```bash
pm2 logs solar-collector --lines 100 | grep "Daily aggregation"
```

2. **로그 메시지 확인**
- 성공: `Daily aggregation completed`
- 실패: `Daily aggregation failed`

### 데이터베이스에서 직접 확인

```sql
-- 최근 7일 데이터 확인
SELECT
    date,
    total_energy_generated,
    total_carbon_reduction,
    avg_battery_capacity,
    created_at
FROM daily_inverter_stats
WHERE device_id = 'solar_system_001'
ORDER BY date DESC
LIMIT 7;
```

## 🔧 수동 실행 방법

### 방법 1: 수동 집계 스크립트 사용 (권장)

```bash
# 어제 데이터 집계
node scripts/manual-daily-aggregation.js

# 특정 날짜 집계
node scripts/manual-daily-aggregation.js 2025-09-18

# 오늘 데이터 집계 (부분)
node scripts/manual-daily-aggregation.js --today

# 지난 7일 집계
node scripts/manual-daily-aggregation.js --week

# 지난 30일 집계
node scripts/manual-daily-aggregation.js --month
```

### 방법 2: SQL 직접 실행

```sql
-- 특정 날짜 집계
CALL sp_aggregate_daily_data('solar_system_001', '2025-09-18');

-- 어제 집계
CALL sp_aggregate_daily_data('solar_system_001', DATE_SUB(CURDATE(), INTERVAL 1 DAY));

-- 오늘 집계 (부분)
CALL sp_aggregate_daily_data('solar_system_001', CURDATE());
```

### 방법 3: Node.js 코드에서 실행

```javascript
const mysql = require('mysql2/promise');

async function aggregateDaily(date) {
    const connection = await mysql.createConnection({
        host: '118.45.181.229',
        user: 'root',
        password: 'Qusrud8545!!@@',
        database: 'mysolar'
    });

    await connection.execute(
        'CALL sp_aggregate_daily_data(?, ?)',
        ['solar_system_001', date]
    );

    await connection.end();
}

// 사용 예
aggregateDaily('2025-09-18');
```

## ⚙️ 스케줄러 설정 확인

### 현재 설정
- **파일**: `src/schedulers/aggregation-scheduler.ts`
- **시간**: 매일 00:05 (라인 26)
```typescript
const dailyTask = cron.schedule('5 0 * * *', async () => {
    await this.runDailyAggregation();
});
```

### Cron 표현식 설명
- `5 0 * * *` = 분(5) 시(0) 일(*) 월(*) 요일(*)
- 즉, 매일 0시 5분

## 🚨 문제 해결

### 1. 자동 업데이트가 안 될 때

**원인 1**: Solar Data Collector가 실행되지 않음
```bash
# 상태 확인
pm2 status

# 시작
pm2 start ecosystem.config.js
```

**원인 2**: 데이터베이스 연결 문제
```bash
# 연결 테스트
node scripts/test-connection.js
```

**원인 3**: Stored Procedure가 없음
```bash
# 프로시저 재생성
node scripts/setup-database.js
```

### 2. 데이터가 잘못된 경우

**재집계 방법**:
```sql
-- 기존 데이터 삭제
DELETE FROM daily_inverter_stats
WHERE device_id = 'solar_system_001'
AND date = '2025-09-18';

-- 다시 집계
CALL sp_aggregate_daily_data('solar_system_001', '2025-09-18');
```

### 3. 누락된 날짜 채우기

```bash
# 지난 30일 전체 재집계
node scripts/manual-daily-aggregation.js --month
```

## 📅 일일 데이터 처리 타임라인

| 시간 | 작업 | 설명 |
|------|------|------|
| 00:00 | 날짜 변경 | 새로운 날 시작 |
| 00:05 | **일별 집계 실행** | 전날 데이터 최종 집계 |
| 00:10 | 월별 집계 (1일만) | 전월 데이터 집계 |
| 02:00 | 데이터 보존 정책 | 오래된 raw 데이터 삭제 |

## 📊 집계 데이터 검증

### 정상 동작 확인 쿼리

```sql
-- 일별 발전량 추이
SELECT
    date,
    total_energy_generated as 'kWh',
    total_carbon_reduction as 'CO2(kg)',
    avg_battery_capacity as 'Battery(%)',
    generator_runtime_hours as 'Generator(h)'
FROM daily_inverter_stats
WHERE device_id = 'solar_system_001'
    AND date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
ORDER BY date DESC;

-- 데이터 완성도 확인
SELECT
    date,
    COUNT(*) as raw_data_points,
    ROUND(COUNT(*) / 2880 * 100, 1) as completeness_percent
FROM raw_inverter_data
WHERE device_id = 'solar_system_001'
    AND DATE(timestamp) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY DATE(timestamp)
ORDER BY date DESC;
```

## 📝 요약

✅ **자동 업데이트**: 매일 00:05 자동 실행
✅ **수동 실행**: `manual-daily-aggregation.js` 스크립트 사용
✅ **데이터 검증**: SQL 쿼리로 확인
✅ **문제 해결**: PM2 상태 확인, 연결 테스트, 재집계

**중요**: Solar Data Collector가 실행 중이어야 자동 업데이트가 작동합니다!
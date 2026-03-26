#!/usr/bin/env node

/**
 * Manual Daily Aggregation Script
 *
 * 수동으로 daily_inverter_stats 테이블을 업데이트하는 스크립트
 *
 * 사용법:
 * node scripts/manual-daily-aggregation.js              # 어제 데이터 집계
 * node scripts/manual-daily-aggregation.js 2025-09-18   # 특정 날짜 집계
 * node scripts/manual-daily-aggregation.js --week       # 지난 7일 집계
 * node scripts/manual-daily-aggregation.js --month      # 지난 30일 집계
 */

const mysql = require('mysql2/promise');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const dbConfig = {
  host: process.env.MARIADB_HOST,
  port: process.env.MARIADB_PORT,
  user: process.env.MARIADB_USER,
  password: process.env.MARIADB_PASSWORD,
  database: process.env.MARIADB_DATABASE
};

async function aggregateDailyData(date) {
  let connection;

  try {
    connection = await mysql.createConnection(dbConfig);
    console.log(`📊 Aggregating data for ${date}...`);

    // Call stored procedure
    await connection.execute(
      'CALL sp_aggregate_daily_data(?, ?)',
      [process.env.DEVICE_ID || 'solar_system_001', date]
    );

    // Verify the update
    const [rows] = await connection.execute(
      'SELECT * FROM daily_inverter_stats WHERE device_id = ? AND date = ?',
      [process.env.DEVICE_ID || 'solar_system_001', date]
    );

    if (rows.length > 0) {
      const stats = rows[0];
      console.log(`✅ Successfully updated daily_inverter_stats for ${date}`);
      console.log(`   - Total Energy: ${stats.total_energy_generated?.toFixed(2)} kWh`);
      console.log(`   - Max Power: ${stats.max_pv1_charging_power} W`);
      console.log(`   - Avg Battery: ${stats.avg_battery_capacity?.toFixed(1)}%`);
      console.log(`   - Carbon Saved: ${stats.total_carbon_reduction?.toFixed(2)} kg`);
      console.log(`   - Generator Hours: ${stats.generator_runtime_hours?.toFixed(1)} h`);
    } else {
      console.log(`⚠️ No data found for ${date}`);
    }

    return true;
  } catch (error) {
    console.error(`❌ Error processing ${date}:`, error.message);
    return false;
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

async function aggregateMultipleDays(days) {
  const dates = [];
  const today = new Date();

  for (let i = 1; i <= days; i++) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    dates.push(date.toISOString().split('T')[0]);
  }

  console.log(`📅 Processing ${dates.length} days...`);
  console.log('═══════════════════════════════════════');

  let successCount = 0;
  for (const date of dates) {
    const success = await aggregateDailyData(date);
    if (success) successCount++;
    console.log('─────────────────────────────────────');
  }

  console.log('═══════════════════════════════════════');
  console.log(`📊 Summary: ${successCount}/${dates.length} days processed successfully`);
}

async function checkExistingData() {
  let connection;

  try {
    connection = await mysql.createConnection(dbConfig);

    // Check recent daily_inverter_stats
    const [stats] = await connection.execute(
      `SELECT
        date,
        total_energy_generated,
        total_carbon_reduction,
        avg_battery_capacity
      FROM daily_inverter_stats
      WHERE device_id = ?
      ORDER BY date DESC
      LIMIT 7`,
      [process.env.DEVICE_ID || 'solar_system_001']
    );

    console.log('\n📋 Current daily_inverter_stats (last 7 days):');
    console.log('═══════════════════════════════════════════════');

    if (stats.length > 0) {
      stats.forEach(row => {
        console.log(`📅 ${row.date.toISOString().split('T')[0]}: ` +
          `${row.total_energy_generated?.toFixed(2)} kWh | ` +
          `${row.total_carbon_reduction?.toFixed(2)} kg CO₂ | ` +
          `Battery: ${row.avg_battery_capacity?.toFixed(1)}%`);
      });
    } else {
      console.log('No data found in daily_inverter_stats');
    }

    console.log('═══════════════════════════════════════════════\n');

  } catch (error) {
    console.error('Error checking existing data:', error.message);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);

  console.log('🚀 Solar Data Collector - Manual Daily Aggregation');
  console.log('═══════════════════════════════════════════════════');

  // First, show current status
  await checkExistingData();

  if (args.length === 0) {
    // Default: aggregate yesterday's data
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dateStr = yesterday.toISOString().split('T')[0];
    await aggregateDailyData(dateStr);

  } else if (args[0] === '--week') {
    // Aggregate last 7 days
    await aggregateMultipleDays(7);

  } else if (args[0] === '--month') {
    // Aggregate last 30 days
    await aggregateMultipleDays(30);

  } else if (args[0] === '--today') {
    // Aggregate today's data (partial)
    const today = new Date().toISOString().split('T')[0];
    await aggregateDailyData(today);

  } else if (args[0].match(/^\d{4}-\d{2}-\d{2}$/)) {
    // Aggregate specific date
    await aggregateDailyData(args[0]);

  } else {
    console.log('\n📖 Usage:');
    console.log('  node manual-daily-aggregation.js              # Yesterday');
    console.log('  node manual-daily-aggregation.js 2025-09-18   # Specific date');
    console.log('  node manual-daily-aggregation.js --today      # Today (partial)');
    console.log('  node manual-daily-aggregation.js --week       # Last 7 days');
    console.log('  node manual-daily-aggregation.js --month      # Last 30 days');
  }

  console.log('\n✨ Done!');
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
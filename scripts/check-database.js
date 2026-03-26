#!/usr/bin/env node

/**
 * Database Check Script
 * This script checks if the database tables already exist
 * Used to prevent accidental data loss during installation
 *
 * Exit codes:
 * 0 - Database needs initialization (safe to run setup)
 * 1 - Database structure exists but empty
 * 2 - Database has data (WARNING: setup will cause data loss)
 * 3 - Connection error
 */

const mysql = require('mysql2/promise');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function checkDatabase() {
  let connection;

  try {
    console.log('🔄 Checking database status...');
    connection = await mysql.createConnection({
      host: process.env.MARIADB_HOST,
      port: process.env.MARIADB_PORT,
      user: process.env.MARIADB_USER,
      password: process.env.MARIADB_PASSWORD,
      database: process.env.MARIADB_DATABASE
    });

    console.log('✅ Connected to MariaDB successfully');
    console.log(`   Server: ${process.env.MARIADB_HOST}:${process.env.MARIADB_PORT}`);
    console.log(`   Database: ${process.env.MARIADB_DATABASE}`);

    // Check critical tables
    const criticalTables = [
      'raw_inverter_data',
      'daily_inverter_stats'
    ];

    const aggregationTables = [
      'minute_data',
      'five_minute_data',
      'hourly_data',
      'daily_data',
      'monthly_data'
    ];

    let hasData = false;
    let hasStructure = false;
    let totalRecords = 0;

    console.log('\n📊 Checking critical tables:');
    for (const table of criticalTables) {
      const [rows] = await connection.execute(
        `SELECT COUNT(*) as count FROM information_schema.tables
         WHERE table_schema = ? AND table_name = ?`,
        [process.env.MARIADB_DATABASE, table]
      );

      if (rows[0].count > 0) {
        hasStructure = true;
        // Table exists, get record count
        const [countRows] = await connection.execute(
          `SELECT COUNT(*) as count FROM ${table}`
        );
        const recordCount = countRows[0].count;
        totalRecords += recordCount;
        if (recordCount > 0) hasData = true;
        console.log(`   ✅ ${table}: ${recordCount.toLocaleString()} records`);
      } else {
        console.log(`   ❌ ${table}: NOT FOUND`);
      }
    }

    // Check aggregation tables
    console.log('\n📊 Checking aggregation tables:');
    for (const table of aggregationTables) {
      const [rows] = await connection.execute(
        `SELECT COUNT(*) as count FROM information_schema.tables
         WHERE table_schema = ? AND table_name = ?`,
        [process.env.MARIADB_DATABASE, table]
      );

      if (rows[0].count > 0) {
        const [countRows] = await connection.execute(
          `SELECT COUNT(*) as count FROM ${table}`
        );
        console.log(`   ✅ ${table}: ${countRows[0].count.toLocaleString()} records`);
      } else {
        console.log(`   ⚠️  ${table}: NOT FOUND (will be created)`);
      }
    }

    // Check stored procedures
    const [procedures] = await connection.execute(
      `SELECT COUNT(*) as count FROM information_schema.ROUTINES
       WHERE ROUTINE_SCHEMA = ? AND ROUTINE_NAME = 'sp_aggregate_daily_data'`,
      [process.env.MARIADB_DATABASE]
    );
    const hasProcedures = procedures[0].count > 0;
    console.log(`\n📦 Stored procedures: ${hasProcedures ? '✅ Found' : '⚠️  Not found (will be created)'}`);

    // Show recent data if exists
    if (hasData) {
      console.log('\n📈 Recent data (last 3 records):');
      try {
        const [recentData] = await connection.execute(
          `SELECT device_id, timestamp, pv1_charging_power, battery_capacity
           FROM raw_inverter_data
           ORDER BY timestamp DESC
           LIMIT 3`
        );

        recentData.forEach(row => {
          console.log(`   ${row.timestamp}: Power=${row.pv1_charging_power}W, Battery=${row.battery_capacity}%`);
        });
      } catch (e) {
        // Ignore if columns don't exist
      }
    }

    // Determine action based on status
    console.log('\n' + '='.repeat(60));
    if (hasData) {
      console.log('⚠️  WARNING: Database contains existing data!');
      console.log(`   Total records: ${totalRecords.toLocaleString()}`);
      console.log('\n   DO NOT run setup-database.js - it may cause data loss!');
      console.log('   The database is already in use by other applications.');
      console.log('\n   Safe actions:');
      console.log('   - Run the collector to add new data');
      console.log('   - Use manual-daily-aggregation.js for aggregations');
      console.log('   - Check data with check-database.js');
      process.exit(2); // Exit code 2: Has data
    } else if (hasStructure) {
      console.log('✅ Database structure exists but no data yet.');
      console.log('   You can safely run the collector.');
      process.exit(1); // Exit code 1: Structure exists, no data
    } else {
      console.log('✅ Database needs initialization.');
      console.log('   Run setup-database.js to create tables and procedures.');
      process.exit(0); // Exit code 0: Safe to initialize
    }

  } catch (error) {
    console.error('❌ Database error:', error.message);
    if (error.code === 'ER_BAD_DB_ERROR') {
      console.log('   Database does not exist. Please create it first.');
    } else if (error.code === 'ECONNREFUSED') {
      console.log('   Cannot connect to MariaDB server. Check if it\'s running.');
    } else if (error.code === 'ER_NO_SUCH_TABLE') {
      console.log('   Tables not found. Safe to run setup-database.js');
      process.exit(0); // Safe to initialize
    }
    process.exit(3); // Exit code 3: Connection error
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

checkDatabase();
#!/usr/bin/env tsx

/**
 * Test database connection and verify structure
 */

import { createConnection } from 'mysql2/promise';
import { config } from 'dotenv';

config();

const DB_CONFIG = {
  host: process.env.MARIADB_HOST || '220.69.222.151',
  port: Number(process.env.MARIADB_PORT) || 3306,
  user: process.env.MARIADB_USER || 'root',
  password: process.env.MARIADB_PASSWORD,
  database: process.env.MARIADB_DATABASE || 'mysolar',
};

async function testConnection() {
  console.log('🔍 Testing database connection...\n');

  let connection;

  try {
    // Test connection
    console.log('📡 Connecting to MariaDB...');
    console.log(`   Host: ${DB_CONFIG.host}:${DB_CONFIG.port}`);
    console.log(`   User: ${DB_CONFIG.user}`);
    console.log(`   Database: ${DB_CONFIG.database}\n`);

    connection = await createConnection(DB_CONFIG);
    console.log('✅ Connection successful!\n');

    // Check database version
    console.log('🔍 Checking database version...');
    const [version] = await connection.query('SELECT VERSION() as version');
    console.log(`   MariaDB Version: ${(version as any[])[0].version}\n`);

    // List all tables
    console.log('📋 Checking tables in database...');
    const [tables] = await connection.query('SHOW TABLES');
    const tableList = tables as any[];

    if (tableList.length === 0) {
      console.log('⚠️  No tables found in database!\n');
    } else {
      console.log(`✅ Found ${tableList.length} tables:`);
      tableList.forEach((row: any) => {
        const tableName = Object.values(row)[0];
        console.log(`   - ${tableName}`);
      });
      console.log();
    }

    // Check stored procedures
    console.log('🔍 Checking stored procedures...');
    const [procedures] = await connection.query(
      `SHOW PROCEDURE STATUS WHERE Db = ?`,
      [DB_CONFIG.database]
    );
    const procList = procedures as any[];

    if (procList.length === 0) {
      console.log('⚠️  No stored procedures found!\n');
      console.log('💡 Run: npm run setup-procedures\n');
    } else {
      console.log(`✅ Found ${procList.length} stored procedures:`);
      procList.forEach((proc: any) => {
        console.log(`   - ${proc.Name}`);
      });
      console.log();
    }

    // Check required tables
    console.log('🔍 Checking required tables...');
    const requiredTables = [
      'raw_inverter_data',
      'raw_environment_data',
      'minute_data',
      'five_minute_data',
      'hourly_data',
      'daily_data',
      'monthly_data',
      'processing_log'
    ];

    const existingTables = tableList.map((row: any) => Object.values(row)[0]);
    const missingTables = requiredTables.filter(
      table => !existingTables.includes(table)
    );

    if (missingTables.length === 0) {
      console.log('✅ All required tables exist\n');
    } else {
      console.log('⚠️  Missing tables:');
      missingTables.forEach(table => {
        console.log(`   - ${table}`);
      });
      console.log('\n💡 Run database migration scripts\n');
    }

    // Check required procedures
    console.log('🔍 Checking required stored procedures...');
    const requiredProcedures = [
      'sp_aggregate_minute_data',
      'sp_aggregate_five_minute_data',
      'sp_aggregate_hourly_data',
      'sp_aggregate_daily_data',
      'sp_aggregate_monthly_data',
      'sp_run_all_aggregations'
    ];

    const existingProcedures = procList.map((proc: any) => proc.Name);
    const missingProcedures = requiredProcedures.filter(
      proc => !existingProcedures.includes(proc)
    );

    if (missingProcedures.length === 0) {
      console.log('✅ All required stored procedures exist\n');
    } else {
      console.log('⚠️  Missing stored procedures:');
      missingProcedures.forEach(proc => {
        console.log(`   - ${proc}`);
      });
      console.log('\n💡 Run: npm run setup-procedures\n');
    }

    // Summary
    console.log('📊 Summary:');
    console.log(`   Connection: ✅ OK`);
    console.log(`   Tables: ${existingTables.length}/${requiredTables.length}`);
    console.log(`   Procedures: ${existingProcedures.length}/${requiredProcedures.length}`);

    if (missingTables.length === 0 && missingProcedures.length === 0) {
      console.log('\n🎉 Database is ready to use!');
    } else {
      console.log('\n⚠️  Database setup incomplete');
      console.log('\nNext steps:');
      if (missingTables.length > 0) {
        console.log('   1. Run database migration: npm run migrate');
      }
      if (missingProcedures.length > 0) {
        console.log('   2. Setup procedures: npm run setup-procedures');
      }
      if (missingTables.includes('processing_log')) {
        console.log('   3. Create processing_log: npm run create-processing-log');
      }
    }

  } catch (error: any) {
    console.error('\n❌ Connection failed!');
    console.error(`Error: ${error.message}`);

    if (error.code === 'ECONNREFUSED') {
      console.error('\n💡 Possible causes:');
      console.error('   - Database server is not running');
      console.error('   - Firewall is blocking port 3306');
      console.error('   - Wrong host or port');
    } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      console.error('\n💡 Possible causes:');
      console.error('   - Wrong username or password');
      console.error('   - User does not have access from this IP');
      console.error('   - Database does not exist');
    }

    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n📡 Connection closed');
    }
  }
}

testConnection().catch(console.error);

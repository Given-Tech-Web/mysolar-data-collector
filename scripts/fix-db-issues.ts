#!/usr/bin/env tsx

/**
 * Fix database issues:
 * 1. Remove generated columns from raw_inverter_data
 * 2. Fix stored procedure definers
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

async function fixDatabaseIssues() {
  console.log('🔧 Fixing database issues...\n');

  let connection;

  try {
    console.log('📡 Connecting to MariaDB...');
    connection = await createConnection(DB_CONFIG);
    console.log('✅ Connected\n');

    // Issue 1: Check if columns are generated columns
    console.log('🔍 Checking raw_inverter_data table structure...');
    const [columns] = await connection.query(
      `SHOW FULL COLUMNS FROM raw_inverter_data WHERE Field IN ('solar_kwh', 'battery_kwh', 'carbon_reduction', 'generator_status')`
    );

    const generatedColumns = (columns as any[]).filter(
      col => col.Extra && col.Extra.includes('GENERATED')
    );

    if (generatedColumns.length > 0) {
      console.log(`⚠️  Found ${generatedColumns.length} generated columns:`);
      generatedColumns.forEach((col: any) => {
        console.log(`   - ${col.Field} (${col.Extra})`);
      });
      console.log();

      console.log('🔧 Converting generated columns to normal columns...');

      // Drop generated columns and recreate as normal columns
      for (const col of generatedColumns) {
        console.log(`   Modifying ${col.Field}...`);

        await connection.query(`ALTER TABLE raw_inverter_data DROP COLUMN ${col.Field}`);

        // Recreate as normal column with appropriate type
        let columnDef = '';
        if (col.Field === 'solar_kwh' || col.Field === 'battery_kwh' || col.Field === 'carbon_reduction') {
          columnDef = `${col.Field} FLOAT NOT NULL DEFAULT 0`;
        } else if (col.Field === 'generator_status') {
          columnDef = `${col.Field} VARCHAR(10) NOT NULL DEFAULT 'stopped'`;
        }

        await connection.query(`ALTER TABLE raw_inverter_data ADD COLUMN ${columnDef}`);
        console.log(`   ✅ ${col.Field} converted`);
      }
      console.log();
    } else {
      console.log('✅ No generated columns found\n');
    }

    // Issue 2: Fix stored procedure definers
    console.log('🔍 Checking stored procedures definers...');
    const [procedures] = await connection.query(
      `SELECT ROUTINE_NAME, DEFINER
       FROM information_schema.ROUTINES
       WHERE ROUTINE_SCHEMA = ?
         AND ROUTINE_TYPE = 'PROCEDURE'
         AND ROUTINE_NAME LIKE 'sp_aggregate%'`,
      [DB_CONFIG.database]
    );

    const procedureList = procedures as any[];

    if (procedureList.length > 0) {
      console.log(`Found ${procedureList.length} stored procedures`);

      const invalidDefiners = procedureList.filter(
        proc => proc.DEFINER === 'root@%' || !proc.DEFINER.includes('@')
      );

      if (invalidDefiners.length > 0) {
        console.log(`⚠️  Found ${invalidDefiners.length} procedures with invalid definer\n`);
        console.log('💡 Need to recreate stored procedures with correct definer');
        console.log('   Run: npm run setup-procedures\n');
      } else {
        console.log('✅ All procedures have valid definers\n');
      }
    }

    console.log('📊 Summary:');
    if (generatedColumns.length > 0) {
      console.log('   ✅ Fixed generated columns');
    }
    console.log('   💡 Next step: Run npm run setup-procedures to fix definer issues\n');

    console.log('🎉 Database fixes completed!');

  } catch (error: any) {
    console.error('\n❌ Fix failed!');
    console.error(`Error: ${error.message}`);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n📡 Connection closed');
    }
  }
}

fixDatabaseIssues().catch(console.error);

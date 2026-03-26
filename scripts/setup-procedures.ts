#!/usr/bin/env tsx

/**
 * Database Stored Procedures Setup Script
 *
 * Creates all required stored procedures in MariaDB.
 * Run when: Initial setup or procedures are missing (ER_SP_DOES_NOT_EXIST error)
 */

import { createConnection } from 'mysql2/promise';
import { config as dotenvConfig } from 'dotenv';
import { readFileSync } from 'fs';
import { join } from 'path';

dotenvConfig();

const DB_CONFIG = {
  host: process.env.MARIADB_HOST || '118.45.181.229',
  port: Number(process.env.MARIADB_PORT) || 3306,
  user: process.env.MARIADB_USER || 'root',
  password: process.env.MARIADB_PASSWORD,
  database: process.env.MARIADB_DATABASE || 'mysolar',
  multipleStatements: true,
};

async function setupProcedures() {
  console.log('🔧 Starting stored procedures setup...\n');

  let connection;

  try {
    // Connect to database
    console.log('📡 Connecting to MariaDB...');
    console.log(`   Host: ${DB_CONFIG.host}:${DB_CONFIG.port}`);
    console.log(`   Database: ${DB_CONFIG.database}\n`);

    connection = await createConnection(DB_CONFIG);
    console.log('✅ Connected to MariaDB\n');

    // Read SQL file
    const sqlFilePath = join(__dirname, '../migrations/02_create_stored_procedures.sql');
    console.log(`📄 Reading SQL file: ${sqlFilePath}\n`);
    const sqlContent = readFileSync(sqlFilePath, 'utf8');

    // Split by DELIMITER and procedure boundaries
    const procedures = [
      'sp_aggregate_minute_data',
      'sp_aggregate_five_minute_data',
      'sp_aggregate_hourly_data',
      'sp_aggregate_daily_data',
      'sp_aggregate_monthly_data',
      'sp_run_all_aggregations'
    ];

    console.log(`📝 Found ${procedures.length} procedures to create\n`);

    // Drop existing procedures first
    console.log('🗑️  Dropping existing procedures...');
    for (const procName of procedures) {
      try {
        await connection.query(`DROP PROCEDURE IF EXISTS ${procName}`);
        console.log(`   ✓ Dropped ${procName}`);
      } catch (error: any) {
        console.log(`   ℹ️  ${procName} did not exist`);
      }
    }
    console.log();

    // Extract and execute each procedure
    console.log('⚙️  Creating stored procedures...');

    // Split by CREATE PROCEDURE and process each one
    const parts = sqlContent.split(/CREATE PROCEDURE/i);

    for (let i = 1; i < parts.length; i++) {
      const procedureSQL = 'CREATE PROCEDURE' + parts[i];

      // Extract procedure name
      const nameMatch = procedureSQL.match(/CREATE PROCEDURE\s+(\w+)/i);
      const procedureName = nameMatch ? nameMatch[1] : `Procedure ${i}`;

      // Get the SQL up to the next delimiter or end
      let cleanSQL = procedureSQL;

      // Remove DELIMITER statements
      cleanSQL = cleanSQL.replace(/DELIMITER\s+\/\//gi, '');
      cleanSQL = cleanSQL.replace(/DELIMITER\s+;/gi, '');

      // Find the end of this procedure (next CREATE PROCEDURE or end of file)
      const endMatch = cleanSQL.match(/\/\/\s*$/m);
      if (endMatch) {
        cleanSQL = cleanSQL.substring(0, endMatch.index);
      }

      cleanSQL = cleanSQL.trim();

      try {
        console.log(`   Creating ${procedureName}...`);
        await connection.query(cleanSQL);
        console.log(`   ✅ ${procedureName} created successfully`);
      } catch (error: any) {
        console.error(`   ❌ Failed to create ${procedureName}`);
        console.error(`   Error: ${error.message}`);
        if (error.sql) {
          console.error(`   SQL Preview: ${error.sql.substring(0, 200)}...`);
        }
      }
    }
    console.log();

    // Verify procedures were created
    console.log('🔍 Verifying stored procedures...');
    const [rows] = await connection.query(
      `SHOW PROCEDURE STATUS WHERE Db = ?`,
      [DB_CONFIG.database]
    );

    const createdProcs = rows as any[];
    console.log(`\n✅ Found ${createdProcs.length} stored procedures in database:`);
    createdProcs.forEach((proc: any) => {
      console.log(`   - ${proc.Name}`);
    });

    if (createdProcs.length === procedures.length) {
      console.log('\n🎉 All stored procedures created successfully!');
      console.log('\n✨ You can now restart your application.');
    } else {
      console.log('\n⚠️  Warning: Some procedures may not have been created.');
      console.log(`   Expected: ${procedures.length}, Found: ${createdProcs.length}`);
    }

  } catch (error: any) {
    console.error('\n❌ Setup failed:');
    console.error(error.message);
    if (error.code) {
      console.error(`Error code: ${error.code}`);
    }
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n📡 Database connection closed');
    }
  }
}

// Run setup
setupProcedures().catch(console.error);

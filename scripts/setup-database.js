#!/usr/bin/env node

/**
 * Database Setup Script
 * This script sets up the required database tables and stored procedures
 */

const mysql = require('mysql2/promise');
const fs = require('fs').promises;
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const dbConfig = {
  host: process.env.MARIADB_HOST,
  port: process.env.MARIADB_PORT,
  user: process.env.MARIADB_USER,
  password: process.env.MARIADB_PASSWORD,
  database: process.env.MARIADB_DATABASE,
  multipleStatements: true
};

async function setupDatabase() {
  let connection;

  try {
    console.log('🔄 Connecting to MariaDB...');
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to MariaDB');

    // Execute aggregation tables SQL
    console.log('📊 Creating aggregation tables...');
    const tablesSQL = await fs.readFile(
      path.join(__dirname, '../migrations/01_create_aggregation_tables.sql'),
      'utf8'
    );
    await connection.query(tablesSQL);
    console.log('✅ Aggregation tables created');

    // Execute stored procedures SQL
    console.log('🔧 Creating stored procedures...');
    const proceduresSQL = await fs.readFile(
      path.join(__dirname, '../migrations/02_create_stored_procedures.sql'),
      'utf8'
    );
    await connection.query(proceduresSQL);
    console.log('✅ Stored procedures created');

    // Verify tables exist
    console.log('🔍 Verifying database setup...');
    const [tables] = await connection.query(
      "SHOW TABLES LIKE '%_data'"
    );
    console.log(`📋 Found ${tables.length} data tables`);

    const [procedures] = await connection.query(
      "SHOW PROCEDURE STATUS WHERE Db = ? AND Name LIKE 'sp_%'",
      [process.env.MARIADB_DATABASE]
    );
    console.log(`📋 Found ${procedures.length} stored procedures`);

    console.log('✅ Database setup completed successfully!');

  } catch (error) {
    console.error('❌ Database setup failed:', error.message);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run setup
setupDatabase();
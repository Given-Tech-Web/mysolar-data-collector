#!/usr/bin/env tsx

/**
 * Create processing_log table
 *
 * This table is used by stored procedures to log aggregation operations
 */

import { createConnection } from 'mysql2/promise';
import { config } from 'dotenv';

config();

const DB_CONFIG = {
  host: process.env.MARIADB_HOST || '118.45.181.229',
  port: Number(process.env.MARIADB_PORT) || 3306,
  user: process.env.MARIADB_USER || 'root',
  password: process.env.MARIADB_PASSWORD,
  database: process.env.MARIADB_DATABASE || 'mysolar',
};

async function createProcessingLogTable() {
  console.log('🔧 Creating processing_log table...\n');

  let connection;

  try {
    console.log('📡 Connecting to MariaDB...');
    connection = await createConnection(DB_CONFIG);
    console.log('✅ Connected\n');

    // Create processing_log table (unified schema from both versions)
    const createTableSQL = `
      CREATE TABLE IF NOT EXISTS processing_log (
        id INT AUTO_INCREMENT PRIMARY KEY,
        process_type VARCHAR(50) NOT NULL,
        process_name VARCHAR(100),
        device_id VARCHAR(50),

        -- Timing
        start_time DATETIME NOT NULL,
        end_time DATETIME,
        started_at DATETIME,
        completed_at DATETIME,
        duration_ms INT,

        -- Results
        records_processed INT,
        records_failed INT,
        status ENUM('running', 'completed', 'failed') DEFAULT 'running',
        error_message TEXT,

        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

        -- Indexes
        INDEX idx_process_type (process_type),
        INDEX idx_process_time (process_type, start_time),
        INDEX idx_status (status),
        INDEX idx_created (created_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `;

    console.log('⚙️  Creating table...');
    await connection.query(createTableSQL);
    console.log('✅ Table created successfully\n');

    // Verify table exists
    console.log('🔍 Verifying table...');
    const [tables] = await connection.query(
      `SHOW TABLES LIKE 'processing_log'`
    );

    if ((tables as any[]).length > 0) {
      console.log('✅ Table verified\n');

      // Show table structure
      console.log('📋 Table structure:');
      const [columns] = await connection.query(
        `DESCRIBE processing_log`
      );

      (columns as any[]).forEach((col: any) => {
        console.log(`   - ${col.Field} (${col.Type})`);
      });

      console.log('\n🎉 processing_log table created successfully!');
    } else {
      console.log('❌ Table verification failed');
    }

  } catch (error: any) {
    console.error('\n❌ Failed to create table:');
    console.error(error.message);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n📡 Database connection closed');
    }
  }
}

createProcessingLogTable().catch(console.error);

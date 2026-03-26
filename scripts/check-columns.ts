#!/usr/bin/env tsx

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

async function checkColumns() {
  let connection;

  try {
    connection = await createConnection(DB_CONFIG);
    console.log('Connected to database\n');

    const [columns] = await connection.query(
      `SHOW FULL COLUMNS FROM raw_inverter_data WHERE Field IN ('solar_kwh', 'battery_kwh', 'carbon_reduction', 'generator_status')`
    );

    console.log('Column details:');
    (columns as any[]).forEach((col: any) => {
      console.log(`\n${col.Field}:`);
      console.log(`  Type: ${col.Type}`);
      console.log(`  Extra: ${col.Extra}`);
      console.log(`  Default: ${col.Default}`);
    });

  } catch (error: any) {
    console.error('Error:', error.message);
  } finally {
    if (connection) await connection.end();
  }
}

checkColumns();

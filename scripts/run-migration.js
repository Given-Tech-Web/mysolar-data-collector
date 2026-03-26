const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function runMigration() {
  let connection;

  try {
    console.log('🔗 Connecting to MariaDB...');
    connection = await mysql.createConnection({
      host: process.env.MARIADB_HOST,
      port: process.env.MARIADB_PORT,
      user: process.env.MARIADB_USER,
      password: process.env.MARIADB_PASSWORD,
      database: process.env.MARIADB_DATABASE,
      multipleStatements: true
    });

    console.log('✅ Connected successfully');

    // Read migration file
    const migrationPath = path.join(__dirname, '../migrations/001_create_schema.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');

    console.log('📝 Running migration: 001_create_schema.sql');
    await connection.query(migrationSQL);
    console.log('✅ Migration completed successfully');

    // Read and run stored procedures
    const procedurePath = path.join(__dirname, '../procedures/aggregation_procedures.sql');
    const procedureSQL = fs.readFileSync(procedurePath, 'utf8');

    console.log('📝 Creating stored procedures...');
    await connection.query(procedureSQL);
    console.log('✅ Stored procedures created successfully');

    console.log('\n🎉 Database setup complete!');

  } catch (error) {
    console.error('❌ Migration error:', error.message);
    if (error.sqlMessage) {
      console.error('   SQL Error:', error.sqlMessage);
    }
  } finally {
    if (connection) {
      await connection.end();
      console.log('✅ Connection closed');
    }
  }
}

runMigration();
#!/usr/bin/env node

/**
 * Connection Test Script
 * Tests both MQTT and MariaDB connections
 */

const mqtt = require('mqtt');
const mysql = require('mysql2/promise');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

// Test MariaDB connection
async function testDatabase() {
  console.log('\n📊 Testing MariaDB Connection...');
  console.log(`Host: ${process.env.MARIADB_HOST}`);
  console.log(`Database: ${process.env.MARIADB_DATABASE}`);

  try {
    const connection = await mysql.createConnection({
      host: process.env.MARIADB_HOST,
      port: process.env.MARIADB_PORT,
      user: process.env.MARIADB_USER,
      password: process.env.MARIADB_PASSWORD,
      database: process.env.MARIADB_DATABASE
    });

    // Test query
    const [rows] = await connection.execute(
      'SELECT COUNT(*) as count FROM raw_inverter_data WHERE timestamp > DATE_SUB(NOW(), INTERVAL 1 HOUR)'
    );
    console.log(`✅ MariaDB connected successfully`);
    console.log(`📈 Recent data points (last hour): ${rows[0].count}`);

    // Check if calculated columns exist
    const [columns] = await connection.execute(
      "SHOW COLUMNS FROM raw_inverter_data WHERE Field IN ('solar_kwh', 'battery_kwh', 'carbon_reduction', 'generator_status')"
    );

    if (columns.length === 4) {
      console.log('✅ All calculated columns exist');
    } else {
      console.log(`⚠️ Only ${columns.length}/4 calculated columns exist`);
      console.log('   Run setup-database.js to add missing columns');
    }

    await connection.end();
  } catch (error) {
    console.error('❌ MariaDB connection failed:', error.message);
    return false;
  }
  return true;
}

// Test MQTT connection
async function testMQTT() {
  console.log('\n📡 Testing MQTT Connection...');
  console.log(`Host: ${process.env.HIVEMQ_HOST}`);
  console.log(`Port: ${process.env.HIVEMQ_PORT}`);

  return new Promise((resolve) => {
    const client = mqtt.connect({
      host: process.env.HIVEMQ_HOST,
      port: process.env.HIVEMQ_PORT,
      protocol: 'mqtts',
      username: process.env.HIVEMQ_USERNAME,
      password: process.env.HIVEMQ_PASSWORD,
      connectTimeout: 10000
    });

    const timeout = setTimeout(() => {
      console.error('❌ MQTT connection timeout');
      client.end();
      resolve(false);
    }, 10000);

    client.on('connect', () => {
      clearTimeout(timeout);
      console.log('✅ MQTT connected successfully');

      // Subscribe to test topics
      client.subscribe(['solar/inverter/status', 'solar/environment/data'], (err) => {
        if (err) {
          console.error('❌ MQTT subscription failed:', err.message);
        } else {
          console.log('✅ Subscribed to solar topics');
        }

        // Wait for a message (with timeout)
        console.log('⏳ Waiting for messages (5 seconds)...');
        let messageReceived = false;

        client.on('message', (topic, payload) => {
          if (!messageReceived) {
            messageReceived = true;
            console.log(`✅ Received message on topic: ${topic}`);
            const data = JSON.parse(payload.toString());
            console.log(`   Device: ${data.device_id}`);
            console.log(`   Solar Power: ${data.pv1_charging_power}W`);
            console.log(`   Battery: ${data.battery_capacity}%`);
          }
        });

        setTimeout(() => {
          if (!messageReceived) {
            console.log('⚠️ No messages received (device might be offline)');
          }
          client.end();
          resolve(true);
        }, 5000);
      });
    });

    client.on('error', (error) => {
      clearTimeout(timeout);
      console.error('❌ MQTT connection error:', error.message);
      client.end();
      resolve(false);
    });
  });
}

// Run tests
async function runTests() {
  console.log('🚀 Solar Data Collector - Connection Test');
  console.log('=========================================');

  const dbOk = await testDatabase();
  const mqttOk = await testMQTT();

  console.log('\n=========================================');
  console.log('📋 Test Results:');
  console.log(`   Database: ${dbOk ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`   MQTT: ${mqttOk ? '✅ PASS' : '❌ FAIL'}`);

  if (dbOk && mqttOk) {
    console.log('\n✅ All systems operational! Ready to start collector.');
  } else {
    console.log('\n⚠️ Some connections failed. Please check configuration.');
    process.exit(1);
  }
}

runTests();
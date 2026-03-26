const mqtt = require('mqtt');
const mysql = require('mysql2/promise');
require('dotenv').config();

let dbConnection;
let messageCount = 0;

async function connectDatabase() {
  try {
    dbConnection = await mysql.createConnection({
      host: process.env.MARIADB_HOST,
      port: process.env.MARIADB_PORT,
      user: process.env.MARIADB_USER,
      password: process.env.MARIADB_PASSWORD,
      database: process.env.MARIADB_DATABASE
    });
    console.log('✅ Connected to MariaDB');
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    process.exit(1);
  }
}

async function insertInverterData(data) {
  try {
    // Calculate derived fields
    const solar_kwh = data.pv1_charging_power / 1000;
    const carbon_reduction = solar_kwh * 0.4781;
    const generator_status = data.ac_voltage > 200 ? 'running' : 'stopped';

    const query = `
      INSERT INTO raw_inverter_data (
        device_id, timestamp,
        pv1_input_voltage, pv1_input_current, pv1_charging_power,
        battery_voltage, battery_capacity, charging_current, battery_discharge_current,
        ac_voltage, ac_frequency,
        output_voltage, output_frequency, output_apparent_power, output_active_power, load_percentage,
        raw_data
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        pv1_charging_power = VALUES(pv1_charging_power),
        battery_capacity = VALUES(battery_capacity),
        load_percentage = VALUES(load_percentage)
    `;

    const values = [
      data.device_id,
      data.timestamp,
      data.pv1_input_voltage || 0,
      data.pv1_input_current || 0,
      data.pv1_charging_power || 0,
      data.battery_voltage || 0,
      data.battery_capacity || 0,
      data.charging_current || 0,
      data.battery_discharge_current || 0,
      data.ac_voltage || 0,
      data.ac_frequency || 0,
      data.output_voltage || 0,
      data.output_frequency || 0,
      data.output_apparent_power || 0,
      data.output_active_power || 0,
      data.load_percentage || 0,
      data.raw_data || null
    ];

    await dbConnection.execute(query, values);
    messageCount++;
    console.log(`✅ Inserted inverter data #${messageCount} - Battery: ${data.battery_capacity}%, Solar: ${data.pv1_charging_power}W, Generator: ${generator_status}`);
  } catch (error) {
    console.error('❌ Failed to insert inverter data:', error.message);
  }
}

async function insertEnvironmentData(data) {
  try {
    const query = `
      INSERT INTO raw_environment_data (
        device_id, timestamp, temperature, humidity
      ) VALUES (?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        temperature = VALUES(temperature),
        humidity = VALUES(humidity)
    `;

    const values = [
      data.device_id,
      data.timestamp,
      data.temperature,
      data.humidity
    ];

    await dbConnection.execute(query, values);
    console.log(`✅ Inserted environment data - Temp: ${data.temperature}°C, Humidity: ${data.humidity}%`);
  } catch (error) {
    console.error('❌ Failed to insert environment data:', error.message);
  }
}

async function main() {
  // Connect to database
  await connectDatabase();

  // Connect to MQTT
  const mqttOptions = {
    host: '9933a3ad2bed43528b8317e5c5b56ae3.s1.eu.hivemq.cloud',
    port: 8883,
    protocol: 'mqtts',
    username: 'hivemq.webclient.1756781079211',
    password: 'qCDS3wF?8ba,%R9#U1sk',
    clientId: `direct_insert_${Date.now()}`,
    clean: true,
    keepalive: 60
  };

  console.log('🔗 Connecting to MQTT broker...');
  const client = mqtt.connect(mqttOptions);

  client.on('connect', () => {
    console.log('✅ Connected to MQTT broker');

    // Subscribe to topics
    client.subscribe(['solar/inverter/status', 'solar/environment/data'], (err) => {
      if (err) {
        console.error('❌ Subscribe error:', err);
      } else {
        console.log('✅ Subscribed to topics');
        console.log('📡 Waiting for data...\n');
      }
    });
  });

  client.on('message', async (topic, message) => {
    try {
      const data = JSON.parse(message.toString());

      if (topic === 'solar/inverter/status') {
        await insertInverterData(data);
      } else if (topic === 'solar/environment/data') {
        await insertEnvironmentData(data);
      }
    } catch (error) {
      console.error('❌ Error processing message:', error.message);
    }
  });

  client.on('error', (error) => {
    console.error('❌ MQTT error:', error.message);
  });

  // Graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\n📊 Summary: Inserted', messageCount, 'messages');
    client.end();
    await dbConnection.end();
    process.exit(0);
  });
}

main().catch(console.error);
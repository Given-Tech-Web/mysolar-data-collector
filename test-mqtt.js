const mqtt = require('mqtt');

// Test MQTT connection
const options = {
  host: '9933a3ad2bed43528b8317e5c5b56ae3.s1.eu.hivemq.cloud',
  port: 8883,
  protocol: 'mqtts',
  username: 'hivemq.webclient.1757770222944',
  password: ':gBpA7F6tM,lL4y*.5Ze',
  clientId: `test_collector_${Date.now()}`,
  clean: true,
  keepalive: 60,
  reconnectPeriod: 5000
};

console.log('Connecting with options:', {
  ...options,
  password: '***'
});

const client = mqtt.connect(options);

client.on('connect', () => {
  console.log('✅ Connected to MQTT broker successfully!');

  // Subscribe to topics
  client.subscribe(['solar/inverter/status', 'solar/environment/data'], (err) => {
    if (err) {
      console.error('Subscribe error:', err);
    } else {
      console.log('✅ Subscribed to topics successfully!');
    }
  });
});

client.on('message', (topic, message) => {
  const data = JSON.parse(message.toString());
  console.log(`📦 Received on ${topic}:`, {
    device_id: data.device_id,
    timestamp: data.timestamp,
    ...(topic === 'solar/inverter/status' ? {
      battery_capacity: data.battery_capacity,
      pv1_charging_power: data.pv1_charging_power,
      ac_voltage: data.ac_voltage
    } : {
      temperature: data.temperature,
      humidity: data.humidity
    })
  });
});

client.on('error', (error) => {
  console.error('❌ MQTT error:', error.message);
});

client.on('close', () => {
  console.log('Connection closed');
});

// Keep process running
process.on('SIGINT', () => {
  console.log('Disconnecting...');
  client.end();
  process.exit(0);
});
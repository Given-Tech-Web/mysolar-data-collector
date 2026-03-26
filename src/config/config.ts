import dotenv from 'dotenv';
import path from 'path';

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../../.env') });

export const config = {
  // HiveMQ Cloud Configuration
  mqtt: {
    host: process.env.HIVEMQ_HOST!,
    port: parseInt(process.env.HIVEMQ_PORT || '8883'),
    username: process.env.HIVEMQ_USERNAME!,
    password: process.env.HIVEMQ_PASSWORD!,
    clientId: `solar_collector_${Date.now()}`, // Always use dynamic ID to avoid conflicts
    topics: {
      inverter: 'solar/inverter/status',
      environment: 'solar/environment/data',
      alerts: 'solar/alerts/+',
      control: 'solar/control/+'
    }
  },

  // MariaDB Configuration
  database: {
    host: process.env.MARIADB_HOST!,
    port: parseInt(process.env.MARIADB_PORT || '3306'),
    user: process.env.MARIADB_USER!,
    password: process.env.MARIADB_PASSWORD!,
    database: process.env.MARIADB_DATABASE!,
    connectionLimit: 10,
    waitForConnections: true,
    queueLimit: 0,
    enableKeepAlive: true,
    keepAliveInitialDelay: 0
  },

  // Application Configuration
  app: {
    nodeEnv: process.env.NODE_ENV || 'development',
    logLevel: process.env.LOG_LEVEL || 'info',
    logDir: process.env.LOG_DIR || './logs',
    deviceId: process.env.DEVICE_ID || 'solar_system_001'
  },

  // Data Retention (days)
  retention: {
    rawData: parseInt(process.env.RAW_DATA_RETENTION || '90'),
    minuteData: parseInt(process.env.MINUTE_DATA_RETENTION || '30'),
    fiveMinuteData: parseInt(process.env.FIVE_MINUTE_DATA_RETENTION || '90'),
    hourlyData: parseInt(process.env.HOURLY_DATA_RETENTION || '365')
  },

  // Processing Configuration
  processing: {
    batchSize: parseInt(process.env.BATCH_SIZE || '100'),
    aggregationInterval: parseInt(process.env.AGGREGATION_INTERVAL || '60000'), // 1 minute
    retryAttempts: 3,
    retryDelay: 5000 // 5 seconds
  },

  // Solar System Configuration
  solar: {
    carbonFactor: parseFloat(process.env.CARBON_FACTOR || '0.4781'), // kg CO2 per kWh
    panelCapacity: parseInt(process.env.SOLAR_PANEL_CAPACITY || '5000'), // Watts
    batteryMaxCapacity: parseFloat(process.env.BATTERY_MAX_CAPACITY || '19.2') // kWh
  }
};

// Validate required configuration
export function validateConfig(): void {
  const required = [
    'mqtt.host',
    'mqtt.username',
    'mqtt.password',
    'database.host',
    'database.user',
    'database.password',
    'database.database'
  ];

  const missing: string[] = [];

  for (const key of required) {
    const keys = key.split('.');
    let value: any = config;

    for (const k of keys) {
      value = value[k as keyof typeof value];
      if (value === undefined || value === null || value === '') {
        missing.push(key);
        break;
      }
    }
  }

  if (missing.length > 0) {
    throw new Error(`Missing required configuration: ${missing.join(', ')}`);
  }
}
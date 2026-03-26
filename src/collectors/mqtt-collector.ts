import mqtt, { MqttClient } from 'mqtt';
import { config } from '../config/config';
import { mqttLogger as logger } from '../utils/logger';
import { DataProcessor } from '../processors/data-processor';
import { InverterData, EnvironmentData } from '../types/mqtt-data';

export class MQTTCollector {
  private client: MqttClient | null = null;
  private dataProcessor: DataProcessor;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private reconnectInterval = 5000;

  constructor() {
    this.dataProcessor = new DataProcessor();
  }

  public async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      logger.info('Connecting to MQTT broker', {
        host: config.mqtt.host,
        port: config.mqtt.port,
        clientId: config.mqtt.clientId
      });

      this.client = mqtt.connect({
        host: config.mqtt.host,
        port: config.mqtt.port,
        protocol: 'mqtts',
        clientId: config.mqtt.clientId,
        username: config.mqtt.username,
        password: config.mqtt.password,
        clean: true,
        reconnectPeriod: this.reconnectInterval,
        connectTimeout: 30000,
        keepalive: 60
      });

      this.setupEventHandlers(resolve, reject);
    });
  }

  private setupEventHandlers(
    connectResolve: () => void,
    connectReject: (error: Error) => void
  ): void {
    if (!this.client) return;

    let connected = false;

    this.client.on('connect', () => {
      logger.info('Connected to MQTT broker successfully');
      this.reconnectAttempts = 0;

      // Subscribe to topics
      this.subscribeToTopics();

      if (!connected) {
        connected = true;
        connectResolve();
      }
    });

    this.client.on('message', async (topic: string, payload: Buffer) => {
      try {
        await this.handleMessage(topic, payload);
      } catch (error) {
        logger.error('Error handling MQTT message', { topic, error });
      }
    });

    this.client.on('error', (error: Error) => {
      logger.error('MQTT client error', { error: error.message });

      if (!connected) {
        connectReject(error);
      }
    });

    this.client.on('close', () => {
      logger.warn('MQTT connection closed');
    });

    this.client.on('reconnect', () => {
      this.reconnectAttempts++;
      logger.info(`Attempting to reconnect to MQTT broker (attempt ${this.reconnectAttempts})`);

      if (this.reconnectAttempts >= this.maxReconnectAttempts) {
        logger.error('Max reconnection attempts reached');
        this.disconnect();
      }
    });

    this.client.on('offline', () => {
      logger.warn('MQTT client is offline');
    });
  }

  private subscribeToTopics(): void {
    if (!this.client) return;

    const topics = [
      config.mqtt.topics.inverter,
      config.mqtt.topics.environment,
      config.mqtt.topics.alerts
    ];

    this.client.subscribe(topics, { qos: 1 }, (error, granted) => {
      if (error) {
        logger.error('Failed to subscribe to topics', { error });
      } else {
        logger.info('Subscribed to MQTT topics', {
          topics: granted ? granted.map(g => ({ topic: g.topic, qos: g.qos })) : []
        });
      }
    });
  }

  private async handleMessage(topic: string, payload: Buffer): Promise<void> {
    const message = payload.toString();
    logger.debug('Received MQTT message', { topic, size: message.length });

    try {
      const data = JSON.parse(message);

      // Add receive timestamp if not present
      if (!data.timestamp) {
        data.timestamp = new Date().toISOString();
      }

      // Route to appropriate handler based on topic
      if (topic === config.mqtt.topics.inverter) {
        await this.handleInverterData(data as InverterData);
      } else if (topic === config.mqtt.topics.environment) {
        await this.handleEnvironmentData(data as EnvironmentData);
      } else if (topic.startsWith('solar/alerts/')) {
        await this.handleAlertData(data);
      }
    } catch (error) {
      logger.error('Failed to parse MQTT message', {
        topic,
        error,
        message: message.substring(0, 200)
      });
    }
  }

  private async handleInverterData(data: InverterData): Promise<void> {
    logger.debug('Processing inverter data', {
      deviceId: data.device_id,
      power: data.pv1_charging_power,
      battery: data.battery_capacity
    });

    try {
      await this.dataProcessor.processInverterData(data);
      logger.debug('Inverter data processed successfully');
    } catch (error) {
      logger.error('Failed to process inverter data', { error, data });
    }
  }

  private async handleEnvironmentData(data: EnvironmentData): Promise<void> {
    logger.debug('Processing environment data', {
      deviceId: data.device_id,
      temperature: data.temperature,
      humidity: data.humidity
    });

    try {
      await this.dataProcessor.processEnvironmentData(data);
      logger.debug('Environment data processed successfully');
    } catch (error) {
      logger.error('Failed to process environment data', { error, data });
    }
  }

  private async handleAlertData(data: any): Promise<void> {
    logger.info('Received alert', { data });
    // Alert processing logic here
  }

  public disconnect(): void {
    if (this.client) {
      this.client.end();
      this.client = null;
      logger.info('Disconnected from MQTT broker');
    }
  }

  public isConnected(): boolean {
    return this.client?.connected || false;
  }
}
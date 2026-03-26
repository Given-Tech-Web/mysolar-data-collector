import { validateConfig } from './config/config';
import { logger } from './utils/logger';
import { MQTTCollector } from './collectors/mqtt-collector';
import { createConnection, closeConnection } from './database/connection';
import { DataRetentionManager } from './schedulers/data-retention';
import { AggregationScheduler } from './schedulers/aggregation-scheduler';

class SolarDataCollector {
  private mqttCollector: MQTTCollector;
  private retentionManager: DataRetentionManager;
  private aggregationScheduler: AggregationScheduler;

  constructor() {
    this.mqttCollector = new MQTTCollector();
    this.retentionManager = new DataRetentionManager();
    this.aggregationScheduler = new AggregationScheduler();
  }

  public async start(): Promise<void> {
    try {
      logger.info('Starting Solar Data Collector...');

      // Validate configuration
      validateConfig();
      logger.info('Configuration validated successfully');

      // Test database connection
      await createConnection();
      logger.info('Database connection established');

      // Connect to MQTT broker
      await this.mqttCollector.connect();
      logger.info('MQTT collector started');

      // Start schedulers
      this.retentionManager.start();
      logger.info('Data retention manager started');

      this.aggregationScheduler.start();
      logger.info('Aggregation scheduler started');

      logger.info('Solar Data Collector started successfully');

      // Setup graceful shutdown
      this.setupGracefulShutdown();
    } catch (error) {
      logger.error('Failed to start Solar Data Collector', { error });
      process.exit(1);
    }
  }

  private setupGracefulShutdown(): void {
    const shutdown = async (signal: string) => {
      logger.info(`Received ${signal}, shutting down gracefully...`);

      try {
        // Stop schedulers
        this.retentionManager.stop();
        this.aggregationScheduler.stop();

        // Disconnect from MQTT
        this.mqttCollector.disconnect();

        // Close database connections
        await closeConnection();

        logger.info('Shutdown complete');
        process.exit(0);
      } catch (error) {
        logger.error('Error during shutdown', { error });
        process.exit(1);
      }
    };

    // Handle different shutdown signals
    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGUSR2', () => shutdown('SIGUSR2'));

    // Handle uncaught errors
    process.on('uncaughtException', (error: Error) => {
      logger.error('Uncaught exception', { error });
      shutdown('uncaughtException');
    });

    process.on('unhandledRejection', (reason: any) => {
      logger.error('Unhandled rejection', { reason });
      shutdown('unhandledRejection');
    });
  }
}

// Start the application
const app = new SolarDataCollector();
app.start().catch((error) => {
  logger.error('Failed to start application', { error });
  process.exit(1);
});
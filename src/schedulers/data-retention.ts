import cron from 'node-cron';
import { executeQuery } from '../database/connection';
import { config } from '../config/config';
import { logger } from '../utils/logger';

export class DataRetentionManager {
  private tasks: cron.ScheduledTask[] = [];

  public start(): void {
    // Run daily at 2 AM
    const dailyTask = cron.schedule('0 2 * * *', async () => {
      await this.runRetentionPolicies();
    });

    this.tasks.push(dailyTask);
    logger.info('Data retention manager scheduled (daily at 2 AM)');
  }

  public stop(): void {
    this.tasks.forEach(task => task.stop());
    this.tasks = [];
    logger.info('Data retention manager stopped');
  }

  private async runRetentionPolicies(): Promise<void> {
    logger.info('Starting data retention cleanup');

    try {
      // Clean raw inverter data
      await this.cleanRawInverterData();

      // Clean raw environment data
      await this.cleanRawEnvironmentData();

      // Clean minute data
      await this.cleanMinuteData();

      // Clean 5-minute data
      await this.cleanFiveMinuteData();

      // Clean old processing logs
      await this.cleanProcessingLogs();

      // Optimize tables
      await this.optimizeTables();

      logger.info('Data retention cleanup completed successfully');
    } catch (error) {
      logger.error('Data retention cleanup failed', { error });
    }
  }

  private async cleanRawInverterData(): Promise<void> {
    const retentionDays = config.retention.rawData;

    const query = `
      DELETE FROM raw_inverter_data
      WHERE timestamp < DATE_SUB(NOW(), INTERVAL ? DAY)
      LIMIT 10000
    `;

    let totalDeleted = 0;
    let deleted = 0;

    do {
      const result = await executeQuery(query, [retentionDays]);
      deleted = (result as any).affectedRows;
      totalDeleted += deleted;
    } while (deleted === 10000);

    if (totalDeleted > 0) {
      logger.info(`Deleted ${totalDeleted} old raw inverter records`);
    }
  }

  private async cleanRawEnvironmentData(): Promise<void> {
    const retentionDays = config.retention.rawData;

    const query = `
      DELETE FROM raw_environment_data
      WHERE timestamp < DATE_SUB(NOW(), INTERVAL ? DAY)
      LIMIT 10000
    `;

    let totalDeleted = 0;
    let deleted = 0;

    do {
      const result = await executeQuery(query, [retentionDays]);
      deleted = (result as any).affectedRows;
      totalDeleted += deleted;
    } while (deleted === 10000);

    if (totalDeleted > 0) {
      logger.info(`Deleted ${totalDeleted} old raw environment records`);
    }
  }

  private async cleanMinuteData(): Promise<void> {
    const retentionDays = config.retention.minuteData;

    const query = `
      DELETE FROM minute_data
      WHERE timestamp < DATE_SUB(NOW(), INTERVAL ? DAY)
      LIMIT 5000
    `;

    let totalDeleted = 0;
    let deleted = 0;

    do {
      const result = await executeQuery(query, [retentionDays]);
      deleted = (result as any).affectedRows;
      totalDeleted += deleted;
    } while (deleted === 5000);

    if (totalDeleted > 0) {
      logger.info(`Deleted ${totalDeleted} old minute data records`);
    }
  }

  private async cleanFiveMinuteData(): Promise<void> {
    const retentionDays = config.retention.fiveMinuteData;

    const query = `
      DELETE FROM five_minute_data
      WHERE timestamp < DATE_SUB(NOW(), INTERVAL ? DAY)
      LIMIT 5000
    `;

    let totalDeleted = 0;
    let deleted = 0;

    do {
      const result = await executeQuery(query, [retentionDays]);
      deleted = (result as any).affectedRows;
      totalDeleted += deleted;
    } while (deleted === 5000);

    if (totalDeleted > 0) {
      logger.info(`Deleted ${totalDeleted} old 5-minute data records`);
    }
  }

  private async cleanProcessingLogs(): Promise<void> {
    // Keep processing logs for 30 days
    const query = `
      DELETE FROM processing_log
      WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
    `;

    const result = await executeQuery(query);
    const deleted = (result as any).affectedRows;

    if (deleted > 0) {
      logger.info(`Deleted ${deleted} old processing log records`);
    }
  }

  private async optimizeTables(): Promise<void> {
    const tables = [
      'raw_inverter_data',
      'raw_environment_data',
      'minute_data',
      'five_minute_data',
      'hourly_data',
      'daily_data'
    ];

    for (const table of tables) {
      try {
        await executeQuery(`OPTIMIZE TABLE ${table}`);
        logger.debug(`Optimized table ${table}`);
      } catch (error) {
        logger.warn(`Failed to optimize table ${table}`, { error });
      }
    }
  }

  // Manual trigger for immediate cleanup
  public async runNow(): Promise<void> {
    await this.runRetentionPolicies();
  }
}
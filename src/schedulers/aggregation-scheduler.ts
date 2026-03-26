import cron from 'node-cron';
import { executeQuery } from '../database/connection';
import { config } from '../config/config';
import { logger } from '../utils/logger';

export class AggregationScheduler {
  private tasks: cron.ScheduledTask[] = [];

  public start(): void {
    // Run minute aggregation every minute
    const minuteTask = cron.schedule('* * * * *', async () => {
      await this.runMinuteAggregation();
    });

    // Run 5-minute aggregation every 5 minutes
    const fiveMinuteTask = cron.schedule('*/5 * * * *', async () => {
      await this.runFiveMinuteAggregation();
    });

    // Run hourly aggregation at the start of each hour
    const hourlyTask = cron.schedule('0 * * * *', async () => {
      await this.runHourlyAggregation();
    });

    // Run daily aggregation at 00:05
    const dailyTask = cron.schedule('5 0 * * *', async () => {
      await this.runDailyAggregation();
    });

    // Run monthly aggregation on the 1st of each month at 00:10
    const monthlyTask = cron.schedule('10 0 1 * *', async () => {
      await this.runMonthlyAggregation();
    });

    this.tasks.push(minuteTask, fiveMinuteTask, hourlyTask, dailyTask, monthlyTask);
    logger.info('Aggregation scheduler started');
  }

  public stop(): void {
    this.tasks.forEach(task => task.stop());
    this.tasks = [];
    logger.info('Aggregation scheduler stopped');
  }

  private async runMinuteAggregation(): Promise<void> {
    try {
      const endTime = new Date();
      const startTime = new Date(endTime.getTime() - 2 * 60 * 1000); // Last 2 minutes

      await executeQuery(
        'CALL sp_aggregate_minute_data(?, ?, ?)',
        [config.app.deviceId, startTime, endTime]
      );

      logger.debug('Minute aggregation completed');
    } catch (error) {
      logger.error('Minute aggregation failed', { error });
    }
  }

  private async runFiveMinuteAggregation(): Promise<void> {
    try {
      const endTime = new Date();
      const startTime = new Date(endTime.getTime() - 10 * 60 * 1000); // Last 10 minutes

      await executeQuery(
        'CALL sp_aggregate_five_minute_data(?, ?, ?)',
        [config.app.deviceId, startTime, endTime]
      );

      logger.debug('5-minute aggregation completed');
    } catch (error) {
      logger.error('5-minute aggregation failed', { error });
    }
  }

  private async runHourlyAggregation(): Promise<void> {
    try {
      const endTime = new Date();
      const startTime = new Date(endTime.getTime() - 2 * 60 * 60 * 1000); // Last 2 hours

      await executeQuery(
        'CALL sp_aggregate_hourly_data(?, ?, ?)',
        [config.app.deviceId, startTime, endTime]
      );

      logger.info('Hourly aggregation completed');
    } catch (error) {
      logger.error('Hourly aggregation failed', { error });
    }
  }

  private async runDailyAggregation(): Promise<void> {
    try {
      // Aggregate yesterday's data
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);

      await executeQuery(
        'CALL sp_aggregate_daily_data(?, ?)',
        [config.app.deviceId, yesterday]
      );

      // Also aggregate today's partial data
      await executeQuery(
        'CALL sp_aggregate_daily_data(?, ?)',
        [config.app.deviceId, new Date()]
      );

      logger.info('Daily aggregation completed');
    } catch (error) {
      logger.error('Daily aggregation failed', { error });
    }
  }

  private async runMonthlyAggregation(): Promise<void> {
    try {
      // Aggregate last month's data
      const lastMonth = new Date();
      lastMonth.setMonth(lastMonth.getMonth() - 1);

      await executeQuery(
        'CALL sp_aggregate_monthly_data(?, ?, ?)',
        [config.app.deviceId, lastMonth.getFullYear(), lastMonth.getMonth() + 1]
      );

      // Also aggregate current month's partial data
      const currentMonth = new Date();
      await executeQuery(
        'CALL sp_aggregate_monthly_data(?, ?, ?)',
        [config.app.deviceId, currentMonth.getFullYear(), currentMonth.getMonth() + 1]
      );

      logger.info('Monthly aggregation completed');
    } catch (error) {
      logger.error('Monthly aggregation failed', { error });
    }
  }
}
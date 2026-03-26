import { InverterData, EnvironmentData, ProcessedInverterData } from '../types/mqtt-data';
import { executeQuery } from '../database/connection';
import { config } from '../config/config';
import { processingLogger as logger } from '../utils/logger';
import { DataValidator } from './data-validator';

export class DataProcessor {
  private validator: DataValidator;
  private batchBuffer: ProcessedInverterData[] = [];
  private envBuffer: EnvironmentData[] = [];
  private batchTimer: NodeJS.Timeout | null = null;

  constructor() {
    this.validator = new DataValidator();
  }

  public async processInverterData(data: InverterData): Promise<void> {
    try {
      // Validate data
      if (!this.validator.validateInverterData(data)) {
        logger.warn('Invalid inverter data received', { data });
        return;
      }

      // Calculate derived fields
      const processedData: ProcessedInverterData = {
        ...data,
        solar_kwh: data.pv1_charging_power / 1000,
        battery_kwh: (data.battery_capacity / 100) * config.solar.batteryMaxCapacity,
        carbon_reduction: (data.pv1_charging_power / 1000) * config.solar.carbonFactor,
        generator_status: data.ac_voltage > 200 ? 'running' : 'stopped'
      };

      // Add to batch buffer
      this.batchBuffer.push(processedData);

      // Process batch if full
      if (this.batchBuffer.length >= config.processing.batchSize) {
        await this.processBatch();
      } else {
        // Set timer for batch processing
        this.setBatchTimer();
      }
    } catch (error) {
      logger.error('Error processing inverter data', { error, data });
      throw error;
    }
  }

  public async processEnvironmentData(data: EnvironmentData): Promise<void> {
    try {
      // Validate data
      if (!this.validator.validateEnvironmentData(data)) {
        logger.warn('Invalid environment data received', { data });
        return;
      }

      // Add to buffer
      this.envBuffer.push(data);

      // Process if buffer is full
      if (this.envBuffer.length >= config.processing.batchSize) {
        await this.processEnvironmentBatch();
      }
    } catch (error) {
      logger.error('Error processing environment data', { error, data });
      throw error;
    }
  }

  private setBatchTimer(): void {
    if (this.batchTimer) return;

    this.batchTimer = setTimeout(async () => {
      await this.processBatch();
      this.batchTimer = null;
    }, 5000); // Process batch after 5 seconds
  }

  private async processBatch(): Promise<void> {
    if (this.batchBuffer.length === 0) return;

    const batch = [...this.batchBuffer];
    this.batchBuffer = [];

    try {
      logger.debug(`Processing batch of ${batch.length} inverter records`);

      // Prepare batch insert query (excluding GENERATED columns: solar_kwh, battery_kwh, carbon_reduction, generator_status)
      const values = batch.map(data => {
        return [
          data.device_id,
          data.timestamp,
          data.pv1_input_voltage,
          data.pv1_input_current,
          data.pv1_charging_power,
          data.battery_voltage,
          data.battery_capacity,
          data.charging_current,
          data.battery_discharge_current,
          data.ac_voltage,
          data.ac_frequency,
          data.output_voltage,
          data.output_frequency,
          data.output_apparent_power,
          data.output_active_power,
          data.load_percentage,
          data.raw_data || null
        ];
      });

      const placeholders = values.map(() => '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)').join(',');

      const query = `
        INSERT INTO raw_inverter_data (
          device_id, timestamp,
          pv1_input_voltage, pv1_input_current, pv1_charging_power,
          battery_voltage, battery_capacity, charging_current, battery_discharge_current,
          ac_voltage, ac_frequency,
          output_voltage, output_frequency, output_apparent_power, output_active_power, load_percentage,
          raw_data
        ) VALUES ${placeholders}
        ON DUPLICATE KEY UPDATE
          pv1_charging_power = VALUES(pv1_charging_power),
          battery_capacity = VALUES(battery_capacity),
          load_percentage = VALUES(load_percentage)
      `;

      const flatValues = values.flat();
      await executeQuery(query, flatValues);

      logger.info(`Successfully stored ${batch.length} inverter records`);

      // Trigger aggregation for the processed data
      await this.triggerAggregation(batch[0].device_id);
    } catch (error) {
      logger.error('Failed to process inverter batch', { error, batchSize: batch.length });
      // Re-add failed batch to buffer for retry
      this.batchBuffer = [...batch, ...this.batchBuffer];
    }
  }

  private async processEnvironmentBatch(): Promise<void> {
    if (this.envBuffer.length === 0) return;

    const batch = [...this.envBuffer];
    this.envBuffer = [];

    try {
      logger.debug(`Processing batch of ${batch.length} environment records`);

      const values = batch.map(data => [
        data.device_id,
        data.timestamp,
        data.temperature,
        data.humidity
      ]);

      const placeholders = values.map(() => '(?, ?, ?, ?)').join(',');

      const query = `
        INSERT INTO raw_environment_data (
          device_id, timestamp, temperature, humidity
        ) VALUES ${placeholders}
        ON DUPLICATE KEY UPDATE
          temperature = VALUES(temperature),
          humidity = VALUES(humidity)
      `;

      const flatValues = values.flat();
      await executeQuery(query, flatValues);

      logger.info(`Successfully stored ${batch.length} environment records`);
    } catch (error) {
      logger.error('Failed to process environment batch', { error, batchSize: batch.length });
      // Re-add failed batch to buffer for retry
      this.envBuffer = [...batch, ...this.envBuffer];
    }
  }

  private async triggerAggregation(deviceId: string): Promise<void> {
    try {
      // Call stored procedure for aggregation
      await executeQuery('CALL sp_run_all_aggregations(?)', [deviceId]);
      logger.debug('Aggregation triggered successfully', { deviceId });
    } catch (error) {
      logger.error('Failed to trigger aggregation', { error, deviceId });
    }
  }

  public async flush(): Promise<void> {
    // Process any remaining data in buffers
    if (this.batchBuffer.length > 0) {
      await this.processBatch();
    }
    if (this.envBuffer.length > 0) {
      await this.processEnvironmentBatch();
    }
  }
}
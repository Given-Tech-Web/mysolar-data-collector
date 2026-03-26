import { InverterData, EnvironmentData } from '../types/mqtt-data';
import { processingLogger as logger } from '../utils/logger';

export class DataValidator {

  public validateInverterData(data: InverterData): boolean {
    try {
      // Check required fields
      if (!data.device_id || !data.timestamp) {
        logger.warn('Missing required fields in inverter data', {
          hasDeviceId: !!data.device_id,
          hasTimestamp: !!data.timestamp
        });
        return false;
      }

      // Validate timestamp
      const timestamp = new Date(data.timestamp);
      if (isNaN(timestamp.getTime())) {
        logger.warn('Invalid timestamp in inverter data', { timestamp: data.timestamp });
        return false;
      }

      // Check if timestamp is not too old (more than 1 hour)
      const now = new Date();
      const diffMs = now.getTime() - timestamp.getTime();
      if (diffMs > 3600000) {
        logger.warn('Timestamp too old in inverter data', {
          timestamp: data.timestamp,
          ageMinutes: Math.round(diffMs / 60000)
        });
        return false;
      }

      // Validate ranges
      if (!this.validateRanges(data)) {
        return false;
      }

      return true;
    } catch (error) {
      logger.error('Error validating inverter data', { error });
      return false;
    }
  }

  public validateEnvironmentData(data: EnvironmentData): boolean {
    try {
      // Check required fields
      if (!data.device_id || !data.timestamp) {
        logger.warn('Missing required fields in environment data');
        return false;
      }

      // Validate timestamp
      const timestamp = new Date(data.timestamp);
      if (isNaN(timestamp.getTime())) {
        logger.warn('Invalid timestamp in environment data', { timestamp: data.timestamp });
        return false;
      }

      // Validate temperature range (-50 to 100°C)
      if (data.temperature < -50 || data.temperature > 100) {
        logger.warn('Temperature out of range', { temperature: data.temperature });
        return false;
      }

      // Validate humidity range (0-100%)
      if (data.humidity < 0 || data.humidity > 100) {
        logger.warn('Humidity out of range', { humidity: data.humidity });
        return false;
      }

      return true;
    } catch (error) {
      logger.error('Error validating environment data', { error });
      return false;
    }
  }

  private validateRanges(data: InverterData): boolean {
    const validations = [
      // Voltage validations
      { field: 'battery_voltage', value: data.battery_voltage, min: 0, max: 100 },
      { field: 'pv1_input_voltage', value: data.pv1_input_voltage, min: 0, max: 500 },
      { field: 'output_voltage', value: data.output_voltage, min: 0, max: 300 },
      { field: 'ac_voltage', value: data.ac_voltage, min: 0, max: 300 },

      // Current validations
      { field: 'pv1_input_current', value: data.pv1_input_current, min: 0, max: 50 },
      { field: 'charging_current', value: data.charging_current, min: 0, max: 100 },
      { field: 'battery_discharge_current', value: data.battery_discharge_current, min: 0, max: 100 },

      // Power validations
      { field: 'pv1_charging_power', value: data.pv1_charging_power, min: 0, max: 10000 },
      { field: 'output_active_power', value: data.output_active_power, min: 0, max: 10000 },
      { field: 'output_apparent_power', value: data.output_apparent_power, min: 0, max: 10000 },

      // Percentage validations
      { field: 'battery_capacity', value: data.battery_capacity, min: 0, max: 100 },
      { field: 'load_percentage', value: data.load_percentage, min: 0, max: 200 },

      // Frequency validations
      { field: 'ac_frequency', value: data.ac_frequency, min: 0, max: 100 },
      { field: 'output_frequency', value: data.output_frequency, min: 0, max: 100 }
    ];

    for (const validation of validations) {
      if (validation.value < validation.min || validation.value > validation.max) {
        logger.warn('Value out of range', {
          field: validation.field,
          value: validation.value,
          min: validation.min,
          max: validation.max
        });
        // Don't reject, just warn - data might be valid but unusual
      }
    }

    return true;
  }

  public detectAnomalies(current: InverterData, previous?: InverterData): string[] {
    const anomalies: string[] = [];

    if (!previous) return anomalies;

    // Check for sudden large changes
    const checks = [
      {
        field: 'pv1_charging_power',
        current: current.pv1_charging_power,
        previous: previous.pv1_charging_power,
        threshold: 1000, // 1kW sudden change
        message: 'Sudden solar power change'
      },
      {
        field: 'battery_capacity',
        current: current.battery_capacity,
        previous: previous.battery_capacity,
        threshold: 10, // 10% sudden change
        message: 'Sudden battery capacity change'
      },
      {
        field: 'load_percentage',
        current: current.load_percentage,
        previous: previous.load_percentage,
        threshold: 50, // 50% sudden change
        message: 'Sudden load change'
      }
    ];

    for (const check of checks) {
      const diff = Math.abs(check.current - check.previous);
      if (diff > check.threshold) {
        anomalies.push(`${check.message}: ${check.previous} -> ${check.current}`);
      }
    }

    // Check for impossible conditions
    if (current.pv1_charging_power > 0 && current.pv1_input_voltage === 0) {
      anomalies.push('Solar power without voltage detected');
    }

    if (current.battery_capacity === 100 && current.charging_current > 10) {
      anomalies.push('Battery charging while at 100% capacity');
    }

    if (current.load_percentage > 0 && current.output_active_power === 0) {
      anomalies.push('Load percentage without output power');
    }

    return anomalies;
  }
}
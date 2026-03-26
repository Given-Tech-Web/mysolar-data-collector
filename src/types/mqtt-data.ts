export interface InverterData {
  device_id: string;
  timestamp: string;

  // AC Input (Generator)
  ac_voltage: number;
  ac_frequency: number;

  // Output
  output_voltage: number;
  output_frequency: number;
  output_apparent_power: number;
  output_active_power: number;
  load_percentage: number;

  // Battery
  battery_voltage: number;
  charging_current: number;
  battery_capacity: number;
  battery_discharge_current: number;

  // Solar
  pv1_input_current: number;
  pv1_input_voltage: number;
  pv1_charging_power: number;

  // Raw data
  raw_data?: string;
}

export interface EnvironmentData {
  device_id: string;
  timestamp: string;
  temperature: number;
  humidity: number;
}

export interface ProcessedInverterData extends InverterData {
  // Calculated fields
  solar_kwh: number;
  battery_kwh: number;
  carbon_reduction: number;
  generator_status: 'running' | 'stopped';
}

export interface AlertData {
  device_id: string;
  timestamp: string;
  alert_type: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  message: string;
  data?: any;
}
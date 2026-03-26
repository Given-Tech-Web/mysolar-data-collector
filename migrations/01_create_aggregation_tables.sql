-- ============================================================
-- Solar Data Collector - Aggregation Tables
-- ============================================================
-- This script creates the necessary aggregation tables for the Solar Data Collector
-- These tables work alongside the existing raw_inverter_data table

USE mysolar;

-- ============================================================
-- 1. Minute-level Aggregation Table
-- ============================================================
CREATE TABLE IF NOT EXISTS minute_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    timestamp DATETIME NOT NULL,

    -- Solar metrics
    avg_pv_voltage DECIMAL(8,2),
    avg_pv_current DECIMAL(8,2),
    avg_pv_power INT,
    max_pv_power INT,
    total_solar_kwh DECIMAL(10,4),

    -- Battery metrics
    avg_battery_voltage DECIMAL(8,2),
    avg_battery_capacity INT,
    avg_charging_current DECIMAL(8,2),
    avg_discharge_current DECIMAL(8,2),

    -- Output metrics
    avg_output_voltage DECIMAL(8,2),
    avg_output_power INT,
    avg_load_percentage INT,

    -- Carbon metrics
    carbon_reduction DECIMAL(10,4),

    -- Generator status
    generator_runtime_seconds INT DEFAULT 0,

    -- Data quality
    data_points INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_device_minute (device_id, timestamp),
    INDEX idx_device_timestamp (device_id, timestamp),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 2. Five-Minute Aggregation Table
-- ============================================================
CREATE TABLE IF NOT EXISTS five_minute_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    timestamp DATETIME NOT NULL,

    -- Solar metrics
    avg_pv_power INT,
    max_pv_power INT,
    min_pv_power INT,
    total_solar_kwh DECIMAL(10,3),

    -- Battery metrics
    avg_battery_capacity INT,
    max_battery_capacity INT,
    min_battery_capacity INT,
    battery_charge_kwh DECIMAL(10,3),
    battery_discharge_kwh DECIMAL(10,3),

    -- Load metrics
    avg_load_percentage INT,
    max_load_percentage INT,

    -- Carbon metrics
    carbon_reduction DECIMAL(10,3),

    -- Generator metrics
    generator_runtime_minutes DECIMAL(5,2),

    -- Data quality
    data_points INT,
    data_completeness DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_device_5min (device_id, timestamp),
    INDEX idx_device_timestamp (device_id, timestamp),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 3. Hourly Aggregation Table (if not exists)
-- ============================================================
CREATE TABLE IF NOT EXISTS hourly_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    timestamp DATETIME NOT NULL,

    -- Solar production
    avg_pv_power INT,
    max_pv_power INT,
    total_solar_kwh DECIMAL(10,3),
    solar_efficiency DECIMAL(5,2),

    -- Battery statistics
    avg_battery_capacity INT,
    max_battery_capacity INT,
    min_battery_capacity INT,
    battery_cycles DECIMAL(5,2),
    battery_charge_kwh DECIMAL(10,3),
    battery_discharge_kwh DECIMAL(10,3),

    -- Load and consumption
    avg_load_percentage INT,
    max_load_percentage INT,
    total_consumption_kwh DECIMAL(10,3),

    -- Environmental
    avg_temperature DECIMAL(5,2),
    avg_humidity DECIMAL(5,2),

    -- Carbon and cost
    carbon_reduction DECIMAL(10,3),
    electricity_saved DECIMAL(10,2),

    -- Generator usage
    generator_runtime_minutes INT,
    generator_fuel_consumed DECIMAL(10,2),

    -- Data quality
    data_points INT,
    data_completeness DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_device_hour (device_id, timestamp),
    INDEX idx_device_timestamp (device_id, timestamp),
    INDEX idx_timestamp (timestamp),
    INDEX idx_date (DATE(timestamp))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 4. Daily Aggregation Table (extend if exists)
-- ============================================================
CREATE TABLE IF NOT EXISTS daily_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    date DATE NOT NULL,

    -- Solar production summary
    total_solar_kwh DECIMAL(10,3),
    peak_power_w INT,
    peak_power_time TIME,
    avg_daily_power INT,
    solar_hours DECIMAL(5,2),

    -- Battery summary
    avg_battery_capacity DECIMAL(5,2),
    max_battery_capacity INT,
    min_battery_capacity INT,
    battery_cycles DECIMAL(5,2),
    total_charge_kwh DECIMAL(10,3),
    total_discharge_kwh DECIMAL(10,3),

    -- Load summary
    total_consumption_kwh DECIMAL(10,3),
    peak_load_w INT,
    avg_load_percentage DECIMAL(5,2),

    -- Environmental summary
    avg_temperature DECIMAL(5,2),
    max_temperature DECIMAL(5,2),
    min_temperature DECIMAL(5,2),
    avg_humidity DECIMAL(5,2),

    -- Carbon and financial
    carbon_reduction DECIMAL(10,3),
    electricity_saved DECIMAL(10,2),
    roi_percentage DECIMAL(5,2),

    -- Generator summary
    generator_runtime_hours DECIMAL(5,2),
    generator_fuel_liters DECIMAL(10,2),
    generator_cost DECIMAL(10,2),

    -- System performance
    system_efficiency DECIMAL(5,2),
    capacity_factor DECIMAL(5,2),
    availability_percentage DECIMAL(5,2),

    -- Data quality
    data_points INT,
    data_completeness DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_device_date (device_id, date),
    INDEX idx_device_date (device_id, date),
    INDEX idx_date (date),
    INDEX idx_year_month (YEAR(date), MONTH(date))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 5. Processing Log Table
-- ============================================================
CREATE TABLE IF NOT EXISTS processing_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    process_type VARCHAR(50) NOT NULL,
    device_id VARCHAR(50),
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    records_processed INT,
    status ENUM('running', 'completed', 'failed') DEFAULT 'running',
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_process_type (process_type),
    INDEX idx_status (status),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 6. Add missing columns to raw_inverter_data if not exists
-- ============================================================
-- Check and add calculated fields to existing table
DELIMITER //
CREATE PROCEDURE AddMissingColumns()
BEGIN
    -- Add solar_kwh if not exists
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_NAME = 'raw_inverter_data'
                   AND COLUMN_NAME = 'solar_kwh'
                   AND TABLE_SCHEMA = 'mysolar') THEN
        ALTER TABLE raw_inverter_data ADD COLUMN solar_kwh DECIMAL(10,4)
            GENERATED ALWAYS AS (pv1_charging_power / 1000) STORED;
    END IF;

    -- Add battery_kwh if not exists
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_NAME = 'raw_inverter_data'
                   AND COLUMN_NAME = 'battery_kwh'
                   AND TABLE_SCHEMA = 'mysolar') THEN
        ALTER TABLE raw_inverter_data ADD COLUMN battery_kwh DECIMAL(10,4)
            GENERATED ALWAYS AS ((battery_capacity / 100) * 19.2) STORED;
    END IF;

    -- Add carbon_reduction if not exists
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_NAME = 'raw_inverter_data'
                   AND COLUMN_NAME = 'carbon_reduction'
                   AND TABLE_SCHEMA = 'mysolar') THEN
        ALTER TABLE raw_inverter_data ADD COLUMN carbon_reduction DECIMAL(10,4)
            GENERATED ALWAYS AS ((pv1_charging_power / 1000) * 0.4781) STORED;
    END IF;

    -- Add generator_status if not exists
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_NAME = 'raw_inverter_data'
                   AND COLUMN_NAME = 'generator_status'
                   AND TABLE_SCHEMA = 'mysolar') THEN
        ALTER TABLE raw_inverter_data ADD COLUMN generator_status VARCHAR(10)
            GENERATED ALWAYS AS (IF(ac_voltage > 200, 'running', 'stopped')) STORED;
    END IF;
END//
DELIMITER ;

-- Execute the procedure
CALL AddMissingColumns();
DROP PROCEDURE AddMissingColumns;

-- ============================================================
-- 7. Create environment data table if not exists
-- ============================================================
CREATE TABLE IF NOT EXISTS raw_environment_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    timestamp DATETIME NOT NULL,
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_device_timestamp (device_id, timestamp),
    INDEX idx_device_timestamp (device_id, timestamp),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
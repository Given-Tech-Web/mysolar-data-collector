-- Solar Data Collector Database Schema
-- Version: 1.0.0
-- Description: Comprehensive schema for solar monitoring data

USE mysolar;

-- =====================================================
-- 1. RAW DATA TABLES (30-second interval data)
-- =====================================================

-- Raw inverter data with partitioning
CREATE TABLE IF NOT EXISTS raw_inverter_data (
    id BIGINT AUTO_INCREMENT,
    device_id VARCHAR(50) NOT NULL,
    timestamp DATETIME(3) NOT NULL,

    -- Solar fields
    pv1_input_voltage FLOAT,
    pv1_input_current FLOAT,
    pv1_charging_power INT,

    -- Battery fields
    battery_voltage FLOAT,
    battery_capacity INT,
    charging_current INT,
    battery_discharge_current FLOAT,

    -- Generator fields
    ac_voltage FLOAT,
    ac_frequency FLOAT,

    -- Inverter fields
    output_voltage FLOAT,
    output_frequency FLOAT,
    output_apparent_power INT,
    output_active_power INT,
    load_percentage INT,

    -- Calculated fields
    solar_kwh FLOAT GENERATED ALWAYS AS (pv1_charging_power / 1000) STORED,
    battery_kwh FLOAT GENERATED ALWAYS AS ((battery_capacity / 100) * 19.2) STORED,
    carbon_reduction FLOAT GENERATED ALWAYS AS ((pv1_charging_power / 1000) * 0.4781) STORED,
    generator_status VARCHAR(10) GENERATED ALWAYS AS (IF(ac_voltage > 200, 'running', 'stopped')) STORED,

    -- Metadata
    raw_data TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id, timestamp),
    INDEX idx_device_timestamp (device_id, timestamp),
    INDEX idx_timestamp (timestamp),
    INDEX idx_solar_power (pv1_charging_power, timestamp)
) PARTITION BY RANGE (TO_DAYS(timestamp)) (
    PARTITION p_default VALUES LESS THAN MAXVALUE
);

-- Raw environment data with partitioning
CREATE TABLE IF NOT EXISTS raw_environment_data (
    id BIGINT AUTO_INCREMENT,
    device_id VARCHAR(50) NOT NULL,
    timestamp DATETIME(3) NOT NULL,
    temperature FLOAT,
    humidity FLOAT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id, timestamp),
    INDEX idx_device_timestamp (device_id, timestamp),
    INDEX idx_timestamp (timestamp)
) PARTITION BY RANGE (TO_DAYS(timestamp)) (
    PARTITION p_default VALUES LESS THAN MAXVALUE
);

-- =====================================================
-- 2. AGGREGATED DATA TABLES
-- =====================================================

-- 1-minute aggregated data
CREATE TABLE IF NOT EXISTS minute_data (
    device_id VARCHAR(50) NOT NULL,
    timestamp DATETIME NOT NULL,

    -- Solar aggregates
    solar_power_avg FLOAT,
    solar_power_max INT,
    solar_power_min INT,
    solar_kwh_sum FLOAT,

    -- Battery aggregates
    battery_capacity_avg FLOAT,
    battery_capacity_max INT,
    battery_capacity_min INT,
    battery_kwh_avg FLOAT,

    -- Load aggregates
    load_percentage_avg FLOAT,
    load_percentage_max INT,

    -- Environment aggregates
    temperature_avg FLOAT,
    humidity_avg FLOAT,

    -- Calculated
    carbon_reduction_sum FLOAT,
    efficiency FLOAT,
    generator_runtime_seconds INT,

    -- Metadata
    data_points INT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (device_id, timestamp),
    INDEX idx_timestamp (timestamp)
);

-- 5-minute aggregated data
CREATE TABLE IF NOT EXISTS five_minute_data (
    device_id VARCHAR(50) NOT NULL,
    timestamp DATETIME NOT NULL,

    -- Solar aggregates
    solar_power_avg FLOAT,
    solar_power_max INT,
    solar_kwh_sum FLOAT,

    -- Battery aggregates
    battery_capacity_avg FLOAT,
    battery_kwh_avg FLOAT,
    charge_cycles FLOAT,

    -- Performance
    system_efficiency FLOAT,
    capacity_factor FLOAT,

    -- Environment
    temperature_avg FLOAT,
    humidity_avg FLOAT,

    -- Calculated
    carbon_reduction_sum FLOAT,
    cost_savings DECIMAL(10,2),

    -- Metadata
    data_points INT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (device_id, timestamp),
    INDEX idx_timestamp (timestamp)
);

-- Hourly aggregated data
CREATE TABLE IF NOT EXISTS hourly_data (
    device_id VARCHAR(50) NOT NULL,
    timestamp DATETIME NOT NULL,

    -- Solar statistics
    solar_kwh_total FLOAT,
    solar_power_avg FLOAT,
    solar_power_peak INT,
    solar_power_min INT,

    -- Battery statistics
    battery_capacity_avg FLOAT,
    battery_kwh_avg FLOAT,
    battery_cycles FLOAT,
    battery_health FLOAT,

    -- Generator statistics
    generator_runtime_minutes INT,
    generator_fuel_estimate FLOAT,

    -- Load statistics
    load_kwh_total FLOAT,
    load_percentage_avg FLOAT,
    load_peak_percentage INT,

    -- Environment
    temperature_avg FLOAT,
    temperature_max FLOAT,
    temperature_min FLOAT,
    humidity_avg FLOAT,

    -- Performance metrics
    system_efficiency FLOAT,
    capacity_factor FLOAT,
    performance_ratio FLOAT,

    -- Financial metrics
    carbon_reduction_total FLOAT,
    cost_savings DECIMAL(10,2),
    revenue_generated DECIMAL(10,2),

    -- Metadata
    data_quality_score FLOAT,
    data_points INT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (device_id, timestamp),
    INDEX idx_timestamp (timestamp),
    INDEX idx_solar_kwh (solar_kwh_total)
);

-- Daily aggregated data
CREATE TABLE IF NOT EXISTS daily_data (
    device_id VARCHAR(50) NOT NULL,
    date DATE NOT NULL,

    -- Solar production
    solar_kwh_total FLOAT,
    solar_power_peak INT,
    solar_power_avg FLOAT,
    peak_sun_hours FLOAT,

    -- Battery performance
    battery_capacity_avg FLOAT,
    battery_cycles FLOAT,
    battery_health FLOAT,
    battery_kwh_throughput FLOAT,

    -- Generator usage
    generator_runtime_hours FLOAT,
    generator_start_count INT,
    generator_fuel_consumption FLOAT,

    -- Load consumption
    load_kwh_total FLOAT,
    load_peak_kw FLOAT,
    load_avg_kw FLOAT,
    self_consumption_rate FLOAT,

    -- Environment
    temperature_avg FLOAT,
    temperature_max FLOAT,
    temperature_min FLOAT,
    humidity_avg FLOAT,
    weather_condition VARCHAR(50),

    -- Performance metrics
    system_efficiency FLOAT,
    capacity_factor FLOAT,
    performance_ratio FLOAT,
    availability FLOAT,

    -- Financial metrics
    carbon_reduction_total FLOAT,
    trees_equivalent INT,
    cost_savings DECIMAL(10,2),
    revenue_generated DECIMAL(10,2),
    roi_daily DECIMAL(10,4),

    -- Data quality
    data_completeness FLOAT,
    data_quality_score FLOAT,
    anomalies_detected INT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (device_id, date),
    INDEX idx_date (date),
    INDEX idx_solar_production (solar_kwh_total, date)
);

-- Monthly aggregated data
CREATE TABLE IF NOT EXISTS monthly_data (
    device_id VARCHAR(50) NOT NULL,
    year INT NOT NULL,
    month INT NOT NULL,

    -- Solar production
    solar_kwh_total FLOAT,
    solar_kwh_daily_avg FLOAT,
    solar_power_peak INT,
    best_production_day DATE,
    worst_production_day DATE,

    -- Battery statistics
    battery_cycles_total FLOAT,
    battery_health_avg FLOAT,
    battery_degradation FLOAT,

    -- Generator statistics
    generator_runtime_hours FLOAT,
    generator_fuel_cost DECIMAL(10,2),

    -- Load statistics
    load_kwh_total FLOAT,
    self_sufficiency_rate FLOAT,

    -- Performance metrics
    system_efficiency_avg FLOAT,
    capacity_factor_avg FLOAT,
    uptime_percentage FLOAT,

    -- Financial summary
    carbon_reduction_total FLOAT,
    cost_savings_total DECIMAL(10,2),
    revenue_total DECIMAL(10,2),
    roi_monthly DECIMAL(10,4),
    payback_period_months FLOAT,

    -- Comparative metrics
    vs_previous_month FLOAT,
    vs_same_month_last_year FLOAT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (device_id, year, month),
    INDEX idx_year_month (year, month)
);

-- =====================================================
-- 3. ANALYSIS TABLES
-- =====================================================

-- Performance analysis
CREATE TABLE IF NOT EXISTS performance_analysis (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    analysis_date DATE NOT NULL,
    analysis_type VARCHAR(50),

    -- Efficiency metrics
    dc_to_ac_efficiency FLOAT,
    battery_round_trip_efficiency FLOAT,
    system_losses FLOAT,

    -- Peak performance
    peak_performance_time TIME,
    peak_performance_value FLOAT,
    peak_performance_conditions JSON,

    -- Patterns
    daily_pattern JSON,
    weekly_pattern JSON,
    seasonal_factor FLOAT,

    -- Recommendations
    optimization_potential FLOAT,
    recommendations JSON,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_device_date_type (device_id, analysis_date, analysis_type),
    INDEX idx_analysis_date (analysis_date)
);

-- Anomaly detection
CREATE TABLE IF NOT EXISTS anomaly_detection (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    detected_at DATETIME NOT NULL,
    anomaly_type VARCHAR(50),
    severity ENUM('low', 'medium', 'high', 'critical'),

    -- Anomaly details
    metric_name VARCHAR(100),
    expected_value FLOAT,
    actual_value FLOAT,
    deviation_percentage FLOAT,

    -- Context
    conditions JSON,
    possible_causes JSON,

    -- Resolution
    auto_resolved BOOLEAN DEFAULT FALSE,
    resolved_at DATETIME,
    resolution_notes TEXT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_device_time (device_id, detected_at),
    INDEX idx_severity (severity),
    INDEX idx_unresolved (auto_resolved, severity)
);

-- Predictive analytics
CREATE TABLE IF NOT EXISTS predictions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    prediction_date DATE NOT NULL,
    prediction_type VARCHAR(50),
    target_date DATE NOT NULL,

    -- Predictions
    predicted_value FLOAT,
    confidence_level FLOAT,
    prediction_range_min FLOAT,
    prediction_range_max FLOAT,

    -- Model info
    model_name VARCHAR(100),
    model_accuracy FLOAT,
    features_used JSON,

    -- Actual vs predicted (updated later)
    actual_value FLOAT,
    error_percentage FLOAT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_device_target (device_id, target_date),
    INDEX idx_prediction_type (prediction_type, prediction_date)
);

-- Cost analysis
CREATE TABLE IF NOT EXISTS cost_analysis (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    analysis_date DATE NOT NULL,

    -- Energy costs
    grid_electricity_cost DECIMAL(10,2),
    solar_savings DECIMAL(10,2),
    net_metering_credit DECIMAL(10,2),

    -- Operational costs
    maintenance_cost DECIMAL(10,2),
    generator_fuel_cost DECIMAL(10,2),

    -- Financial metrics
    daily_roi DECIMAL(10,4),
    payback_days_remaining INT,
    lcoe DECIMAL(10,4), -- Levelized Cost of Energy

    -- Carbon economics
    carbon_credit_value DECIMAL(10,2),
    environmental_benefit_value DECIMAL(10,2),

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_device_date (device_id, analysis_date),
    INDEX idx_analysis_date (analysis_date)
);

-- =====================================================
-- 4. REPORT TABLES
-- =====================================================

-- Report metadata
CREATE TABLE IF NOT EXISTS report_metadata (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    report_id VARCHAR(100) UNIQUE NOT NULL,
    report_type VARCHAR(50) NOT NULL,
    device_id VARCHAR(50) NOT NULL,

    -- Report parameters
    start_date DATE,
    end_date DATE,
    parameters JSON,

    -- Report info
    generated_at DATETIME NOT NULL,
    generated_by VARCHAR(100),
    file_path VARCHAR(500),
    file_size INT,

    -- Status
    status ENUM('pending', 'processing', 'completed', 'failed'),
    error_message TEXT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_report_type (report_type),
    INDEX idx_device_date (device_id, generated_at)
);

-- Report cache
CREATE TABLE IF NOT EXISTS report_cache (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cache_key VARCHAR(255) UNIQUE NOT NULL,
    report_type VARCHAR(50) NOT NULL,

    -- Cache data
    data JSON,
    metadata JSON,

    -- Validity
    expires_at DATETIME NOT NULL,
    hit_count INT DEFAULT 0,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_accessed DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_expires (expires_at),
    INDEX idx_report_type (report_type)
);

-- =====================================================
-- 5. SYSTEM TABLES
-- =====================================================

-- System configuration
CREATE TABLE IF NOT EXISTS system_config (
    config_key VARCHAR(100) PRIMARY KEY,
    config_value TEXT,
    config_type VARCHAR(50),
    description TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Processing log
CREATE TABLE IF NOT EXISTS processing_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    process_name VARCHAR(100),
    process_type VARCHAR(50),

    -- Execution details
    started_at DATETIME NOT NULL,
    completed_at DATETIME,
    duration_ms INT,

    -- Results
    records_processed INT,
    records_failed INT,
    status ENUM('running', 'completed', 'failed'),
    error_message TEXT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_process_time (process_type, started_at),
    INDEX idx_status (status)
);

-- Data quality metrics
CREATE TABLE IF NOT EXISTS data_quality_metrics (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    metric_date DATE NOT NULL,

    -- Quality scores (0-100)
    completeness_score FLOAT,
    accuracy_score FLOAT,
    consistency_score FLOAT,
    timeliness_score FLOAT,
    overall_score FLOAT,

    -- Issues
    missing_data_points INT,
    invalid_data_points INT,
    late_data_points INT,

    -- Details
    quality_issues JSON,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_device_date (device_id, metric_date),
    INDEX idx_metric_date (metric_date)
);

-- =====================================================
-- 6. INITIAL CONFIGURATION
-- =====================================================

-- Insert default configuration
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES
('retention.raw_data', '90', 'integer', 'Days to retain raw data'),
('retention.minute_data', '30', 'integer', 'Days to retain minute data'),
('retention.five_minute_data', '90', 'integer', 'Days to retain 5-minute data'),
('retention.hourly_data', '365', 'integer', 'Days to retain hourly data'),
('carbon_factor', '0.4781', 'float', 'kg CO2 per kWh'),
('solar_capacity', '5000', 'integer', 'Solar panel capacity in watts'),
('battery_capacity', '19.2', 'float', 'Battery capacity in kWh'),
('electricity_rate', '0.12', 'float', 'Electricity rate per kWh')
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;
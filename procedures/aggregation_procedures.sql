-- Stored Procedures for Data Aggregation
-- Solar Data Collector System

USE mysolar;

DELIMITER $$

-- =====================================================
-- 1. MINUTE AGGREGATION PROCEDURE
-- =====================================================
CREATE PROCEDURE IF NOT EXISTS sp_aggregate_minute_data(
    IN p_device_id VARCHAR(50),
    IN p_start_time DATETIME,
    IN p_end_time DATETIME
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        INSERT INTO processing_log (process_name, process_type, started_at, status, error_message)
        VALUES ('sp_aggregate_minute_data', 'aggregation', NOW(), 'failed', 'SQL Exception occurred');
    END;

    START TRANSACTION;

    -- Insert aggregated minute data
    INSERT INTO minute_data (
        device_id, timestamp,
        solar_power_avg, solar_power_max, solar_power_min, solar_kwh_sum,
        battery_capacity_avg, battery_capacity_max, battery_capacity_min, battery_kwh_avg,
        load_percentage_avg, load_percentage_max,
        temperature_avg, humidity_avg,
        carbon_reduction_sum, efficiency, generator_runtime_seconds,
        data_points
    )
    SELECT
        r.device_id,
        DATE_FORMAT(r.timestamp, '%Y-%m-%d %H:%i:00') as minute_timestamp,

        -- Solar aggregates
        AVG(r.pv1_charging_power) as solar_power_avg,
        MAX(r.pv1_charging_power) as solar_power_max,
        MIN(r.pv1_charging_power) as solar_power_min,
        SUM(r.solar_kwh) as solar_kwh_sum,

        -- Battery aggregates
        AVG(r.battery_capacity) as battery_capacity_avg,
        MAX(r.battery_capacity) as battery_capacity_max,
        MIN(r.battery_capacity) as battery_capacity_min,
        AVG(r.battery_kwh) as battery_kwh_avg,

        -- Load aggregates
        AVG(r.load_percentage) as load_percentage_avg,
        MAX(r.load_percentage) as load_percentage_max,

        -- Environment aggregates
        AVG(e.temperature) as temperature_avg,
        AVG(e.humidity) as humidity_avg,

        -- Calculated fields
        SUM(r.carbon_reduction) as carbon_reduction_sum,
        AVG(r.pv1_charging_power / 5000 * 100) as efficiency,
        SUM(CASE WHEN r.generator_status = 'running' THEN 30 ELSE 0 END) as generator_runtime_seconds,

        COUNT(*) as data_points

    FROM raw_inverter_data r
    LEFT JOIN raw_environment_data e ON r.device_id = e.device_id
        AND ABS(TIMESTAMPDIFF(SECOND, r.timestamp, e.timestamp)) <= 30
    WHERE r.device_id = p_device_id
        AND r.timestamp >= p_start_time
        AND r.timestamp < p_end_time
    GROUP BY r.device_id, minute_timestamp
    ON DUPLICATE KEY UPDATE
        solar_power_avg = VALUES(solar_power_avg),
        solar_power_max = VALUES(solar_power_max),
        solar_power_min = VALUES(solar_power_min),
        solar_kwh_sum = VALUES(solar_kwh_sum),
        data_points = VALUES(data_points);

    COMMIT;
END$$

-- =====================================================
-- 2. 5-MINUTE AGGREGATION PROCEDURE
-- =====================================================
CREATE PROCEDURE IF NOT EXISTS sp_aggregate_five_minute_data(
    IN p_device_id VARCHAR(50),
    IN p_start_time DATETIME,
    IN p_end_time DATETIME
)
BEGIN
    DECLARE v_electricity_rate DECIMAL(10,4);

    -- Get electricity rate from config
    SELECT CAST(config_value AS DECIMAL(10,4)) INTO v_electricity_rate
    FROM system_config WHERE config_key = 'electricity_rate';

    INSERT INTO five_minute_data (
        device_id, timestamp,
        solar_power_avg, solar_power_max, solar_kwh_sum,
        battery_capacity_avg, battery_kwh_avg, charge_cycles,
        system_efficiency, capacity_factor,
        temperature_avg, humidity_avg,
        carbon_reduction_sum, cost_savings,
        data_points
    )
    SELECT
        device_id,
        DATE_FORMAT(timestamp, '%Y-%m-%d %H:%i:00') - INTERVAL MINUTE(timestamp) % 5 MINUTE as five_min_timestamp,

        AVG(solar_power_avg) as solar_power_avg,
        MAX(solar_power_max) as solar_power_max,
        SUM(solar_kwh_sum) as solar_kwh_sum,

        AVG(battery_capacity_avg) as battery_capacity_avg,
        AVG(battery_kwh_avg) as battery_kwh_avg,
        SUM(CASE WHEN battery_capacity_max - battery_capacity_min > 20 THEN 0.1 ELSE 0 END) as charge_cycles,

        AVG(efficiency) as system_efficiency,
        AVG(solar_power_avg) / 5000 as capacity_factor,

        AVG(temperature_avg) as temperature_avg,
        AVG(humidity_avg) as humidity_avg,

        SUM(carbon_reduction_sum) as carbon_reduction_sum,
        SUM(solar_kwh_sum) * v_electricity_rate as cost_savings,

        SUM(data_points) as data_points

    FROM minute_data
    WHERE device_id = p_device_id
        AND timestamp >= p_start_time
        AND timestamp < p_end_time
    GROUP BY device_id, five_min_timestamp
    ON DUPLICATE KEY UPDATE
        solar_power_avg = VALUES(solar_power_avg),
        solar_power_max = VALUES(solar_power_max),
        solar_kwh_sum = VALUES(solar_kwh_sum),
        data_points = VALUES(data_points);
END$$

-- =====================================================
-- 3. HOURLY AGGREGATION PROCEDURE
-- =====================================================
CREATE PROCEDURE IF NOT EXISTS sp_aggregate_hourly_data(
    IN p_device_id VARCHAR(50),
    IN p_start_time DATETIME,
    IN p_end_time DATETIME
)
BEGIN
    DECLARE v_electricity_rate DECIMAL(10,4);
    DECLARE v_carbon_credit_rate DECIMAL(10,4) DEFAULT 0.02;

    -- Get electricity rate
    SELECT CAST(config_value AS DECIMAL(10,4)) INTO v_electricity_rate
    FROM system_config WHERE config_key = 'electricity_rate';

    INSERT INTO hourly_data (
        device_id, timestamp,
        solar_kwh_total, solar_power_avg, solar_power_peak, solar_power_min,
        battery_capacity_avg, battery_kwh_avg, battery_cycles, battery_health,
        generator_runtime_minutes, generator_fuel_estimate,
        load_kwh_total, load_percentage_avg, load_peak_percentage,
        temperature_avg, temperature_max, temperature_min, humidity_avg,
        system_efficiency, capacity_factor, performance_ratio,
        carbon_reduction_total, cost_savings, revenue_generated,
        data_quality_score, data_points
    )
    SELECT
        device_id,
        DATE_FORMAT(timestamp, '%Y-%m-%d %H:00:00') as hour_timestamp,

        -- Solar statistics
        SUM(solar_kwh_sum) as solar_kwh_total,
        AVG(solar_power_avg) as solar_power_avg,
        MAX(solar_power_max) as solar_power_peak,
        MIN(solar_power_avg) as solar_power_min,

        -- Battery statistics
        AVG(battery_capacity_avg) as battery_capacity_avg,
        AVG(battery_kwh_avg) as battery_kwh_avg,
        SUM(charge_cycles) as battery_cycles,
        100.0 as battery_health, -- Placeholder, needs actual calculation

        -- Generator statistics
        SUM(CASE WHEN solar_power_avg < 100 THEN 5 ELSE 0 END) as generator_runtime_minutes,
        SUM(CASE WHEN solar_power_avg < 100 THEN 0.5 ELSE 0 END) as generator_fuel_estimate,

        -- Load statistics
        SUM(solar_kwh_sum * 0.8) as load_kwh_total, -- Assuming 80% self-consumption
        AVG(solar_power_avg * 0.8 / 50) as load_percentage_avg,
        MAX(solar_power_max * 0.8 / 50) as load_peak_percentage,

        -- Environment
        AVG(temperature_avg) as temperature_avg,
        MAX(temperature_avg) as temperature_max,
        MIN(temperature_avg) as temperature_min,
        AVG(humidity_avg) as humidity_avg,

        -- Performance metrics
        AVG(system_efficiency) as system_efficiency,
        AVG(capacity_factor) as capacity_factor,
        AVG(system_efficiency * 0.95) as performance_ratio,

        -- Financial metrics
        SUM(carbon_reduction_sum) as carbon_reduction_total,
        SUM(cost_savings) as cost_savings,
        SUM(solar_kwh_sum * v_electricity_rate * 1.1) as revenue_generated,

        -- Data quality
        LEAST(100, (SUM(data_points) / 12) * 100) as data_quality_score,
        SUM(data_points) as data_points

    FROM five_minute_data
    WHERE device_id = p_device_id
        AND timestamp >= p_start_time
        AND timestamp < p_end_time
    GROUP BY device_id, hour_timestamp
    ON DUPLICATE KEY UPDATE
        solar_kwh_total = VALUES(solar_kwh_total),
        solar_power_avg = VALUES(solar_power_avg),
        solar_power_peak = VALUES(solar_power_peak),
        data_points = VALUES(data_points);
END$$

-- =====================================================
-- 4. DAILY AGGREGATION PROCEDURE
-- =====================================================
CREATE PROCEDURE IF NOT EXISTS sp_aggregate_daily_data(
    IN p_device_id VARCHAR(50),
    IN p_date DATE
)
BEGIN
    DECLARE v_electricity_rate DECIMAL(10,4);

    SELECT CAST(config_value AS DECIMAL(10,4)) INTO v_electricity_rate
    FROM system_config WHERE config_key = 'electricity_rate';

    INSERT INTO daily_data (
        device_id, date,
        solar_kwh_total, solar_power_peak, solar_power_avg, peak_sun_hours,
        battery_capacity_avg, battery_cycles, battery_health, battery_kwh_throughput,
        generator_runtime_hours, generator_start_count, generator_fuel_consumption,
        load_kwh_total, load_peak_kw, load_avg_kw, self_consumption_rate,
        temperature_avg, temperature_max, temperature_min, humidity_avg,
        system_efficiency, capacity_factor, performance_ratio, availability,
        carbon_reduction_total, trees_equivalent, cost_savings, revenue_generated, roi_daily,
        data_completeness, data_quality_score, anomalies_detected
    )
    SELECT
        device_id,
        p_date,

        -- Solar production
        SUM(solar_kwh_total) as solar_kwh_total,
        MAX(solar_power_peak) as solar_power_peak,
        AVG(solar_power_avg) as solar_power_avg,
        SUM(solar_kwh_total) / (MAX(solar_power_peak) / 1000) as peak_sun_hours,

        -- Battery performance
        AVG(battery_capacity_avg) as battery_capacity_avg,
        SUM(battery_cycles) as battery_cycles,
        AVG(battery_health) as battery_health,
        SUM(battery_kwh_avg) as battery_kwh_throughput,

        -- Generator usage
        SUM(generator_runtime_minutes) / 60 as generator_runtime_hours,
        SUM(CASE WHEN generator_runtime_minutes > 0 THEN 1 ELSE 0 END) as generator_start_count,
        SUM(generator_fuel_estimate) as generator_fuel_consumption,

        -- Load consumption
        SUM(load_kwh_total) as load_kwh_total,
        MAX(load_kwh_total) as load_peak_kw,
        AVG(load_kwh_total) as load_avg_kw,
        (SUM(load_kwh_total) / NULLIF(SUM(solar_kwh_total), 0)) * 100 as self_consumption_rate,

        -- Environment
        AVG(temperature_avg) as temperature_avg,
        MAX(temperature_max) as temperature_max,
        MIN(temperature_min) as temperature_min,
        AVG(humidity_avg) as humidity_avg,

        -- Performance metrics
        AVG(system_efficiency) as system_efficiency,
        AVG(capacity_factor) as capacity_factor,
        AVG(performance_ratio) as performance_ratio,
        (SUM(data_points) / (24 * 12)) * 100 as availability,

        -- Financial metrics
        SUM(carbon_reduction_total) as carbon_reduction_total,
        ROUND(SUM(carbon_reduction_total) / 21) as trees_equivalent,
        SUM(cost_savings) as cost_savings,
        SUM(revenue_generated) as revenue_generated,
        (SUM(cost_savings) / 10000) * 100 as roi_daily,

        -- Data quality
        (SUM(data_points) / (24 * 12)) * 100 as data_completeness,
        AVG(data_quality_score) as data_quality_score,
        0 as anomalies_detected

    FROM hourly_data
    WHERE device_id = p_device_id
        AND DATE(timestamp) = p_date
    GROUP BY device_id
    ON DUPLICATE KEY UPDATE
        solar_kwh_total = VALUES(solar_kwh_total),
        solar_power_peak = VALUES(solar_power_peak),
        carbon_reduction_total = VALUES(carbon_reduction_total),
        updated_at = CURRENT_TIMESTAMP;
END$$

-- =====================================================
-- 5. MONTHLY AGGREGATION PROCEDURE
-- =====================================================
CREATE PROCEDURE IF NOT EXISTS sp_aggregate_monthly_data(
    IN p_device_id VARCHAR(50),
    IN p_year INT,
    IN p_month INT
)
BEGIN
    DECLARE v_previous_month_solar FLOAT DEFAULT 0;
    DECLARE v_last_year_solar FLOAT DEFAULT 0;

    -- Get previous month data
    SELECT solar_kwh_total INTO v_previous_month_solar
    FROM monthly_data
    WHERE device_id = p_device_id
        AND ((year = p_year AND month = p_month - 1) OR (year = p_year - 1 AND month = 12 AND p_month = 1))
    LIMIT 1;

    -- Get same month last year data
    SELECT solar_kwh_total INTO v_last_year_solar
    FROM monthly_data
    WHERE device_id = p_device_id
        AND year = p_year - 1
        AND month = p_month
    LIMIT 1;

    INSERT INTO monthly_data (
        device_id, year, month,
        solar_kwh_total, solar_kwh_daily_avg, solar_power_peak,
        best_production_day, worst_production_day,
        battery_cycles_total, battery_health_avg, battery_degradation,
        generator_runtime_hours, generator_fuel_cost,
        load_kwh_total, self_sufficiency_rate,
        system_efficiency_avg, capacity_factor_avg, uptime_percentage,
        carbon_reduction_total, cost_savings_total, revenue_total, roi_monthly,
        vs_previous_month, vs_same_month_last_year
    )
    SELECT
        device_id,
        p_year,
        p_month,

        -- Solar production
        SUM(solar_kwh_total) as solar_kwh_total,
        AVG(solar_kwh_total) as solar_kwh_daily_avg,
        MAX(solar_power_peak) as solar_power_peak,
        (SELECT date FROM daily_data WHERE device_id = p_device_id AND YEAR(date) = p_year AND MONTH(date) = p_month ORDER BY solar_kwh_total DESC LIMIT 1) as best_day,
        (SELECT date FROM daily_data WHERE device_id = p_device_id AND YEAR(date) = p_year AND MONTH(date) = p_month ORDER BY solar_kwh_total ASC LIMIT 1) as worst_day,

        -- Battery statistics
        SUM(battery_cycles) as battery_cycles_total,
        AVG(battery_health) as battery_health_avg,
        0 as battery_degradation, -- Placeholder

        -- Generator statistics
        SUM(generator_runtime_hours) as generator_runtime_hours,
        SUM(generator_fuel_consumption * 2.5) as generator_fuel_cost,

        -- Load statistics
        SUM(load_kwh_total) as load_kwh_total,
        AVG(self_consumption_rate) as self_sufficiency_rate,

        -- Performance metrics
        AVG(system_efficiency) as system_efficiency_avg,
        AVG(capacity_factor) as capacity_factor_avg,
        AVG(availability) as uptime_percentage,

        -- Financial summary
        SUM(carbon_reduction_total) as carbon_reduction_total,
        SUM(cost_savings) as cost_savings_total,
        SUM(revenue_generated) as revenue_total,
        (SUM(cost_savings) / 10000) * 100 as roi_monthly,

        -- Comparative metrics
        CASE WHEN v_previous_month_solar > 0
            THEN ((SUM(solar_kwh_total) - v_previous_month_solar) / v_previous_month_solar) * 100
            ELSE 0 END as vs_previous_month,
        CASE WHEN v_last_year_solar > 0
            THEN ((SUM(solar_kwh_total) - v_last_year_solar) / v_last_year_solar) * 100
            ELSE 0 END as vs_same_month_last_year

    FROM daily_data
    WHERE device_id = p_device_id
        AND YEAR(date) = p_year
        AND MONTH(date) = p_month
    GROUP BY device_id
    ON DUPLICATE KEY UPDATE
        solar_kwh_total = VALUES(solar_kwh_total),
        carbon_reduction_total = VALUES(carbon_reduction_total),
        updated_at = CURRENT_TIMESTAMP;
END$$

-- =====================================================
-- 6. MASTER AGGREGATION PROCEDURE
-- =====================================================
CREATE PROCEDURE IF NOT EXISTS sp_run_all_aggregations(
    IN p_device_id VARCHAR(50)
)
BEGIN
    DECLARE v_start_time DATETIME;
    DECLARE v_end_time DATETIME;

    -- Set time range (last 2 hours to ensure overlap)
    SET v_end_time = NOW();
    SET v_start_time = DATE_SUB(v_end_time, INTERVAL 2 HOUR);

    -- Log start
    INSERT INTO processing_log (process_name, process_type, started_at, status)
    VALUES ('sp_run_all_aggregations', 'master_aggregation', NOW(), 'running');

    -- Run minute aggregation
    CALL sp_aggregate_minute_data(p_device_id, v_start_time, v_end_time);

    -- Run 5-minute aggregation
    CALL sp_aggregate_five_minute_data(p_device_id, v_start_time, v_end_time);

    -- Run hourly aggregation
    CALL sp_aggregate_hourly_data(p_device_id, v_start_time, v_end_time);

    -- Run daily aggregation for today
    CALL sp_aggregate_daily_data(p_device_id, CURDATE());

    -- Run monthly aggregation for current month
    CALL sp_aggregate_monthly_data(p_device_id, YEAR(NOW()), MONTH(NOW()));

    -- Log completion
    UPDATE processing_log
    SET completed_at = NOW(),
        duration_ms = TIMESTAMPDIFF(MICROSECOND, started_at, NOW()) / 1000,
        status = 'completed'
    WHERE process_name = 'sp_run_all_aggregations'
        AND status = 'running'
    ORDER BY started_at DESC
    LIMIT 1;
END$$

DELIMITER ;
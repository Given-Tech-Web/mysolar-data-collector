-- ============================================================
-- Solar Data Collector - Stored Procedures
-- ============================================================
-- This script creates the necessary stored procedures for data aggregation

USE mysolar;

-- Drop existing procedures if they exist
DROP PROCEDURE IF EXISTS sp_aggregate_minute_data;
DROP PROCEDURE IF EXISTS sp_aggregate_five_minute_data;
DROP PROCEDURE IF EXISTS sp_aggregate_hourly_data;
DROP PROCEDURE IF EXISTS sp_aggregate_daily_data;
DROP PROCEDURE IF EXISTS sp_aggregate_monthly_data;
DROP PROCEDURE IF EXISTS sp_run_all_aggregations;

DELIMITER //

-- ============================================================
-- 1. Minute-level Aggregation Procedure
-- ============================================================
CREATE PROCEDURE sp_aggregate_minute_data(
    IN p_device_id VARCHAR(50),
    IN p_start_time DATETIME,
    IN p_end_time DATETIME
)
BEGIN
    DECLARE v_process_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE processing_log SET
            status = 'failed',
            end_time = NOW(),
            error_message = 'Error in minute aggregation'
        WHERE id = v_process_id;
    END;

    -- Log the start of processing
    INSERT INTO processing_log (process_type, device_id, start_time, status)
    VALUES ('minute_aggregation', p_device_id, NOW(), 'running');
    SET v_process_id = LAST_INSERT_ID();

    START TRANSACTION;

    -- Insert aggregated minute data
    INSERT INTO minute_data (
        device_id, timestamp,
        avg_pv_voltage, avg_pv_current, avg_pv_power, max_pv_power, total_solar_kwh,
        avg_battery_voltage, avg_battery_capacity, avg_charging_current, avg_discharge_current,
        avg_output_voltage, avg_output_power, avg_load_percentage,
        carbon_reduction, generator_runtime_seconds, data_points
    )
    SELECT
        device_id,
        DATE_FORMAT(timestamp, '%Y-%m-%d %H:%i:00') as minute_timestamp,
        AVG(pv1_input_voltage),
        AVG(pv1_input_current),
        AVG(pv1_charging_power),
        MAX(pv1_charging_power),
        SUM(pv1_charging_power) / 1000 / 120, -- Convert to kWh (30-second intervals)
        AVG(battery_voltage),
        AVG(battery_capacity),
        AVG(charging_current),
        AVG(battery_discharge_current),
        AVG(output_voltage),
        AVG(output_active_power),
        AVG(load_percentage),
        SUM(pv1_charging_power) / 1000 / 120 * 0.4781, -- Carbon reduction
        SUM(CASE WHEN ac_voltage > 200 THEN 30 ELSE 0 END), -- Generator runtime in seconds
        COUNT(*) as data_points
    FROM raw_inverter_data
    WHERE device_id = p_device_id
        AND timestamp >= p_start_time
        AND timestamp < p_end_time
    GROUP BY device_id, minute_timestamp
    ON DUPLICATE KEY UPDATE
        avg_pv_voltage = VALUES(avg_pv_voltage),
        avg_pv_current = VALUES(avg_pv_current),
        avg_pv_power = VALUES(avg_pv_power),
        max_pv_power = VALUES(max_pv_power),
        total_solar_kwh = VALUES(total_solar_kwh),
        avg_battery_voltage = VALUES(avg_battery_voltage),
        avg_battery_capacity = VALUES(avg_battery_capacity),
        carbon_reduction = VALUES(carbon_reduction),
        generator_runtime_seconds = VALUES(generator_runtime_seconds),
        data_points = VALUES(data_points);

    COMMIT;

    -- Update processing log
    UPDATE processing_log SET
        status = 'completed',
        end_time = NOW(),
        records_processed = ROW_COUNT()
    WHERE id = v_process_id;
END//

-- ============================================================
-- 2. Five-Minute Aggregation Procedure
-- ============================================================
CREATE PROCEDURE sp_aggregate_five_minute_data(
    IN p_device_id VARCHAR(50),
    IN p_start_time DATETIME,
    IN p_end_time DATETIME
)
BEGIN
    DECLARE v_process_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE processing_log SET
            status = 'failed',
            end_time = NOW()
        WHERE id = v_process_id;
    END;

    -- Log the start
    INSERT INTO processing_log (process_type, device_id, start_time, status)
    VALUES ('five_minute_aggregation', p_device_id, NOW(), 'running');
    SET v_process_id = LAST_INSERT_ID();

    START TRANSACTION;

    INSERT INTO five_minute_data (
        device_id, timestamp,
        avg_pv_power, max_pv_power, min_pv_power, total_solar_kwh,
        avg_battery_capacity, max_battery_capacity, min_battery_capacity,
        avg_load_percentage, max_load_percentage,
        carbon_reduction, generator_runtime_minutes, data_points, data_completeness
    )
    SELECT
        device_id,
        DATE_FORMAT(timestamp, '%Y-%m-%d %H:%i:00') - INTERVAL (MINUTE(timestamp) % 5) MINUTE as five_min_timestamp,
        AVG(pv1_charging_power),
        MAX(pv1_charging_power),
        MIN(pv1_charging_power),
        SUM(pv1_charging_power) / 1000 / 120, -- kWh
        AVG(battery_capacity),
        MAX(battery_capacity),
        MIN(battery_capacity),
        AVG(load_percentage),
        MAX(load_percentage),
        SUM(pv1_charging_power) / 1000 / 120 * 0.4781,
        SUM(CASE WHEN ac_voltage > 200 THEN 0.5 ELSE 0 END), -- Minutes
        COUNT(*),
        COUNT(*) / 10.0 * 100 -- Expected 10 readings per 5 minutes
    FROM raw_inverter_data
    WHERE device_id = p_device_id
        AND timestamp >= p_start_time
        AND timestamp < p_end_time
    GROUP BY device_id, five_min_timestamp
    ON DUPLICATE KEY UPDATE
        avg_pv_power = VALUES(avg_pv_power),
        max_pv_power = VALUES(max_pv_power),
        min_pv_power = VALUES(min_pv_power),
        total_solar_kwh = VALUES(total_solar_kwh),
        carbon_reduction = VALUES(carbon_reduction),
        data_points = VALUES(data_points);

    COMMIT;

    UPDATE processing_log SET
        status = 'completed',
        end_time = NOW(),
        records_processed = ROW_COUNT()
    WHERE id = v_process_id;
END//

-- ============================================================
-- 3. Hourly Aggregation Procedure
-- ============================================================
CREATE PROCEDURE sp_aggregate_hourly_data(
    IN p_device_id VARCHAR(50),
    IN p_start_time DATETIME,
    IN p_end_time DATETIME
)
BEGIN
    DECLARE v_process_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE processing_log SET
            status = 'failed',
            end_time = NOW()
        WHERE id = v_process_id;
    END;

    INSERT INTO processing_log (process_type, device_id, start_time, status)
    VALUES ('hourly_aggregation', p_device_id, NOW(), 'running');
    SET v_process_id = LAST_INSERT_ID();

    START TRANSACTION;

    INSERT INTO hourly_data (
        device_id, timestamp,
        avg_pv_power, max_pv_power, total_solar_kwh,
        avg_battery_capacity, max_battery_capacity, min_battery_capacity,
        battery_charge_kwh, battery_discharge_kwh,
        avg_load_percentage, max_load_percentage,
        avg_temperature, avg_humidity,
        carbon_reduction, generator_runtime_minutes,
        data_points, data_completeness
    )
    SELECT
        r.device_id,
        DATE_FORMAT(r.timestamp, '%Y-%m-%d %H:00:00') as hour_timestamp,
        AVG(r.pv1_charging_power),
        MAX(r.pv1_charging_power),
        SUM(r.pv1_charging_power) / 1000 / 120,
        AVG(r.battery_capacity),
        MAX(r.battery_capacity),
        MIN(r.battery_capacity),
        SUM(CASE WHEN r.charging_current > 0 THEN r.charging_current * r.battery_voltage / 1000 / 120 ELSE 0 END),
        SUM(CASE WHEN r.battery_discharge_current > 0 THEN r.battery_discharge_current * r.battery_voltage / 1000 / 120 ELSE 0 END),
        AVG(r.load_percentage),
        MAX(r.load_percentage),
        AVG(e.temperature),
        AVG(e.humidity),
        SUM(r.pv1_charging_power) / 1000 / 120 * 0.4781,
        SUM(CASE WHEN r.ac_voltage > 200 THEN 0.5 ELSE 0 END),
        COUNT(r.id),
        COUNT(r.id) / 120.0 * 100 -- Expected 120 readings per hour
    FROM raw_inverter_data r
    LEFT JOIN raw_environment_data e
        ON r.device_id = e.device_id
        AND ABS(TIMESTAMPDIFF(SECOND, r.timestamp, e.timestamp)) <= 30
    WHERE r.device_id = p_device_id
        AND r.timestamp >= p_start_time
        AND r.timestamp < p_end_time
    GROUP BY r.device_id, hour_timestamp
    ON DUPLICATE KEY UPDATE
        avg_pv_power = VALUES(avg_pv_power),
        max_pv_power = VALUES(max_pv_power),
        total_solar_kwh = VALUES(total_solar_kwh),
        carbon_reduction = VALUES(carbon_reduction),
        data_points = VALUES(data_points);

    COMMIT;

    UPDATE processing_log SET
        status = 'completed',
        end_time = NOW(),
        records_processed = ROW_COUNT()
    WHERE id = v_process_id;
END//

-- ============================================================
-- 4. Daily Aggregation Procedure
-- ============================================================
CREATE PROCEDURE sp_aggregate_daily_data(
    IN p_device_id VARCHAR(50),
    IN p_date DATE
)
BEGIN
    DECLARE v_process_id INT;
    DECLARE v_peak_time TIME;
    DECLARE v_peak_power INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE processing_log SET
            status = 'failed',
            end_time = NOW()
        WHERE id = v_process_id;
    END;

    INSERT INTO processing_log (process_type, device_id, start_time, status)
    VALUES ('daily_aggregation', p_device_id, NOW(), 'running');
    SET v_process_id = LAST_INSERT_ID();

    -- Get peak power time
    SELECT TIME(timestamp), pv1_charging_power
    INTO v_peak_time, v_peak_power
    FROM raw_inverter_data
    WHERE device_id = p_device_id
        AND DATE(timestamp) = p_date
    ORDER BY pv1_charging_power DESC
    LIMIT 1;

    START TRANSACTION;

    INSERT INTO daily_data (
        device_id, date,
        total_solar_kwh, peak_power_w, peak_power_time, avg_daily_power,
        avg_battery_capacity, max_battery_capacity, min_battery_capacity,
        total_charge_kwh, total_discharge_kwh,
        avg_temperature, max_temperature, min_temperature, avg_humidity,
        carbon_reduction, generator_runtime_hours,
        data_points, data_completeness
    )
    SELECT
        r.device_id,
        p_date,
        SUM(r.pv1_charging_power) / 1000 / 120,
        v_peak_power,
        v_peak_time,
        AVG(r.pv1_charging_power),
        AVG(r.battery_capacity),
        MAX(r.battery_capacity),
        MIN(r.battery_capacity),
        SUM(CASE WHEN r.charging_current > 0 THEN r.charging_current * r.battery_voltage / 1000 / 120 ELSE 0 END),
        SUM(CASE WHEN r.battery_discharge_current > 0 THEN r.battery_discharge_current * r.battery_voltage / 1000 / 120 ELSE 0 END),
        AVG(e.temperature),
        MAX(e.temperature),
        MIN(e.temperature),
        AVG(e.humidity),
        SUM(r.pv1_charging_power) / 1000 / 120 * 0.4781,
        SUM(CASE WHEN r.ac_voltage > 200 THEN 1 ELSE 0 END) / 120.0,
        COUNT(r.id),
        COUNT(r.id) / 2880.0 * 100 -- Expected 2880 readings per day
    FROM raw_inverter_data r
    LEFT JOIN raw_environment_data e
        ON r.device_id = e.device_id
        AND ABS(TIMESTAMPDIFF(SECOND, r.timestamp, e.timestamp)) <= 30
    WHERE r.device_id = p_device_id
        AND DATE(r.timestamp) = p_date
    GROUP BY r.device_id
    ON DUPLICATE KEY UPDATE
        total_solar_kwh = VALUES(total_solar_kwh),
        peak_power_w = VALUES(peak_power_w),
        peak_power_time = VALUES(peak_power_time),
        carbon_reduction = VALUES(carbon_reduction),
        generator_runtime_hours = VALUES(generator_runtime_hours),
        data_points = VALUES(data_points);

    -- Also update or insert into daily_inverter_stats for compatibility
    INSERT INTO daily_inverter_stats (
        device_id, date,
        avg_battery_capacity, max_pv1_charging_power,
        total_energy_generated, total_carbon_reduction,
        generator_runtime_hours
    )
    SELECT
        device_id,
        p_date,
        AVG(battery_capacity),
        MAX(pv1_charging_power),
        SUM(pv1_charging_power) / 1000 / 120,
        SUM(pv1_charging_power) / 1000 / 120 * 0.4781,
        SUM(CASE WHEN ac_voltage > 200 THEN 1 ELSE 0 END) / 120.0
    FROM raw_inverter_data
    WHERE device_id = p_device_id
        AND DATE(timestamp) = p_date
    GROUP BY device_id
    ON DUPLICATE KEY UPDATE
        avg_battery_capacity = VALUES(avg_battery_capacity),
        max_pv1_charging_power = VALUES(max_pv1_charging_power),
        total_energy_generated = VALUES(total_energy_generated),
        total_carbon_reduction = VALUES(total_carbon_reduction),
        generator_runtime_hours = VALUES(generator_runtime_hours);

    COMMIT;

    UPDATE processing_log SET
        status = 'completed',
        end_time = NOW(),
        records_processed = ROW_COUNT()
    WHERE id = v_process_id;
END//

-- ============================================================
-- 5. Monthly Aggregation Procedure
-- ============================================================
CREATE PROCEDURE sp_aggregate_monthly_data(
    IN p_device_id VARCHAR(50),
    IN p_year INT,
    IN p_month INT
)
BEGIN
    DECLARE v_process_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE processing_log SET
            status = 'failed',
            end_time = NOW()
        WHERE id = v_process_id;
    END;

    INSERT INTO processing_log (process_type, device_id, start_time, status)
    VALUES ('monthly_aggregation', p_device_id, NOW(), 'running');
    SET v_process_id = LAST_INSERT_ID();

    START TRANSACTION;

    -- Update monthly_data table
    INSERT INTO monthly_data (
        device_id, year, month,
        solar_kwh_total, carbon_reduction_total,
        battery_health_avg, generator_runtime_hours
    )
    SELECT
        device_id,
        p_year,
        p_month,
        SUM(total_solar_kwh),
        SUM(carbon_reduction),
        AVG(avg_battery_capacity),
        SUM(generator_runtime_hours)
    FROM daily_data
    WHERE device_id = p_device_id
        AND YEAR(date) = p_year
        AND MONTH(date) = p_month
    GROUP BY device_id
    ON DUPLICATE KEY UPDATE
        solar_kwh_total = VALUES(solar_kwh_total),
        carbon_reduction_total = VALUES(carbon_reduction_total),
        battery_health_avg = VALUES(battery_health_avg),
        generator_runtime_hours = VALUES(generator_runtime_hours);

    COMMIT;

    UPDATE processing_log SET
        status = 'completed',
        end_time = NOW(),
        records_processed = ROW_COUNT()
    WHERE id = v_process_id;
END//

-- ============================================================
-- 6. Run All Aggregations Procedure
-- ============================================================
CREATE PROCEDURE sp_run_all_aggregations(
    IN p_device_id VARCHAR(50)
)
BEGIN
    DECLARE v_current_time DATETIME;
    SET v_current_time = NOW();

    -- Run minute aggregation for last 5 minutes
    CALL sp_aggregate_minute_data(
        p_device_id,
        v_current_time - INTERVAL 5 MINUTE,
        v_current_time
    );

    -- Run 5-minute aggregation for last 15 minutes
    CALL sp_aggregate_five_minute_data(
        p_device_id,
        v_current_time - INTERVAL 15 MINUTE,
        v_current_time
    );

    -- Run hourly aggregation for last 2 hours
    CALL sp_aggregate_hourly_data(
        p_device_id,
        v_current_time - INTERVAL 2 HOUR,
        v_current_time
    );

    -- Run daily aggregation for today
    CALL sp_aggregate_daily_data(
        p_device_id,
        CURDATE()
    );
END//

DELIMITER ;
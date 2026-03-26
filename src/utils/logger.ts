import winston from 'winston';
import path from 'path';
import fs from 'fs';
import { config } from '../config/config';

// Ensure log directory exists
const logDir = path.resolve(config.app.logDir);
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

// Define log format
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  winston.format.json()
);

// Console format for development
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: 'HH:mm:ss' }),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    let log = `${timestamp} [${level}]: ${message}`;
    if (Object.keys(meta).length > 0) {
      log += ` ${JSON.stringify(meta, null, 2)}`;
    }
    return log;
  })
);

// Create logger instance
export const logger = winston.createLogger({
  level: config.app.logLevel,
  format: logFormat,
  defaultMeta: { service: 'solar-data-collector' },
  transports: [
    // Write all logs to combined.log
    new winston.transports.File({
      filename: path.join(logDir, 'combined.log'),
      maxsize: 10485760, // 10MB
      maxFiles: 5
    }),
    // Write errors to error.log
    new winston.transports.File({
      filename: path.join(logDir, 'error.log'),
      level: 'error',
      maxsize: 10485760,
      maxFiles: 5
    })
  ]
});

// Add console transport in development
if (config.app.nodeEnv !== 'production') {
  logger.add(
    new winston.transports.Console({
      format: consoleFormat
    })
  );
}

// Create specialized loggers
export const mqttLogger = logger.child({ module: 'mqtt' });
export const dbLogger = logger.child({ module: 'database' });
export const processingLogger = logger.child({ module: 'processing' });
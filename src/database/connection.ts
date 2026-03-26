import mysql from 'mysql2/promise';
import { config } from '../config/config';
import { logger } from '../utils/logger';

let pool: mysql.Pool | null = null;

export async function createConnection(): Promise<mysql.Pool> {
  if (pool) {
    return pool;
  }

  try {
    pool = mysql.createPool({
      host: config.database.host,
      port: config.database.port,
      user: config.database.user,
      password: config.database.password,
      database: config.database.database,
      connectionLimit: config.database.connectionLimit,
      waitForConnections: config.database.waitForConnections,
      queueLimit: config.database.queueLimit,
      enableKeepAlive: config.database.enableKeepAlive,
      keepAliveInitialDelay: config.database.keepAliveInitialDelay
    });

    // Test connection
    const connection = await pool.getConnection();
    await connection.ping();
    connection.release();

    logger.info('MariaDB connection pool created successfully');
    return pool;
  } catch (error) {
    logger.error('Failed to create MariaDB connection pool:', error);
    throw error;
  }
}

export async function closeConnection(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
    logger.info('MariaDB connection pool closed');
  }
}

export async function executeQuery<T = any>(
  query: string,
  params?: any[]
): Promise<T[]> {
  const connection = await createConnection();

  try {
    const [rows] = await connection.execute(query, params);
    return rows as T[];
  } catch (error) {
    logger.error('Query execution failed:', { query, params, error });
    throw error;
  }
}

export async function executeTransaction(
  queries: Array<{ query: string; params?: any[] }>
): Promise<void> {
  const connection = await createConnection();
  const conn = await connection.getConnection();

  try {
    await conn.beginTransaction();

    for (const { query, params } of queries) {
      await conn.execute(query, params);
    }

    await conn.commit();
  } catch (error) {
    await conn.rollback();
    logger.error('Transaction failed:', error);
    throw error;
  } finally {
    conn.release();
  }
}
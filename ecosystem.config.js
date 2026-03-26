module.exports = {
  apps: [
    {
      name: 'solar-collector',
      script: './dist/index.js',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      env: {
        NODE_ENV: 'production'
      },
      env_development: {
        NODE_ENV: 'development'
      },
      error_file: './logs/pm2-error.log',
      out_file: './logs/pm2-out.log',
      log_file: './logs/pm2-combined.log',
      time: true,

      // Restart strategies
      min_uptime: '10s',
      max_restarts: 10,
      restart_delay: 4000,

      // Graceful shutdown
      kill_timeout: 5000,
      wait_ready: true,
      listen_timeout: 3000,

      // Monitoring
      merge_logs: true,
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',

      // Resource monitoring
      monitoring: {
        http: false,
        https: false
      }
    }
  ]
};
@echo off
title Solar Data Collector Logs
color 0E

echo =========================================
echo    Solar Data Collector - Live Logs
echo =========================================
echo.
echo Press Ctrl+C to exit log viewer
echo.
echo =========================================

pm2 --version >nul 2>&1
if errorlevel 1 (
    echo PM2 is not installed
    echo Showing file logs instead...
    echo.

    if exist logs\app.log (
        echo === Application Logs ===
        type logs\app.log | more
    ) else (
        echo No log files found in logs directory
    )
    pause
    exit /b 1
)

call pm2 logs solar-collector --lines 100
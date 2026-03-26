@echo off
title Stop Solar Data Collector
color 0C

echo =========================================
echo    Stopping Solar Data Collector
echo =========================================
echo.

pm2 --version >nul 2>&1
if errorlevel 1 (
    echo PM2 is not installed
    echo.
    echo If the collector is running in a console window,
    echo please close it manually or press Ctrl+C
    pause
    exit /b 1
)

echo Stopping Solar Data Collector...
call pm2 stop solar-collector

echo.
echo Current PM2 Status:
call pm2 status

echo.
echo Solar Data Collector has been stopped.
pause
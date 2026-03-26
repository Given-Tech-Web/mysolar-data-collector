@echo off
title Solar Data Collector - PM2
color 0A

echo =========================================
echo    Solar Data Collector PM2 Manager
echo =========================================
echo.

cd /d %~dp0\..

echo Checking PM2 installation...
pm2 --version >nul 2>&1
if errorlevel 1 (
    echo PM2 not found. Installing PM2...
    call npm install -g pm2
    if errorlevel 1 (
        echo ERROR: Failed to install PM2
        echo Try running as Administrator
        pause
        exit /b 1
    )
)

echo.
echo Starting Solar Data Collector with PM2...
call pm2 start ecosystem.config.js

echo.
echo =========================================
echo Status:
call pm2 status

echo.
echo =========================================
echo.
echo Commands:
echo   pm2 logs solar-collector    - View logs
echo   pm2 stop solar-collector    - Stop service
echo   pm2 restart solar-collector - Restart service
echo   pm2 monit                   - Monitor service
echo.
pause
@echo off
title Solar Data Collector
color 0A

echo =========================================
echo    Solar Data Collector for Windows
echo =========================================
echo.

cd /d %~dp0\..

echo [1/5] Checking Node.js installation...
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)
echo OK - Node.js found

echo.
echo [2/5] Installing dependencies...
call npm install
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo [3/5] Building TypeScript...
call npm run build
if errorlevel 1 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo.
echo [4/5] Testing connections...
node scripts\test-connection.js
if errorlevel 1 (
    echo ERROR: Connection test failed
    echo Please check your .env configuration
    pause
    exit /b 1
)

echo.
echo [5/5] Starting Solar Data Collector...
echo.
echo Press Ctrl+C to stop
echo =========================================
node dist\index.js
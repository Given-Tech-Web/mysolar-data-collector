@echo off
title Solar Data Collector - Windows Setup
color 0B

echo =========================================
echo    Solar Data Collector Setup
echo    Windows 11 Environment
echo =========================================
echo.

cd /d %~dp0\..

echo This script will set up Solar Data Collector
echo.
echo Prerequisites:
echo   - Node.js 18+ must be installed
echo   - Internet connection required
echo   - MariaDB access credentials ready
echo.
pause

echo.
echo [Step 1] Checking Node.js...
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed
    echo.
    echo Please download and install Node.js from:
    echo https://nodejs.org/
    echo.
    echo After installation, run this script again.
    pause
    exit /b 1
)
node --version
npm --version

echo.
echo [Step 2] Installing project dependencies...
call npm install
if errorlevel 1 (
    echo WARNING: Some packages may have failed to install
    echo Continuing anyway...
)

echo.
echo [Step 3] Checking environment configuration...
if not exist .env (
    if exist .env.example (
        echo Creating .env file from template...
        copy .env.example .env
        echo.
        echo IMPORTANT: Edit the .env file with your credentials
        echo Opening .env file in notepad...
        notepad .env
        echo.
        echo After editing, save the file and continue
        pause
    ) else (
        echo ERROR: No .env file found
        echo Please create .env file with your configuration
        pause
        exit /b 1
    )
) else (
    echo .env file found
    echo.
    echo Do you want to edit the configuration? (Y/N)
    set /p edit_config=
    if /i "%edit_config%"=="Y" (
        notepad .env
        echo.
        echo Configuration updated
    )
)

echo.
echo [Step 4] Setting up database...
echo.
echo This will create necessary tables and stored procedures.
echo Make sure your database credentials in .env are correct.
echo.
echo Continue? (Y/N)
set /p setup_db=
if /i "%setup_db%"=="Y" (
    node scripts\setup-database.js
    if errorlevel 1 (
        echo WARNING: Database setup may have issues
        echo Check the error messages above
        pause
    )
) else (
    echo Skipping database setup
)

echo.
echo [Step 5] Testing connections...
node scripts\test-connection.js
if errorlevel 1 (
    echo WARNING: Connection test failed
    echo Please check your configuration
    pause
)

echo.
echo [Step 6] Building TypeScript...
call npm run build
if errorlevel 1 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo.
echo [Step 7] Installing PM2 (optional)...
echo.
echo PM2 is recommended for running the service in background
echo Install PM2 globally? (Y/N)
set /p install_pm2=
if /i "%install_pm2%"=="Y" (
    echo Installing PM2...
    call npm install -g pm2
    if errorlevel 1 (
        echo WARNING: PM2 installation failed
        echo You may need to run as Administrator
    ) else (
        echo PM2 installed successfully
    )
)

echo.
echo =========================================
echo    Setup Complete!
echo =========================================
echo.
echo You can now start the collector using:
echo.
echo   1. Direct start:
echo      npm start
echo.
echo   2. Development mode:
echo      npm run dev
echo.
echo   3. Using batch file:
echo      scripts\start-collector.bat
echo.
echo   4. Using PM2 (if installed):
echo      scripts\start-pm2.bat
echo.
echo =========================================
echo.
pause
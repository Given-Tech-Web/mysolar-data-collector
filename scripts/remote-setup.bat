@echo off
setlocal enabledelayedexpansion

REM ================================================================
REM Solar Data Collector - Remote Installation Script
REM ================================================================
REM This script automatically downloads and installs Solar Data Collector
REM from GitHub repository
REM ================================================================

echo.
echo =========================================================
echo    Solar Data Collector - Remote Installation
echo =========================================================
echo.

REM Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] This script requires Administrator privileges for some features.
    echo          Please run as Administrator for full installation.
    echo.
    pause
)

REM Set installation directory
set "INSTALL_DIR=C:\mysolar"
echo [INFO] Default installation directory: %INSTALL_DIR%
echo.
echo Do you want to use the default directory? (Y/N)
set /p USE_DEFAULT=
if /i "%USE_DEFAULT%" neq "Y" (
    echo Enter installation directory path:
    set /p INSTALL_DIR=
)

echo.
echo [INFO] Installation directory: %INSTALL_DIR%
echo.

REM Create installation directory
if not exist "%INSTALL_DIR%" (
    echo [INFO] Creating installation directory...
    mkdir "%INSTALL_DIR%" 2>nul
    if %errorLevel% neq 0 (
        echo [ERROR] Failed to create directory. Please check permissions.
        pause
        exit /b 1
    )
)

cd /d "%INSTALL_DIR%"

REM ================================================================
REM Step 1: Check prerequisites
REM ================================================================
echo.
echo [Step 1/7] Checking prerequisites...
echo.

REM Check Git
where git >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] Git is not installed.
    echo.
    echo Do you want to download the project as ZIP instead? (Y/N)
    set /p DOWNLOAD_ZIP=
    if /i "!DOWNLOAD_ZIP!" neq "Y" (
        echo.
        echo Please install Git from: https://git-scm.com/download/win
        echo Then run this script again.
        pause
        exit /b 1
    )
    set USE_GIT=0
) else (
    echo [OK] Git found:
    git --version
    set USE_GIT=1
)

REM Check Node.js
where node >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Node.js is not installed.
    echo.
    echo Please install Node.js from: https://nodejs.org/
    echo Download the LTS version and install it.
    echo Then run this script again.
    echo.
    pause
    exit /b 1
)
echo [OK] Node.js found:
node --version
npm --version

REM ================================================================
REM Step 2: Download project from GitHub
REM ================================================================
echo.
echo [Step 2/7] Downloading project from GitHub...
echo.

if %USE_GIT%==1 (
    REM Use Git clone
    if exist "%INSTALL_DIR%\solar-data-collector" (
        echo [INFO] Project directory already exists.
        echo Do you want to update it? (Y/N)
        set /p UPDATE_PROJECT=
        if /i "!UPDATE_PROJECT!"=="Y" (
            cd solar-data-collector
            echo [INFO] Updating from GitHub...
            git pull origin master
            if %errorLevel% neq 0 (
                echo [WARNING] Update failed. Continuing with existing code...
            )
        ) else (
            cd solar-data-collector
        )
    ) else (
        echo [INFO] Cloning from GitHub...
        git clone https://github.com/utonics/mysolar-data-collector.git solar-data-collector
        if %errorLevel% neq 0 (
            echo [ERROR] Failed to clone repository.
            pause
            exit /b 1
        )
        cd solar-data-collector
    )
) else (
    REM Download as ZIP using PowerShell
    echo [INFO] Downloading project as ZIP file...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/utonics/mysolar-data-collector/archive/refs/heads/master.zip' -OutFile 'solar-data-collector.zip'"

    if not exist solar-data-collector.zip (
        echo [ERROR] Failed to download project.
        pause
        exit /b 1
    )

    echo [INFO] Extracting ZIP file...
    powershell -Command "Expand-Archive -Path 'solar-data-collector.zip' -DestinationPath '.' -Force"

    if exist "mysolar-data-collector-master" (
        if exist "solar-data-collector" (
            echo [INFO] Removing old installation...
            rmdir /s /q "solar-data-collector" 2>nul
        )
        rename "mysolar-data-collector-master" "solar-data-collector"
    )

    del solar-data-collector.zip
    cd solar-data-collector
)

echo [OK] Project downloaded successfully.

REM ================================================================
REM Step 3: Install npm packages
REM ================================================================
echo.
echo [Step 3/7] Installing npm packages...
echo This may take a few minutes...
echo.

call npm install
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install npm packages.
    echo.
    echo Trying to clean cache and retry...
    call npm cache clean --force
    call npm install
    if %errorLevel% neq 0 (
        echo [ERROR] Installation failed. Please check the error messages above.
        pause
        exit /b 1
    )
)

echo [OK] npm packages installed successfully.

REM ================================================================
REM Step 4: Create environment configuration
REM ================================================================
echo.
echo [Step 4/7] Setting up environment configuration...
echo.

if not exist .env (
    if exist .env.example (
        echo [INFO] Creating .env file from template...
        copy .env.example .env >nul
    ) else (
        echo [INFO] Creating new .env file...
        (
            echo # HiveMQ Cloud Configuration
            echo HIVEMQ_HOST=9933a3ad2bed43528b8317e5c5b56ae3.s1.eu.hivemq.cloud
            echo HIVEMQ_PORT=8883
            echo HIVEMQ_USERNAME=hivemq.webclient.1756781079211
            echo HIVEMQ_PASSWORD=qCDS3wF?8ba,%%R9#U1sk
            echo HIVEMQ_CLIENT_ID=solar_data_collector
            echo.
            echo # MariaDB Configuration
            echo MARIADB_HOST=118.45.181.229
            echo MARIADB_PORT=3306
            echo MARIADB_USER=root
            echo MARIADB_PASSWORD=Qusrud8545!!@@
            echo MARIADB_DATABASE=mysolar
            echo.
            echo # Application Configuration
            echo NODE_ENV=production
            echo LOG_LEVEL=info
            echo LOG_DIR=./logs
            echo DEVICE_ID=solar_system_001
            echo.
            echo # Data Retention ^(days^)
            echo RAW_DATA_RETENTION=90
            echo MINUTE_DATA_RETENTION=30
            echo FIVE_MINUTE_DATA_RETENTION=90
            echo HOURLY_DATA_RETENTION=365
            echo.
            echo # Processing Configuration
            echo BATCH_SIZE=100
            echo AGGREGATION_INTERVAL=60000
            echo.
            echo # Carbon Emission Factor ^(kg CO2 per kWh^)
            echo CARBON_FACTOR=0.4781
            echo.
            echo # Solar System Configuration
            echo SOLAR_PANEL_CAPACITY=5000
            echo BATTERY_MAX_CAPACITY=19.2
        ) > .env
    )
    echo [OK] Environment file created.
    echo.
    echo [IMPORTANT] Please edit the .env file with your credentials:
    echo.
    notepad .env
    echo.
    echo Press any key after saving the .env file...
    pause >nul
) else (
    echo [OK] Environment file already exists.
)

REM ================================================================
REM Step 5: Check and Initialize database
REM ================================================================
echo.
echo [Step 5/7] Checking database status...
echo.

REM First check if database already has data
if exist scripts\check-database.js (
    call node scripts\check-database.js
    set DB_STATUS=%errorLevel%

    if !DB_STATUS!==0 (
        REM Database needs initialization
        echo [INFO] Database needs initialization. Setting up tables...
        if exist scripts\setup-database.js (
            call node scripts\setup-database.js
            if %errorLevel% neq 0 (
                echo [WARNING] Database setup encountered issues.
                echo           Please check your database credentials in .env file.
            ) else (
                echo [OK] Database initialized successfully.
            )
        )
    ) else if !DB_STATUS!==1 (
        REM Database structure exists but empty
        echo [OK] Database structure already exists. Skipping initialization.
    ) else if !DB_STATUS!==2 (
        REM Database has data - DO NOT INITIALIZE
        echo.
        echo [IMPORTANT] Database already contains data!
        echo            Skipping database initialization to prevent data loss.
        echo            The database is ready to use.
    ) else (
        REM Connection error
        echo [WARNING] Could not check database status.
        echo           Please verify your database credentials in .env file.
    )
) else (
    echo [WARNING] Database check script not found.
    echo           Please verify database manually before running setup.
)

REM ================================================================
REM Step 6: Build the project
REM ================================================================
echo.
echo [Step 6/7] Building the project...
echo.

call npm run build
if %errorLevel% neq 0 (
    echo [WARNING] Build failed. You may need to build manually later.
) else (
    echo [OK] Project built successfully.
)

REM ================================================================
REM Step 7: Test connections
REM ================================================================
echo.
echo [Step 7/7] Testing connections...
echo.

if exist scripts\test-connection.js (
    echo [INFO] Testing MQTT and Database connections...
    call node scripts\test-connection.js
    if %errorLevel% neq 0 (
        echo [WARNING] Connection test failed.
        echo           Please check your credentials in the .env file.
    ) else (
        echo [OK] All connections tested successfully.
    )
)

REM ================================================================
REM Installation Complete
REM ================================================================
echo.
echo =========================================================
echo    Installation Complete!
echo =========================================================
echo.
echo Installation directory: %INSTALL_DIR%\solar-data-collector
echo.
echo Next steps:
echo 1. Review and update .env file if needed
echo 2. Run the collector:
echo    - Development: npm run dev
echo    - Production: npm start
echo    - With PM2: pm2 start ecosystem.config.js
echo.
echo Useful commands:
echo - View logs: type logs\app.log
echo - Test connection: node scripts\test-connection.js
echo - Manual aggregation: node scripts\manual-daily-aggregation.js
echo.

REM Ask if user wants to start the service
echo Do you want to start the Solar Data Collector now? (Y/N)
set /p START_NOW=
if /i "%START_NOW%"=="Y" (
    echo.
    echo Starting Solar Data Collector...
    echo Press Ctrl+C to stop.
    echo.
    call npm start
)

echo.
echo Thank you for installing Solar Data Collector!
echo.
pause
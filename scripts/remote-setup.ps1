# ================================================================
# Solar Data Collector - Remote Installation Script (PowerShell)
# ================================================================
# Advanced installation script with error handling and automation
# ================================================================

param(
    [string]$InstallPath = "C:\mysolar",
    [switch]$Silent = $false,
    [switch]$SkipPrerequisites = $false,
    [switch]$UpdateOnly = $false,
    [switch]$UseZip = $false
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Colors for console output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success { Write-ColorOutput "[✓] $args" "Green" }
function Write-Info { Write-ColorOutput "[i] $args" "Cyan" }
function Write-Warning { Write-ColorOutput "[!] $args" "Yellow" }
function Write-Error { Write-ColorOutput "[✗] $args" "Red" }
function Write-Step { Write-ColorOutput "`n=== $args ===" "Magenta" }

# Banner
Clear-Host
Write-ColorOutput @"
=========================================================
    Solar Data Collector - Remote Installation
    PowerShell Advanced Installer v1.0
=========================================================
"@ "Cyan"

# Check for Administrator privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Warning "This script is running without Administrator privileges."
    Write-Warning "Some features may not work properly."

    if (-not $Silent) {
        $response = Read-Host "Do you want to restart as Administrator? (Y/N)"
        if ($response -eq 'Y') {
            Start-Process PowerShell -Verb RunAs -ArgumentList "-File `"$PSCommandPath`" -InstallPath `"$InstallPath`""
            exit
        }
    }
}

# ================================================================
# Step 1: Check Prerequisites
# ================================================================
if (-not $SkipPrerequisites) {
    Write-Step "Step 1/7: Checking Prerequisites"

    # Check Git
    try {
        $gitVersion = git --version 2>$null
        Write-Success "Git found: $gitVersion"
        $useGit = $true
    }
    catch {
        Write-Warning "Git is not installed."

        if (-not $UseZip -and -not $Silent) {
            $response = Read-Host "Do you want to install Git automatically? (Y/N)"
            if ($response -eq 'Y') {
                Write-Info "Installing Git via winget..."
                try {
                    winget install --id Git.Git --exact --silent --accept-package-agreements --accept-source-agreements
                    Write-Success "Git installed successfully. Please restart this script."
                    exit
                }
                catch {
                    Write-Warning "Failed to install Git automatically."
                    Write-Info "Please install Git manually from: https://git-scm.com/download/win"
                    $useGit = $false
                    $UseZip = $true
                }
            }
            else {
                $UseZip = $true
                $useGit = $false
            }
        }
        else {
            $useGit = $false
            $UseZip = $true
        }
    }

    # Check Node.js
    try {
        $nodeVersion = node --version 2>$null
        $npmVersion = npm --version 2>$null
        Write-Success "Node.js found: $nodeVersion"
        Write-Success "npm found: $npmVersion"

        # Check Node.js version
        $minVersion = [Version]"18.0.0"
        $currentVersion = [Version]($nodeVersion -replace 'v', '')

        if ($currentVersion -lt $minVersion) {
            Write-Warning "Node.js version $nodeVersion is below minimum required v18.0.0"

            if (-not $Silent) {
                $response = Read-Host "Do you want to update Node.js? (Y/N)"
                if ($response -eq 'Y') {
                    Write-Info "Please update Node.js from: https://nodejs.org/"
                    exit
                }
            }
        }
    }
    catch {
        Write-Error "Node.js is not installed."

        if (-not $Silent) {
            $response = Read-Host "Do you want to install Node.js automatically? (Y/N)"
            if ($response -eq 'Y') {
                Write-Info "Installing Node.js via winget..."
                try {
                    winget install --id OpenJS.NodeJS.LTS --exact --silent --accept-package-agreements --accept-source-agreements
                    Write-Success "Node.js installed successfully. Please restart this script."
                    exit
                }
                catch {
                    Write-Error "Failed to install Node.js automatically."
                    Write-Info "Please install Node.js manually from: https://nodejs.org/"
                    exit 1
                }
            }
            else {
                Write-Error "Node.js is required. Please install it from: https://nodejs.org/"
                exit 1
            }
        }
        else {
            exit 1
        }
    }
}

# ================================================================
# Step 2: Create Installation Directory
# ================================================================
Write-Step "Step 2/7: Setting Up Installation Directory"

if (-not $UpdateOnly) {
    if (-not (Test-Path $InstallPath)) {
        try {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
            Write-Success "Created installation directory: $InstallPath"
        }
        catch {
            Write-Error "Failed to create directory: $_"
            exit 1
        }
    }
    else {
        Write-Info "Using existing directory: $InstallPath"
    }
}

Set-Location $InstallPath

# ================================================================
# Step 3: Download Project from GitHub
# ================================================================
Write-Step "Step 3/7: Downloading Project from GitHub"

$projectPath = Join-Path $InstallPath "solar-data-collector"

if ($UpdateOnly) {
    if (Test-Path $projectPath) {
        Set-Location $projectPath
        Write-Info "Updating existing installation..."

        if ($useGit -and (Test-Path ".git")) {
            try {
                git pull origin master
                Write-Success "Project updated successfully."
            }
            catch {
                Write-Warning "Git pull failed. Continuing with existing code..."
            }
        }
        else {
            Write-Warning "Cannot update: not a git repository."
        }
    }
    else {
        Write-Error "No existing installation found at $projectPath"
        exit 1
    }
}
else {
    if (Test-Path $projectPath) {
        if (-not $Silent) {
            $response = Read-Host "Project already exists. Update (U), Reinstall (R), or Cancel (C)?"
            switch ($response.ToUpper()) {
                'U' {
                    Set-Location $projectPath
                    if ($useGit -and (Test-Path ".git")) {
                        git pull origin master
                        Write-Success "Project updated."
                    }
                }
                'R' {
                    Remove-Item $projectPath -Recurse -Force
                    Write-Info "Removed old installation."
                }
                'C' {
                    Write-Info "Installation cancelled."
                    exit 0
                }
            }
        }
    }

    if (-not (Test-Path $projectPath)) {
        if ($useGit -and -not $UseZip) {
            try {
                Write-Info "Cloning repository..."
                git clone https://github.com/utonics/mysolar-data-collector.git solar-data-collector
                Write-Success "Repository cloned successfully."
            }
            catch {
                Write-Error "Failed to clone repository: $_"
                $UseZip = $true
            }
        }

        if ($UseZip -or -not $useGit) {
            try {
                Write-Info "Downloading as ZIP file..."
                $zipUrl = "https://github.com/utonics/mysolar-data-collector/archive/refs/heads/master.zip"
                $zipPath = Join-Path $InstallPath "solar-data-collector.zip"

                Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
                Write-Success "Downloaded ZIP file."

                Write-Info "Extracting ZIP file..."
                Expand-Archive -Path $zipPath -DestinationPath $InstallPath -Force

                # Rename extracted folder
                if (Test-Path "mysolar-data-collector-master") {
                    Rename-Item "mysolar-data-collector-master" "solar-data-collector"
                }

                # Clean up
                Remove-Item $zipPath -Force
                Write-Success "Extraction complete."
            }
            catch {
                Write-Error "Failed to download or extract project: $_"
                exit 1
            }
        }
    }

    Set-Location $projectPath
}

# ================================================================
# Step 4: Install npm packages
# ================================================================
Write-Step "Step 4/7: Installing npm Packages"

try {
    Write-Info "Installing dependencies (this may take a few minutes)..."

    # Clear npm cache if needed
    if ($env:NPM_CLEAR_CACHE -eq "true") {
        npm cache clean --force
    }

    # Install packages
    npm install --loglevel=error

    Write-Success "npm packages installed successfully."
}
catch {
    Write-Warning "npm install failed. Retrying with cache clean..."
    try {
        npm cache clean --force
        npm install --loglevel=error
        Write-Success "npm packages installed after cache clean."
    }
    catch {
        Write-Error "Failed to install npm packages: $_"
        exit 1
    }
}

# ================================================================
# Step 5: Configure Environment
# ================================================================
Write-Step "Step 5/7: Configuring Environment"

$envPath = Join-Path $projectPath ".env"
$envExamplePath = Join-Path $projectPath ".env.example"

if (-not (Test-Path $envPath)) {
    if (Test-Path $envExamplePath) {
        Copy-Item $envExamplePath $envPath
        Write-Info "Created .env file from template."
    }
    else {
        # Create .env file with default values
        $envContent = @"
# HiveMQ Cloud Configuration
HIVEMQ_HOST=9933a3ad2bed43528b8317e5c5b56ae3.s1.eu.hivemq.cloud
HIVEMQ_PORT=8883
HIVEMQ_USERNAME=hivemq.webclient.1756781079211
HIVEMQ_PASSWORD=qCDS3wF?8ba,%R9#U1sk
HIVEMQ_CLIENT_ID=solar_data_collector

# MariaDB Configuration
MARIADB_HOST=118.45.181.229
MARIADB_PORT=3306
MARIADB_USER=root
MARIADB_PASSWORD=Qusrud8545!!@@
MARIADB_DATABASE=mysolar

# Application Configuration
NODE_ENV=production
LOG_LEVEL=info
LOG_DIR=./logs
DEVICE_ID=solar_system_001

# Data Retention (days)
RAW_DATA_RETENTION=90
MINUTE_DATA_RETENTION=30
FIVE_MINUTE_DATA_RETENTION=90
HOURLY_DATA_RETENTION=365

# Processing Configuration
BATCH_SIZE=100
AGGREGATION_INTERVAL=60000

# Carbon Emission Factor (kg CO2 per kWh)
CARBON_FACTOR=0.4781

# Solar System Configuration
SOLAR_PANEL_CAPACITY=5000
BATTERY_MAX_CAPACITY=19.2
"@
        Set-Content -Path $envPath -Value $envContent
        Write-Info "Created .env file with default configuration."
    }

    if (-not $Silent) {
        Write-Warning "Please review and update the .env file with your credentials."
        $response = Read-Host "Do you want to edit the .env file now? (Y/N)"
        if ($response -eq 'Y') {
            notepad $envPath
            Read-Host "Press Enter after saving the .env file..."
        }
    }
}
else {
    Write-Success ".env file already exists."
}

# ================================================================
# Step 6: Check and Initialize Database
# ================================================================
Write-Step "Step 6/7: Checking and Initializing Database"

$checkDbPath = Join-Path $projectPath "scripts\check-database.js"
$setupDbPath = Join-Path $projectPath "scripts\setup-database.js"

# First check database status
if (Test-Path $checkDbPath) {
    try {
        Write-Info "Checking database status..."
        $process = Start-Process -FilePath "node" -ArgumentList $checkDbPath -Wait -PassThru -NoNewWindow
        $dbStatus = $process.ExitCode

        switch ($dbStatus) {
            0 {
                # Database needs initialization
                Write-Info "Database needs initialization. Setting up tables..."
                if (Test-Path $setupDbPath) {
                    try {
                        node $setupDbPath
                        Write-Success "Database initialized successfully."
                    }
                    catch {
                        Write-Warning "Database setup failed: $_"
                        Write-Info "Please check your database credentials in .env file."
                    }
                }
                else {
                    Write-Warning "Setup script not found. Please run setup-database.js manually."
                }
            }
            1 {
                # Database structure exists but empty
                Write-Success "Database structure already exists. Skipping initialization."
            }
            2 {
                # Database has data - DO NOT INITIALIZE
                Write-Warning "Database already contains data!"
                Write-Info "Skipping database initialization to prevent data loss."
                Write-Info "The database is ready to use."
            }
            3 {
                # Connection error
                Write-Error "Could not check database status."
                Write-Info "Please verify your database credentials in .env file."
            }
            default {
                Write-Warning "Unknown database status. Please check manually."
            }
        }
    }
    catch {
        Write-Warning "Database check failed: $_"
        Write-Info "Please verify database manually before setup."
    }
}
else {
    Write-Warning "Database check script not found."

    # Ask user if they want to proceed without checking
    if (-not $Silent) {
        $response = Read-Host "Do you want to run database setup anyway? (Y/N)"
        if ($response -eq 'Y' -and (Test-Path $setupDbPath)) {
            try {
                Write-Warning "Running database setup without safety check..."
                node $setupDbPath
                Write-Success "Database setup completed."
            }
            catch {
                Write-Error "Database setup failed: $_"
            }
        }
    }
}

# Build the project
Write-Info "Building TypeScript project..."
try {
    npm run build
    Write-Success "Project built successfully."
}
catch {
    Write-Warning "Build failed. You may need to build manually later."
}

# ================================================================
# Step 7: Test Connections
# ================================================================
Write-Step "Step 7/7: Testing Connections"

$testConnPath = Join-Path $projectPath "scripts\test-connection.js"

if (Test-Path $testConnPath) {
    try {
        Write-Info "Testing MQTT and Database connections..."
        node $testConnPath
        Write-Success "All connections tested successfully."
    }
    catch {
        Write-Warning "Connection test failed: $_"
        Write-Info "Please verify your credentials in the .env file."
    }
}

# ================================================================
# Installation Complete
# ================================================================
Write-Step "Installation Complete!"

Write-ColorOutput @"

Installation Summary:
- Location: $projectPath
- Status: Ready to run

Quick Start Commands:
  Development Mode:  npm run dev
  Production Mode:   npm start
  With PM2:         pm2 start ecosystem.config.js

Useful Commands:
  View logs:        Get-Content logs\app.log -Tail 50 -Wait
  Test connection:  node scripts\test-connection.js
  Daily aggregation: node scripts\manual-daily-aggregation.js

"@ "Green"

if (-not $Silent) {
    $response = Read-Host "Do you want to start the Solar Data Collector now? (Y/N)"
    if ($response -eq 'Y') {
        Write-Info "Starting Solar Data Collector..."
        Write-Info "Press Ctrl+C to stop."
        npm start
    }

    # Offer to install PM2
    $response = Read-Host "Do you want to install PM2 for process management? (Y/N)"
    if ($response -eq 'Y') {
        try {
            npm install -g pm2
            Write-Success "PM2 installed successfully."
            Write-Info "You can now use: pm2 start ecosystem.config.js"
        }
        catch {
            Write-Warning "Failed to install PM2: $_"
        }
    }
}

Write-Success "Installation completed successfully!"
@echo off
echo === Alias Proxy Setup ===
echo.

:: Check for admin privileges (needed to edit hosts file)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

:: Change to the directory where this script lives
cd /d "%~dp0"

:: Validate mapping keys and update hosts file
echo [1/3] Updating hosts file...
powershell -ExecutionPolicy Bypass -File "%~dp0update_hosts.ps1" -MappingFile "%~dp0mapping.json"
if %errorlevel% neq 0 (
    echo ERROR: Hosts file update failed. Check mapping.json for invalid keys.
    pause
    exit /b 1
)
ipconfig /flushdns >nul 2>&1

:: Build Docker image
echo.
echo [2/3] Building Docker image...
copy mapping.json backend\mapping.json >nul
docker build -t alias-proxy ./backend
del backend\mapping.json >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker build failed. Is Docker Desktop running?
    pause
    exit /b 1
)

:: Stop existing container if running, then start fresh
echo.
echo [3/3] Starting proxy container...
docker stop alias-proxy >nul 2>&1
docker rm alias-proxy >nul 2>&1
docker run -d --name alias-proxy -p 80:80 alias-proxy
if %errorlevel% neq 0 (
    echo ERROR: Failed to start container. Is port 80 already in use?
    pause
    exit /b 1
)
docker update --restart unless-stopped alias-proxy

echo.
echo ========================================
echo   Setup complete!
echo.
echo   Active mappings:
powershell -Command ^
    "$m = (Get-Content 'mapping.json' | ConvertFrom-Json).PSObject.Properties; " ^
    "foreach ($p in $m) { " ^
    "    if ($p.Value -match '(^127\.|^localhost)') { " ^
    "        Write-Host ('    ' + $p.Name + '/ -> ' + $p.Value + '  [proxy]') " ^
    "    } else { " ^
    "        Write-Host ('    ' + $p.Name + '/ -> ' + $p.Value + '  [redirect]') " ^
    "    } " ^
    "}"
echo ========================================
pause

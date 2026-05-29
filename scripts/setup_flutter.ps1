# Flutter Setup Script
# Run this AFTER flutter_sdk.zip has finished downloading to D:\flutter_sdk.zip
# Usage: powershell -ExecutionPolicy Bypass -File M:\zabil\scripts\setup_flutter.ps1

$zipPath   = "D:\flutter_sdk.zip"
$flutterDir = "D:\flutter"
$projectDir = "E:\chat\collab_notes_app"

# 1. Check zip exists
if (-not (Test-Path $zipPath)) {
    Write-Host "ERROR: $zipPath not found. Download it first." -ForegroundColor Red
    exit 1
}

# 2. Extract Flutter SDK
Write-Host "Extracting Flutter SDK to D:\flutter ..." -ForegroundColor Cyan
if (Test-Path $flutterDir) { Remove-Item $flutterDir -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath "D:\" -Force
Write-Host "Extracted." -ForegroundColor Green

# 3. Add D:\flutter\bin to PATH (current user, permanent)
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*D:\flutter\bin*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;D:\flutter\bin", "User")
    Write-Host "Added D:\flutter\bin to PATH." -ForegroundColor Green
} else {
    Write-Host "D:\flutter\bin already in PATH." -ForegroundColor Yellow
}

# 4. Use flutter from full path for this session
$env:Path += ";D:\flutter\bin"

# 5. flutter create (will skip if android/ and windows/ already exist)
if (-not (Test-Path "$projectDir\android")) {
    Write-Host "Creating Flutter project at $projectDir ..." -ForegroundColor Cyan
    Remove-Item $projectDir -Recurse -Force -ErrorAction SilentlyContinue
    Set-Location "E:\chat"
    & "D:\flutter\bin\flutter.bat" create collab_notes_app --platforms=android,windows --org=com.zabili
    Write-Host "Project created." -ForegroundColor Green
} else {
    Write-Host "Project already has android/ folder, skipping create." -ForegroundColor Yellow
}

# 6. Copy our source code into the project
Write-Host "Copying source code from M:\zabil\frontend\ ..." -ForegroundColor Cyan
Copy-Item -Path "M:\zabil\frontend\lib\*"           -Destination "$projectDir\lib\"        -Recurse -Force
Copy-Item -Path "M:\zabil\frontend\pubspec.yaml"    -Destination "$projectDir\pubspec.yaml" -Force
Write-Host "Source code copied." -ForegroundColor Green

# 7. flutter pub get
Write-Host "Running flutter pub get ..." -ForegroundColor Cyan
Set-Location $projectDir
& "D:\flutter\bin\flutter.bat" pub get

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup complete! Now you can build:" -ForegroundColor Green
Write-Host ""
Write-Host "  Android APK:" -ForegroundColor Yellow
Write-Host "  cd E:\chat\collab_notes_app" -ForegroundColor White
Write-Host "  D:\flutter\bin\flutter.bat build apk --release" -ForegroundColor White
Write-Host ""
Write-Host "  Windows .exe:" -ForegroundColor Yellow
Write-Host "  D:\flutter\bin\flutter.bat build windows --release" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Green

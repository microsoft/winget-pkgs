# Google USB Driver Installer Script
# Installs Android USB driver using pnputil

$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host "Google USB Driver Installer"
Write-Host "========================================="

# -------------------------------------------------
# Check for Administrator privileges
# -------------------------------------------------

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to install drivers."
    exit 1
}

Write-Host "[OK] Running with Administrator privileges."

# -------------------------------------------------
# Variables
# -------------------------------------------------

$DriverUrl = "https://dl.google.com/android/repository/usb_driver_r13-windows.zip"
$TempDir = Join-Path $env:TEMP "GoogleUSBDriverInstall"
$ZipPath = Join-Path $TempDir "usb_driver.zip"
$ExtractPath = Join-Path $TempDir "extracted"
$InfPath = Join-Path $ExtractPath "usb_driver\android_winusb.inf"

# -------------------------------------------------
# Prepare working directory
# -------------------------------------------------

Write-Host "[INFO] Creating temporary directory..."

if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force
}

New-Item -ItemType Directory -Path $TempDir | Out-Null

# -------------------------------------------------
# Download driver
# -------------------------------------------------

Write-Host "[INFO] Downloading Google USB Driver..."

try {
    Invoke-WebRequest -Uri $DriverUrl -OutFile $ZipPath
}
catch {
    Write-Error "Failed to download driver."
    exit 1
}

if (!(Test-Path $ZipPath)) {
    Write-Error "Driver download failed."
    exit 1
}

Write-Host "[OK] Download complete."

# -------------------------------------------------
# Extract archive
# -------------------------------------------------

Write-Host "[INFO] Extracting archive..."

Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force

if (!(Test-Path $ExtractPath)) {
    Write-Error "Extraction failed."
    exit 1
}

# -------------------------------------------------
# Locate INF
# -------------------------------------------------

if (!(Test-Path $InfPath)) {
    Write-Error "Driver INF file not found."
    exit 1
}

Write-Host "[OK] Driver INF located."

# -------------------------------------------------
# Install driver
# -------------------------------------------------

Write-Host "[INFO] Installing driver with pnputil..."

$process = Start-Process -FilePath "pnputil.exe" `
    -ArgumentList "/add-driver `"$InfPath`" /install" `
    -Wait -PassThru -NoNewWindow

if ($process.ExitCode -ne 0) {
    Write-Error "Driver installation failed with exit code $($process.ExitCode)"
    exit 1
}

Write-Host "[SUCCESS] Google USB Driver installed successfully."

# -------------------------------------------------
# Cleanup
# -------------------------------------------------

Write-Host "[INFO] Cleaning temporary files..."

try {
    Remove-Item $TempDir -Recurse -Force
}
catch {
    Write-Warning "Cleanup failed but installation succeeded."
}

Write-Host "Installation completed."
exit 0
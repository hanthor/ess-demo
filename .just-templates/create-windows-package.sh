#!/bin/bash
set -euo pipefail

pkg_dir="$1"
runtime_dir="$(dirname "$pkg_dir")/../runtime/windows"

mkdir -p "$pkg_dir"

# Copy runtime scripts
if [ -d "$runtime_dir" ]; then
    cp "$runtime_dir/setup.ps1" "$pkg_dir/" 2>/dev/null || true
    cp "$runtime_dir/verify.ps1" "$pkg_dir/" 2>/dev/null || true
    cp "$runtime_dir/cleanup.ps1" "$pkg_dir/" 2>/dev/null || true
fi

# Create INSTALL.md
cat > "$pkg_dir/INSTALL.md" << 'EOF'
# ESS Community Demo - Windows Installation

## Prerequisites

- Windows 10/11 (Build 19041+)
- Docker Desktop installed
- ~10GB free disk space
- Administrator privileges

## Installation Steps

1. **Extract the package:**
   ```powershell
   .\install.ps1
   ```

2. **Run setup (PowerShell as Administrator):**
   ```powershell
   .\setup.ps1
   ```

3. **Verify installation:**
   ```powershell
   .\verify.ps1
   ```

4. **Access the demo:**
   Open https://chat.ess.localhost in your browser

## Troubleshooting

See TROUBLESHOOTING.md for common issues.
EOF

# Create install.ps1
cat > "$pkg_dir/install.ps1" << 'EOF'
#Requires -RunAsAdministrator

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ParentDir = Split-Path -Parent $ScriptDir

if (-not (Test-Path "$ScriptDir\ess-demo.zip")) {
    Write-Host "Error: ess-demo.zip not found"
    exit 1
}

Write-Host "Extracting ESS Demo..."
Expand-Archive -Path "$ScriptDir\ess-demo.zip" -DestinationPath "$ParentDir" -Force

Write-Host "`n✓ ESS Demo extracted successfully!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  cd .."
Write-Host "  .\setup.ps1"
EOF

# Create extract-installers.ps1
cat > "$pkg_dir/extract-installers.ps1" << 'EOF'
#Requires -RunAsAdministrator

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallersDir = Join-Path $ScriptDir "..\installers"

Write-Host "Extracting installers..."

if (Test-Path "$ScriptDir\installers-windows.zip") {
    Expand-Archive -Path "$ScriptDir\installers-windows.zip" -DestinationPath "$InstallersDir" -Force
    Write-Host "✓ Windows installers extracted"
}

Write-Host ""
Write-Host "Installers ready for use!"
EOF

echo "✓ Windows package structure created"

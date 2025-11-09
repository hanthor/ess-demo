# ESS Community Demo - Cleanup Script for Windows
# Removes the Kind cluster and associated resources
# Use -Uninstall to also remove all installed software

param(
    [switch]$Uninstall = $false,
    [switch]$Help = $false
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "ℹ " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "  $Message" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
}

# Uninstall software
function Uninstall-Software {
    Write-Header "Uninstalling Software"
    
    Write-Host ""
    Write-Warning "This will remove the following software from your system:"
    Write-Host "  • Kind"
    Write-Host "  • kubectl"
    Write-Host "  • Helm"
    Write-Host "  • k9s"
    Write-Host "  • mkcert"
    Write-Host ""
    Write-Warning "Docker Desktop will NOT be removed (may be used by other applications)"
    Write-Host ""
    
    $response = Read-Host "Continue? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Info "Skipping software uninstall"
        return
    }
    
    # Remove Kind
    $kindDir = "C:\Program Files\Kind"
    if (Test-Path "$kindDir\kind.exe") {
        Write-Info "Removing Kind..."
        Remove-Item -Path $kindDir -Recurse -Force
        Write-Success "Kind removed"
    }
    
    # Remove kubectl
    $kubectlDir = "C:\Program Files\kubectl"
    if (Test-Path "$kubectlDir\kubectl.exe") {
        Write-Info "Removing kubectl..."
        Remove-Item -Path $kubectlDir -Recurse -Force
        Write-Success "kubectl removed"
    }
    
    # Remove Helm
    $helmDir = "C:\Program Files\Helm"
    if (Test-Path "$helmDir\helm.exe") {
        Write-Info "Removing Helm..."
        Remove-Item -Path $helmDir -Recurse -Force
        Write-Success "Helm removed"
    }
    
    # Remove k9s
    $k9sDir = "C:\Program Files\k9s"
    if (Test-Path "$k9sDir\k9s.exe") {
        Write-Info "Removing k9s..."
        Remove-Item -Path $k9sDir -Recurse -Force
        Write-Success "k9s removed"
    }
    
    # Remove mkcert
    $mkcertDir = "C:\Program Files\mkcert"
    if (Test-Path "$mkcertDir\mkcert.exe") {
        Write-Info "Uninstalling mkcert CA..."
        & "$mkcertDir\mkcert.exe" -uninstall 2>$null
        
        Write-Info "Removing mkcert..."
        Remove-Item -Path $mkcertDir -Recurse -Force
        Write-Success "mkcert removed"
    }
    
    # Clean up PATH
    Write-Info "Cleaning up system PATH..."
    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $path = $path -replace ";C:\\Program Files\\Kind", ""
    $path = $path -replace ";C:\\Program Files\\kubectl", ""
    $path = $path -replace ";C:\\Program Files\\Helm", ""
    $path = $path -replace ";C:\\Program Files\\k9s", ""
    $path = $path -replace ";C:\\Program Files\\mkcert", ""
    [Environment]::SetEnvironmentVariable("Path", $path, "Machine")
    
    Write-Success "Software uninstall complete"
    Write-Info "Note: Docker Desktop was not removed. Uninstall manually if needed."
}

$ClusterName = "ess-demo"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Show help
if ($Help) {
    Write-Host "Usage: .\cleanup.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Uninstall    Remove all installed software (Kind, kubectl, Helm, k9s, mkcert)"
    Write-Host "  -Help         Show this help message"
    Write-Host ""
    Write-Host "Without -Uninstall flag, only removes the Kind cluster."
    exit 0
}

Write-Header "ESS Community Demo - Cleanup"

# Check if kind is installed
if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
    Write-Error "Kind is not installed"
    exit 1
}

# Check if cluster exists
$existingClusters = & kind get clusters 2>$null
if ($existingClusters -notcontains $ClusterName) {
    Write-Warning "Cluster '$ClusterName' does not exist"
    exit 0
}

# Confirm deletion
Write-Host ""
Write-Warning "This will delete the Kind cluster '$ClusterName' and all its resources"
Write-Warning "This includes all pods, services, and data in the cluster"
Write-Host ""
$response = Read-Host "Continue? (y/N)"
if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Info "Cancelled"
    exit 0
}

Write-Info "Deleting Kind cluster '$ClusterName'..."
& kind delete cluster --name $ClusterName

Write-Success "Cluster deleted successfully"

# Optionally clean up generated certificates
Write-Host ""
$response = Read-Host "Also remove generated certificates? (y/N)"
if ($response -eq 'y' -or $response -eq 'Y') {
    $certsDir = Join-Path $ScriptDir "certs"
    if (Test-Path $certsDir) {
        Write-Info "Removing certificates..."
        Remove-Item -Path $certsDir -Recurse -Force
        Write-Success "Certificates removed"
    }
}

# Uninstall software if requested
if ($Uninstall) {
    Uninstall-Software
}

Write-Header "Cleanup Complete!"
if ($Uninstall) {
    Write-Info "Cluster and software have been removed"
} else {
    Write-Info "To reinstall, run: .\setup.ps1"
    Write-Info "To also remove installed software, run: .\cleanup.ps1 -Uninstall"
}
Write-Host ""

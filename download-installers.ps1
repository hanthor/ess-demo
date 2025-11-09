# ESS Community Demo - Installer Download Script for Windows
# Downloads all required software for offline installation
# Can download for Windows only or for all platforms (macOS, Linux, Windows)

param(
    [switch]$All = $false,
    [switch]$Help = $false
)

$ErrorActionPreference = "Stop"

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallersDir = Join-Path $ScriptDir "installers\windows"

# Version definitions
$KIND_VERSION = "v0.20.0"
$KUBECTL_VERSION = "v1.28.4"
$HELM_VERSION = "v3.13.2"
$K9S_VERSION = "v0.29.1"
$MKCERT_VERSION = "v1.4.4"

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

# Download file with progress
function Get-FileDownload {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    Write-Info "Downloading: $(Split-Path $OutputPath -Leaf)"
    
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        Write-Success "Downloaded: $(Split-Path $OutputPath -Leaf)"
    } catch {
        Write-Error "Failed to download: $Url"
        Write-Error $_.Exception.Message
        exit 1
    }
}

# Download Docker Desktop
function Get-Docker {
    Write-Header "Downloading Docker Desktop"
    
    Write-Warning "Downloading Docker Desktop (this is a large file, ~500-600MB)"
    
    $dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    $dockerPath = Join-Path $InstallersDir "Docker Desktop Installer.exe"
    
    Get-FileDownload -Url $dockerUrl -OutputPath $dockerPath
}

# Download Kind
function Get-Kind {
    Write-Header "Downloading Kind"
    
    $kindUrl = "https://github.com/kubernetes-sigs/kind/releases/download/$KIND_VERSION/kind-windows-amd64"
    $kindPath = Join-Path $InstallersDir "kind-windows-amd64.exe"
    
    Get-FileDownload -Url $kindUrl -OutputPath $kindPath
}

# Download kubectl
function Get-Kubectl {
    Write-Header "Downloading kubectl"
    
    $kubectlUrl = "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/windows/amd64/kubectl.exe"
    $kubectlPath = Join-Path $InstallersDir "kubectl.exe"
    
    Get-FileDownload -Url $kubectlUrl -OutputPath $kubectlPath
}

# Download Helm
function Get-Helm {
    Write-Header "Downloading Helm"
    
    $helmUrl = "https://get.helm.sh/helm-$HELM_VERSION-windows-amd64.zip"
    $helmPath = Join-Path $InstallersDir "helm-windows-amd64.zip"
    
    Get-FileDownload -Url $helmUrl -OutputPath $helmPath
}

# Download k9s
function Get-K9s {
    Write-Header "Downloading k9s"
    
    $k9sUrl = "https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Windows_amd64.zip"
    $k9sPath = Join-Path $InstallersDir "k9s_windows_amd64.zip"
    
    Get-FileDownload -Url $k9sUrl -OutputPath $k9sPath
}

# Download mkcert
function Get-Mkcert {
    Write-Header "Downloading mkcert"
    
    $mkcertUrl = "https://github.com/FiloSottile/mkcert/releases/download/$MKCERT_VERSION/mkcert-$MKCERT_VERSION-windows-amd64.exe"
    $mkcertPath = Join-Path $InstallersDir "mkcert-windows-amd64.exe"
    
    Get-FileDownload -Url $mkcertUrl -OutputPath $mkcertPath
}

# Download for all platforms
function Get-AllPlatforms {
    Write-Header "Downloading for All Platforms"
    
    Write-Host ""
    Write-Warning "This will download installers for:"
    Write-Host "  • macOS (Intel x86_64 and Apple Silicon arm64)"
    Write-Host "  • Linux (x86_64 and arm64)"
    Write-Host "  • Windows (x86_64)"
    Write-Host ""
    Write-Warning "Total download size: approximately 3-4GB"
    Write-Host ""
    
    $response = Read-Host "Continue? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Info "Cancelled"
        exit 0
    }
    
    # Create all platform directories
    $macosDir = Join-Path $ScriptDir "installers\macos"
    $linuxDir = Join-Path $ScriptDir "installers\linux"
    $windowsDir = Join-Path $ScriptDir "installers\windows"
    
    New-Item -ItemType Directory -Path $macosDir -Force | Out-Null
    New-Item -ItemType Directory -Path $linuxDir -Force | Out-Null
    New-Item -ItemType Directory -Path $windowsDir -Force | Out-Null
    
    # macOS Intel
    Write-Info "Downloading macOS (Intel x86_64)..."
    Get-FileDownload "https://desktop.docker.com/mac/main/amd64/Docker.dmg" "$macosDir\Docker-amd64.dmg"
    Get-FileDownload "https://github.com/kubernetes-sigs/kind/releases/download/$KIND_VERSION/kind-darwin-amd64" "$macosDir\kind-darwin-amd64"
    Get-FileDownload "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/darwin/amd64/kubectl" "$macosDir\kubectl-amd64"
    Get-FileDownload "https://get.helm.sh/helm-$HELM_VERSION-darwin-amd64.tar.gz" "$macosDir\helm-darwin-amd64.tar.gz"
    Get-FileDownload "https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Darwin_x86_64.tar.gz" "$macosDir\k9s_darwin_x86_64.tar.gz"
    Get-FileDownload "https://github.com/FiloSottile/mkcert/releases/download/$MKCERT_VERSION/mkcert-$MKCERT_VERSION-darwin-amd64" "$macosDir\mkcert-darwin-amd64"
    
    # macOS Apple Silicon
    Write-Info "Downloading macOS (Apple Silicon arm64)..."
    Get-FileDownload "https://desktop.docker.com/mac/main/arm64/Docker.dmg" "$macosDir\Docker-arm64.dmg"
    Get-FileDownload "https://github.com/kubernetes-sigs/kind/releases/download/$KIND_VERSION/kind-darwin-arm64" "$macosDir\kind-darwin-arm64"
    Get-FileDownload "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/darwin/arm64/kubectl" "$macosDir\kubectl-arm64"
    Get-FileDownload "https://get.helm.sh/helm-$HELM_VERSION-darwin-arm64.tar.gz" "$macosDir\helm-darwin-arm64.tar.gz"
    Get-FileDownload "https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Darwin_arm64.tar.gz" "$macosDir\k9s_darwin_arm64.tar.gz"
    Get-FileDownload "https://github.com/FiloSottile/mkcert/releases/download/$MKCERT_VERSION/mkcert-$MKCERT_VERSION-darwin-arm64" "$macosDir\mkcert-darwin-arm64"
    
    # Linux x86_64
    Write-Info "Downloading Linux (x86_64)..."
    Get-FileDownload "https://download.docker.com/linux/static/stable/x86_64/docker-24.0.7.tgz" "$linuxDir\docker-amd64.tgz"
    Get-FileDownload "https://github.com/kubernetes-sigs/kind/releases/download/$KIND_VERSION/kind-linux-amd64" "$linuxDir\kind-linux-amd64"
    Get-FileDownload "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl" "$linuxDir\kubectl-amd64"
    Get-FileDownload "https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz" "$linuxDir\helm-linux-amd64.tar.gz"
    Get-FileDownload "https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_x86_64.tar.gz" "$linuxDir\k9s_linux_x86_64.tar.gz"
    Get-FileDownload "https://github.com/FiloSottile/mkcert/releases/download/$MKCERT_VERSION/mkcert-$MKCERT_VERSION-linux-amd64" "$linuxDir\mkcert-linux-amd64"
    
    # Linux ARM64
    Write-Info "Downloading Linux (arm64)..."
    Get-FileDownload "https://download.docker.com/linux/static/stable/aarch64/docker-24.0.7.tgz" "$linuxDir\docker-arm64.tgz"
    Get-FileDownload "https://github.com/kubernetes-sigs/kind/releases/download/$KIND_VERSION/kind-linux-arm64" "$linuxDir\kind-linux-arm64"
    Get-FileDownload "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/arm64/kubectl" "$linuxDir\kubectl-arm64"
    Get-FileDownload "https://get.helm.sh/helm-$HELM_VERSION-linux-arm64.tar.gz" "$linuxDir\helm-linux-arm64.tar.gz"
    Get-FileDownload "https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_arm64.tar.gz" "$linuxDir\k9s_linux_arm64.tar.gz"
    Get-FileDownload "https://github.com/FiloSottile/mkcert/releases/download/$MKCERT_VERSION/mkcert-$MKCERT_VERSION-linux-arm64" "$linuxDir\mkcert-linux-arm64"
    
    # Windows
    Write-Info "Downloading Windows (x86_64)..."
    Get-Docker
    Get-Kind
    Get-Kubectl
    Get-Helm
    Get-K9s
    Get-Mkcert
    
    Write-Header "All Platforms Download Complete!"
    Write-Success "Installers for all platforms downloaded"
    Write-Host ""
    Write-Info "Directory structure:"
    Write-Host "  installers\macos\    - macOS installers (Intel + Apple Silicon)"
    Write-Host "  installers\linux\    - Linux installers (x86_64 + ARM64)"
    Write-Host "  installers\windows\  - Windows installers"
}

# Main execution
function Main {
    # Show help
    if ($Help) {
        Write-Host "Usage: .\download-installers.ps1 [OPTIONS]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -All          Download installers for all platforms (macOS, Linux, Windows)"
        Write-Host "  -Help         Show this help message"
        Write-Host ""
        Write-Host "Without -All flag, downloads only for Windows."
        exit 0
    }
    
    Write-Header "ESS Community Demo - Installer Downloader"
    
    if ($All) {
        Get-AllPlatforms
    } else {
        Write-Info "Detected platform: Windows/amd64"
        Write-Host ""
        
        Write-Info "This script will download the following software:"
        Write-Host "  • Docker Desktop"
        Write-Host "  • Kind $KIND_VERSION"
        Write-Host "  • kubectl $KUBECTL_VERSION"
        Write-Host "  • Helm $HELM_VERSION"
        Write-Host "  • k9s $K9S_VERSION"
        Write-Host "  • mkcert $MKCERT_VERSION"
        Write-Host ""
        Write-Warning "Total download size: approximately 600MB - 800MB"
        Write-Host ""
        Write-Info "Tip: Use -All to download for all platforms (macOS, Linux, Windows)"
        Write-Host ""
        
        $response = Read-Host "Continue? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Info "Cancelled"
            exit 0
        }
        
        # Create installers directory
        if (-not (Test-Path $InstallersDir)) {
            New-Item -ItemType Directory -Path $InstallersDir -Force | Out-Null
        }
        
        # Download all components
        Get-Docker
        Get-Kind
        Get-Kubectl
        Get-Helm
        Get-K9s
        Get-Mkcert
        
        Write-Header "Download Complete!"
        Write-Success "All installers downloaded to: $InstallersDir"
        Write-Info "You can now run .\setup.ps1 (as Administrator) to install and configure the demo"
    }
}

# Run main function
Main

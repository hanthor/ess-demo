# ESS Community Demo - Automated Setup Script for Windows
# Supports: Windows 10/11 (x86_64/amd64)
# Copyright 2025 - Portable offline demo setup

param(
    [switch]$SkipDocker = $false,
    [switch]$Online = $false
)

$ErrorActionPreference = "Stop"

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallersDir = Join-Path $ScriptDir "installers"

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

# Detect architecture
function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -eq "AMD64" -or $arch -eq "x86_64") {
        return "amd64"
    } else {
        Write-Error "Unsupported architecture: $arch"
        exit 1
    }
}

# Check if command exists
function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Install Docker Desktop
function Install-Docker {
    Write-Header "Installing Docker Desktop"
    
    if (Test-CommandExists docker) {
        $version = & docker --version
        Write-Success "Docker already installed: $version"
        
        # Check if Docker is running
        try {
            & docker info | Out-Null
            Write-Success "Docker is running"
        } catch {
            Write-Warning "Docker is installed but not running"
            Write-Info "Please start Docker Desktop manually and wait for it to be ready"
            Write-Info "Then run this script again"
            exit 1
        }
        return
    }
    
    if ($SkipDocker) {
        Write-Warning "Skipping Docker installation (use -SkipDocker to skip)"
        return
    }
    
    $installerPath = Join-Path $InstallersDir "windows\Docker Desktop Installer.exe"
    if (-not (Test-Path $installerPath)) {
        Write-Error "Docker Desktop installer not found at: $installerPath"
        Write-Info "Please run .\download-installers.ps1 first"
        exit 1
    }
    
    Write-Info "Installing Docker Desktop..."
    Write-Warning "This requires administrator privileges and will take several minutes"
    
    Start-Process -FilePath $installerPath -ArgumentList "install --quiet" -Wait -Verb RunAs
    
    Write-Info "Docker Desktop installed. Please start Docker Desktop and wait for it to be ready"
    Write-Info "Then run this script again"
    exit 0
}

# Install Kind
function Install-Kind {
    Write-Header "Installing Kind"
    
    if (Test-CommandExists kind) {
        $version = & kind --version
        Write-Success "Kind already installed: $version"
        return
    }
    
    $kindPath = Join-Path $InstallersDir "windows\kind-windows-amd64.exe"
    if (-not (Test-Path $kindPath)) {
        Write-Error "Kind binary not found at: $kindPath"
        Write-Info "Please run .\download-installers.ps1 first"
        exit 1
    }
    
    Write-Info "Installing Kind..."
    $binDir = "C:\Program Files\Kind"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }
    
    Copy-Item $kindPath "$binDir\kind.exe" -Force
    
    # Add to PATH
    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($path -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$path;$binDir", "Machine")
        $env:Path = "$env:Path;$binDir"
    }
    
    Write-Success "Kind installed"
}

# Install kubectl
function Install-Kubectl {
    Write-Header "Installing kubectl"
    
    if (Test-CommandExists kubectl) {
        Write-Success "kubectl already installed"
        return
    }
    
    $kubectlPath = Join-Path $InstallersDir "windows\kubectl.exe"
    if (-not (Test-Path $kubectlPath)) {
        Write-Error "kubectl binary not found at: $kubectlPath"
        Write-Info "Please run .\download-installers.ps1 first"
        exit 1
    }
    
    Write-Info "Installing kubectl..."
    $binDir = "C:\Program Files\kubectl"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }
    
    Copy-Item $kubectlPath "$binDir\kubectl.exe" -Force
    
    # Add to PATH
    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($path -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$path;$binDir", "Machine")
        $env:Path = "$env:Path;$binDir"
    }
    
    Write-Success "kubectl installed"
}

# Install Helm
function Install-Helm {
    Write-Header "Installing Helm"
    
    if (Test-CommandExists helm) {
        $version = & helm version --short
        Write-Success "Helm already installed: $version"
        return
    }
    
    $helmArchive = Join-Path $InstallersDir "windows\helm-windows-amd64.zip"
    if (-not (Test-Path $helmArchive)) {
        Write-Error "Helm archive not found at: $helmArchive"
        Write-Info "Please run .\download-installers.ps1 first"
        exit 1
    }
    
    Write-Info "Installing Helm..."
    $binDir = "C:\Program Files\Helm"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }
    
    Expand-Archive -Path $helmArchive -DestinationPath $env:TEMP -Force
    Copy-Item "$env:TEMP\windows-amd64\helm.exe" "$binDir\helm.exe" -Force
    
    # Add to PATH
    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($path -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$path;$binDir", "Machine")
        $env:Path = "$env:Path;$binDir"
    }
    
    Write-Success "Helm installed"
}

# Install k9s
function Install-K9s {
    Write-Header "Installing k9s"
    
    if (Test-CommandExists k9s) {
        Write-Success "k9s already installed"
        return
    }
    
    $k9sArchive = Join-Path $InstallersDir "windows\k9s_windows_amd64.zip"
    if (-not (Test-Path $k9sArchive)) {
        Write-Warning "k9s archive not found at: $k9sArchive"
        Write-Info "k9s is optional - skipping"
        return
    }
    
    Write-Info "Installing k9s..."
    $binDir = "C:\Program Files\k9s"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }
    
    Expand-Archive -Path $k9sArchive -DestinationPath $env:TEMP\k9s -Force
    Copy-Item "$env:TEMP\k9s\k9s.exe" "$binDir\k9s.exe" -Force
    
    # Add to PATH
    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($path -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$path;$binDir", "Machine")
        $env:Path = "$env:Path;$binDir"
    }
    
    Write-Success "k9s installed"
}

# Install mkcert
function Install-Mkcert {
    Write-Header "Installing mkcert"
    
    if (Test-CommandExists mkcert) {
        Write-Success "mkcert already installed"
        return
    }
    
    $mkcertPath = Join-Path $InstallersDir "windows\mkcert-windows-amd64.exe"
    if (-not (Test-Path $mkcertPath)) {
        Write-Error "mkcert binary not found at: $mkcertPath"
        Write-Info "Please run .\download-installers.ps1 first"
        exit 1
    }
    
    Write-Info "Installing mkcert..."
    $binDir = "C:\Program Files\mkcert"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }
    
    Copy-Item $mkcertPath "$binDir\mkcert.exe" -Force
    
    # Add to PATH
    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($path -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$path;$binDir", "Machine")
        $env:Path = "$env:Path;$binDir"
    }
    
    # Install local CA
    Write-Info "Installing local CA certificates..."
    & "$binDir\mkcert.exe" -install
    
    Write-Success "mkcert installed and CA configured"
}

# Create Kind cluster
function New-KindCluster {
    Write-Header "Creating Kind Cluster"
    
    $clusterName = "ess-demo"
    
    # Check if cluster already exists
    $existingClusters = & kind get clusters 2>$null
    if ($existingClusters -contains $clusterName) {
        Write-Warning "Cluster '$clusterName' already exists"
        $response = Read-Host "Delete and recreate? (y/N)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            Write-Info "Deleting existing cluster..."
            & kind delete cluster --name $clusterName
        } else {
            Write-Info "Using existing cluster"
            return
        }
    }
    
    # Create Kind config
    $kindConfig = @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
"@
    
    $kindConfigPath = Join-Path $env:TEMP "kind-config.yaml"
    $kindConfig | Out-File -FilePath $kindConfigPath -Encoding UTF8
    
    Write-Info "Creating Kind cluster '$clusterName'..."
    & kind create cluster --name $clusterName --config $kindConfigPath
    
    # Set context
    & kubectl cluster-info --context "kind-$clusterName"
    
    Write-Success "Kind cluster created successfully"
}

# Install NGINX Ingress Controller
function Install-NginxIngress {
    Write-Header "Installing NGINX Ingress Controller"
    
    Write-Info "Applying NGINX Ingress manifests..."
    & kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    Write-Info "Waiting for NGINX Ingress to be ready..."
    & kubectl wait --namespace ingress-nginx `
        --for=condition=ready pod `
        --selector=app.kubernetes.io/component=controller `
        --timeout=90s
    
    Write-Success "NGINX Ingress Controller ready"
}

# Prompt for domain name
function Get-DomainName {
    Write-Header "Domain Configuration"
    
    Write-Host ""
    Write-Info "Enter the base domain name for your ESS deployment"
    Write-Info "Examples: ess.localhost, my-matrix.localhost"
    Write-Info "(Using .localhost ensures automatic local DNS resolution)"
    Write-Host ""
    
    $domain = Read-Host "Domain name"
    
    if ([string]::IsNullOrWhiteSpace($domain)) {
        Write-Error "Domain name cannot be empty"
        exit 1
    }
    
    Write-Success "Using domain: $domain"
    return $domain
}

# Generate hostnames configuration
function New-HostnamesConfig {
    param([string]$DomainName)
    
    Write-Header "Generating Configuration Files"
    
    $hostnamesYaml = @"
elementAdmin:
  ingress:
    host: admin.$DomainName
elementWeb:
  ingress:
    host: chat.$DomainName
matrixAuthenticationService:
  ingress:
    host: auth.$DomainName
matrixRTC:
  ingress:
    host: mrtc.$DomainName
serverName: $DomainName
synapse:
  ingress:
    host: matrix.$DomainName
"@
    
    $hostnamesPath = Join-Path $ScriptDir "demo-values\hostnames.yaml"
    $hostnamesYaml | Out-File -FilePath $hostnamesPath -Encoding UTF8
    
    Write-Success "Generated hostnames.yaml"
    return $DomainName
}

# Generate certificates
function New-Certificates {
    param([string]$DomainName)
    
    Write-Header "Generating SSL Certificates"
    
    # Create namespace
    & kubectl create namespace ess --dry-run=client -o yaml | kubectl apply -f -
    
    # Extract hostnames
    $hostnamesFile = Join-Path $ScriptDir "demo-values\hostnames.yaml"
    $certsDir = Join-Path $ScriptDir "certs"
    
    if (-not (Test-Path $certsDir)) {
        New-Item -ItemType Directory -Path $certsDir -Force | Out-Null
    }
    
    # Parse YAML and create certificates
    $content = Get-Content $hostnamesFile -Raw
    
    # Extract hosts (simple parsing - could use proper YAML parser)
    $admin = ($content | Select-String -Pattern 'elementAdmin:.*?host: (.+)' -AllMatches).Matches.Groups[1].Value.Trim()
    $chat = ($content | Select-String -Pattern 'elementWeb:.*?host: (.+)' -AllMatches).Matches.Groups[1].Value.Trim()
    $synapse = ($content | Select-String -Pattern 'synapse:.*?host: (.+)' -AllMatches).Matches.Groups[1].Value.Trim()
    $auth = ($content | Select-String -Pattern 'matrixAuthenticationService:.*?host: (.+)' -AllMatches).Matches.Groups[1].Value.Trim()
    $mrtc = ($content | Select-String -Pattern 'matrixRTC:.*?host: (.+)' -AllMatches).Matches.Groups[1].Value.Trim()
    $servername = ($content | Select-String -Pattern 'serverName: (.+)').Matches.Groups[1].Value.Trim()
    
    Push-Location $certsDir
    
    # Generate certificates
    Write-Info "Generating certificates..."
    
    & mkcert $servername
    & kubectl create secret tls ess-well-known-certificate --cert="$servername.pem" --key="$servername-key.pem" -n ess
    
    & mkcert $synapse
    & kubectl create secret tls ess-matrix-certificate --cert="$synapse.pem" --key="$synapse-key.pem" -n ess
    
    & mkcert $mrtc
    & kubectl create secret tls ess-mrtc-certificate --cert="$mrtc.pem" --key="$mrtc-key.pem" -n ess
    
    & mkcert $chat
    & kubectl create secret tls ess-chat-certificate --cert="$chat.pem" --key="$chat-key.pem" -n ess
    
    & mkcert $auth
    & kubectl create secret tls ess-auth-certificate --cert="$auth.pem" --key="$auth-key.pem" -n ess
    
    & mkcert $admin
    & kubectl create secret tls ess-admin-certificate --cert="$admin.pem" --key="$admin-key.pem" -n ess
    
    Pop-Location
    
    Write-Success "Certificates generated and secrets created"
}

# Deploy ESS
function Install-ESS {
    Write-Header "Deploying ESS Community"
    
    Write-Info "Installing ESS Helm chart..."
    
    $valuesDir = Join-Path $ScriptDir "demo-values"
    
    & helm upgrade --install `
        --namespace "ess" `
        ess `
        oci://ghcr.io/element-hq/ess-helm/matrix-stack `
        -f "$valuesDir\hostnames.yaml" `
        -f "$valuesDir\tls.yaml" `
        -f "$valuesDir\auth.yaml" `
        -f "$valuesDir\mrtc.yaml" `
        -f "$valuesDir\pull-policy.yml" `
        --wait
    
    Write-Success "ESS deployed successfully"
}

# Display access information
function Show-AccessInfo {
    param([string]$DomainName)
    
    Write-Header "Setup Complete!"
    
    Write-Host ""
    Write-Success "Your ESS Community instance is ready!"
    Write-Host ""
    Write-Info "Access URLs:"
    Write-Host "  • Element Web:        https://chat.$DomainName"
    Write-Host "  • Admin Portal:       https://admin.$DomainName"
    Write-Host "  • Matrix Server:      https://matrix.$DomainName"
    Write-Host "  • Authentication:     https://auth.$DomainName"
    Write-Host "  • Matrix RTC:         https://mrtc.$DomainName"
    Write-Host "  • Federation:         https://$DomainName"
    Write-Host ""
    
    # Get Ingress IP
    Write-Info "Waiting for Ingress IP assignment..."
    $ingressIP = ""
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $ingressIP = (kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null)
            if (-not $ingressIP) {
                $ingressIP = (kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null)
            }
            if (-not $ingressIP) {
                # For Kind/local clusters, use localhost
                $ingressIP = "127.0.0.1"
            }
            if ($ingressIP) {
                break
            }
        } catch {
            $ingressIP = "127.0.0.1"
        }
        Start-Sleep -Seconds 2
    }
    
    if (-not $ingressIP) {
        $ingressIP = "127.0.0.1"
        Write-Warning "Could not determine Ingress IP, using localhost (127.0.0.1)"
    }
    
    Write-Header "DNS Configuration"
    Write-Host ""
    Write-Success "Ingress IP: $ingressIP"
    Write-Host ""
    Write-Info "Add these DNS entries to your DNS server:"
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "DNS Zone File Format (BIND):" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    $domainTrimmed = $DomainName.TrimEnd('.')
    Write-Host "${domainTrimmed}.        IN  A     $ingressIP"
    Write-Host "chat.${domainTrimmed}.   IN  A     $ingressIP"
    Write-Host "admin.${domainTrimmed}.  IN  A     $ingressIP"
    Write-Host "matrix.${domainTrimmed}. IN  A     $ingressIP"
    Write-Host "auth.${domainTrimmed}.   IN  A     $ingressIP"
    Write-Host "mrtc.${domainTrimmed}.   IN  A     $ingressIP"
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "Windows hosts File (C:\Windows\System32\drivers\etc\hosts):" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    Write-Host "$ingressIP  $DomainName chat.$DomainName admin.$DomainName matrix.$DomainName auth.$DomainName mrtc.$DomainName"
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "dnsmasq Format:" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    Write-Host "address=/$DomainName/$ingressIP"
    Write-Host "address=/chat.$DomainName/$ingressIP"
    Write-Host "address=/admin.$DomainName/$ingressIP"
    Write-Host "address=/matrix.$DomainName/$ingressIP"
    Write-Host "address=/auth.$DomainName/$ingressIP"
    Write-Host "address=/mrtc.$DomainName/$ingressIP"
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    
    Write-Info "Useful commands:"
    Write-Host "  • View cluster status:     kubectl get pods -n ess"
    Write-Host "  • Watch resources (k9s):   k9s -n ess"
    Write-Host "  • View logs:               kubectl logs -n ess -l app.kubernetes.io/name=synapse"
    Write-Host ""
    Write-Info "Cluster info:"
    Write-Host "  • Context: kind-ess-demo"
    Write-Host "  • Namespace: ess"
    Write-Host ""
    Write-Warning "Note: Your browser may show a certificate warning. This is expected with mkcert."
    Write-Warning "Click 'Advanced' and proceed to accept the local development certificate."
    Write-Host ""
}

# Main execution
function Main {
    Write-Header "ESS Community Portable Demo - Setup"
    
    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "This script requires administrator privileges"
        Write-Info "Please run PowerShell as Administrator and try again"
        exit 1
    }
    
    # Get architecture
    $arch = Get-Architecture
    Write-Info "Detected platform: Windows/$arch"
    
    # Check if installers exist
    $windowsInstallersDir = Join-Path $InstallersDir "windows"
    if (-not (Test-Path $windowsInstallersDir) -or ((Get-ChildItem $windowsInstallersDir).Count -eq 0)) {
        Write-Warning "No installers found for Windows"
        Write-Info "Please run .\download-installers.ps1 first to download required software"
        exit 1
    }
    
    # Install dependencies
    Install-Docker
    Install-Kind
    Install-Kubectl
    Install-Helm
    Install-K9s
    Install-Mkcert
    
    # Prompt for domain
    $domainName = Get-DomainName
    
    # Generate configuration
    New-HostnamesConfig -DomainName $domainName
    
    # Setup Kubernetes
    New-KindCluster
    Install-NginxIngress
    
    # Generate certificates
    New-Certificates -DomainName $domainName
    
    # Deploy ESS
    Install-ESS
    
    # Show access information
    Show-AccessInfo -DomainName $domainName
}

# Run main function
Main

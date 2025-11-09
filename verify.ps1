# ESS Community Demo - Verification Script for Windows
# Checks the status of the ESS deployment

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

$ClusterName = "ess-demo"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Header "ESS Community Demo - Status Check"

# Check if kind is installed
if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
    Write-Error "Kind is not installed"
    exit 1
}

# Check if kubectl is installed
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is not installed"
    exit 1
}

# Check if cluster exists
$existingClusters = & kind get clusters 2>$null
if ($existingClusters -notcontains $ClusterName) {
    Write-Error "Cluster '$ClusterName' does not exist"
    Write-Info "Run .\setup.ps1 to create it"
    exit 1
}

Write-Success "Cluster '$ClusterName' exists"

# Check if context is set
$currentContext = & kubectl config current-context
if ($currentContext -ne "kind-$ClusterName") {
    Write-Warning "Current context is not 'kind-$ClusterName'"
    Write-Info "Switching context..."
    & kubectl config use-context "kind-$ClusterName"
}

Write-Success "Using context: kind-$ClusterName"

# Check namespace
Write-Header "Checking ESS Namespace"

try {
    & kubectl get namespace ess 2>&1 | Out-Null
    Write-Success "Namespace 'ess' exists"
} catch {
    Write-Error "Namespace 'ess' does not exist"
    exit 1
}

# Check pods
Write-Header "Checking Pod Status"

& kubectl get pods -n ess

Write-Host ""
Write-Info "Pod summary:"

$allPods = & kubectl get pods -n ess --no-headers
$totalPods = ($allPods | Measure-Object).Count
$runningPods = (& kubectl get pods -n ess --field-selector=status.phase=Running --no-headers | Measure-Object).Count
$pendingPods = (& kubectl get pods -n ess --field-selector=status.phase=Pending --no-headers | Measure-Object).Count
$failedPods = (& kubectl get pods -n ess --field-selector=status.phase=Failed --no-headers | Measure-Object).Count

Write-Host "  Total: $totalPods"
Write-Host "  Running: $runningPods"
Write-Host "  Pending: $pendingPods"
Write-Host "  Failed: $failedPods"

# Check services
Write-Header "Checking Services"

& kubectl get svc -n ess

# Check ingresses
Write-Header "Checking Ingresses"

& kubectl get ingress -n ess

# Extract domain from hostnames.yaml if it exists
$hostnamesFile = Join-Path $ScriptDir "demo-values\hostnames.yaml"
if (Test-Path $hostnamesFile) {
    $content = Get-Content $hostnamesFile -Raw
    $domain = ($content | Select-String -Pattern 'serverName: (.+)').Matches.Groups[1].Value.Trim()
    
    Write-Header "Access URLs"
    Write-Host ""
    Write-Info "Element Web:        https://chat.$domain"
    Write-Info "Admin Portal:       https://admin.$domain"
    Write-Info "Matrix Server:      https://matrix.$domain"
    Write-Info "Authentication:     https://auth.$domain"
    Write-Info "Matrix RTC:         https://mrtc.$domain"
    Write-Info "Federation:         https://$domain"
    Write-Host ""
}

# Overall status
Write-Host ""
if ($runningPods -eq $totalPods -and $failedPods -eq 0) {
    Write-Success "All pods are running successfully!"
} else {
    Write-Warning "Some pods are not in running state"
    Write-Info "Use 'kubectl logs -n ess <pod-name>' to check logs"
    Write-Info "Use 'k9s -n ess' for interactive management"
}

Write-Host ""

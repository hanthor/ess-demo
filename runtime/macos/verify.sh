#!/bin/bash
# ESS Community Demo - Verification Script
# Checks the status of the ESS deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

CLUSTER_NAME="ess-demo"

print_header "ESS Community Demo - Status Check"

# Check if kind is installed
if ! command -v kind >/dev/null 2>&1; then
    print_error "Kind is not installed"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl >/dev/null 2>&1; then
    print_error "kubectl is not installed"
    exit 1
fi

# Check if cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    print_error "Cluster '${CLUSTER_NAME}' does not exist"
    print_info "Run ./setup.sh to create it"
    exit 1
fi

print_success "Cluster '${CLUSTER_NAME}' exists"

# Check if context is set
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "kind-${CLUSTER_NAME}" ]; then
    print_warning "Current context is not 'kind-${CLUSTER_NAME}'"
    print_info "Switching context..."
    kubectl config use-context "kind-${CLUSTER_NAME}"
fi

print_success "Using context: kind-${CLUSTER_NAME}"

# Check namespace
print_header "Checking ESS Namespace"

if kubectl get namespace ess >/dev/null 2>&1; then
    print_success "Namespace 'ess' exists"
else
    print_error "Namespace 'ess' does not exist"
    exit 1
fi

# Check pods
print_header "Checking Pod Status"

kubectl get pods -n ess

echo ""
print_info "Pod summary:"

TOTAL_PODS=$(kubectl get pods -n ess --no-headers | wc -l)
RUNNING_PODS=$(kubectl get pods -n ess --field-selector=status.phase=Running --no-headers | wc -l)
PENDING_PODS=$(kubectl get pods -n ess --field-selector=status.phase=Pending --no-headers | wc -l)
FAILED_PODS=$(kubectl get pods -n ess --field-selector=status.phase=Failed --no-headers | wc -l)

echo "  Total: $TOTAL_PODS"
echo "  Running: $RUNNING_PODS"
echo "  Pending: $PENDING_PODS"
echo "  Failed: $FAILED_PODS"

# Check services
print_header "Checking Services"

kubectl get svc -n ess

# Check ingresses
print_header "Checking Ingresses"

kubectl get ingress -n ess

# Extract domain from hostnames.yaml if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/demo-values/hostnames.yaml" ]; then
    DOMAIN=$(grep "serverName:" "${SCRIPT_DIR}/demo-values/hostnames.yaml" | sed "s/.*serverName: //" | tr -d ' ')
    
    print_header "Access URLs"
    echo ""
    print_info "Element Web:        https://chat.${DOMAIN}"
    print_info "Admin Portal:       https://admin.${DOMAIN}"
    print_info "Matrix Server:      https://matrix.${DOMAIN}"
    print_info "Authentication:     https://auth.${DOMAIN}"
    print_info "Matrix RTC:         https://mrtc.${DOMAIN}"
    print_info "Federation:         https://${DOMAIN}"
    echo ""
fi

# Overall status
echo ""
if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$FAILED_PODS" -eq 0 ]; then
    print_success "All pods are running successfully!"
else
    print_warning "Some pods are not in running state"
    print_info "Use 'kubectl logs -n ess <pod-name>' to check logs"
    print_info "Use 'k9s -n ess' for interactive management"
fi

echo ""

#!/bin/bash
# ESS Community Demo - Cleanup Script
# Removes the Kind cluster and associated resources
# Use --uninstall to also remove all installed software

set -euo pipefail

# Parse arguments
UNINSTALL_SOFTWARE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --uninstall)
            UNINSTALL_SOFTWARE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --uninstall   Remove all installed software (Docker, Kind, kubectl, Helm, k9s, mkcert)"
            echo "  --help, -h    Show this help message"
            echo ""
            echo "Without --uninstall flag, only removes the Kind cluster."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Uninstall software
uninstall_software() {
    print_header "Uninstalling Software"
    
    echo ""
    print_warning "This will remove the following software from your system:"
    echo "  • Kind"
    echo "  • kubectl"
    echo "  • Helm"
    echo "  • k9s"
    echo "  • mkcert"
    echo ""
    print_warning "Docker will NOT be removed (may be used by other applications)"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping software uninstall"
        return 0
    fi
    
    # Remove Kind
    if command -v kind >/dev/null 2>&1; then
        print_info "Removing Kind..."
        sudo rm -f /usr/local/bin/kind
        print_success "Kind removed"
    fi
    
    # Remove kubectl
    if command -v kubectl >/dev/null 2>&1; then
        KUBECTL_PATH=$(command -v kubectl)
        if [[ "$KUBECTL_PATH" == "/usr/local/bin/kubectl" ]]; then
            print_info "Removing kubectl..."
            sudo rm -f /usr/local/bin/kubectl
            print_success "kubectl removed"
        else
            print_warning "kubectl found at $KUBECTL_PATH (not managed by this demo)"
        fi
    fi
    
    # Remove Helm
    if command -v helm >/dev/null 2>&1; then
        HELM_PATH=$(command -v helm)
        if [[ "$HELM_PATH" == "/usr/local/bin/helm" ]]; then
            print_info "Removing Helm..."
            sudo rm -f /usr/local/bin/helm
            print_success "Helm removed"
        else
            print_warning "Helm found at $HELM_PATH (not managed by this demo)"
        fi
    fi
    
    # Remove k9s
    if command -v k9s >/dev/null 2>&1; then
        K9S_PATH=$(command -v k9s)
        if [[ "$K9S_PATH" == "/usr/local/bin/k9s" ]]; then
            print_info "Removing k9s..."
            sudo rm -f /usr/local/bin/k9s
            print_success "k9s removed"
        else
            print_warning "k9s found at $K9S_PATH (not managed by this demo)"
        fi
    fi
    
    # Remove mkcert
    if command -v mkcert >/dev/null 2>&1; then
        print_info "Uninstalling mkcert CA..."
        mkcert -uninstall || true
        
        MKCERT_PATH=$(command -v mkcert)
        if [[ "$MKCERT_PATH" == "/usr/local/bin/mkcert" ]]; then
            print_info "Removing mkcert..."
            sudo rm -f /usr/local/bin/mkcert
            print_success "mkcert removed"
        else
            print_warning "mkcert found at $MKCERT_PATH (not managed by this demo)"
        fi
    fi
    
    print_success "Software uninstall complete"
    print_info "Note: Docker was not removed. Uninstall manually if needed."
}

print_header "ESS Community Demo - Cleanup"

# Check if kind is installed
if ! command -v kind >/dev/null 2>&1; then
    print_error "Kind is not installed"
    exit 1
fi

# Check if cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    print_warning "Cluster '${CLUSTER_NAME}' does not exist"
    exit 0
fi

# Confirm deletion
echo ""
print_warning "This will delete the Kind cluster '${CLUSTER_NAME}' and all its resources"
print_warning "This includes all pods, services, and data in the cluster"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Cancelled"
    exit 0
fi

print_info "Deleting Kind cluster '${CLUSTER_NAME}'..."
kind delete cluster --name "$CLUSTER_NAME"

print_success "Cluster deleted successfully"

# Optionally clean up generated certificates
echo ""
read -p "Also remove generated certificates? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "${SCRIPT_DIR}/certs" ]; then
        print_info "Removing certificates..."
        rm -rf "${SCRIPT_DIR}/certs"
        print_success "Certificates removed"
    fi
fi

# Uninstall software if requested
if [ "$UNINSTALL_SOFTWARE" = true ]; then
    uninstall_software
fi

print_header "Cleanup Complete!"
if [ "$UNINSTALL_SOFTWARE" = true ]; then
    print_info "Cluster and software have been removed"
else
    print_info "To reinstall, run: ./setup.sh"
    print_info "To also remove installed software, run: ./cleanup.sh --uninstall"
fi
echo ""

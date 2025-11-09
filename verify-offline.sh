#!/bin/bash
# ESS Community Demo - Offline Readiness Verification Script
# Checks if all required components are cached for offline deployment

set -uo pipefail  # Removed -e to allow script to continue on errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_CACHE_DIR="${SCRIPT_DIR}/image-cache"
INSTALLERS_DIR="${SCRIPT_DIR}/installers"

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((CHECKS_WARNING++))
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Check if directory exists and has files
check_directory() {
    local dir="$1"
    local name="$2"
    local pattern="$3"
    
    if [ ! -d "$dir" ]; then
        print_error "$name directory not found: $dir"
        return 1
    fi
    
    local count=$(find "$dir" -name "$pattern" 2>/dev/null | wc -l)
    if [ "$count" -eq 0 ]; then
        print_error "No $name files found in: $dir"
        return 1
    fi
    
    local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    print_success "$name: $count file(s) found ($size)"
    return 0
}

# Check file exists
check_file() {
    local file="$1"
    local name="$2"
    
    if [ ! -f "$file" ]; then
        print_error "$name not found: $file"
        return 1
    fi
    
    local size=$(du -sh "$file" 2>/dev/null | cut -f1)
    print_success "$name found ($size)"
    return 0
}

# Main verification
main() {
    print_header "ESS Offline Readiness Check"
    
    print_info "Verifying offline deployment components..."
    echo ""
    
    # Check Docker
    print_header "Docker Availability"
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            print_success "Docker is installed and running"
        else
            print_error "Docker is installed but not running"
            print_info "Please start Docker before running setup"
        fi
    else
        print_error "Docker is not installed"
        print_info "Docker is required for offline deployment"
    fi
    
    # Check installers
    print_header "Installer Binaries"
    
    # Detect current platform
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$OS" in
        darwin*) OS="macos" ;;
        linux*) OS="linux" ;;
        *) OS="unknown" ;;
    esac
    
    if [ -d "${INSTALLERS_DIR}/${OS}" ]; then
        print_success "Installers directory found for ${OS}"
        
        # Check for key binaries
        local binaries=("kind" "kubectl" "helm" "k9s")
        for binary in "${binaries[@]}"; do
            if ls "${INSTALLERS_DIR}/${OS}/${binary}"* >/dev/null 2>&1; then
                local size=$(du -sh "${INSTALLERS_DIR}/${OS}/${binary}"* | head -1 | cut -f1)
                print_success "  ${binary} binary found ($size)"
            else
                print_warning "  ${binary} binary not found (optional)"
            fi
        done
    else
        print_warning "Installers not found for ${OS}"
        print_info "Run: ./download-installers.sh"
    fi
    
    # Check for other platforms (for portable deployment)
    print_header "Multi-Platform Support"
    local platforms=("macos" "linux" "windows")
    for platform in "${platforms[@]}"; do
        if [ -d "${INSTALLERS_DIR}/${platform}" ]; then
            local count=$(find "${INSTALLERS_DIR}/${platform}" -type f 2>/dev/null | wc -l)
            if [ "$count" -gt 0 ]; then
                local size=$(du -sh "${INSTALLERS_DIR}/${platform}" 2>/dev/null | cut -f1)
                print_success "${platform} installers: $count file(s) ($size)"
            fi
        else
            print_warning "${platform} installers not found"
        fi
    done
    print_info "Run './download-installers.sh --all' for all platforms"
    
    # Check image cache
    print_header "Container Image Cache"
    
    if [ ! -d "$IMAGE_CACHE_DIR" ]; then
        print_error "Image cache directory not found: $IMAGE_CACHE_DIR"
        print_info "Run: ./cache-images.sh -y"
    else
        # Check Kind images
        check_directory "${IMAGE_CACHE_DIR}/kind-images" "Kind node images" "*.tar"
        
        # Check ESS images
        check_directory "${IMAGE_CACHE_DIR}/ess-images" "ESS container images" "*.tar"
        
        # Check Helm charts
        if [ -d "${IMAGE_CACHE_DIR}/helm-charts" ]; then
            if ls "${IMAGE_CACHE_DIR}/helm-charts"/*.tgz >/dev/null 2>&1; then
                local chart_version=$(ls -t "${IMAGE_CACHE_DIR}/helm-charts"/matrix-stack-*.tgz 2>/dev/null | head -1 | sed 's/.*matrix-stack-\(.*\)\.tgz/\1/')
                print_success "Helm chart cached (version: ${chart_version:-unknown})"
            else
                print_error "No Helm chart tarball found"
            fi
            
            if [ -d "${IMAGE_CACHE_DIR}/helm-charts/matrix-stack" ]; then
                print_success "Helm chart extracted and ready"
            else
                print_warning "Helm chart not extracted"
            fi
        else
            print_error "Helm charts directory not found"
        fi
        
        # Check for image list
        if [ -f "${IMAGE_CACHE_DIR}/ess-images-list.txt" ]; then
            local image_count=$(wc -l < "${IMAGE_CACHE_DIR}/ess-images-list.txt")
            print_success "Image list found ($image_count images)"
        else
            print_warning "Image list not found"
        fi
        
        # Check for load script
        if [ -f "${SCRIPT_DIR}/load-cached-images.sh" ]; then
            print_success "Image load script generated"
        else
            print_warning "Image load script not found"
        fi
        
        # Total cache size
        if [ -d "$IMAGE_CACHE_DIR" ]; then
            local total_size=$(du -sh "$IMAGE_CACHE_DIR" 2>/dev/null | cut -f1)
            print_info "Total cache size: $total_size"
        fi
    fi
    
    # Check configuration files
    print_header "Configuration Files"
    
    check_file "${SCRIPT_DIR}/setup.sh" "Setup script (Linux/macOS)"
    check_file "${SCRIPT_DIR}/setup.ps1" "Setup script (Windows)"
    check_file "${SCRIPT_DIR}/cleanup.sh" "Cleanup script (Linux/macOS)"
    check_file "${SCRIPT_DIR}/build-certs.sh" "Certificate builder"
    
    # Check optional tools
    print_header "Optional Tools (Recommended)"
    
    if command -v kubectl >/dev/null 2>&1; then
        print_success "kubectl is installed"
    else
        print_warning "kubectl not in PATH (will be installed by setup)"
    fi
    
    if command -v kind >/dev/null 2>&1; then
        print_success "kind is installed"
    else
        print_warning "kind not in PATH (will be installed by setup)"
    fi
    
    if command -v helm >/dev/null 2>&1; then
        print_success "helm is installed"
    else
        print_warning "helm not in PATH (will be installed by setup)"
    fi
    
    if command -v k9s >/dev/null 2>&1; then
        print_success "k9s is installed"
    else
        print_warning "k9s not in PATH (will be installed by setup)"
    fi
    
    if command -v mkcert >/dev/null 2>&1; then
        print_success "mkcert is installed"
    else
        print_warning "mkcert not in PATH (will be installed by setup)"
    fi
    
    if command -v skopeo >/dev/null 2>&1; then
        print_success "skopeo is installed (enables smart image caching)"
    else
        print_warning "skopeo not found (optional, enables version checking)"
    fi
    
    # Summary
    print_header "Verification Summary"
    echo ""
    print_success "Checks passed: $CHECKS_PASSED"
    if [ "$CHECKS_WARNING" -gt 0 ]; then
        print_warning "Warnings: $CHECKS_WARNING"
    fi
    if [ "$CHECKS_FAILED" -gt 0 ]; then
        print_error "Checks failed: $CHECKS_FAILED"
    fi
    echo ""
    
    # Final verdict
    if [ "$CHECKS_FAILED" -eq 0 ]; then
        if [ "$CHECKS_WARNING" -eq 0 ]; then
            print_header "✅ READY FOR OFFLINE DEPLOYMENT"
            echo ""
            print_success "All components are cached and ready!"
            print_info "You can now disconnect from the internet and run:"
            echo "  ./setup.sh"
        else
            print_header "⚠️  MOSTLY READY FOR OFFLINE DEPLOYMENT"
            echo ""
            print_warning "Some optional components are missing but core functionality is ready"
            print_info "You can proceed with offline deployment:"
            echo "  ./setup.sh"
        fi
    else
        print_header "❌ NOT READY FOR OFFLINE DEPLOYMENT"
        echo ""
        print_error "Critical components are missing"
        print_info "Please run the following to prepare:"
        echo ""
        echo "  1. Ensure Docker is running"
        echo "  2. Download installers: ./download-installers.sh --all"
        echo "  3. Cache images: ./cache-images.sh -y"
        echo ""
        print_info "Then run this verification again: ./verify-offline.sh"
    fi
    echo ""
    
    # Exit with appropriate code
    if [ "$CHECKS_FAILED" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"

#!/usr/bin/env bash
# ESS Demo Offline Package Installer
# This script verifies, extracts, and optionally runs the ESS demo setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Package details (will be replaced during packaging)
PACKAGE_FILE="__PACKAGE_FILE__"
CHECKSUM_FILE="__CHECKSUM_FILE__"
PLATFORM="__PLATFORM__"

# Print colored output
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
}

# Check if package file exists
check_package() {
    print_header "Verifying Package"
    
    if [[ ! -f "$PACKAGE_FILE" ]]; then
        print_error "Package file not found: $PACKAGE_FILE"
        print_info "Please ensure the package file is in the current directory"
        exit 1
    fi
    
    print_success "Package file found: $PACKAGE_FILE"
    
    # Show package size
    local size=$(du -h "$PACKAGE_FILE" | cut -f1)
    print_info "Package size: $size"
}

# Verify checksum
verify_checksum() {
    print_header "Verifying Checksum"
    
    if [[ ! -f "$CHECKSUM_FILE" ]]; then
        print_warning "Checksum file not found: $CHECKSUM_FILE"
        print_warning "Skipping checksum verification"
        return 0
    fi
    
    print_info "Verifying package integrity..."
    
    if command -v sha256sum &> /dev/null; then
        if sha256sum -c "$CHECKSUM_FILE" &> /dev/null; then
            print_success "Checksum verification passed"
        else
            print_error "Checksum verification failed!"
            print_error "The package may be corrupted or tampered with"
            exit 1
        fi
    else
        print_warning "sha256sum not found, skipping checksum verification"
    fi
}

# Install zstd if needed
install_zstd() {
    # Check if zstd is already available
    if command -v zstd &> /dev/null; then
        return 0
    fi
    
    print_header "Installing zstd"
    print_info "zstd is required to extract the package..."
    
    # Detect platform
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    # Extract zstd from the package directory
    local zstd_dir=""
    
    if [[ "$os" == "darwin" ]]; then
        zstd_dir="macos"
    elif [[ "$os" == "linux" ]]; then
        zstd_dir="linux"
    elif [[ "$os" =~ "mingw"* ]] || [[ "$os" =~ "msys"* ]]; then
        zstd_dir="windows"
    else
        print_error "Unsupported platform: $os"
        exit 1
    fi
    
    # Check if we're in a directory with zstd installers
    if [[ -f "zstd-*.tar.gz" ]] || [[ -f "zstd-*.zip" ]]; then
        print_info "Extracting bundled zstd..."
        if [[ "$zstd_dir" == "windows" ]]; then
            unzip -q zstd-*.zip
            export PATH="$PWD/zstd:$PATH"
        else
            tar -xzf zstd-*.tar.gz
            export PATH="$PWD/zstd/bin:$PATH"
        fi
        print_success "zstd installed from bundle"
    else
        print_error "zstd not found and no bundled version available"
        print_info "Please install zstd manually:"
        print_info "  Ubuntu/Debian: sudo apt install zstd"
        print_info "  Fedora/RHEL: sudo dnf install zstd"
        print_info "  macOS: brew install zstd"
        exit 1
    fi
}

# Extract package
extract_package() {
    print_header "Extracting Package"
    
    local extract_dir="ess-demo"
    
    if [[ -d "$extract_dir" ]]; then
        print_warning "Directory '$extract_dir' already exists"
        read -p "Remove existing directory and continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Extraction cancelled"
            exit 0
        fi
        rm -rf "$extract_dir"
    fi
    
    print_info "Extracting to: $extract_dir/"
    
    # Detect compression format from filename
    if [[ "$PACKAGE_FILE" == *.tar.zst ]]; then
        if zstd -d -c "$PACKAGE_FILE" | tar -xf -; then
            print_success "Package extracted successfully"
        else
            print_error "Failed to extract package"
            exit 1
        fi
    elif [[ "$PACKAGE_FILE" == *.tar.gz ]]; then
        if tar -xzf "$PACKAGE_FILE"; then
            print_success "Package extracted successfully"
        else
            print_error "Failed to extract package"
            exit 1
        fi
    else
        print_error "Unknown package format: $PACKAGE_FILE"
        exit 1
    fi
    
    # Verify extraction
    if [[ ! -d "$extract_dir" ]]; then
        print_error "Extraction succeeded but directory not found: $extract_dir"
        exit 1
    fi
    
    # List key contents
    print_info "Package contents:"
    echo "  - Scripts: $(ls -1 $extract_dir/*.sh 2>/dev/null | wc -l) files"
    echo "  - Installers: $(find $extract_dir/installers -type f 2>/dev/null | wc -l) files"
    echo "  - Cached images: $(find $extract_dir/image-cache -name "*.tar" 2>/dev/null | wc -l) images"
}

# Run verification
run_verification() {
    print_header "Running Offline Verification"
    
    cd ess-demo
    
    if [[ -f "verify-offline.sh" ]]; then
        print_info "Running verification script..."
        if bash verify-offline.sh; then
            print_success "Verification passed"
            return 0
        else
            print_error "Verification failed"
            return 1
        fi
    else
        print_warning "Verification script not found, skipping"
        return 0
    fi
    
    cd ..
}

# Offer to run setup
offer_setup() {
    print_header "Ready to Deploy"
    
    echo ""
    echo "The ESS demo package has been extracted and verified."
    echo "You can now deploy the demo by running:"
    echo ""
    echo "  cd ess-demo"
    
    case "$PLATFORM" in
        windows)
            echo "  .\\setup.ps1    # PowerShell (recommended)"
            echo "  ./setup.sh     # WSL/Git Bash"
            ;;
        *)
            echo "  ./setup.sh"
            ;;
    esac
    
    echo ""
    read -p "Would you like to run the setup now? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Starting setup..."
        cd ess-demo
        
        case "$PLATFORM" in
            windows)
                if command -v powershell.exe &> /dev/null; then
                    print_info "Launching PowerShell setup..."
                    powershell.exe -ExecutionPolicy Bypass -File setup.ps1
                else
                    print_info "Running bash setup..."
                    bash setup.sh
                fi
                ;;
            *)
                bash setup.sh
                ;;
        esac
    else
        print_info "Setup skipped. Run the setup script manually when ready."
    fi
}

# Main execution
main() {
    print_header "ESS Demo Offline Package Installer"
    print_info "Platform: $PLATFORM"
    
    # Check prerequisites
    if ! command -v tar &> /dev/null; then
        print_error "tar command not found. Please install tar and try again."
        exit 1
    fi
    
    # Run installation steps
    check_package
    verify_checksum
    install_zstd  # Install zstd if not available
    extract_package
    
    if run_verification; then
        offer_setup
    else
        print_warning "Verification failed, but you can still try running setup manually"
        print_info "To run setup: cd ess-demo && ./setup.sh"
    fi
    
    print_header "Installation Complete"
    print_success "Done!"
}

# Run main function
main "$@"

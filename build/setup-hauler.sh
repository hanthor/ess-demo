#!/bin/bash
# Setup Hauler for air-gapped artifact management
# This script downloads and installs Hauler

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

# Detect platform
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
    darwin*)
        OS="darwin"
        ;;
    linux*)
        OS="linux"
        ;;
    *)
        print_error "Unsupported OS: $OS"
        exit 1
        ;;
esac

case "$ARCH" in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        print_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

print_header "Installing Hauler"

HAULER_VERSION="${HAULER_VERSION:-1.0.7}"
HAULER_URL="https://github.com/rancherfederal/hauler/releases/download/v${HAULER_VERSION}/hauler_${HAULER_VERSION}_${OS}_${ARCH}.tar.gz"

print_info "Detected platform: ${OS}/${ARCH}"
print_info "Hauler version: v${HAULER_VERSION}"

# Check if Hauler is already installed
if command -v hauler >/dev/null 2>&1; then
    INSTALLED_VERSION=$(hauler version 2>/dev/null | grep -oP 'v\K[0-9.]+' || echo "unknown")
    print_success "Hauler already installed: v${INSTALLED_VERSION}"
    
    if [ "$INSTALLED_VERSION" = "$HAULER_VERSION" ]; then
        print_info "Version matches, skipping installation"
        exit 0
    else
        print_warning "Installed version differs from target version"
        read -p "Reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
fi

# Download Hauler
print_info "Downloading Hauler from: $HAULER_URL"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

if command -v curl >/dev/null 2>&1; then
    curl -L -o hauler.tar.gz "$HAULER_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O hauler.tar.gz "$HAULER_URL"
else
    print_error "Neither curl nor wget found"
    exit 1
fi

# Extract and install
print_info "Extracting Hauler..."
tar -xzf hauler.tar.gz

print_info "Installing Hauler to /usr/local/bin..."
sudo install -m 755 hauler /usr/local/bin/hauler

# Cleanup
cd - >/dev/null
rm -rf "$TEMP_DIR"

# Verify installation
if command -v hauler >/dev/null 2>&1; then
    print_success "Hauler installed successfully: $(hauler version)"
else
    print_error "Hauler installation failed"
    exit 1
fi

print_header "Hauler Ready"
echo ""
print_info "Next steps:"
echo "  1. Sync artifacts:  hauler store sync --files hauler-manifest.yaml"
echo "  2. Save store:      hauler store save --filename ess-hauler-store.tar.zst"
echo "  3. Copy to airgap:  cp ess-hauler-store.tar.zst /path/to/usb/"
echo "  4. Load on target:  hauler store load ess-hauler-store.tar.zst"
echo "  5. Serve content:   hauler store serve registry"
echo ""

#!/bin/bash
# ESS Community Demo - Installer Download Script
# Downloads all required software for offline installation
# Supports: macOS (Intel/Apple Silicon), Linux (x86_64/arm64), and Windows
# Can download for all platforms or just the current platform

set -euo pipefail

# Download mode
DOWNLOAD_ALL_PLATFORMS=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="${SCRIPT_DIR}/installers"

# Version definitions
KIND_VERSION="v0.20.0"
KUBECTL_VERSION="v1.28.4"
HELM_VERSION="v3.13.2"
K9S_VERSION="v0.29.1"
MKCERT_VERSION="v1.4.4"
DOCKER_VERSION="latest"
ZSTD_VERSION="1.5.6"

# Function to print colored messages
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

# Detect OS and Architecture
detect_platform() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"
    
    case "$OS" in
        darwin*)
            OS="macos"
            if [ "$ARCH" = "arm64" ]; then
                ARCH="arm64"
                DOCKER_ARCH="arm64"
            else
                ARCH="x86_64"
                DOCKER_ARCH="amd64"
            fi
            ;;
        linux*)
            OS="linux"
            if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
                ARCH="arm64"
                DOCKER_ARCH="arm64"
            else
                ARCH="x86_64"
                DOCKER_ARCH="amd64"
            fi
            ;;
        *)
            print_error "Unsupported OS: $OS"
            print_info "Please use download-installers.ps1 for Windows"
            exit 1
            ;;
    esac
    
    print_info "Detected platform: ${OS}/${ARCH}"
}

# Download file with progress
download_file() {
    local url="$1"
    local output="$2"
    
    print_info "Downloading: $(basename "$output")"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget --show-progress -O "$output" "$url"
    else
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    print_success "Downloaded: $(basename "$output")"
}

# Download Docker
download_docker() {
    print_header "Downloading Docker"
    
    local DOCKER_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$DOCKER_DIR"
    
    if [ "$OS" = "macos" ]; then
        # Docker Desktop for macOS
        print_info "Docker Desktop for macOS"
        print_warning "Downloading Docker Desktop (this is a large file, ~600MB)"
        
        if [ "$ARCH" = "arm64" ]; then
            download_file \
                "https://desktop.docker.com/mac/main/arm64/Docker.dmg" \
                "${DOCKER_DIR}/Docker.dmg"
        else
            download_file \
                "https://desktop.docker.com/mac/main/amd64/Docker.dmg" \
                "${DOCKER_DIR}/Docker.dmg"
        fi
    else
        # Docker Engine for Linux
        print_info "Docker Engine for Linux"
        print_warning "Downloading Docker binaries (this may take a while)"
        
        local DOCKER_VERSION_TAG="24.0.7"
        
        if [ "$ARCH" = "arm64" ]; then
            download_file \
                "https://download.docker.com/linux/static/stable/aarch64/docker-${DOCKER_VERSION_TAG}.tgz" \
                "${DOCKER_DIR}/docker.tgz"
        else
            download_file \
                "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION_TAG}.tgz" \
                "${DOCKER_DIR}/docker.tgz"
        fi
    fi
}

# Download Kind
download_kind() {
    print_header "Downloading Kind"
    
    local KIND_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$KIND_DIR"
    
    local KIND_URL="https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-${OS}-${DOCKER_ARCH}"
    download_file "$KIND_URL" "${KIND_DIR}/kind-${OS}-${DOCKER_ARCH}"
    chmod +x "${KIND_DIR}/kind-${OS}-${DOCKER_ARCH}"
}

# Download kubectl
download_kubectl() {
    print_header "Downloading kubectl"
    
    local KUBECTL_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$KUBECTL_DIR"
    
    local KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${DOCKER_ARCH}/kubectl"
    download_file "$KUBECTL_URL" "${KUBECTL_DIR}/kubectl"
    chmod +x "${KUBECTL_DIR}/kubectl"
}

# Download Helm
download_helm() {
    print_header "Downloading Helm"
    
    local HELM_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$HELM_DIR"
    
    local HELM_URL="https://get.helm.sh/helm-${HELM_VERSION}-${OS}-${DOCKER_ARCH}.tar.gz"
    download_file "$HELM_URL" "${HELM_DIR}/helm-${OS}-${DOCKER_ARCH}.tar.gz"
}

# Download k9s
download_k9s() {
    print_header "Downloading k9s"
    
    local K9S_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$K9S_DIR"
    
    # k9s uses different arch naming
    local K9S_ARCH="$ARCH"
    if [ "$OS" = "macos" ]; then
        if [ "$ARCH" = "arm64" ]; then
            K9S_ARCH="arm64"
        else
            K9S_ARCH="x86_64"
        fi
    else
        if [ "$ARCH" = "arm64" ]; then
            K9S_ARCH="arm64"
        else
            K9S_ARCH="x86_64"
        fi
    fi
    
    # k9s uses "Darwin" for macOS
    local K9S_OS="$OS"
    if [ "$OS" = "macos" ]; then
        K9S_OS="Darwin"
    else
        K9S_OS="Linux"
    fi
    
    local K9S_URL="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${K9S_OS}_${K9S_ARCH}.tar.gz"
    download_file "$K9S_URL" "${K9S_DIR}/k9s_${OS}_${ARCH}.tar.gz"
}

# Download mkcert
download_mkcert() {
    print_header "Downloading mkcert"
    
    local MKCERT_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$MKCERT_DIR"
    
    # mkcert uses different naming
    local MKCERT_OS="$OS"
    local MKCERT_ARCH="$DOCKER_ARCH"
    
    if [ "$OS" = "macos" ]; then
        MKCERT_OS="darwin"
    fi
    
    local MKCERT_URL="https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-${MKCERT_OS}-${MKCERT_ARCH}"
    download_file "$MKCERT_URL" "${MKCERT_DIR}/mkcert-${OS}-${DOCKER_ARCH}"
    chmod +x "${MKCERT_DIR}/mkcert-${OS}-${DOCKER_ARCH}"
}

download_zstd() {
    print_header "Downloading zstd"
    
    local ZSTD_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$ZSTD_DIR"
    
    local ZSTD_FILE=""
    local ZSTD_URL=""
    
    if [ "$OS" = "windows" ]; then
        ZSTD_FILE="zstd-v${ZSTD_VERSION}-win64.zip"
        ZSTD_URL="https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/${ZSTD_FILE}"
    elif [ "$OS" = "macos" ]; then
        ZSTD_FILE="zstd-${ZSTD_VERSION}-macos-${DOCKER_ARCH}.tar.gz"
        ZSTD_URL="https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/${ZSTD_FILE}"
    else
        # Linux
        ZSTD_FILE="zstd-${ZSTD_VERSION}-linux-${DOCKER_ARCH}.tar.gz"
        ZSTD_URL="https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/${ZSTD_FILE}"
    fi
    
    download_file "$ZSTD_URL" "${ZSTD_DIR}/${ZSTD_FILE}"
}

# Download for specific platform
download_for_platform() {
    local target_os="$1"
    local target_arch="$2"
    local target_docker_arch="$3"
    
    print_info "Downloading for ${target_os}/${target_arch}..."
    
    # Set global variables for this download
    OS="$target_os"
    ARCH="$target_arch"
    DOCKER_ARCH="$target_docker_arch"
    
    download_docker
    download_kind
    download_kubectl
    download_helm
    download_k9s
    download_mkcert
    download_zstd
}

# Download for all platforms
download_all_platforms() {
    print_header "Downloading for All Platforms"
    
    print_warning "This will download installers for:"
    echo "  • macOS (Intel x86_64 and Apple Silicon arm64)"
    echo "  • Linux (x86_64 and arm64)"
    echo "  • Windows (x86_64)"
    echo ""
    print_warning "Total download size: approximately 3-4GB"
    echo ""
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        exit 0
    fi
    
    # macOS Intel
    download_for_platform "macos" "x86_64" "amd64"
    
    # macOS Apple Silicon
    download_for_platform "macos" "arm64" "arm64"
    
    # Linux x86_64
    download_for_platform "linux" "x86_64" "amd64"
    
    # Linux ARM64
    download_for_platform "linux" "arm64" "arm64"
    
    # Windows
    # Download Windows installers
    print_info "Downloading for Windows/amd64..."
    local WIN_DIR="${INSTALLERS_DIR}/windows"
    mkdir -p "$WIN_DIR"
    
    # Docker Desktop for Windows
    download_file \
        "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" \
        "${WIN_DIR}/Docker Desktop Installer.exe"
    
    # Kind for Windows
    download_file \
        "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-windows-amd64" \
        "${WIN_DIR}/kind-windows-amd64.exe"
    
    # kubectl for Windows
    download_file \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/windows/amd64/kubectl.exe" \
        "${WIN_DIR}/kubectl.exe"
    
    # Helm for Windows
    download_file \
        "https://get.helm.sh/helm-${HELM_VERSION}-windows-amd64.zip" \
        "${WIN_DIR}/helm-windows-amd64.zip"
    
    # k9s for Windows
    download_file \
        "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Windows_amd64.zip" \
        "${WIN_DIR}/k9s_windows_amd64.zip"
    
    # mkcert for Windows
    download_file \
        "https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-windows-amd64.exe" \
        "${WIN_DIR}/mkcert-windows-amd64.exe"
    
    print_header "All Platforms Download Complete!"
    print_success "Installers for all platforms downloaded to: ${INSTALLERS_DIR}/"
    echo ""
    print_info "Directory structure:"
    echo "  installers/macos/    - macOS installers (Intel + Apple Silicon)"
    echo "  installers/linux/    - Linux installers (x86_64 + ARM64)"
    echo "  installers/windows/  - Windows installers"
}

# Main execution
main() {
    print_header "ESS Community Demo - Installer Downloader"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all|-a)
                DOWNLOAD_ALL_PLATFORMS=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --all, -a     Download installers for all platforms (macOS, Linux, Windows)"
                echo "  --help, -h    Show this help message"
                echo ""
                echo "Without --all flag, downloads only for the current platform."
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    if [ "$DOWNLOAD_ALL_PLATFORMS" = true ]; then
        download_all_platforms
    else
        detect_platform
        
        print_info "This script will download the following software:"
        echo "  • Docker Desktop/Engine"
        echo "  • Kind ${KIND_VERSION}"
        echo "  • kubectl ${KUBECTL_VERSION}"
        echo "  • Helm ${HELM_VERSION}"
        echo "  • k9s ${K9S_VERSION}"
        echo "  • mkcert ${MKCERT_VERSION}"
        echo ""
        print_warning "Total download size: approximately 700MB - 1GB"
        echo ""
        print_info "Platform: ${OS}/${ARCH}"
        echo ""
        print_info "Tip: Use --all to download for all platforms (macOS, Linux, Windows)"
        echo ""
        
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            exit 0
        fi
        
        # Download all components
        download_docker
        download_kind
        download_kubectl
        download_helm
        download_k9s
        download_mkcert
        
        print_header "Download Complete!"
        print_success "All installers downloaded to: ${INSTALLERS_DIR}/${OS}"
        print_info "You can now run ./setup.sh to install and configure the demo"
    fi
}

# Run main function
main "$@"

#!/bin/bash
# ESS Community Demo - Installer Download Script
# Downloads all required software for offline installation
# Supports: macOS (Intel/Apple Silicon), Linux (x86_64/arm64), and Windows
# Can download for all platforms or just the current platform
# Idempotent: Skips downloads if checksums match remote versions
# Strategy: K3s/Rancher Desktop as primary, Kind only if Docker/Podman already installed

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/checksum-utils.sh"
source "${SCRIPT_DIR}/version-utils.sh"

# Download mode
DOWNLOAD_ALL_PLATFORMS=false
FORCE_DOWNLOAD=false
SKIP_CONFIRMATION=true  # Default to skip confirmation
USE_LATEST_VERSIONS=true  # Get latest versions dynamically by default

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="$(dirname "$SCRIPT_DIR")/installers"

# Version definitions - Can be overridden by --use-static-versions flag
# These are fallback versions for airgapped builds
if [ "$USE_LATEST_VERSIONS" = true ]; then
    K3S_VERSION="${K3S_VERSION:-$(get_latest_k3s_version || echo 'v1.31.3+k3s1')}"
    RANCHER_DESKTOP_VERSION="${RANCHER_DESKTOP_VERSION:-$(get_latest_rancher_desktop_version || echo 'v1.16.0')}"
    KUBECTL_VERSION="${KUBECTL_VERSION:-$(get_latest_kubectl_version || echo 'v1.31.3')}"
    HELM_VERSION="${HELM_VERSION:-$(get_latest_helm_version || echo 'v3.16.3')}"
    K9S_VERSION="${K9S_VERSION:-$(get_latest_k9s_version || echo 'v0.32.7')}"
    MKCERT_VERSION="${MKCERT_VERSION:-$(get_latest_mkcert_version || echo 'v1.4.4')}"
    ANSIBLE_VERSION="${ANSIBLE_VERSION:-$(get_latest_ansible_version || echo '11.1.0')}"
    ZSTD_VERSION="${ZSTD_VERSION:-$(get_latest_zstd_version || echo 'v1.5.6')}"
    HAULER_VERSION="${HAULER_VERSION:-$(get_latest_hauler_version || echo 'v1.1.1')}"
else
    # Static versions for airgapped/reproducible builds
    K3S_VERSION="v1.31.3+k3s1"
    RANCHER_DESKTOP_VERSION="v1.16.0"
    KUBECTL_VERSION="v1.31.3"
    HELM_VERSION="v3.16.3"
    K9S_VERSION="v0.32.7"
    MKCERT_VERSION="v1.4.4"
    ANSIBLE_VERSION="11.1.0"
    ZSTD_VERSION="v1.5.6"
    HAULER_VERSION="v1.1.1"
fi

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

# Check if aria2c is available
has_aria2() {
    command -v aria2c >/dev/null 2>&1
}

# Note: calculate_checksum() is now sourced from checksum-utils.sh

# Get remote checksum from various sources
get_remote_checksum() {
    local url="$1"
    local filename="$2"
    local explicit_checksum_url="${3:-}"  # Optional explicit checksum URL
    local checksum=""
    
    # Extract the actual remote filename from the URL (for matching in checksum files)
    local remote_filename=$(basename "$url")
    
    # If explicit checksum URL provided, try it first
    if [ -n "$explicit_checksum_url" ]; then
        if command -v curl >/dev/null 2>&1; then
            checksum=$(curl -L --fail --silent "$explicit_checksum_url" 2>/dev/null || echo "")
        elif command -v wget >/dev/null 2>&1; then
            checksum=$(wget -qO- "$explicit_checksum_url" 2>/dev/null || echo "")
        fi
        
        if [ -n "$checksum" ]; then
            # If file contains only the checksum (64 hex chars), use it directly
            if [[ "$checksum" =~ ^[a-f0-9]{64}$ ]]; then
                echo "$checksum"
                return 0
            fi
            
            # Try to extract checksum using the remote filename first (most accurate)
            local extracted=$(echo "$checksum" | grep -i "$(basename "$remote_filename")" | head -1 | awk '{print $1}')
            if [ -n "$extracted" ] && [[ "$extracted" =~ ^[a-f0-9]{64}$ ]]; then
                echo "$extracted"
                return 0
            fi
            
            # Fall back to local filename pattern
            extracted=$(echo "$checksum" | grep -i "$(basename "$filename")" | head -1 | awk '{print $1}')
            if [ -n "$extracted" ] && [[ "$extracted" =~ ^[a-f0-9]{64}$ ]]; then
                echo "$extracted"
                return 0
            fi
            
            # Pattern 2: Just the first 64 hex chars if no filename match
            extracted=$(echo "$checksum" | head -1 | grep -oE '^[a-f0-9]{64}')
            if [ -n "$extracted" ]; then
                echo "$extracted"
                return 0
            fi
        fi
    fi
    
    # Try different checksum file patterns
    # GitHub releases typically have .sha256sum or .sha256 files
    local checksum_urls=(
        "${url}.sha256sum"
        "${url}.sha256"
        "$(dirname "$url")/SHA256SUMS"
        "$(dirname "$url")/checksums.txt"
        "$(dirname "$url")/$(basename "$url").sha256"
    )
    
    for checksum_url in "${checksum_urls[@]}"; do
        if command -v curl >/dev/null 2>&1; then
            checksum=$(curl -L --fail --silent "$checksum_url" 2>/dev/null || echo "")
        elif command -v wget >/dev/null 2>&1; then
            checksum=$(wget -qO- "$checksum_url" 2>/dev/null || echo "")
        fi
        
        if [ -n "$checksum" ]; then
            # If file contains only the checksum (64 hex chars), use it directly
            if [[ "$checksum" =~ ^[a-f0-9]{64}$ ]]; then
                echo "$checksum"
                return 0
            fi
            
            # Try to extract checksum using the remote filename first (most accurate)
            local extracted=$(echo "$checksum" | grep -i "$(basename "$remote_filename")" | head -1 | awk '{print $1}')
            if [ -n "$extracted" ] && [[ "$extracted" =~ ^[a-f0-9]{64}$ ]]; then
                echo "$extracted"
                return 0
            fi
            
            # Fall back to local filename pattern
            extracted=$(echo "$checksum" | grep -i "$(basename "$filename")" | head -1 | awk '{print $1}')
            if [ -n "$extracted" ] && [[ "$extracted" =~ ^[a-f0-9]{64}$ ]]; then
                echo "$extracted"
                return 0
            fi
            
            # Pattern 2: Just the first 64 hex chars if no filename match
            extracted=$(echo "$checksum" | head -1 | grep -oE '^[a-f0-9]{64}')
            if [ -n "$extracted" ]; then
                echo "$extracted"
                return 0
            fi
        fi
    done
    
    echo ""
}

# Check if file needs download
needs_download() {
    local url="$1"
    local output="$2"
    local explicit_checksum_url="${3:-}"  # Optional explicit checksum URL
    
    # Force download if requested
    if [ "$FORCE_DOWNLOAD" = true ]; then
        return 0
    fi
    
    # Download if file doesn't exist
    if [ ! -f "$output" ]; then
        return 0
    fi
    
    # Get remote checksum
    local remote_checksum=$(get_remote_checksum "$url" "$(basename "$output")" "$explicit_checksum_url")
    
    if [ -z "$remote_checksum" ]; then
        print_warning "No remote checksum available for $(basename "$output")"
        print_info "File exists locally, skipping download"
        return 1
    fi
    
    # Calculate local checksum
    local local_checksum=$(calculate_checksum "$output")
    
    if [ -z "$local_checksum" ]; then
        print_warning "Cannot calculate local checksum for $(basename "$output")"
        return 0
    fi
    
    # Compare checksums
    if [ "$local_checksum" = "$remote_checksum" ]; then
        print_success "$(basename "$output") is up to date (checksum matches)"
        return 1
    else
        print_info "$(basename "$output") checksum differs, will re-download"
        return 0
    fi
}

# Download file with progress and resume support
download_file() {
    local url="$1"
    local output="$2"
    local explicit_checksum_url="${3:-}"  # Optional explicit checksum URL
    
    # Check if download is needed
    if ! needs_download "$url" "$output" "$explicit_checksum_url"; then
        return 0
    fi
    
    print_info "Downloading: $(basename "$output")"
    
    # Use aria2c if available (supports resume)
    if has_aria2; then
        # Try download with resume
        if ! aria2c -c -x 16 -s 16 -k 1M \
            --allow-overwrite=true \
            --auto-file-renaming=false \
            -d "$(dirname "$output")" \
            -o "$(basename "$output")" \
            "$url" 2>&1; then
            
            # If download failed (e.g., size mismatch), remove partial file and retry
            print_warning "Download failed, removing partial file and retrying..."
            rm -f "$output" "${output}.aria2"
            
            aria2c -x 16 -s 16 -k 1M \
                --allow-overwrite=true \
                --auto-file-renaming=false \
                -d "$(dirname "$output")" \
                -o "$(basename "$output")" \
                "$url"
        fi
        print_success "Downloaded: $(basename "$output")"
    elif command -v curl >/dev/null 2>&1; then
        # curl with resume support
        curl -L -C - --progress-bar "$url" -o "$output"
        print_success "Downloaded: $(basename "$output")"
    elif command -v wget >/dev/null 2>&1; then
        # wget with resume support
        wget -c --show-progress -O "$output" "$url"
        print_success "Downloaded: $(basename "$output")"
    else
        print_error "No download tool found. Please install aria2c, curl, or wget."
        exit 1
    fi
    
    # Save checksum for future verification
    local checksum=$(calculate_checksum "$output")
    if [ -n "$checksum" ]; then
        echo "$checksum  $(basename "$output")" > "${output}.sha256"
    fi
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

# Download K3s
download_k3s() {
    print_header "Downloading K3s"
    
    local K3S_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$K3S_DIR"
    
    if [ "$OS" = "macos" ]; then
        print_info "K3s is not officially supported on macOS - use Rancher Desktop instead"
        return 0
    elif [ "$OS" = "linux" ]; then
        print_info "K3s ${K3S_VERSION} for Linux"
        
        local K3S_ARCH="${ARCH}"
        if [ "$ARCH" = "x86_64" ]; then
            K3S_ARCH="amd64"
        fi
        
        local K3S_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s"
        if [ "$K3S_ARCH" = "arm64" ]; then
            K3S_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-arm64"
        fi
        
        local CHECKSUM_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/sha256sum-${K3S_ARCH}.txt"
        
        download_file "$K3S_URL" "${K3S_DIR}/k3s-${K3S_ARCH}" "$CHECKSUM_URL"
        chmod +x "${K3S_DIR}/k3s-${K3S_ARCH}"
    fi
}

# Download Rancher Desktop
download_rancher_desktop() {
    print_header "Downloading Rancher Desktop"
    
    local RD_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$RD_DIR"
    
    # Remove 'v' prefix from version for download URLs
    local VERSION_NUM="${RANCHER_DESKTOP_VERSION#v}"
    
    if [ "$OS" = "macos" ]; then
        print_info "Rancher Desktop ${RANCHER_DESKTOP_VERSION} for macOS"
        print_warning "Downloading Rancher Desktop (this is a large file, ~600MB)"
        
        local RD_ARCH="${DOCKER_ARCH}"
        if [ "$RD_ARCH" = "amd64" ]; then
            RD_ARCH="x86_64"
        fi
        
        local RD_URL="https://github.com/rancher-sandbox/rancher-desktop/releases/download/${RANCHER_DESKTOP_VERSION}/Rancher.Desktop-${VERSION_NUM}.${RD_ARCH}.dmg"
        
        download_file "$RD_URL" "${RD_DIR}/Rancher.Desktop-${VERSION_NUM}.${RD_ARCH}.dmg"
    elif [ "$OS" = "linux" ]; then
        print_info "Rancher Desktop is typically installed via package manager on Linux"
        print_info "Downloading AppImage for portable use"
        
        # Rancher Desktop provides AppImage for Linux
        local RD_URL="https://github.com/rancher-sandbox/rancher-desktop/releases/download/${RANCHER_DESKTOP_VERSION}/Rancher.Desktop-${VERSION_NUM}.x86_64.AppImage"
        
        download_file "$RD_URL" "${RD_DIR}/Rancher.Desktop-${VERSION_NUM}.x86_64.AppImage"
        chmod +x "${RD_DIR}/Rancher.Desktop-${VERSION_NUM}.x86_64.AppImage"
    fi
}

## Podman support removed for k3s-only flow.
## If Podman needs to be reintroduced later, add a download_podman() function here.

# Download Ansible
download_ansible() {
    print_header "Downloading Ansible"
    
    local ANSIBLE_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$ANSIBLE_DIR"
    
    print_info "Ansible ${ANSIBLE_VERSION}"
    print_info "Downloading Python wheel for offline installation"
    
    # Download Ansible and its dependencies using pip download
    # This creates a portable package that can be installed offline
    local ANSIBLE_PKG_DIR="${ANSIBLE_DIR}/ansible-packages"
    mkdir -p "$ANSIBLE_PKG_DIR"
    
    if command -v pip3 >/dev/null 2>&1; then
        print_info "Downloading Ansible ${ANSIBLE_VERSION} and dependencies..."
        pip3 download -d "$ANSIBLE_PKG_DIR" "ansible==${ANSIBLE_VERSION}" || {
            print_warning "Failed to download Ansible packages"
            print_info "Ansible will need to be installed from package manager"
        }
    else
        print_warning "pip3 not found, skipping Ansible package download"
        print_info "Ansible will need to be installed from package manager"
    fi
}

# Download Kind
# Download kubectl
download_kubectl() {
    print_header "Downloading kubectl"
    
    local KUBECTL_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$KUBECTL_DIR"
    
    # kubectl uses 'darwin' instead of 'macos' in its release URLs
    local KUBECTL_OS="${OS}"
    if [ "$OS" = "macos" ]; then
        KUBECTL_OS="darwin"
    fi
    
    local KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${KUBECTL_OS}/${DOCKER_ARCH}/kubectl"
    local CHECKSUM_URL="${KUBECTL_URL}.sha256"
    
    download_file "$KUBECTL_URL" "${KUBECTL_DIR}/kubectl" "$CHECKSUM_URL"
    chmod +x "${KUBECTL_DIR}/kubectl"
}

# Download Helm
download_helm() {
    print_header "Downloading Helm"
    
    local HELM_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$HELM_DIR"
    
    # Helm uses 'darwin' instead of 'macos' in its release URLs
    local HELM_OS="${OS}"
    if [ "$OS" = "macos" ]; then
        HELM_OS="darwin"
    fi
    
    local HELM_URL="https://get.helm.sh/helm-${HELM_VERSION}-${HELM_OS}-${DOCKER_ARCH}.tar.gz"
    local CHECKSUM_URL="https://get.helm.sh/helm-${HELM_VERSION}-${HELM_OS}-${DOCKER_ARCH}.tar.gz.sha256sum"
    download_file "$HELM_URL" "${HELM_DIR}/helm-${OS}-${DOCKER_ARCH}.tar.gz" "$CHECKSUM_URL"
}

# Download k9s
download_k9s() {
    print_header "Downloading k9s"
    
    local K9S_DIR="${INSTALLERS_DIR}/${OS}"
    mkdir -p "$K9S_DIR"
    
    # k9s uses 'amd64' instead of 'x86_64' and Darwin/Linux instead of macos/linux
    local K9S_ARCH="$ARCH"
    if [ "$ARCH" = "x86_64" ]; then
        K9S_ARCH="amd64"
    fi
    # arm64 stays as arm64
    
    # k9s uses "Darwin" for macOS and "Linux" for linux
    local K9S_OS="$OS"
    if [ "$OS" = "macos" ]; then
        K9S_OS="Darwin"
    else
        K9S_OS="Linux"
    fi
    
    local K9S_URL="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${K9S_OS}_${K9S_ARCH}.tar.gz"
    local CHECKSUM_URL="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/checksums.sha256"
    
    # Use the same naming as the remote file to avoid checksum verification issues
    download_file "$K9S_URL" "${K9S_DIR}/k9s_${K9S_OS}_${K9S_ARCH}.tar.gz" "$CHECKSUM_URL"
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
    local CHECKSUM_URL=""
    
    if [ "$OS" = "windows" ]; then
        # Windows: Use official GitHub release binary
        ZSTD_FILE="zstd-v${ZSTD_VERSION}-win64.zip"
        ZSTD_URL="https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/${ZSTD_FILE}"
        # Windows binaries don't have checksums
    else
        # For Linux and macOS: Download source tarball with checksum
        # Users can build locally or use package managers (brew, apt, etc.)
        ZSTD_FILE="zstd-${ZSTD_VERSION}.tar.gz"
        ZSTD_URL="https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/${ZSTD_FILE}"
        CHECKSUM_URL="${ZSTD_URL}.sha256"
    fi
    
    download_file "$ZSTD_URL" "${ZSTD_DIR}/${ZSTD_FILE}" "$CHECKSUM_URL"
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
    
    # Download K3s (Linux only) or Rancher Desktop (macOS)
    if [ "$target_os" = "linux" ]; then
        download_k3s
    elif [ "$target_os" = "macos" ]; then
        download_rancher_desktop
    fi
    
    # Podman is not part of the k3s-only flow (removed)
    
    # Download common tools
    download_kubectl
    download_helm
    download_k9s
    download_mkcert
    download_zstd
    
    # Download Ansible for automation
    download_ansible
}

# Download for all platforms
download_all_platforms() {
    print_header "Downloading for All Platforms"
    
    print_warning "This will download installers for:"
    echo "  • macOS (Apple Silicon arm64)"
    echo "  • Linux (x86_64 and arm64)"
    echo "  • Windows (x86_64)"
    echo ""
    print_info "Installers include:"
    echo "  • K3s (Linux only)"
    echo "  • Rancher Desktop (macOS/Windows)"
    echo "  • (Podman support removed; runtime is k3s)"
    echo "  • kubectl, Helm, k9s, mkcert, zstd"
    echo "  • Ansible (all platforms)"
    echo ""
    print_warning "Total download size: approximately 3-4GB"
    echo ""
    
    if [ "$SKIP_CONFIRMATION" = false ]; then
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            exit 0
        fi
    fi
    
    # macOS Apple Silicon (arm64)
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
    
    # Rancher Desktop for Windows
    local VERSION_NUM="${RANCHER_DESKTOP_VERSION#v}"
    download_file \
        "https://github.com/rancher-sandbox/rancher-desktop/releases/download/${RANCHER_DESKTOP_VERSION}/Rancher.Desktop.Setup.${VERSION_NUM}.msi" \
        "${WIN_DIR}/Rancher.Desktop.Setup.${VERSION_NUM}.msi"
    
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
    
    # Ansible for Windows (via Python pip)
    local ANSIBLE_PKG_DIR="${WIN_DIR}/ansible-packages"
    mkdir -p "$ANSIBLE_PKG_DIR"
    if command -v pip3 >/dev/null 2>&1; then
        print_info "Downloading Ansible ${ANSIBLE_VERSION} for Windows..."
        pip3 download -d "$ANSIBLE_PKG_DIR" "ansible==${ANSIBLE_VERSION}" || {
            print_warning "Failed to download Ansible packages for Windows"
        }
    fi
    
    print_header "All Platforms Download Complete!"
    print_success "Installers for all platforms downloaded to: ${INSTALLERS_DIR}/"
    echo ""
    print_info "Directory structure:"
    echo "  installers/macos/    - macOS installers (Apple Silicon only)"
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
            --force|-f)
                FORCE_DOWNLOAD=true
                print_warning "Force download enabled - all files will be re-downloaded"
                shift
                ;;
            -y|--yes)
                SKIP_CONFIRMATION=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --all, -a     Download installers for all platforms (macOS, Linux, Windows)"
                echo "  --force, -f   Force re-download even if files exist and checksums match"
                echo "  -y, --yes     Skip confirmation prompt"
                echo "  --help, -h    Show this help message"
                echo ""
                echo "Without --all flag, downloads only for the current platform."
                echo "By default, skips downloads if local checksums match remote versions."
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
        if [ "$OS" = "linux" ]; then
            echo "  • K3s ${K3S_VERSION}"
        elif [ "$OS" = "macos" ]; then
            echo "  • Rancher Desktop ${RANCHER_DESKTOP_VERSION}"
        fi
    echo "  • (Podman support removed; runtime is k3s)"
        echo "  • kubectl ${KUBECTL_VERSION}"
        echo "  • Helm ${HELM_VERSION}"
        echo "  • k9s ${K9S_VERSION}"
        echo "  • mkcert ${MKCERT_VERSION}"
        echo "  • zstd ${ZSTD_VERSION}"
        echo "  • Ansible ${ANSIBLE_VERSION}"
        echo ""
        print_warning "Total download size: approximately 700MB - 1GB"
        echo ""
        print_info "Platform: ${OS}/${ARCH}"
        echo ""
        print_info "Tip: Use --all to download for all platforms (macOS, Linux, Windows)"
        echo ""
        
        if [ "$SKIP_CONFIRMATION" = false ]; then
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Cancelled"
                exit 0
            fi
        fi
        
        # Download all components
        if [ "$OS" = "linux" ]; then
            download_k3s
        elif [ "$OS" = "macos" ]; then
            download_rancher_desktop
        fi
    # Podman removed from k3s-only flow
    download_kubectl
        download_helm
        download_k9s
        download_mkcert
        download_zstd
        download_ansible
        
        print_header "Download Complete!"
        print_success "All installers downloaded to: ${INSTALLERS_DIR}/${OS}"
        print_info "You can now run Ansible playbooks to install and configure the demo"
    fi
}

# Run main function
main "$@"

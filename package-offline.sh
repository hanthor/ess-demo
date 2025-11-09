#!/bin/bash
# ESS Community Demo - Offline Package Builder
# Creates platform-specific tarballs for offline deployment

set -uo pipefail

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
OUTPUT_DIR="${SCRIPT_DIR}/packages"

# Use zstd for compression (much faster and better compression than gzip)
COMPRESS_CMD="zstd"
COMPRESS_EXT="zst"
COMPRESS_ARGS="-19 --threads=0"  # Maximum compression, use all CPU cores

# Package version (from git tag or date)
VERSION=$(git describe --tags 2>/dev/null || date +%Y%m%d)

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

# Create installer script for a package
create_installer_script() {
    local package_name="$1"
    local platform="$2"
    local installer_name="${package_name%.tar.gz}-install.sh"
    local installer_path="${OUTPUT_DIR}/${installer_name}"
    local checksum_file="${package_name}.sha256"
    
    print_info "Creating installer script: ${installer_name}"
    
    # Check if template exists
    if [ ! -f "${SCRIPT_DIR}/install-template.sh" ]; then
        print_warning "Installer template not found, skipping"
        return 0
    fi
    
    # Create installer by replacing placeholders in template
    sed -e "s|__PACKAGE_FILE__|${package_name}|g" \
        -e "s|__CHECKSUM_FILE__|${checksum_file}|g" \
        -e "s|__PLATFORM__|${platform}|g" \
        "${SCRIPT_DIR}/install-template.sh" > "$installer_path"
    
    # Make it executable
    chmod +x "$installer_path"
    
    print_success "Installer script created: ${installer_name}"
    print_info "Usage: ./${installer_name}"
}

# Create README for packages directory
create_packages_readme() {
    local readme_path="${OUTPUT_DIR}/README.txt"
    
    # Only create if it doesn't exist or if we're creating the first package
    if [ -f "$readme_path" ]; then
        return 0
    fi
    
    cat > "$readme_path" <<'EOF'
ESS Community Demo - Offline Distribution Packages
===================================================

This directory contains offline installation packages for the ESS Community Demo.

QUICK START
-----------

1. Copy this entire 'packages' folder to a USB drive or transfer to target machine
2. On the target machine, run the installer script for your platform:

   Linux:
   chmod +x ess-demo-linux-*-install.sh
   ./ess-demo-linux-*-install.sh

   macOS:
   chmod +x ess-demo-macos-*-install.sh
   ./ess-demo-macos-*-install.sh

   Windows (Git Bash/WSL):
   chmod +x ess-demo-windows-*-install.sh
   ./ess-demo-windows-*-install.sh

   Universal (all platforms):
   chmod +x ess-demo-universal-*-install.sh
   ./ess-demo-universal-*-install.sh

3. The installer will:
   ✓ Verify package integrity (SHA256 checksum)
   ✓ Install zstd if needed (bundled for offline use)
   ✓ Extract the package
   ✓ Run offline verification
   ✓ Offer to start setup immediately

NOTE: Packages use zstd compression for better speed and compression ratio.
      The installer script will automatically install zstd from the bundled binary.

MANUAL INSTALLATION
-------------------

If you prefer to extract manually:

1. Verify checksum:
   sha256sum -c ess-demo-*.tar.gz.sha256

2. Extract package:
   tar -xzf ess-demo-*.tar.gz

3. Run setup:
   cd ess-demo
   ./setup.sh          # Linux/macOS
   .\setup.ps1         # Windows PowerShell

PACKAGE CONTENTS
----------------

Each package includes:
- Docker, Kind, kubectl, Helm, k9s, mkcert installers
- All container images (pre-cached for offline use)
- Setup and cleanup scripts
- ESS Helm chart configuration
- TLS certificates setup
- Complete documentation

REQUIREMENTS
------------

- Docker must be installed and running
- Minimum 8GB RAM, 20GB disk space
- Administrator/sudo access for software installation

NO INTERNET CONNECTION REQUIRED
--------------------------------

These packages are designed for complete offline/air-gapped deployment.
All dependencies are included.

For more information, see the documentation inside the extracted package.
EOF

    print_success "Created packages/README.txt"
}

# Create a package for a specific platform
create_package() {
    local platform="$1"
    local package_name="ess-demo-${platform}-${VERSION}.tar.${COMPRESS_EXT}"
    local package_path="${OUTPUT_DIR}/${package_name}"
    
    print_header "Creating ${platform} Package"
    
    # Check if installers exist for this platform
    if [ ! -d "${INSTALLERS_DIR}/${platform}" ]; then
        print_error "Installers not found for ${platform}"
        print_info "Run: ./download-installers.sh --all"
        return 1
    fi
    
    local installer_count=$(find "${INSTALLERS_DIR}/${platform}" -type f | wc -l)
    if [ "$installer_count" -eq 0 ]; then
        print_error "No installer files found for ${platform}"
        return 1
    fi
    
    # Create temporary staging directory in current directory to avoid /tmp quota issues
    local staging_dir="${SCRIPT_DIR}/.package-staging-$$"
    local package_dir="${staging_dir}/ess-demo"
    
    mkdir -p "$package_dir"
    
    print_info "Staging files for ${platform}..."
    
    # Copy platform-specific installers
    print_info "  Copying ${platform} installers..."
    mkdir -p "${package_dir}/installers/${platform}"
    cp -r "${INSTALLERS_DIR}/${platform}"/* "${package_dir}/installers/${platform}/"
    
    # Copy image cache (shared across all platforms)
    if [ -d "$IMAGE_CACHE_DIR" ]; then
        local cache_size=$(du -sh "$IMAGE_CACHE_DIR" | cut -f1)
        print_info "  Copying container image cache (${cache_size})..."
        cp -r "$IMAGE_CACHE_DIR" "${package_dir}/"
    else
        print_warning "  Image cache not found, package will require internet"
    fi
    
    # Copy demo configuration files
    print_info "  Copying configuration files..."
    if [ -d "${SCRIPT_DIR}/demo-values" ]; then
        cp -r "${SCRIPT_DIR}/demo-values" "${package_dir}/"
    fi
    
    if [ -d "${SCRIPT_DIR}/assets" ]; then
        cp -r "${SCRIPT_DIR}/assets" "${package_dir}/"
    fi
    
    # Copy scripts based on platform
    print_info "  Copying setup scripts..."
    case "$platform" in
        windows)
            cp "${SCRIPT_DIR}/setup.ps1" "${package_dir}/"
            cp "${SCRIPT_DIR}/cleanup.ps1" "${package_dir}/"
            cp "${SCRIPT_DIR}/download-installers.ps1" "${package_dir}/"
            cp "${SCRIPT_DIR}/verify.ps1" "${package_dir}/"
            # Also copy bash scripts for WSL users
            cp "${SCRIPT_DIR}/setup.sh" "${package_dir}/"
            cp "${SCRIPT_DIR}/cleanup.sh" "${package_dir}/"
            cp "${SCRIPT_DIR}/build-certs.sh" "${package_dir}/"
            cp "${SCRIPT_DIR}/cache-images.sh" "${package_dir}/"
            cp "${SCRIPT_DIR}/verify-offline.sh" "${package_dir}/"
            ;;
        *)
            # macOS and Linux use bash scripts
            cp "${SCRIPT_DIR}/setup.sh" "${package_dir}/"
            cp "${SCRIPT_DIR}/cleanup.sh" "${package_dir}/"
            cp "${SCRIPT_DIR}/build-certs.sh" "${package_dir}/"
            cp "${SCRIPT_DIR}/download-installers.sh" "${package_dir}/"
            cp "${SCRIPT_DIR}/cache-images.sh" "${package_dir}/"
            cp "${SCRIPT_DIR}/verify.sh" "${package_dir}/"
            cp "${SCRIPT_DIR}/verify-offline.sh" "${package_dir}/"
            ;;
    esac
    
    # Copy load-cached-images script if it exists
    if [ -f "${SCRIPT_DIR}/load-cached-images.sh" ]; then
        cp "${SCRIPT_DIR}/load-cached-images.sh" "${package_dir}/"
    fi
    
    # Copy documentation
    print_info "  Copying documentation..."
    cp "${SCRIPT_DIR}/README.md" "${package_dir}/" 2>/dev/null || true
    cp "${SCRIPT_DIR}/"*.md "${package_dir}/" 2>/dev/null || true
    
    # Create a platform-specific README
    cat > "${package_dir}/README-${platform}.txt" <<EOF
ESS Community Demo - Offline Package for ${platform}
Version: ${VERSION}
Generated: $(date)

This package contains everything needed for offline deployment on ${platform}.

Contents:
- Container image cache (${IMAGE_CACHE_DIR})
- ${platform} installer binaries
- Setup and deployment scripts
- Configuration files
- Documentation

Quick Start:
EOF
    
    case "$platform" in
        windows)
            cat >> "${package_dir}/README-${platform}.txt" <<'EOF'

1. Extract this archive to a folder
2. Run PowerShell as Administrator
3. Navigate to the extracted folder
4. Run: .\setup.ps1

For WSL/Linux users on Windows:
1. Extract this archive
2. Open WSL terminal
3. Navigate to the extracted folder
4. Run: ./setup.sh

Note: Docker Desktop must be installed and running.
EOF
            ;;
        macos)
            cat >> "${package_dir}/README-${platform}.txt" <<'EOF'

1. Extract this archive: tar -xzf ess-demo-macos-*.tar.gz
2. Navigate to the folder: cd ess-demo
3. Run: ./setup.sh

Note: Docker Desktop must be installed and running.
      On Apple Silicon Macs, ensure you have the ARM64 version.
EOF
            ;;
        linux)
            cat >> "${package_dir}/README-${platform}.txt" <<'EOF'

1. Extract this archive: tar -xzf ess-demo-linux-*.tar.gz
2. Navigate to the folder: cd ess-demo
3. Run: ./setup.sh

Note: Docker must be installed and running.
EOF
            ;;
    esac
    
    # Create the tarball with progress indicator
    print_info "Creating tarball with zstd compression (this may take a few minutes)..."
    cd "$staging_dir"
    
    if command -v pv &> /dev/null; then
        # Use pv for progress if available
        tar -cf - ess-demo/ | pv -s $(du -sb ess-demo/ | awk '{print $1}') | $COMPRESS_CMD $COMPRESS_ARGS > "$package_path"
    else
        # Fallback: show verbose tar output with file count
        local total_files=$(find ess-demo/ -type f | wc -l)
        print_info "  Compressing ${total_files} files with zstd..."
        tar -cf - ess-demo/ | $COMPRESS_CMD $COMPRESS_ARGS > "$package_path" &
        local tar_pid=$!
        
        # Show spinner while tar is running
        local spin='-\|/'
        local i=0
        while kill -0 $tar_pid 2>/dev/null; do
            i=$(( (i+1) %4 ))
            printf "\r  ${BLUE}ℹ${NC} Compressing... ${spin:$i:1}"
            sleep 0.1
        done
        wait $tar_pid
        printf "\r  ${BLUE}ℹ${NC} Compressing... Done!     \n"
    fi
    
    cd - > /dev/null
    
    # Cleanup staging
    rm -rf "$staging_dir"
    
    # Show results
    local size=$(du -sh "$package_path" | cut -f1)
    print_success "Package created: ${package_name} (${size})"
    
    # Create checksum
    print_info "Generating checksum..."
    cd "$OUTPUT_DIR"
    sha256sum "$package_name" > "${package_name}.sha256"
    print_success "Checksum: ${package_name}.sha256"
    cd - > /dev/null
    
    # Create installer script
    create_installer_script "$package_name" "$platform"
    
    # Copy zstd binary next to the package for self-contained extraction
    if [ -d "${INSTALLERS_DIR}/${platform}" ]; then
        print_info "Copying zstd binary for self-contained extraction..."
        cp "${INSTALLERS_DIR}/${platform}"/zstd-* "${OUTPUT_DIR}/" 2>/dev/null || true
    fi
    
    # Create packages README (only once)
    create_packages_readme
    
    return 0
}

# Create all-in-one package with all platforms
create_universal_package() {
    local package_name="ess-demo-universal-${VERSION}.tar.${COMPRESS_EXT}"
    local package_path="${OUTPUT_DIR}/${package_name}"
    
    print_header "Creating Universal Package (All Platforms)"
    
    # Create temporary staging directory in current directory to avoid /tmp quota issues
    local staging_dir="${SCRIPT_DIR}/.package-staging-$$"
    local package_dir="${staging_dir}/ess-demo"
    
    mkdir -p "$package_dir"
    
    print_info "Staging files for universal package..."
    
    # Copy all installers
    local installer_size=$(du -sh "$INSTALLERS_DIR" | cut -f1)
    print_info "  Copying installers for all platforms (${installer_size})..."
    cp -r "$INSTALLERS_DIR" "${package_dir}/"
    
    # Copy image cache
    if [ -d "$IMAGE_CACHE_DIR" ]; then
        local cache_size=$(du -sh "$IMAGE_CACHE_DIR" | cut -f1)
        print_info "  Copying container image cache (${cache_size})..."
        cp -r "$IMAGE_CACHE_DIR" "${package_dir}/"
    fi
    
    # Copy configuration
    print_info "  Copying configuration files..."
    [ -d "${SCRIPT_DIR}/demo-values" ] && cp -r "${SCRIPT_DIR}/demo-values" "${package_dir}/"
    [ -d "${SCRIPT_DIR}/assets" ] && cp -r "${SCRIPT_DIR}/assets" "${package_dir}/"
    
    # Copy all scripts
    print_info "  Copying all scripts..."
    cp "${SCRIPT_DIR}"/*.sh "${package_dir}/" 2>/dev/null || true
    cp "${SCRIPT_DIR}"/*.ps1 "${package_dir}/" 2>/dev/null || true
    
    # Copy documentation
    print_info "  Copying documentation..."
    cp "${SCRIPT_DIR}"/*.md "${package_dir}/" 2>/dev/null || true
    
    # Create README
    cat > "${package_dir}/README-UNIVERSAL.txt" <<EOF
ESS Community Demo - Universal Offline Package
Version: ${VERSION}
Generated: $(date)

This package contains everything needed for offline deployment on ALL platforms:
- macOS (Intel and Apple Silicon)
- Linux (x86_64 and ARM64)
- Windows (x86_64)

Contents:
- Container image cache (shared)
- Installer binaries for all platforms
- Setup scripts for all platforms
- Configuration files
- Documentation

Choose your platform:
- macOS / Linux: Run ./setup.sh
- Windows PowerShell: Run .\setup.ps1
- Windows WSL: Run ./setup.sh

Total Size: Approximately 5GB
EOF
    
    # Create the tarball with progress indicator
    print_info "Creating universal tarball with zstd compression (this may take several minutes)..."
    cd "$staging_dir"
    
    if command -v pv &> /dev/null; then
        # Use pv for progress if available
        tar -cf - ess-demo/ | pv -s $(du -sb ess-demo/ | awk '{print $1}') | $COMPRESS_CMD $COMPRESS_ARGS > "$package_path"
    else
        # Fallback: show verbose tar output with file count
        local total_files=$(find ess-demo/ -type f | wc -l)
        print_info "  Compressing ${total_files} files with zstd..."
        tar -cf - ess-demo/ | $COMPRESS_CMD $COMPRESS_ARGS > "$package_path" &
        local tar_pid=$!
        
        # Show spinner while tar is running
        local spin='-\|/'
        local i=0
        while kill -0 $tar_pid 2>/dev/null; do
            i=$(( (i+1) %4 ))
            printf "\r  ${BLUE}ℹ${NC} Compressing... ${spin:$i:1}"
            sleep 0.1
        done
        wait $tar_pid
        printf "\r  ${BLUE}ℹ${NC} Compressing... Done!     \n"
    fi
    
    cd - > /dev/null
    
    # Cleanup staging
    rm -rf "$staging_dir"
    
    # Show results
    local size=$(du -sh "$package_path" | cut -f1)
    print_success "Universal package created: ${package_name} (${size})"
    
    # Create checksum
    print_info "Generating checksum..."
    cd "$OUTPUT_DIR"
    sha256sum "$package_name" > "${package_name}.sha256"
    print_success "Checksum: ${package_name}.sha256"
    cd - > /dev/null
    
    # Create installer script
    create_installer_script "$package_name" "universal"
    
    # Create packages README (only once)
    create_packages_readme
}

# Main execution
main() {
    print_header "ESS Demo Offline Package Builder"
    
    # Parse arguments
    local platform="${1:-}"
    
    if [ "$platform" = "--help" ] || [ "$platform" = "-h" ]; then
        echo "Usage: $0 [PLATFORM|--all|--universal]"
        echo ""
        echo "PLATFORM: macos, linux, windows"
        echo "  --all        Create packages for all platforms"
        echo "  --universal  Create one package with all platforms"
        echo "  --help       Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 linux              # Create Linux-only package"
        echo "  $0 --all              # Create separate packages for each platform"
        echo "  $0 --universal        # Create one universal package"
        echo ""
        exit 0
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Check prerequisites
    print_info "Checking prerequisites..."
    
    if [ ! -d "$IMAGE_CACHE_DIR" ]; then
        print_warning "Image cache not found"
        print_info "Run ./cache-images.sh -y to create offline cache"
        echo ""
    fi
    
    local platforms=()
    
    case "$platform" in
        --all)
            platforms=("macos" "linux" "windows")
            ;;
        --universal)
            create_universal_package
            print_header "Packaging Complete!"
            print_success "Universal package ready in: ${OUTPUT_DIR}/"
            ls -lh "${OUTPUT_DIR}"/ess-demo-universal-*.tar.gz 2>/dev/null || true
            exit 0
            ;;
        macos|linux|windows)
            platforms=("$platform")
            ;;
        "")
            print_error "No platform specified"
            echo "Usage: $0 [macos|linux|windows|--all|--universal]"
            echo "Run '$0 --help' for more information"
            exit 1
            ;;
        *)
            print_error "Unknown platform: $platform"
            echo "Valid platforms: macos, linux, windows"
            echo "Or use: --all, --universal"
            exit 1
            ;;
    esac
    
    # Create packages
    local success_count=0
    local failed_count=0
    
    for plat in "${platforms[@]}"; do
        if create_package "$plat"; then
            ((success_count++))
        else
            ((failed_count++))
        fi
        echo ""
    done
    
    # Summary
    print_header "Packaging Complete!"
    
    if [ "$success_count" -gt 0 ]; then
        print_success "Created $success_count package(s)"
        echo ""
        print_info "Packages created in: ${OUTPUT_DIR}/"
        ls -lh "${OUTPUT_DIR}"/*.tar.gz 2>/dev/null || true
        echo ""
        print_info "Checksums:"
        cat "${OUTPUT_DIR}"/*.sha256 2>/dev/null || true
    fi
    
    if [ "$failed_count" -gt 0 ]; then
        echo ""
        print_warning "Failed to create $failed_count package(s)"
    fi
    
    echo ""
    print_info "To distribute:"
    echo "  1. Copy the .tar.gz file to target machine"
    echo "  2. Verify checksum: sha256sum -c <package>.tar.gz.sha256"
    echo "  3. Extract: tar -xzf <package>.tar.gz"
    echo "  4. Run setup script"
    echo ""
}

# Run main function
main "$@"

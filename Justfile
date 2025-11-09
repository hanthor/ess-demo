# ESS Demo - Just Recipes
# Comprehensive build and deployment automation
# Usage: just [recipe] [options]

set shell := ["bash", "-c"]
set positional-arguments := true

# Variables

SCRIPT_DIR := justfile_dir()
BUILD_DIR := SCRIPT_DIR / "build"
RUNTIME_DIR := SCRIPT_DIR / "runtime"
INSTALLERS_DIR := SCRIPT_DIR / "installers"
IMAGE_CACHE_DIR := SCRIPT_DIR / "image-cache"
PACKAGES_DIR := SCRIPT_DIR / "packages"
HELM_CACHE_DIR := IMAGE_CACHE_DIR / "helm-charts"
TEMPLATES_DIR := SCRIPT_DIR / ".just-templates"

# Detect platform

OS := if os_family() == "macos" { "macos" } else if os_family() == "unix" { "linux" } else { "windows" }
ARCH := if arch() == "aarch64" { "arm64" } else if arch() == "arm64" { "arm64" } else { "x86_64" }

# Color codes for output

RED := "\\033[0;31m"
GREEN := "\\033[0;32m"
YELLOW := "\\033[1;33m"
BLUE := "\\033[0;34m"
NC := "\\033[0m"

# Version definitions

KIND_VERSION := "v0.20.0"
KUBECTL_VERSION := "v1.28.4"
HELM_VERSION := "v3.13.2"
K9S_VERSION := "v0.29.1"
MKCERT_VERSION := "v1.4.4"
ZSTD_VERSION := "1.5.6"
KIND_NODE_VERSION := "v1.28.0"

# Print help
@help:
    echo -e "{{ BLUE }}ESS Demo - Just Recipes{{ NC }}"
    echo -e "{{ BLUE }}═══════════════════════════════════════════{{ NC }}"
    echo ""
    echo -e "{{ GREEN }}Setup & Dependencies:{{ NC }}"
    echo "  just setup              - Complete setup (deps + download + cache + build)"
    echo "  just install-deps       - Install Homebrew dependencies"
    echo "  just check-deps         - Check if all dependencies are installed"
    echo ""
    echo -e "{{ GREEN }}Download & Cache:{{ NC }}"
    echo "  just download-all       - Download installers for all platforms"
    echo "  just download-current   - Download installers for current platform"
    echo "  just download-platform <os> - Download for specific platform (macos/linux/windows)"
    echo "  just cache-images       - Cache all container images for offline use"
    echo "  just cache-check        - Check cached images"
    echo ""
    echo -e "{{ GREEN }}Update & Verify:{{ NC }}"
    echo "  just update-helm        - Update/pull latest Helm chart"
    echo "  just verify-helm        - Verify Helm chart and extract image versions"
    echo "  just verify-installers  - Verify installer checksums against remote"
    echo "  just verify-all         - Verify everything (installers, helm, cache)"
    echo ""
    echo -e "{{ GREEN }}Package Building:{{ NC }}"
    echo "  just build-packages     - Build distribution packages for all platforms"
    echo "  just build-macos        - Build macOS package"
    echo "  just build-linux        - Build Linux package"
    echo "  just build-windows      - Build Windows package"
    echo ""
    echo -e "{{ GREEN }}Maintenance:{{ NC }}"
    echo "  just clean              - Remove generated packages"
    echo "  just clean-all          - Remove packages, caches, and installers"
    echo "  just status             - Show current setup status"
    echo ""

# Print colored header
@_header *msg:
    echo ""
    echo -e "{{ BLUE }}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{{ NC }}"
    echo -e "{{ BLUE }}  {{ msg }}{{ NC }}"
    echo -e "{{ BLUE }}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{{ NC }}"
    echo ""

# Print success message
@_success *msg:
    echo -e "{{ GREEN }}✓{{ NC }} {{ msg }}"

# Print info message
@_info *msg:
    echo -e "{{ BLUE }}ℹ{{ NC }} {{ msg }}"

# Print warning message
@_warning *msg:
    echo -e "{{ YELLOW }}⚠{{ NC }} {{ msg }}"

# Print error message
@_error *msg:
    echo -e "{{ RED }}✗{{ NC }} {{ msg }}"

# Check if command exists
@_has_command cmd:
    if command -v {{ cmd }} >/dev/null 2>&1; then echo "yes"; else echo "no"; fi

# Check if all dependencies are installed
@check-deps:
    just _header "Checking Dependencies"
    echo "Checking for required tools..."
    @if [ "$(just _has_command curl)" = "yes" ]; then \
        just _success "curl installed"; \
    elif [ "$(just _has_command wget)" = "yes" ]; then \
        just _success "wget installed"; \
    else \
        just _error "Neither curl nor wget found"; \
    fi
    @if [ "$(just _has_command bash)" = "yes" ]; then \
        just _success "bash installed"; \
    else \
        just _error "bash not found"; \
    fi
    @if [ "$(just _has_command docker)" = "yes" ]; then \
        just _success "docker installed"; \
    elif [ "$(just _has_command podman)" = "yes" ]; then \
        just _success "podman installed (Docker alternative)"; \
    else \
        just _warning "docker/podman not installed (required for operations)"; \
    fi
    @if [ "$(just _has_command helm)" = "yes" ]; then \
        just _success "helm installed"; \
    else \
        just _warning "helm not installed (needed for chart operations)"; \
    fi
    echo ""
    just _info "Checking platform-specific dependencies for {{ OS }}/{{ ARCH }}..."

# Install dependencies via Homebrew
@install-deps:
    just _header "Installing Dependencies via Homebrew"
    @if [ "$(just _has_command brew)" = "no" ]; then \
        just _error "Homebrew not found"; \
        echo "Please install Homebrew from https://brew.sh"; \
        exit 1; \
    fi
    just _info "Updating Homebrew..."
    brew update
    @if [ "$(just _has_command docker)" = "no" ] && [ "$(just _has_command podman)" = "no" ]; then \
        just _info "Installing Docker..."; \
        brew install --cask docker || just _warning "Docker already installed"; \
    else \
        just _success "Container runtime already installed"; \
    fi
    just _info "Installing Kind..."
    brew install kind || just _warning "Kind already installed"
    just _info "Installing kubectl..."
    brew install kubectl || just _warning "kubectl already installed"
    just _info "Installing Helm..."
    brew install helm || just _warning "Helm already installed"
    just _info "Installing k9s..."
    brew install k9s || just _warning "k9s already installed"
    just _info "Installing mkcert..."
    brew install mkcert || just _warning "mkcert already installed"
    just _info "Installing jq (for JSON parsing)..."
    brew install jq || just _warning "jq already installed"
    just _success "All Homebrew dependencies installed!"

# Download installers for all platforms
@download-all:
    just _header "Downloading Installers for All Platforms"
    bash {{ BUILD_DIR }}/download-installers.sh --yes --all

# Download installers for current platform only
@download-current:
    just _header "Downloading Installers for {{ OS }}/{{ ARCH }}"
    bash {{ BUILD_DIR }}/download-installers.sh -y

# Download installers for specific platform
@download-platform platform:
    just _header "Downloading Installers for {{ platform }}"
    bash {{ BUILD_DIR }}/download-installers.sh -y --platform {{ platform }}

# Verify installer checksums against remote
@verify-installers:
    #!/usr/bin/env bash
    set -euo pipefail
    just _header "Verifying Installer Checksums"
    just _info "Verifying checksums for {{ OS }}/{{ ARCH }} installers..."
    
    # Source the shared checksum utilities
    source "{{ BUILD_DIR }}/checksum-utils.sh"
    
    local_installers_dir="{{ INSTALLERS_DIR }}/{{ OS }}"
    if [ ! -d "$local_installers_dir" ]; then
      echo -e "{{ RED }}✗{{ NC }} No installers found for {{ OS }}/{{ ARCH }}"
      exit 1
    fi
    
    # Use the shared verification function
    if verify_directory_checksums "$local_installers_dir"; then
      echo ""
      echo -e "{{ GREEN }}✓{{ NC }} All checksums verified successfully"
      exit 0
    else
      echo ""
      echo -e "{{ RED }}✗{{ NC }} Checksum verification failed"
      exit 1
    fi

@update-helm:
    just _header "Updating Helm Chart"
    just _info "Fetching latest matrix-stack Helm chart..."
    mkdir -p "{{ HELM_CACHE_DIR }}"
    @if [ "$(just _has_command helm)" = "no" ]; then \
        just _error "helm not installed"; \
        exit 1; \
    fi
    helm repo add element https://packages.element.io/helm || true
    helm repo update element
    helm pull element/matrix-stack --destination "{{ HELM_CACHE_DIR }}" --untar --untardir "{{ HELM_CACHE_DIR }}" || \
        just _info "Using locally cached chart"
    just _success "Helm chart updated"

# Extract image versions from Helm chart
@verify-helm:
    #!/usr/bin/env bash
    set -euo pipefail
    just _header "Verifying Helm Chart & Extracting Image Versions"
    chart_dir="{{ HELM_CACHE_DIR }}/matrix-stack"
    if [ ! -d "$chart_dir" ]; then
      echo -e "{{ RED }}✗{{ NC }} Helm chart not found at $chart_dir"
      echo -e "{{ BLUE }}ℹ{{ NC }} Run 'just update-helm' first"
      exit 1
    fi
    echo -e "{{ BLUE }}ℹ{{ NC }} Chart version: $(grep 'version:' "$chart_dir/Chart.yaml" | head -1 | cut -d' ' -f2)"
    echo -e "{{ BLUE }}ℹ{{ NC }} App version: $(grep 'appVersion:' "$chart_dir/Chart.yaml" | head -1 | cut -d' ' -f2)"
    echo -e "{{ BLUE }}ℹ{{ NC }} Extracting image references..."
    if command -v jq >/dev/null 2>&1; then
      echo -e "{{ BLUE }}ℹ{{ NC }} Container images referenced in chart:"
      grep -r "image:" "$chart_dir/values.yaml" | grep -v "^#" | sort | uniq || true
    else
      echo -e "{{ YELLOW }}⚠{{ NC }} jq not installed - install with 'just install-deps'"
      grep -r "image:" "$chart_dir/values.yaml" | grep -v "^#" | sort | uniq || true
    fi
    echo -e "{{ GREEN }}✓{{ NC }} Helm chart verification complete"

# Cache all container images for offline use
@cache-images:
    just _header "Caching Container Images for Offline Use"
    @if [ ! -f "{{ BUILD_DIR }}/cache-images.sh" ]; then \
        just _error "cache-images.sh not found"; \
        exit 1; \
    fi
    bash {{ BUILD_DIR }}/cache-images.sh -y

# Check cached images
@cache-check:
    #!/usr/bin/env bash
    set -euo pipefail
    just _header "Checking Cached Images"
    cache_dir="{{ IMAGE_CACHE_DIR }}"
    if [ ! -d "$cache_dir" ]; then
      echo -e "{{ YELLOW }}⚠{{ NC }} Image cache directory not found"
      exit 0
    fi
    if [ -d "$cache_dir/kind-images" ]; then
      echo -e "{{ BLUE }}ℹ{{ NC }} Kind images:"
      ls -lh "$cache_dir/kind-images" 2>/dev/null | tail -n +2 || echo "  (none)"
    fi
    if [ -d "$cache_dir/ess-images" ]; then
      echo -e "{{ BLUE }}ℹ{{ NC }} ESS images:"
      ls -lh "$cache_dir/ess-images" 2>/dev/null | tail -n +2 | head -20 || echo "  (none)"
    fi
    if [ -d "$cache_dir/helm-charts" ]; then
      echo -e "{{ BLUE }}ℹ{{ NC }} Helm charts:"
      find "$cache_dir/helm-charts" -type f -name "Chart.yaml" -exec dirname {} \;
    fi

# Verify everything
@verify-all:
    just _header "Complete Verification"
    just _info "Step 1: Checking dependencies..."
    just check-deps
    just _info "Step 2: Verifying installers..."
    just verify-installers
    just _info "Step 3: Verifying Helm chart..."
    just verify-helm
    just _info "Step 4: Checking cached images..."
    just cache-check
    just _success "All verifications complete!"

# Build distribution packages for all platforms
@build-packages: build-macos build-linux build-windows
    just _header "All Packages Built Successfully"
    echo ""
    echo "Package locations:"
    echo "  macOS:   {{ PACKAGES_DIR }}/macos"
    echo "  Linux:   {{ PACKAGES_DIR }}/linux"
    echo "  Windows: {{ PACKAGES_DIR }}/windows"
    echo ""
    just _success "Ready for distribution!"

# Build macOS package
@build-macos:
    just _header "Building macOS Package"
    just _info "Creating macOS package structure..."
    bash {{ TEMPLATES_DIR }}/create-macos-package.sh {{ PACKAGES_DIR }}/macos

# Build Linux package
@build-linux:
    just _header "Building Linux Package"
    just _info "Creating Linux package structure..."
    bash {{ TEMPLATES_DIR }}/create-linux-package.sh {{ PACKAGES_DIR }}/linux

# Build Windows package
@build-windows:
    just _header "Building Windows Package"
    just _info "Creating Windows package structure..."
    bash {{ TEMPLATES_DIR }}/create-windows-package.sh {{ PACKAGES_DIR }}/windows

# Show current setup status
@status:
    #!/usr/bin/env bash
    set -euo pipefail
    just _header "ESS Demo Setup Status"
    echo "Platform: {{ OS }}/{{ ARCH }}"
    echo ""
    echo "Installers:"
    if [ -d "{{ INSTALLERS_DIR }}/{{ OS }}" ]; then
      echo "  ✓ Downloaded for {{ OS }}"
      ls -lh "{{ INSTALLERS_DIR }}/{{ OS }}" 2>/dev/null | tail -n +2 | awk '{print "    - " $9 " (" $5 ")"}'
    else
      echo "  ✗ Not downloaded for {{ OS }}"
    fi
    echo ""
    echo "Image Cache:"
    if [ -d "{{ IMAGE_CACHE_DIR }}/ess-images" ] && [ -n "$(ls -A {{ IMAGE_CACHE_DIR }}/ess-images 2>/dev/null)" ]; then
      echo "  ✓ Container images cached"
      cache_size=$(du -sh {{ IMAGE_CACHE_DIR }}/ess-images 2>/dev/null | cut -f1)
      echo "    Size: $cache_size"
    else
      echo "  ✗ No container images cached"
    fi
    echo ""
    echo "Helm Chart:"
    if [ -d "{{ HELM_CACHE_DIR }}/matrix-stack" ]; then
      echo "  ✓ Helm chart cached"
      version=$(grep 'version:' {{ HELM_CACHE_DIR }}/matrix-stack/Chart.yaml | head -1 | cut -d' ' -f2)
      echo "    Version: $version"
    else
      echo "  ✗ Helm chart not cached"
    fi
    echo ""
    echo "Packages:"
    if [ -d "{{ PACKAGES_DIR }}" ] && [ -n "$(ls -d {{ PACKAGES_DIR }}/* 2>/dev/null)" ]; then
      echo "  ✓ Packages built"
      for os_dir in {{ PACKAGES_DIR }}/*; do
        if [ -d "$os_dir" ]; then
          echo "    - $(basename $os_dir)"
        fi
      done
    else
      echo "  ✗ No packages built"
    fi# Clean generated packages

@clean:
    just _header "Cleaning Generated Packages"
    @if [ -d "{{ PACKAGES_DIR }}" ]; then \
        just _info "Removing {{ PACKAGES_DIR }}..."; \
        rm -rf "{{ PACKAGES_DIR }}"; \
        just _success "Packages cleaned"; \
    else \
        just _info "No packages to clean"; \
    fi

# Clean everything
@clean-all:
    just _header "Complete Cleanup"
    just _warning "This will remove installers, caches, and packages!"
    echo ""
    echo "Directories to be removed:"
    echo "  - {{ INSTALLERS_DIR }}"
    echo "  - {{ IMAGE_CACHE_DIR }}"
    echo "  - {{ PACKAGES_DIR }}"
    echo ""
    echo "Type 'yes' to confirm: "
    @read confirm && \
    if [ "$confirm" = "yes" ]; then \
        just _info "Removing installers..."; \
        rm -rf "{{ INSTALLERS_DIR }}"/*; \
        just _info "Removing image cache..."; \
        rm -rf "{{ IMAGE_CACHE_DIR }}"/*; \
        just _info "Removing packages..."; \
        rm -rf "{{ PACKAGES_DIR }}"/*; \
        just _success "Cleanup complete"; \
    else \
        just _warning "Cleanup cancelled"; \
    fi

# Complete setup: deps, download, cache, verify, and build
@setup: check-deps download-current verify-installers update-helm verify-helm cache-images verify-all build-packages
    just _header "Setup Complete!"
    echo ""
    echo -e "{{ GREEN }}All components are ready for deployment!{{ NC }}"
    echo ""
    just status
    echo ""
    echo "To get started:"
    echo "  1. Run setup: ./setup.sh (or .\\setup.ps1 on Windows)"
    echo "  2. Check status: ./verify.sh"
    echo "  3. View logs: kubectl logs -n ess -l app.kubernetes.io/name=synapse"
    echo ""

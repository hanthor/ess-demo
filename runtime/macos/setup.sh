#!/bin/bash
# ESS Community Demo - Automated Setup Script
# Supports: macOS (Intel/Apple Silicon) and Linux (x86_64/arm64)
# Copyright 2025 - Portable offline demo setup

set -euo pipefail

# Offline mode flag - now defaults to true
OFFLINE_MODE=true
USE_CACHED_IMAGES=false
DOMAIN_NAME=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="${SCRIPT_DIR}/installers"
IMAGE_CACHE_DIR="${SCRIPT_DIR}/image-cache"

# Source container runtime utilities (detects docker or podman)
if [ -f "${SCRIPT_DIR}/../build/container-runtime.sh" ]; then
    source "${SCRIPT_DIR}/../build/container-runtime.sh"
elif [ -f "${SCRIPT_DIR}/build/container-runtime.sh" ]; then
    source "${SCRIPT_DIR}/build/container-runtime.sh"
fi

# Determine container runtime to use (docker or podman)
CONTAINER_RUNTIME=""
if command -v detect_container_runtime >/dev/null 2>&1; then
    CONTAINER_RUNTIME=$(detect_container_runtime)
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
            print_info "Please use setup.ps1 for Windows"
            exit 1
            ;;
    esac
    
    print_info "Detected platform: ${OS}/${ARCH}"
}

# Load cached images if available
load_cached_images() {
    if [ ! -d "$IMAGE_CACHE_DIR" ]; then
        return 0
    fi
    
    print_header "Loading Cached Images"
    
    print_info "Found cached images, loading into ${CONTAINER_RUNTIME:-docker}..."

    # Load Kind images
    if [ -d "${IMAGE_CACHE_DIR}/kind-images" ]; then
        for img in "${IMAGE_CACHE_DIR}/kind-images"/*.tar; do
            if [ -f "$img" ]; then
                print_info "Loading: $(basename "$img")"
                if command -v container_load_image >/dev/null 2>&1; then
                    container_load_image "$img" "${CONTAINER_RUNTIME}"
                else
                    ${CONTAINER_RUNTIME:-docker} load -i "$img"
                fi
            fi
        done
    fi

    # Load ESS images
    if [ -d "${IMAGE_CACHE_DIR}/ess-images" ]; then
        for img in "${IMAGE_CACHE_DIR}/ess-images"/*.tar; do
            if [ -f "$img" ]; then
                print_info "Loading: $(basename "$img")"
                if command -v container_load_image >/dev/null 2>&1; then
                    container_load_image "$img" "${CONTAINER_RUNTIME}"
                else
                    ${CONTAINER_RUNTIME:-docker} load -i "$img"
                fi
            fi
        done
    fi

    print_success "Cached images loaded into ${CONTAINER_RUNTIME:-docker}"
    USE_CACHED_IMAGES=true
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install from local installer
install_docker() {
    print_header "Installing Docker"
    
    # Check if Docker is actually working (not just present)
    if command_exists docker && docker info >/dev/null 2>&1; then
        print_success "Docker already installed and running: $(docker --version)"
        return 0
    fi
    
    # Check if Podman (rootful or rootless) or Docker is available - prefer detected runtime
    if command -v detect_container_runtime >/dev/null 2>&1; then
        RUNTIME=$(detect_container_runtime || true)
        if [ -n "${RUNTIME:-}" ] && [ "${RUNTIME}" != "docker" ]; then
            print_success "Container runtime detected: ${RUNTIME}"
            print_info "Skipping Docker installation (using ${RUNTIME} instead)"
            return 0
        fi
    else
        # Fallback: check podman (rootful or rootless)
        if command_exists podman && (podman info >/dev/null 2>&1 || sudo podman info >/dev/null 2>&1); then
            print_success "Podman is already available and running"
            print_info "Skipping Docker installation (using Podman instead)"
            return 0
        fi
    fi
    
    if [ "$OS" = "macos" ]; then
        # macOS - Docker Desktop
        DMG_FILE="${INSTALLERS_DIR}/macos/Docker.dmg"
        if [ ! -f "$DMG_FILE" ]; then
            print_error "Docker Desktop installer not found at: $DMG_FILE"
            print_info "Please run ./download-installers.sh first"
            exit 1
        fi
        
        print_info "Installing Docker Desktop..."
        hdiutil attach "$DMG_FILE"
        cp -R /Volumes/Docker/Docker.app /Applications/
        hdiutil detach /Volumes/Docker
        
        print_info "Starting Docker Desktop..."
        open -a Docker
        print_warning "Waiting for Docker to start (this may take a minute)..."
        
        # Wait for Docker to be ready
        for i in {1..60}; do
            if docker info >/dev/null 2>&1; then
                print_success "Docker is ready"
                break
            fi
            sleep 2
        done
        
    else
        # Linux - Install from downloaded package
        if [ -f "${INSTALLERS_DIR}/linux/docker.tgz" ]; then
            print_info "Installing Docker from local package..."
            
            # Clean up any broken Docker installation first
            rm -f /usr/local/bin/docker* 2>/dev/null || true
            
            # Extract and install Docker binaries
            tar xzvf "${INSTALLERS_DIR}/linux/docker.tgz" -C /tmp
            sudo cp /tmp/docker/* /usr/local/bin/
            sudo groupadd docker 2>/dev/null || true
            sudo usermod -aG docker "$USER" || true
            
            # Start Docker daemon
            if ! pgrep dockerd >/dev/null; then
                print_info "Starting Docker daemon..."
                sudo dockerd > /dev/null 2>&1 &
                sleep 5
            fi
            
        else
            print_error "Docker package not found at: ${INSTALLERS_DIR}/linux/docker.tgz"
            print_info "Please run ./download-installers.sh first"
            exit 1
        fi
    fi
    
    print_success "Docker installed successfully"
}

# Install Kind
install_kind() {
    print_header "Installing Kind"
    
    if command_exists kind; then
        print_success "Kind already installed: $(kind --version)"
        return 0
    fi
    
    local KIND_BIN="${INSTALLERS_DIR}/${OS}/kind-${OS}-${DOCKER_ARCH}"
    if [ ! -f "$KIND_BIN" ]; then
        print_error "Kind binary not found at: $KIND_BIN"
        print_info "Please run ./download-installers.sh first"
        exit 1
    fi
    
    print_info "Installing Kind..."
    sudo install -m 755 "$KIND_BIN" /usr/local/bin/kind
    print_success "Kind installed: $(kind --version)"
}

# Install kubectl
install_kubectl() {
    print_header "Installing kubectl"
    
    if command_exists kubectl; then
        print_success "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return 0
    fi
    
    local KUBECTL_BIN="${INSTALLERS_DIR}/${OS}/kubectl"
    if [ ! -f "$KUBECTL_BIN" ]; then
        print_error "kubectl binary not found at: $KUBECTL_BIN"
        print_info "Please run ./download-installers.sh first"
        exit 1
    fi
    
    print_info "Installing kubectl..."
    sudo install -m 755 "$KUBECTL_BIN" /usr/local/bin/kubectl
    print_success "kubectl installed"
}

# Install Helm
install_helm() {
    print_header "Installing Helm"
    
    if command_exists helm; then
        print_success "Helm already installed: $(helm version --short)"
        return 0
    fi
    
    local HELM_ARCHIVE="${INSTALLERS_DIR}/${OS}/helm-${OS}-${DOCKER_ARCH}.tar.gz"
    if [ ! -f "$HELM_ARCHIVE" ]; then
        print_error "Helm archive not found at: $HELM_ARCHIVE"
        print_info "Please run ./download-installers.sh first"
        exit 1
    fi
    
    print_info "Installing Helm..."
    tar -xzf "$HELM_ARCHIVE" -C /tmp
    sudo mv "/tmp/${OS}-${DOCKER_ARCH}/helm" /usr/local/bin/helm
    sudo chmod +x /usr/local/bin/helm
    print_success "Helm installed: $(helm version --short)"
}

# Install k9s
install_k9s() {
    print_header "Installing k9s"
    
    if command_exists k9s; then
        print_success "k9s already installed: $(k9s version --short 2>/dev/null || echo 'installed')"
        return 0
    fi
    
    local K9S_ARCHIVE="${INSTALLERS_DIR}/${OS}/k9s_${OS}_${ARCH}.tar.gz"
    if [ ! -f "$K9S_ARCHIVE" ]; then
        print_warning "k9s archive not found at: $K9S_ARCHIVE"
        print_info "k9s is optional - skipping"
        return 0
    fi
    
    print_info "Installing k9s..."
    tar -xzf "$K9S_ARCHIVE" -C /tmp
    sudo mv /tmp/k9s /usr/local/bin/k9s
    sudo chmod +x /usr/local/bin/k9s
    print_success "k9s installed"
}

# Install mkcert
install_mkcert() {
    print_header "Installing mkcert"
    
    if command_exists mkcert; then
        print_success "mkcert already installed"
        return 0
    fi
    
    local MKCERT_BIN="${INSTALLERS_DIR}/${OS}/mkcert-${OS}-${DOCKER_ARCH}"
    if [ ! -f "$MKCERT_BIN" ]; then
        print_error "mkcert binary not found at: $MKCERT_BIN"
        print_info "Please run ./download-installers.sh first"
        exit 1
    fi
    
    print_info "Installing mkcert..."
    sudo install -m 755 "$MKCERT_BIN" /usr/local/bin/mkcert
    
    # Install local CA
    print_info "Installing local CA certificates..."
    mkcert -install
    
    print_success "mkcert installed and CA configured"
}

# Create Kind cluster
create_kind_cluster() {
    print_header "Creating Kind Cluster"
    
    local CLUSTER_NAME="ess-demo"
    
    # Check if cluster already exists
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        print_warning "Cluster '${CLUSTER_NAME}' already exists"
        read -p "Delete and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing cluster..."
            if command -v container_kind_delete >/dev/null 2>&1; then
                container_kind_delete "$CLUSTER_NAME" "${CONTAINER_RUNTIME}"
            else
                kind delete cluster --name "$CLUSTER_NAME"
            fi
        else
            print_info "Using existing cluster"
            return 0
        fi
    fi
    
    # Create Kind config with optional cached image
    local KIND_CONFIG="/tmp/kind-config.yaml"
    
    # Always use standard ports (80, 443) - rootful podman can bind them
    local HTTP_PORT=80
    local HTTPS_PORT=443
    
    # Initialize CACHED_IMAGE
    local CACHED_IMAGE=""
    
    if [ "$USE_CACHED_IMAGES" = true ] && ls ${IMAGE_CACHE_DIR}/kind-images/kind-node-*.tar >/dev/null 2>&1; then
        # Use cached Kind node image - extract version from filename
        local KIND_IMAGE_FILE=$(ls -1 "${IMAGE_CACHE_DIR}/kind-images/kind-node-"*.tar 2>/dev/null | head -1)
        if [ -n "$KIND_IMAGE_FILE" ]; then
            # Extract version from filename (e.g., kind-node-v1.28.0.tar -> v1.28.0)
            local KIND_VERSION=$(basename "$KIND_IMAGE_FILE" | sed 's/kind-node-\(.*\)\.tar$/\1/')
            CACHED_IMAGE="kindest/node:${KIND_VERSION}"
            print_info "Using cached Kind node image: $CACHED_IMAGE (from $KIND_IMAGE_FILE)"
        fi
    fi
    
    # Generate Kind config based on whether we have a cached image
    if [ -n "$CACHED_IMAGE" ]; then
        cat > "$KIND_CONFIG" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: ${CACHED_IMAGE}
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: ${HTTP_PORT}
    protocol: TCP
  - containerPort: 443
    hostPort: ${HTTPS_PORT}
    protocol: TCP
EOF
    else
        # Let Kind pull the image
        cat > "$KIND_CONFIG" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: ${HTTP_PORT}
    protocol: TCP
  - containerPort: 443
    hostPort: ${HTTPS_PORT}
    protocol: TCP
EOF
    fi
    
    print_info "Creating Kind cluster '${CLUSTER_NAME}' using runtime: ${CONTAINER_RUNTIME:-docker}"
    if command -v container_kind_create >/dev/null 2>&1; then
        container_kind_create "$CLUSTER_NAME" "${CONTAINER_RUNTIME}" --config "$KIND_CONFIG"
    else
        kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
    fi
    
    # Set context
    kubectl cluster-info --context "kind-${CLUSTER_NAME}"
    
    print_success "Kind cluster created successfully"
}

# Install NGINX Ingress Controller
install_nginx_ingress() {
    print_header "Installing NGINX Ingress Controller"
    
    local CLUSTER_NAME="ess-demo"
    
    # Try to use Helm first (if available and charts are cached)
    if command_exists helm && [ -f "${IMAGE_CACHE_DIR}/helm-charts/ingress-nginx-"*.tgz ]; then
        print_info "Installing NGINX Ingress via Helm (cached chart)..."
        local INGRESS_CHART=$(ls -1 "${IMAGE_CACHE_DIR}/helm-charts/ingress-nginx-"*.tgz 2>/dev/null | head -1)
        if [ -n "$INGRESS_CHART" ]; then
            helm upgrade -i ingress-nginx "$INGRESS_CHART" \
                --namespace ingress-nginx \
                --create-namespace \
                --kube-context "kind-${CLUSTER_NAME}" \
                --set controller.service.type=NodePort \
                --set controller.hostNetwork=true || true
        fi
    fi
    
    # Fall back to kubectl apply with offline manifest (try cached, then URL)
    if ! kubectl get deployment -n ingress-nginx ingress-nginx-controller >/dev/null 2>&1; then
        print_info "Installing NGINX Ingress via kubectl..."
        
        # Try to load from cached manifest if available
        local NGINX_MANIFEST="${IMAGE_CACHE_DIR}/../demo-values/nginx-kind-deploy.yaml"
        if [ -f "$NGINX_MANIFEST" ]; then
            kubectl apply -f "$NGINX_MANIFEST" || true
        else
            # Fall back to online deployment (requires network)
            print_warning "NGINX manifest not cached, attempting to fetch from internet..."
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml || \
                { print_error "Failed to fetch NGINX manifest from internet"; return 1; }
        fi
    fi
    
    # Wait for NGINX deployment to be ready
    print_info "Waiting for NGINX Ingress Controller to be ready (this may take 1-2 minutes)..."
    
    # First, wait for the deployment to exist
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if kubectl get deployment -n ingress-nginx ingress-nginx-controller >/dev/null 2>&1; then
            break
        fi
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_warning "NGINX deployment not found after ${max_attempts} attempts"
    fi
    
    # Now wait for the deployment to be available
    kubectl rollout status deployment/ingress-nginx-controller \
        -n ingress-nginx \
        --timeout=120s || print_warning "NGINX Ingress installation may still be in progress"
    
    print_success "NGINX Ingress Controller installation complete"
}

# Prompt for domain name
prompt_domain() {
    print_header "Domain Configuration"
    
    # If domain was provided via command line argument, skip prompt
    if [ -n "$DOMAIN_NAME" ]; then
        print_success "Using domain: $DOMAIN_NAME"
        return 0
    fi
    
    echo ""
    print_info "Enter the base domain name for your ESS deployment"
    print_info "Examples: ess.localhost, my-matrix.localhost"
    print_info "(Using .localhost ensures automatic local DNS resolution)"
    echo ""
    
    read -p "Domain name: " DOMAIN_NAME
    
    # Validate domain
    if [ -z "$DOMAIN_NAME" ]; then
        print_error "Domain name cannot be empty"
        exit 1
    fi
    
    print_success "Using domain: $DOMAIN_NAME"
}

# Generate hostnames configuration
generate_hostnames_config() {
    print_header "Generating Configuration Files"
    
    cat > "${SCRIPT_DIR}/demo-values/hostnames.yaml" <<EOF
elementAdmin:
  ingress:
    host: admin.${DOMAIN_NAME}
elementWeb:
  ingress:
    host: chat.${DOMAIN_NAME}
matrixAuthenticationService:
  ingress:
    host: auth.${DOMAIN_NAME}
matrixRTC:
  ingress:
    host: mrtc.${DOMAIN_NAME}
serverName: ${DOMAIN_NAME}
synapse:
  ingress:
    host: matrix.${DOMAIN_NAME}
EOF
    
    print_success "Generated hostnames.yaml"
}

# Generate certificates
generate_certificates() {
    print_header "Generating SSL Certificates with mkcert"
    
    # Create namespace
    kubectl create namespace ess --dry-run=client -o yaml | kubectl apply -f -
    
    # Extract hostnames from the domain
    local ADMIN_HOST="admin.${DOMAIN_NAME}"
    local CHAT_HOST="chat.${DOMAIN_NAME}"
    local AUTH_HOST="auth.${DOMAIN_NAME}"
    local MRTC_HOST="mrtc.${DOMAIN_NAME}"
    local MATRIX_HOST="matrix.${DOMAIN_NAME}"
    local WK_HOST="${DOMAIN_NAME}"
    
    # Create certs directory if it doesn't exist
    mkdir -p "${SCRIPT_DIR}/certs"
    
    print_info "Generating certificates for domain: ${DOMAIN_NAME}"
    
    # Generate certificate for admin
    print_info "  • Generating admin.${DOMAIN_NAME} certificate..."
    mkcert -cert-file "${SCRIPT_DIR}/certs/admin-cert.pem" \
           -key-file "${SCRIPT_DIR}/certs/admin-key.pem" \
           "${ADMIN_HOST}" 2>/dev/null || print_warning "mkcert may need to be installed"
    
    # Generate certificate for chat
    print_info "  • Generating chat.${DOMAIN_NAME} certificate..."
    mkcert -cert-file "${SCRIPT_DIR}/certs/chat-cert.pem" \
           -key-file "${SCRIPT_DIR}/certs/chat-key.pem" \
           "${CHAT_HOST}"
    
    # Generate certificate for auth
    print_info "  • Generating auth.${DOMAIN_NAME} certificate..."
    mkcert -cert-file "${SCRIPT_DIR}/certs/auth-cert.pem" \
           -key-file "${SCRIPT_DIR}/certs/auth-key.pem" \
           "${AUTH_HOST}"
    
    # Generate certificate for mrtc
    print_info "  • Generating mrtc.${DOMAIN_NAME} certificate..."
    mkcert -cert-file "${SCRIPT_DIR}/certs/mrtc-cert.pem" \
           -key-file "${SCRIPT_DIR}/certs/mrtc-key.pem" \
           "${MRTC_HOST}"
    
    # Generate certificate for matrix
    print_info "  • Generating matrix.${DOMAIN_NAME} certificate..."
    mkcert -cert-file "${SCRIPT_DIR}/certs/matrix-cert.pem" \
           -key-file "${SCRIPT_DIR}/certs/matrix-key.pem" \
           "${MATRIX_HOST}"
    
    # Generate certificate for well-known
    print_info "  • Generating ${DOMAIN_NAME} certificate..."
    mkcert -cert-file "${SCRIPT_DIR}/certs/well-known-cert.pem" \
           -key-file "${SCRIPT_DIR}/certs/well-known-key.pem" \
           "${WK_HOST}"
    
    # Create Kubernetes secrets from the certificates
    print_info "Creating Kubernetes secrets in 'ess' namespace..."
    
    # Create admin certificate secret
    kubectl create secret tls ess-admin-certificate \
        --cert="${SCRIPT_DIR}/certs/admin-cert.pem" \
        --key="${SCRIPT_DIR}/certs/admin-key.pem" \
        -n ess --dry-run=client -o yaml | kubectl apply -f -
    
    # Create chat certificate secret
    kubectl create secret tls ess-chat-certificate \
        --cert="${SCRIPT_DIR}/certs/chat-cert.pem" \
        --key="${SCRIPT_DIR}/certs/chat-key.pem" \
        -n ess --dry-run=client -o yaml | kubectl apply -f -
    
    # Create auth certificate secret
    kubectl create secret tls ess-auth-certificate \
        --cert="${SCRIPT_DIR}/certs/auth-cert.pem" \
        --key="${SCRIPT_DIR}/certs/auth-key.pem" \
        -n ess --dry-run=client -o yaml | kubectl apply -f -
    
    # Create mrtc certificate secret
    kubectl create secret tls ess-mrtc-certificate \
        --cert="${SCRIPT_DIR}/certs/mrtc-cert.pem" \
        --key="${SCRIPT_DIR}/certs/mrtc-key.pem" \
        -n ess --dry-run=client -o yaml | kubectl apply -f -
    
    # Create matrix certificate secret
    kubectl create secret tls ess-matrix-certificate \
        --cert="${SCRIPT_DIR}/certs/matrix-cert.pem" \
        --key="${SCRIPT_DIR}/certs/matrix-key.pem" \
        -n ess --dry-run=client -o yaml | kubectl apply -f -
    
    # Create well-known certificate secret
    kubectl create secret tls ess-well-known-certificate \
        --cert="${SCRIPT_DIR}/certs/well-known-cert.pem" \
        --key="${SCRIPT_DIR}/certs/well-known-key.pem" \
        -n ess --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "SSL certificates generated and Kubernetes secrets created"
}

# Deploy ESS
deploy_ess() {
    print_header "Deploying ESS Community"
    
    print_info "Installing ESS Helm chart..."
    helm upgrade --install \
        --namespace "ess" \
        ess \
        oci://ghcr.io/element-hq/ess-helm/matrix-stack \
        -f "${SCRIPT_DIR}/demo-values/hostnames.yaml" \
        -f "${SCRIPT_DIR}/demo-values/tls.yaml" \
        -f "${SCRIPT_DIR}/demo-values/auth.yaml" \
        -f "${SCRIPT_DIR}/demo-values/mrtc.yaml" \
        -f "${SCRIPT_DIR}/demo-values/pull-policy.yml" \
        --wait
    
    print_success "ESS deployed successfully"
}

# Display access information
show_access_info() {
    print_header "Setup Complete!"
    
    echo ""
    print_success "Your ESS Community instance is ready!"
    echo ""
    print_info "Access URLs:"
    echo "  • Element Web:        https://chat.${DOMAIN_NAME}"
    echo "  • Admin Portal:       https://admin.${DOMAIN_NAME}"
    echo "  • Matrix Server:      https://matrix.${DOMAIN_NAME}"
    echo "  • Authentication:     https://auth.${DOMAIN_NAME}"
    echo "  • Matrix RTC:         https://mrtc.${DOMAIN_NAME}"
    echo "  • Federation:         https://${DOMAIN_NAME}"
    echo ""
    
    # Get Ingress IP
    print_info "Waiting for Ingress IP assignment..."
    local INGRESS_IP=""
    for i in {1..30}; do
        INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        if [ -z "$INGRESS_IP" ]; then
            # Try hostname instead
            INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        fi
        if [ -z "$INGRESS_IP" ]; then
            # For Kind/local clusters, use localhost
            INGRESS_IP="127.0.0.1"
        fi
        if [ -n "$INGRESS_IP" ]; then
            break
        fi
        sleep 2
    done
    
    if [ -z "$INGRESS_IP" ]; then
        INGRESS_IP="127.0.0.1"
        print_warning "Could not determine Ingress IP, using localhost (127.0.0.1)"
    fi
    
    print_header "DNS Configuration"
    echo ""
    print_success "Ingress IP: ${INGRESS_IP}"
    echo ""
    print_info "Add these DNS entries to your DNS server:"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "DNS Zone File Format (BIND):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "${DOMAIN_NAME%.}.        IN  A     ${INGRESS_IP}"
    echo "chat.${DOMAIN_NAME%.}.   IN  A     ${INGRESS_IP}"
    echo "admin.${DOMAIN_NAME%.}.  IN  A     ${INGRESS_IP}"
    echo "matrix.${DOMAIN_NAME%.}. IN  A     ${INGRESS_IP}"
    echo "auth.${DOMAIN_NAME%.}.   IN  A     ${INGRESS_IP}"
    echo "mrtc.${DOMAIN_NAME%.}.   IN  A     ${INGRESS_IP}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "/etc/hosts Format:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "${INGRESS_IP}  ${DOMAIN_NAME} chat.${DOMAIN_NAME} admin.${DOMAIN_NAME} matrix.${DOMAIN_NAME} auth.${DOMAIN_NAME} mrtc.${DOMAIN_NAME}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "dnsmasq Format:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "address=/${DOMAIN_NAME}/${INGRESS_IP}"
    echo "address=/chat.${DOMAIN_NAME}/${INGRESS_IP}"
    echo "address=/admin.${DOMAIN_NAME}/${INGRESS_IP}"
    echo "address=/matrix.${DOMAIN_NAME}/${INGRESS_IP}"
    echo "address=/auth.${DOMAIN_NAME}/${INGRESS_IP}"
    echo "address=/mrtc.${DOMAIN_NAME}/${INGRESS_IP}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    print_info "Useful commands:"
    echo "  • View cluster status:     kubectl get pods -n ess"
    echo "  • Watch resources (k9s):   k9s -n ess"
    echo "  • View logs:               kubectl logs -n ess -l app.kubernetes.io/name=synapse"
    echo "  • Port forward (if needed): kubectl port-forward -n ess svc/ess-synapse 8008:8008"
    echo ""
    print_info "Cluster info:"
    echo "  • Context: kind-ess-demo"
    echo "  • Namespace: ess"
    echo ""
    print_warning "Note: Your browser may show a certificate warning. This is expected with mkcert."
    print_warning "Click 'Advanced' and proceed to accept the local development certificate."
    echo ""
}

# Main execution
main() {
    print_header "ESS Community Portable Demo - Setup"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --online)
                OFFLINE_MODE=false
                shift
                ;;
            --offline)
                OFFLINE_MODE=true
                shift
                ;;
            --domain)
                if [ -z "${2:-}" ]; then
                    print_error "Domain name required for --domain option"
                    exit 1
                fi
                DOMAIN_NAME="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --online           Pull images from internet (default is offline mode)"
                echo "  --offline          Use cached images (default, requires cache-images.sh)"
                echo "  --domain <name>    Set domain name (e.g., ess.localhost) for non-interactive setup"
                echo "  --help, -h         Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0 --offline"
                echo "  $0 --offline --domain ess.localhost"
                echo "  $0 --online --domain demo.example.com"
                echo ""
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Detect platform
    detect_platform
    
    # Check if we need to download installers
    if [ ! -d "${INSTALLERS_DIR}/${OS}" ] || [ -z "$(ls -A "${INSTALLERS_DIR}/${OS}" 2>/dev/null)" ]; then
        print_warning "No installers found for ${OS}"
        print_info "Please run ./download-installers.sh first to download required software"
        exit 1
    fi
    
    # Load cached images if in offline mode or if cache exists
    if [ "$OFFLINE_MODE" = true ] || [ -d "$IMAGE_CACHE_DIR" ]; then
        load_cached_images
    fi
    
    # Install dependencies
    install_docker
    install_kind
    install_kubectl
    install_helm
    install_k9s
    install_mkcert
    
    # Prompt for domain
    prompt_domain
    
    # Generate configuration
    generate_hostnames_config
    
    # Setup Kubernetes
    create_kind_cluster
    install_nginx_ingress
    
    # Generate certificates
    generate_certificates
    
    # Deploy ESS
    deploy_ess
    
    # Show access information
    show_access_info
}

# Run main function
main "$@"

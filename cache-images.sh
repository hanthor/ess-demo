#!/bin/bash
# ESS Community Demo - Image Caching Script
# Downloads and caches all container images for air-gapped/offline deployment
# This includes Kind node images, ESS component images, and the Helm chart

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${SCRIPT_DIR}/image-cache"
KIND_IMAGES_DIR="${CACHE_DIR}/kind-images"
ESS_IMAGES_DIR="${CACHE_DIR}/ess-images"
HELM_CACHE_DIR="${CACHE_DIR}/helm-charts"

# Kubernetes and Kind versions
KIND_NODE_VERSION="v1.28.0"
KIND_NODE_IMAGE="kindest/node:${KIND_NODE_VERSION}"

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

# Check if Docker is running
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed"
        print_info "Please install Docker first"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running"
        print_info "Please start Docker and try again"
        exit 1
    fi
    
    print_success "Docker is running"
}

# Check if skopeo is available
check_skopeo() {
    if command -v skopeo >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get remote image digest using skopeo or docker
get_remote_digest() {
    local image="$1"
    
    if check_skopeo; then
        # Use skopeo for faster, pull-free inspection
        skopeo inspect "docker://${image}" 2>/dev/null | grep -o '"Digest":"sha256:[^"]*"' | cut -d'"' -f4 || echo ""
    else
        # Fallback to docker inspect (requires pulling manifest)
        docker manifest inspect "${image}" 2>/dev/null | grep -o '"digest":"sha256:[^"]*"' | head -1 | cut -d'"' -f4 || echo ""
    fi
}

# Get local cached image digest
get_cached_digest() {
    local image_file="$1"
    local metadata_file="${image_file}.digest"
    
    if [ -f "$metadata_file" ]; then
        cat "$metadata_file"
    else
        echo ""
    fi
}

# Save image digest to metadata file
save_digest() {
    local image_file="$1"
    local digest="$2"
    local metadata_file="${image_file}.digest"
    
    echo "$digest" > "$metadata_file"
}

# Check if image needs update
needs_update() {
    local image="$1"
    local image_file="$2"
    
    # If file doesn't exist, needs download
    if [ ! -f "$image_file" ]; then
        return 0
    fi
    
    # Get remote digest
    print_info "Checking remote version..."
    local remote_digest=$(get_remote_digest "$image")
    
    if [ -z "$remote_digest" ]; then
        print_warning "Could not get remote digest, skipping version check"
        return 1  # Don't update if we can't check
    fi
    
    # Get cached digest
    local cached_digest=$(get_cached_digest "$image_file")
    
    if [ -z "$cached_digest" ]; then
        print_warning "No cached digest found, will re-download"
        return 0
    fi
    
    # Compare digests
    if [ "$remote_digest" != "$cached_digest" ]; then
        print_info "New version available (digest changed)"
        return 0
    else
        print_success "Cached version is up to date"
        return 1
    fi
}

# Create cache directories
create_cache_dirs() {
    print_header "Creating Cache Directories"
    
    mkdir -p "$KIND_IMAGES_DIR"
    mkdir -p "$ESS_IMAGES_DIR"
    mkdir -p "$HELM_CACHE_DIR"
    
    print_success "Cache directories created at: $CACHE_DIR"
}

# Download Kind node image
download_kind_image() {
    print_header "Downloading Kind Node Image"
    
    local IMAGE_FILE="${KIND_IMAGES_DIR}/kind-node-${KIND_NODE_VERSION}.tar"
    
    if [ -f "$IMAGE_FILE" ]; then
        print_info "Kind node image found in cache"
        
        if needs_update "$KIND_NODE_IMAGE" "$IMAGE_FILE"; then
            print_info "Updating Kind node image..."
            rm -f "$IMAGE_FILE" "${IMAGE_FILE}.digest"
        else
            print_success "Using cached Kind node image ($(du -h "$IMAGE_FILE" | cut -f1))"
            return 0
        fi
    fi
    
    print_info "Pulling Kind node image: $KIND_NODE_IMAGE"
    print_warning "This is a large image (~400MB), please wait..."
    
    docker pull "$KIND_NODE_IMAGE"
    
    # Get digest and save
    local digest=$(get_remote_digest "$KIND_NODE_IMAGE")
    
    print_info "Saving image to: $IMAGE_FILE"
    docker save -o "$IMAGE_FILE" "$KIND_NODE_IMAGE"
    
    if [ -n "$digest" ]; then
        save_digest "$IMAGE_FILE" "$digest"
        print_info "Saved digest: ${digest:0:19}..."
    fi
    
    print_success "Kind node image cached ($(du -h "$IMAGE_FILE" | cut -f1))"
}

# Pull Helm chart and extract image list
pull_helm_chart() {
    print_header "Pulling ESS Helm Chart"
    
    if ! command -v helm >/dev/null 2>&1; then
        print_error "Helm is not installed"
        print_info "Please install Helm first or run ./setup.sh"
        exit 1
    fi
    
    local CHART_NAME="matrix-stack"
    local CHART_REPO="oci://ghcr.io/element-hq/ess-helm"
    local CHART_FILE="${HELM_CACHE_DIR}/${CHART_NAME}.tgz"
    local CHART_DIR="${HELM_CACHE_DIR}/${CHART_NAME}"
    local CHART_OCI="${CHART_REPO}/${CHART_NAME}"
    
    # Check if chart already exists
    if [ -d "$CHART_DIR" ] || ls "${HELM_CACHE_DIR}"/${CHART_NAME}-*.tgz >/dev/null 2>&1; then
        print_info "Helm chart found in cache"
        
        # Check for updates using skopeo
        if check_skopeo; then
            print_info "Checking for chart updates..."
            local remote_digest=$(get_remote_digest "ghcr.io/element-hq/ess-helm/matrix-stack")
            local cached_digest=$(get_cached_digest "${CHART_DIR}")
            
            if [ -n "$remote_digest" ] && [ -n "$cached_digest" ] && [ "$remote_digest" = "$cached_digest" ]; then
                local chart_version=$(ls -t "${HELM_CACHE_DIR}"/${CHART_NAME}-*.tgz 2>/dev/null | head -1 | sed 's/.*matrix-stack-\(.*\)\.tgz/\1/' || echo "unknown")
                print_success "Using cached Helm chart v${chart_version}"
                return 0
            elif [ -n "$remote_digest" ] && [ "$remote_digest" != "$cached_digest" ]; then
                print_info "New chart version available, updating..."
            fi
        fi
        
        print_info "Removing existing chart..."
        rm -rf "$CHART_DIR"
        rm -f "${HELM_CACHE_DIR}"/${CHART_NAME}-*.tgz
        rm -f "${CHART_DIR}.digest"
    fi
    
    print_info "Pulling Helm chart: ${CHART_REPO}/${CHART_NAME}"
    
    # Pull chart
    helm pull "${CHART_REPO}/${CHART_NAME}" -d "$HELM_CACHE_DIR" --untar
    
    # Also save as tarball
    helm pull "${CHART_REPO}/${CHART_NAME}" -d "$HELM_CACHE_DIR"
    
    # Save digest if we can get it
    if check_skopeo; then
        local digest=$(get_remote_digest "ghcr.io/element-hq/ess-helm/matrix-stack")
        if [ -n "$digest" ]; then
            save_digest "$CHART_DIR" "$digest"
            print_info "Saved chart digest: ${digest:0:19}..."
        fi
    fi
    
    print_success "Helm chart cached"
    
    # Extract version
    local CHART_VERSION=$(ls -t "${HELM_CACHE_DIR}"/${CHART_NAME}-*.tgz | head -1 | sed 's/.*matrix-stack-\(.*\)\.tgz/\1/')
    print_info "Chart version: $CHART_VERSION"
}

# Get image list from Helm chart
get_ess_images() {
    local CHART_DIR="${HELM_CACHE_DIR}/matrix-stack"
    local VALUES_FILE="${CHART_DIR}/values.yaml"
    
    if [ ! -d "$CHART_DIR" ]; then
        print_error "Helm chart not found. Please pull it first."
        return 1
    fi
    
    if [ ! -f "$VALUES_FILE" ]; then
        print_error "values.yaml not found in chart directory"
        return 1
    fi
    
    # Extract image repository and tag pairs from values.yaml
    # This uses a simple grep-based parser since the values.yaml has a consistent structure
    local IMAGES=()
    
    # Parse registry:repository:tag triplets
    local temp_file=$(mktemp)
    
    # Extract lines with registry, repository and tag
    grep -E "^\s+registry:|^\s+repository:|^\s+tag:" "$VALUES_FILE" > "$temp_file"
    
    local current_registry=""
    local current_repo=""
    local default_registry="ghcr.io"
    
    while IFS= read -r line; do
        if echo "$line" | grep -q "registry:"; then
            # Extract registry
            current_registry=$(echo "$line" | sed 's/.*registry:\s*//;s/["'\'']//g;s/\s*$//')
        elif echo "$line" | grep -q "repository:"; then
            # Extract repository name
            current_repo=$(echo "$line" | sed 's/.*repository:\s*//;s/["'\'']//g;s/\s*$//')
        elif echo "$line" | grep -q "tag:" && [ -n "$current_repo" ]; then
            # Extract tag
            local tag=$(echo "$line" | sed 's/.*tag:\s*//;s/["'\'']//g;s/\s*$//')
            
            if [ -n "$tag" ]; then
                # Determine the full image reference
                local full_image=""
                
                # Use current_registry if set, otherwise use default
                local registry="${current_registry:-$default_registry}"
                
                # Handle special cases for repository paths
                if [[ "$current_repo" =~ ^library/ ]]; then
                    # Docker Hub library images - strip library/ prefix and use docker.io
                    local repo_name=$(echo "$current_repo" | sed 's/^library\///')
                    full_image="docker.io/${repo_name}:${tag}"
                elif [[ "$current_repo" =~ / ]]; then
                    # Repository already has a path (org/name)
                    full_image="${registry}/${current_repo}:${tag}"
                else
                    # Simple repository name
                    full_image="${registry}/${current_repo}:${tag}"
                fi
                
                IMAGES+=("$full_image")
            fi
            
            # Reset for next triplet (but keep registry as it might be inherited)
            current_repo=""
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    # Remove duplicates and sort
    local UNIQUE_IMAGES=($(printf '%s\n' "${IMAGES[@]}" | sort -u))
    
    # Save image list
    printf '%s\n' "${UNIQUE_IMAGES[@]}" > "${CACHE_DIR}/ess-images-list.txt"
    
    # Return array (only to stdout, no print messages)
    printf '%s\n' "${UNIQUE_IMAGES[@]}"
}

# Pull and save ESS images
cache_ess_images() {
    print_header "Caching ESS Container Images"
    
    # Get images into an array
    local IMAGES_LIST=$(get_ess_images)
    readarray -t IMAGES <<< "$IMAGES_LIST"
    
    print_info "Found ${#IMAGES[@]} images to cache"
    print_info "Pulling and caching all ESS images..."
    print_warning "This will download several GB of data"
    echo ""
    
    local count=0
    local total=${#IMAGES[@]}
    
    for image in "${IMAGES[@]}"; do
        count=$((count + 1))
        print_info "[$count/$total] Processing: $image"
        
        # Create safe filename
        local filename=$(echo "$image" | tr '/:' '_')
        local image_file="${ESS_IMAGES_DIR}/${filename}.tar"
        
        # Check if update is needed
        if [ -f "$image_file" ]; then
            if needs_update "$image" "$image_file"; then
                print_info "  New version available, updating..."
                rm -f "$image_file" "${image_file}.digest"
            else
                print_success "  Using cached version ($(du -h "$image_file" | cut -f1))"
                echo ""
                continue
            fi
        fi
        
        # Pull image
        if docker pull "$image" 2>/dev/null; then
            # Get digest and save
            local digest=$(get_remote_digest "$image")
            
            # Save image
            docker save -o "$image_file" "$image"
            
            if [ -n "$digest" ]; then
                save_digest "$image_file" "$digest"
            fi
            
            print_success "  Cached: $(du -h "$image_file" | cut -f1)"
        else
            print_warning "  Failed to pull: $image (may not exist or network issue)"
        fi
        echo ""
    done
    
    print_success "ESS images cached"
}

# Pull NGINX Ingress images
cache_nginx_ingress() {
    print_header "Caching NGINX Ingress Images"
    
    local NGINX_IMAGES=(
        "registry.k8s.io/ingress-nginx/controller:v1.8.1"
        "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230407"
    )
    
    for image in "${NGINX_IMAGES[@]}"; do
        print_info "Pulling: $image"
        
        local filename=$(echo "$image" | tr '/:' '_')
        local image_file="${ESS_IMAGES_DIR}/${filename}.tar"
        
        # Check if update is needed
        if [ -f "$image_file" ]; then
            if needs_update "$image" "$image_file"; then
                print_info "  New version available, updating..."
                rm -f "$image_file" "${image_file}.digest"
            else
                print_success "  Using cached version ($(du -h "$image_file" | cut -f1))"
                continue
            fi
        fi
        
        if docker pull "$image"; then
            # Get digest and save
            local digest=$(get_remote_digest "$image")
            
            docker save -o "$image_file" "$image"
            
            if [ -n "$digest" ]; then
                save_digest "$image_file" "$digest"
            fi
            
            print_success "Cached: $(du -h "$image_file" | cut -f1)"
        else
            print_warning "Failed to pull: $image"
        fi
    done
}

# Create manifest file
create_manifest() {
    print_header "Creating Cache Manifest"
    
    local MANIFEST="${CACHE_DIR}/MANIFEST.txt"
    
    cat > "$MANIFEST" <<EOF
ESS Community Demo - Image Cache Manifest
Generated: $(date)
═══════════════════════════════════════════════════════════

Kind Node Images:
$(ls -lh "${KIND_IMAGES_DIR}"/*.tar 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  None")

ESS Component Images:
$(ls -lh "${ESS_IMAGES_DIR}"/*.tar 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  None")

Helm Charts:
$(ls -lh "${HELM_CACHE_DIR}"/*.tgz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  None")

Total Cache Size:
$(du -sh "$CACHE_DIR" | cut -f1)

═══════════════════════════════════════════════════════════
To use this cache:
1. Copy the entire image-cache/ directory with your demo
2. Run: ./load-cached-images.sh
3. Run: ./setup.sh --offline
EOF
    
    print_success "Manifest created: $MANIFEST"
    cat "$MANIFEST"
}

# Create load script
create_load_script() {
    print_header "Creating Load Script"
    
    cat > "${SCRIPT_DIR}/load-cached-images.sh" <<'EOF'
#!/bin/bash
# Load cached images into Docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${SCRIPT_DIR}/image-cache"

echo "Loading cached images into Docker..."

# Load Kind images
for img in "${CACHE_DIR}/kind-images"/*.tar; do
    if [ -f "$img" ]; then
        echo "Loading: $(basename "$img")"
        docker load -i "$img"
    fi
done

# Load ESS images
for img in "${CACHE_DIR}/ess-images"/*.tar; do
    if [ -f "$img" ]; then
        echo "Loading: $(basename "$img")"
        docker load -i "$img"
    fi
done

echo "✓ All cached images loaded into Docker"
EOF
    
    chmod +x "${SCRIPT_DIR}/load-cached-images.sh"
    print_success "Created: load-cached-images.sh"
}

# Summary
show_summary() {
    print_header "Cache Complete!"
    
    local total_size=$(du -sh "$CACHE_DIR" | cut -f1)
    
    echo ""
    print_success "All images and charts cached successfully"
    echo ""
    print_info "Cache location: $CACHE_DIR"
    print_info "Total size: $total_size"
    echo ""
    print_info "Cached components:"
    echo "  ✓ Kind node image"
    echo "  ✓ ESS Helm chart"
    echo "  ✓ ESS container images"
    echo "  ✓ NGINX Ingress images"
    echo ""
    print_info "For air-gapped deployment:"
    echo "  1. Copy this entire directory to your target machine"
    echo "  2. Run: ./load-cached-images.sh"
    echo "  3. Run: ./setup.sh"
    echo ""
    print_info "Manifest: ${CACHE_DIR}/MANIFEST.txt"
    echo ""
}

# Main execution
main() {
    # Parse command line arguments
    local auto_yes=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                auto_yes=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [-y|--yes] [-h|--help]"
                echo ""
                echo "Options:"
                echo "  -y, --yes    Skip confirmation prompt"
                echo "  -h, --help   Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
    
    print_header "ESS Community Demo - Image Cache Builder"
    
    echo ""
    print_info "This script will download and cache:"
    echo "  • Kind node image (~400MB)"
    echo "  • ESS Helm chart"
    echo "  • All ESS container images (~2-3GB)"
    echo "  • NGINX Ingress images (~200MB)"
    echo ""
    print_warning "Total download: ~3-4GB"
    print_warning "Requires Docker to be running"
    echo ""
    
    # Check for skopeo
    if check_skopeo; then
        print_success "skopeo detected - will perform smart version checking"
        print_info "Only new/updated images will be downloaded"
    else
        print_info "skopeo not found - will cache all images"
        print_info "Install skopeo for faster version checking (optional)"
    fi
    echo ""
    
    # Confirmation prompt (skip if -y flag is used)
    if [ "$auto_yes" = false ]; then
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            exit 0
        fi
    fi
    
    # Execute caching steps
    check_docker
    create_cache_dirs
    download_kind_image
    pull_helm_chart
    cache_ess_images
    cache_nginx_ingress
    create_manifest
    create_load_script
    show_summary
}

# Run main function
main "$@"

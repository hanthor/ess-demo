#!/bin/bash
# Load cached images into Docker or Podman
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${SCRIPT_DIR}/image-cache"

# Source container runtime utilities
source "${SCRIPT_DIR}/container-runtime.sh"

# Detect container runtime
CONTAINER_RUNTIME=$(detect_container_runtime)
if [ -z "$CONTAINER_RUNTIME" ]; then
    echo "✗ Error: No container runtime found. Install Docker or Podman."
    exit 1
fi

echo "Using container runtime: $CONTAINER_RUNTIME"
echo "Loading cached images into ${CONTAINER_RUNTIME}..."
echo ""

# Load Kind images
if [ -d "${CACHE_DIR}/kind-images" ]; then
    for img in "${CACHE_DIR}/kind-images"/*.tar; do
        if [ -f "$img" ]; then
            echo "Loading: $(basename "$img")"
            container_load_image "$img" "$CONTAINER_RUNTIME"
        fi
    done
fi

# Load ESS images
if [ -d "${CACHE_DIR}/ess-images" ]; then
    for img in "${CACHE_DIR}/ess-images"/*.tar; do
        if [ -f "$img" ]; then
            echo "Loading: $(basename "$img")"
            container_load_image "$img" "$CONTAINER_RUNTIME"
        fi
    done
fi

echo ""
echo "✓ All cached images loaded into ${CONTAINER_RUNTIME}"

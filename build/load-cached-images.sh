#!/bin/bash
# Load cached images into Docker or Podman (runtime autodetected)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${SCRIPT_DIR}/image-cache"

# Try to source runtime helper if available
if [ -f "${SCRIPT_DIR}/../build/container-runtime.sh" ]; then
    source "${SCRIPT_DIR}/../build/container-runtime.sh"
fi

RUNTIME="docker"
if command -v detect_container_runtime >/dev/null 2>&1; then
    RUNTIME=$(detect_container_runtime)
fi

echo "Loading cached images into ${RUNTIME}..."

# Load Kind images
for img in "${CACHE_DIR}/kind-images"/*.tar; do
    if [ -f "$img" ]; then
        echo "Loading: $(basename "$img")"
        if command -v container_load_image >/dev/null 2>&1; then
            container_load_image "$img" "$RUNTIME"
        else
            ${RUNTIME} load -i "$img"
        fi
    fi
done

# Load ESS images
for img in "${CACHE_DIR}/ess-images"/*.tar; do
    if [ -f "$img" ]; then
        echo "Loading: $(basename "$img")"
        if command -v container_load_image >/dev/null 2>&1; then
            container_load_image "$img" "$RUNTIME"
        else
            ${RUNTIME} load -i "$img"
        fi
    fi
done

echo "✓ All cached images loaded into ${RUNTIME}"

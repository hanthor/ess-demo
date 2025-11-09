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

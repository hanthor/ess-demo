#!/bin/bash
# Use Hauler to sync and package ESS demo artifacts for air-gapped deployment

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HAULER_STORE_DIR="${PROJECT_ROOT}/hauler-store"
HAULER_MANIFEST="${PROJECT_ROOT}/hauler-manifest.yaml"

# Check if Hauler is installed
if ! command -v hauler >/dev/null 2>&1; then
    print_error "Hauler is not installed"
    print_info "Run: ./build/setup-hauler.sh"
    exit 1
fi

print_header "Hauler Artifact Sync for ESS Demo"

# Ensure manifest exists
if [ ! -f "$HAULER_MANIFEST" ]; then
    print_error "Hauler manifest not found: $HAULER_MANIFEST"
    exit 1
fi

print_info "Using manifest: $HAULER_MANIFEST"
print_info "Store directory: $HAULER_STORE_DIR"

# Create store directory
mkdir -p "$HAULER_STORE_DIR"

# Initialize or use existing store
cd "$HAULER_STORE_DIR"

print_header "Syncing Artifacts"

# Sync artifacts from manifest
print_info "Syncing artifacts (this may take several minutes)..."
if hauler store sync --files "$HAULER_MANIFEST" --store "$HAULER_STORE_DIR"; then
    print_success "Artifacts synced successfully"
else
    print_error "Failed to sync artifacts"
    exit 1
fi

# Show what was downloaded
print_header "Store Contents"
hauler store info --store "$HAULER_STORE_DIR" || true

# Save store to compressed archive
print_header "Creating Portable Archive"

ARCHIVE_NAME="ess-hauler-store-$(date +%Y%m%d-%H%M%S).tar.zst"
print_info "Creating archive: $ARCHIVE_NAME"

if hauler store save --filename "${PROJECT_ROOT}/${ARCHIVE_NAME}" --store "$HAULER_STORE_DIR"; then
    print_success "Archive created: ${PROJECT_ROOT}/${ARCHIVE_NAME}"
    
    # Show archive size
    ARCHIVE_SIZE=$(du -h "${PROJECT_ROOT}/${ARCHIVE_NAME}" | cut -f1)
    print_info "Archive size: $ARCHIVE_SIZE"
else
    print_error "Failed to create archive"
    exit 1
fi

print_header "Hauler Sync Complete"
echo ""
print_success "All artifacts have been collected and packaged"
echo ""
print_info "To use this in an air-gapped environment:"
echo "  1. Copy ${ARCHIVE_NAME} to target machine"
echo "  2. Install Hauler: ./build/setup-hauler.sh"
echo "  3. Load store:  hauler store load ${ARCHIVE_NAME}"
echo "  4. Extract or serve artifacts as needed"
echo ""
print_info "Alternative: Serve as registry"
echo "  hauler store serve registry --store hauler-store"
echo ""

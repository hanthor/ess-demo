#!/bin/bash
set -euo pipefail

pkg_dir="$1"
runtime_dir="$(dirname "$pkg_dir")/../runtime/macos"

mkdir -p "$pkg_dir"

# Copy runtime scripts
if [ -d "$runtime_dir" ]; then
    cp "$runtime_dir/setup.sh" "$pkg_dir/" 2>/dev/null || true
    cp "$runtime_dir/verify.sh" "$pkg_dir/" 2>/dev/null || true
    cp "$runtime_dir/cleanup.sh" "$pkg_dir/" 2>/dev/null || true
    cp "$runtime_dir/build-certs.sh" "$pkg_dir/" 2>/dev/null || true
    chmod +x "$pkg_dir"/*.sh 2>/dev/null || true
fi

# Create INSTALL.md
cat > "$pkg_dir/INSTALL.md" << 'EOF'
# ESS Community Demo - macOS Installation

## Prerequisites

- macOS 11+ (Intel or Apple Silicon)
- ~10GB free disk space
- Administrator privileges

## Installation Steps

1. **Extract the package:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

2. **Verify installation:**
   ```bash
   ./verify.sh
   ```

3. **Access the demo:**
   Open https://chat.ess.localhost in your browser

## Troubleshooting

See TROUBLESHOOTING.md for common issues.
EOF

# Create install.sh
cat > "$pkg_dir/install.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$SCRIPT_DIR/ess-demo.tar.gz" ]; then
    echo "Error: ess-demo.tar.gz not found"
    exit 1
fi

echo "Extracting ESS Demo..."
tar -xzf "$SCRIPT_DIR/ess-demo.tar.gz" -C "$PARENT_DIR"

echo "Setting permissions..."
chmod +x "$PARENT_DIR/setup.sh"
chmod +x "$PARENT_DIR/verify.sh"
chmod +x "$PARENT_DIR/cleanup.sh"
chmod +x "$PARENT_DIR/download-installers.sh"
chmod +x "$PARENT_DIR/cache-images.sh"

echo ""
echo "✓ ESS Demo extracted successfully!"
echo ""
echo "Next steps:"
echo "  cd .."
echo "  ./setup.sh"
EOF
chmod +x "$pkg_dir/install.sh"

# Create extract-installers.sh
cat > "$pkg_dir/extract-installers.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLERS_DIR="$SCRIPT_DIR/../installers"

echo "Extracting installers..."

if [ -f "$SCRIPT_DIR/installers-macos.tar.gz" ]; then
    tar -xzf "$SCRIPT_DIR/installers-macos.tar.gz" -C "$INSTALLERS_DIR"
    echo "✓ macOS installers extracted"
fi

echo ""
echo "Installers ready for use!"
EOF
chmod +x "$pkg_dir/extract-installers.sh"

echo "✓ macOS package structure created"

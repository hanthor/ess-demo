# ESS Demo Air-gapped Package - Justfile
# Ansible-based workflow for building and testing air-gapped packages
# 
# Ansible arguments can be passed to any recipe:
#   just download-installers -vvv
#   just setup-k3s -K
#   just deploy-ess -vvv -K
# 
# Common Ansible args:
#   -vvv           - Extra verbose (debug)
#   -K              - Ask for become password (sudo)
#   -C              - Check mode (dry run)
#   --syntax-check  - Validate syntax only
#   -e VAR=VALUE    - Set extra variables

# Default recipe - show help
default:
    @just --list

# =============================================================================
# Build Workflow (with internet)
# =============================================================================

# Full build: download installers → setup k3s → deploy ESS → capture images
# Usage: just build -vvv
build ARGS='': download-installers setup-k3s deploy-ess capture-images
    @echo "✅ Full build complete!"
    @echo "📦 Hauler store ready at: hauler-store/"
    @echo "🔧 Installers ready at: installers/"

# Download all installer binaries (Linux, macOS, Windows - multi-arch)
# Usage: just download-installers -vvv
download-installers ARGS='':
    @echo "📥 Downloading installer binaries for all platforms..."
    ansible-playbook -i ansible/inventory.ini ansible/setup-playbook.yml --tags installers {{ ARGS }}

# Setup local k3s cluster for image capture
# Usage: just setup-k3s -K -vvv
setup-k3s ARGS='':
    @echo "🚀 Setting up local k3s cluster..."
    ansible-playbook -i ansible/inventory.ini ansible/setup-playbook.yml --tags k3s {{ ARGS }}

# Deploy ESS to local k3s cluster
# Usage: just deploy-ess -vvv
deploy-ess ARGS='':
    @echo "🎯 Deploying ESS to k3s..."
    ansible-playbook -i ansible/inventory.ini ansible/setup-playbook.yml --tags ess,deploy {{ ARGS }}

# Capture all cluster images with hauler
# Usage: just capture-images -vvv
capture-images ARGS='':
    @echo "📸 Capturing cluster images with hauler..."
    ansible-playbook -i ansible/inventory.ini ansible/setup-playbook.yml --tags hauler,capture {{ ARGS }}

# =============================================================================
# Package Management
# =============================================================================

# Create per-OS air-gapped packages (Linux, macOS, Windows)
# Usage: just package -vvv
package ARGS='':
    @echo "📦 Creating per-OS air-gapped packages..."
    ansible-playbook -i ansible/inventory.ini ansible/setup-playbook.yml --tags packaging {{ ARGS }}

# =============================================================================
# Testing & Validation
# =============================================================================

# Test air-gapped deployment (extract and validate package)
# Usage: just test-airgap -vvv
test-airgap ARGS='':
    @echo "🧪 Testing air-gapped deployment..."
    ansible-playbook -i ansible/inventory.ini ansible/test-airgapped.yml {{ ARGS }}

# Verify hauler store contents
verify-store:
    @echo "🔍 Verifying hauler store..."
    @if [ -d hauler-store ]; then \
        hauler store info --store hauler-store; \
    else \
        echo "❌ hauler-store/ not found. Run 'just capture-images' first."; \
        exit 1; \
    fi

# =============================================================================
# Cluster Management
# =============================================================================

# Check k3s cluster status
status:
    @echo "📊 Checking k3s cluster status..."
    @if command -v k3s >/dev/null 2>&1; then \
        sudo k3s kubectl get nodes; \
        echo ""; \
        sudo k3s kubectl get pods -A; \
    else \
        echo "❌ k3s not installed. Run 'just setup-k3s' first."; \
        exit 1; \
    fi

# Get kubeconfig for local k3s
kubeconfig:
    @echo "📄 Kubeconfig location:"
    @if [ -f /etc/rancher/k3s/k3s.yaml ]; then \
        echo "/etc/rancher/k3s/k3s.yaml"; \
        echo ""; \
        echo "Export with:"; \
        echo "  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"; \
    else \
        echo "❌ k3s kubeconfig not found. Run 'just setup-k3s' first."; \
    fi

# =============================================================================
# Cleanup
# =============================================================================

# Clean all build artifacts
clean: clean-installers clean-hauler clean-k3s
    @echo "🧹 All build artifacts cleaned"

# Remove downloaded installers
clean-installers:
    @echo "🧹 Removing installers..."
    rm -rf installers/

# Remove hauler store
clean-hauler:
    @echo "🧹 Removing hauler store..."
    rm -rf hauler-store/ hauler-installers-manifest.yaml

# Uninstall k3s cluster
clean-k3s:
    @echo "🧹 Uninstalling k3s..."
    @if [ -f /usr/local/bin/k3s-uninstall.sh ]; then \
        sudo /usr/local/bin/k3s-uninstall.sh; \
    else \
        echo "ℹ️  k3s not installed or already cleaned"; \
    fi

# Clean everything including certs
clean-all: clean
    @echo "🧹 Removing certificates..."
    rm -rf certs/
    @echo "🧹 Removing kubeconfig copy..."
    rm -f k3s-kubeconfig.yaml

# =============================================================================
# Development & Debugging
# =============================================================================

# Run specific Ansible role for debugging
# Usage: just debug-role installers -vvv
debug-role ROLE ARGS='-vvv':
    @echo "🐛 Running role: {{ ROLE }}"
    ansible-playbook -i ansible/inventory.ini ansible/setup-playbook.yml --tags {{ ROLE }} {{ ARGS }}

# Show Ansible inventory
show-inventory:
    @echo "📋 Ansible inventory:"
    @cat ansible/inventory.ini

# Validate Ansible playbook syntax
validate:
    @echo "✅ Validating Ansible playbook..."
    ansible-playbook --syntax-check ansible/setup-playbook.yml

# =============================================================================
# Information & Help
# =============================================================================

# Show workflow documentation
docs:
    @echo "📚 ESS Demo Air-gapped Package Workflow"
    @echo ""
    @echo "Build Workflow (with internet):"
    @echo "  1. just download-installers  - Download all binaries"
    @echo "  2. just setup-k3s            - Setup local k3s cluster"
    @echo "  3. just deploy-ess           - Deploy ESS to k3s"
    @echo "  4. just capture-images       - Capture images with hauler"
    @echo "  5. just package              - Create OS packages"
    @echo ""
    @echo "Or run everything:"
    @echo "  just build                   - Full build workflow"
    @echo ""
    @echo "Testing & Validation:"
    @echo "  just test-airgap             - Test air-gapped deployment"
    @echo "  just verify-store            - Check hauler store contents"
    @echo "  just status                  - Check k3s cluster status"
    @echo ""
    @echo "Cleanup:"
    @echo "  just clean                   - Remove all build artifacts"
    @echo "  just clean-k3s               - Uninstall k3s only"
    @echo ""
    @echo "📋 All recipes accept Ansible arguments:"
    @echo "  just deploy-ess -vvv         - Verbose output"
    @echo "  just setup-k3s -K            - Ask for sudo password"
    @echo "  just capture-images -C       - Dry-run (check mode)"
    @echo "  just debug-role installers   - Debug specific role"
    @echo ""
    @echo "See ANSIBLE-ARGS.md for complete argument reference"
    @echo "See IMPLEMENTATION-SUMMARY.md for architecture overview"
    @echo "See TODO.md for detailed task breakdown"

# Show versions of installed components
versions:
    @echo "🔢 Component Versions:"
    @echo ""
    @echo "Ansible:"
    @ansible --version | head -n 1
    @echo ""
    @if command -v k3s >/dev/null 2>&1; then \
        echo "k3s:"; \
        k3s --version | head -n 1; \
        echo ""; \
    fi
    @if command -v kubectl >/dev/null 2>&1; then \
        echo "kubectl:"; \
        kubectl version --client --short 2>/dev/null || kubectl version --client; \
        echo ""; \
    fi
    @if command -v helm >/dev/null 2>&1; then \
        echo "helm:"; \
        helm version --short; \
        echo ""; \
    fi
    @if command -v hauler >/dev/null 2>&1; then \
        echo "hauler:"; \
        hauler version; \
    fi

# Show disk usage of build artifacts
disk-usage:
    @echo "💾 Disk Usage:"
    @echo ""
    @if [ -d installers ]; then \
        echo "installers/:"; \
        du -sh installers/ 2>/dev/null || echo "  (empty)"; \
    fi
    @if [ -d hauler-store ]; then \
        echo "hauler-store/:"; \
        du -sh hauler-store/ 2>/dev/null || echo "  (empty)"; \
    fi
    @if [ -d /var/lib/rancher/k3s ]; then \
        echo "k3s data:"; \
        sudo du -sh /var/lib/rancher/k3s 2>/dev/null || echo "  (not accessible)"; \
    fi

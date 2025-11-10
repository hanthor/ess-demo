#!/usr/bin/env bash
# Generate hauler manifest from ESS Helm chart values
# This ensures the hauler manifest stays in sync with the actual ESS dependencies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST_FILE="${PROJECT_ROOT}/hauler-manifest.yaml"
CHART_VALUES="${PROJECT_ROOT}/image-cache/helm-charts/matrix-stack/values.yaml"

if [[ ! -f "${CHART_VALUES}" ]]; then
    echo "Error: ESS Helm chart values not found at ${CHART_VALUES}"
    echo "Run 'just setup' first to download the chart"
    exit 1
fi

echo "Generating hauler manifest from ESS Helm chart..."

# Extract images from values.yaml
# Format: registry/repository:tag
extract_images() {
    local values_file="$1"
    
    # Use awk to parse the YAML and extract image references
    # This looks for registry, repository, and tag fields and combines them
    awk '
    BEGIN { registry = ""; repository = ""; tag = "" }
    
    # Match registry field
    /^[[:space:]]*registry:/ {
        registry = $2
        gsub(/^["\047]|["\047]$/, "", registry)  # Remove quotes
    }
    
    # Match repository field
    /^[[:space:]]*repository:/ {
        repository = $2
        gsub(/^["\047]|["\047]$/, "", repository)
    }
    
    # Match tag field
    /^[[:space:]]*tag:/ {
        tag = $2
        gsub(/^["\047]|["\047]$/, "", tag)
        
        # When we have all three, output the full image reference
        if (registry != "" && repository != "" && tag != "") {
            if (registry == "docker.io") {
                # Docker Hub - handle library/ prefix
                if (repository ~ /^library\//) {
                    # Remove library/ prefix for official images
                    sub(/^library\//, "", repository)
                }
                print "    - name: docker.io/" repository ":" tag
            } else {
                print "    - name: " registry "/" repository ":" tag
            }
            
            # Reset for next image
            registry = ""
            repository = ""
            tag = ""
        }
    }
    ' "$values_file" | sort -u
}

# Generate the manifest
cat > "${MANIFEST_FILE}" << 'EOF'
# Hauler Manifest for ESS Demo
# This manifest is AUTO-GENERATED from the ESS Helm chart values
# DO NOT EDIT MANUALLY - Run 'build/generate-hauler-manifest.sh' to regenerate
# Usage: hauler store sync --files hauler-manifest.yaml

apiVersion: content.hauler.cattle.io/v1alpha1
kind: Images
metadata:
  name: ess-demo-images
spec:
  images:
    # Kind node image for Kubernetes cluster
    - name: docker.io/kindest/node:v1.31.2

    # NGINX Ingress Controller (infrastructure dependency)
    - name: registry.k8s.io/ingress-nginx/controller:v1.9.4
    - name: registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20231011-8b53cabe0

    # ESS Component Images (extracted from Helm chart)
EOF

# Add extracted images
extract_images "${CHART_VALUES}" >> "${MANIFEST_FILE}"

# Add Charts section
cat >> "${MANIFEST_FILE}" << 'EOF'

---
apiVersion: content.hauler.cattle.io/v1alpha1
kind: Charts
metadata:
  name: ess-demo-charts
spec:
  charts:
    # ESS Helm Chart
    - name: matrix-stack
      repoURL: oci://ghcr.io/element-hq/ess-helm
      version: latest

    # NGINX Ingress Helm Chart
    - name: ingress-nginx
      repoURL: https://kubernetes.github.io/ingress-nginx
      version: 4.8.3

---
apiVersion: content.hauler.cattle.io/v1alpha1
kind: Files
metadata:
  name: ess-demo-files
spec:
  files:
    # Kind binary
    - path: https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
      name: kind-linux-amd64
    - path: https://kind.sigs.k8s.io/dl/v0.24.0/kind-darwin-amd64
      name: kind-darwin-amd64
    - path: https://kind.sigs.k8s.io/dl/v0.24.0/kind-darwin-arm64
      name: kind-darwin-arm64

    # kubectl binary
    - path: https://dl.k8s.io/release/v1.31.3/bin/linux/amd64/kubectl
      name: kubectl-linux-amd64
    - path: https://dl.k8s.io/release/v1.31.3/bin/darwin/amd64/kubectl
      name: kubectl-darwin-amd64
    - path: https://dl.k8s.io/release/v1.31.3/bin/darwin/arm64/kubectl
      name: kubectl-darwin-arm64

    # Helm binary
    - path: https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
      name: helm-linux-amd64.tar.gz
    - path: https://get.helm.sh/helm-v3.16.3-darwin-amd64.tar.gz
      name: helm-darwin-amd64.tar.gz
    - path: https://get.helm.sh/helm-v3.16.3-darwin-arm64.tar.gz
      name: helm-darwin-arm64.tar.gz

    # K9s binary
    - path: https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_Linux_amd64.tar.gz
      name: k9s_Linux_amd64.tar.gz
    - path: https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_Darwin_amd64.tar.gz
      name: k9s_Darwin_amd64.tar.gz
    - path: https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_Darwin_arm64.tar.gz
      name: k9s_Darwin_arm64.tar.gz

    # mkcert binary
    - path: https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
      name: mkcert-linux-amd64
    - path: https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-darwin-amd64
      name: mkcert-darwin-amd64
    - path: https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-darwin-arm64
      name: mkcert-darwin-arm64

    # Container Runtime Installers
    # Rancher Desktop for macOS
    - path: https://github.com/rancher-sandbox/rancher-desktop/releases/download/v1.16.0/Rancher.Desktop-1.16.0.aarch64.dmg
      name: Rancher.Desktop-arm64.dmg
    - path: https://github.com/rancher-sandbox/rancher-desktop/releases/download/v1.16.0/Rancher.Desktop-1.16.0.x86_64.dmg
      name: Rancher.Desktop-amd64.dmg
    
    # Rancher Desktop for Windows
    - path: https://github.com/rancher-sandbox/rancher-desktop/releases/download/v1.16.0/Rancher.Desktop.Setup.1.16.0.msi
      name: Rancher.Desktop.Setup.msi
EOF

echo "✓ Generated hauler manifest at ${MANIFEST_FILE}"
echo ""
echo "Images extracted from ESS Helm chart:"
extract_images "${CHART_VALUES}" | sed 's/^    - name: /  - /'

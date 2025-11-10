#!/usr/bin/env bash
# Generate hauler manifest from ESS Helm chart values
# This ensures the hauler manifest stays in sync with the actual ESS dependencies
# Gets latest versions dynamically from sources

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST_FILE="${PROJECT_ROOT}/hauler-manifest.yaml"
CHART_VALUES="${PROJECT_ROOT}/image-cache/helm-charts/matrix-stack/values.yaml"

# Source version utilities to get latest versions
source "${SCRIPT_DIR}/version-utils.sh"

if [[ ! -f "${CHART_VALUES}" ]]; then
    echo "Error: ESS Helm chart values not found at ${CHART_VALUES}"
    echo "Run 'just setup' first to download the chart"
    exit 1
fi

echo "Generating hauler manifest from ESS Helm chart..."
echo "Getting latest versions..."

# Get latest versions
K3S_VERSION="${K3S_VERSION:-$(get_latest_k3s_version || echo 'v1.31.3+k3s1')}"
RANCHER_DESKTOP_VERSION="${RANCHER_DESKTOP_VERSION:-$(get_latest_rancher_desktop_version || echo 'v1.16.0')}"
KUBECTL_VERSION="${KUBECTL_VERSION:-$(get_latest_kubectl_version || echo 'v1.31.3')}"
HELM_VERSION="${HELM_VERSION:-$(get_latest_helm_version || echo 'v3.16.3')}"
K9S_VERSION="${K9S_VERSION:-$(get_latest_k9s_version || echo 'v0.32.7')}"
MKCERT_VERSION="${MKCERT_VERSION:-$(get_latest_mkcert_version || echo 'v1.4.4')}"
PODMAN_VERSION="${PODMAN_VERSION:-$(get_latest_podman_version || echo 'v5.3.1')}"

echo "Using versions:"
echo "  K3s:              ${K3S_VERSION}"
echo "  Rancher Desktop:  ${RANCHER_DESKTOP_VERSION}"
echo "  kubectl:          ${KUBECTL_VERSION}"
echo "  Helm:             ${HELM_VERSION}"
echo "  k9s:              ${K9S_VERSION}"
echo "  mkcert:           ${MKCERT_VERSION}"
echo "  Podman:           ${PODMAN_VERSION}"
echo ""

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

# Remove 'v' prefix from Rancher Desktop version for download URLs
RD_VERSION_NUM="${RANCHER_DESKTOP_VERSION#v}"

# Generate the manifest
cat > "${MANIFEST_FILE}" << EOF
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
EOF

# Add K3s binaries
cat >> "${MANIFEST_FILE}" << EOF
    # K3s binary (Linux only)
    - path: https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s
      name: k3s-amd64
    - path: https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-arm64
      name: k3s-arm64

EOF

# Add kubectl binaries
cat >> "${MANIFEST_FILE}" << EOF
    # kubectl binary
    - path: https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
      name: kubectl-linux-amd64
    - path: https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/darwin/amd64/kubectl
      name: kubectl-darwin-amd64
    - path: https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/darwin/arm64/kubectl
      name: kubectl-darwin-arm64

EOF

# Add Helm binaries
cat >> "${MANIFEST_FILE}" << EOF
    # Helm binary
    - path: https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz
      name: helm-linux-amd64.tar.gz
    - path: https://get.helm.sh/helm-${HELM_VERSION}-darwin-amd64.tar.gz
      name: helm-darwin-amd64.tar.gz
    - path: https://get.helm.sh/helm-${HELM_VERSION}-darwin-arm64.tar.gz
      name: helm-darwin-arm64.tar.gz

EOF

# Add K9s binaries
cat >> "${MANIFEST_FILE}" << EOF
    # K9s binary
    - path: https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz
      name: k9s_Linux_amd64.tar.gz
    - path: https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Darwin_amd64.tar.gz
      name: k9s_Darwin_amd64.tar.gz
    - path: https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Darwin_arm64.tar.gz
      name: k9s_Darwin_arm64.tar.gz

EOF

# Add mkcert binaries
cat >> "${MANIFEST_FILE}" << EOF
    # mkcert binary
    - path: https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-linux-amd64
      name: mkcert-linux-amd64
    - path: https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-darwin-amd64
      name: mkcert-darwin-amd64
    - path: https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-darwin-arm64
      name: mkcert-darwin-arm64

EOF

# Add Rancher Desktop installers
cat >> "${MANIFEST_FILE}" << EOF
    # Container Runtime Installers
    # Rancher Desktop for macOS
    - path: https://github.com/rancher-sandbox/rancher-desktop/releases/download/${RANCHER_DESKTOP_VERSION}/Rancher.Desktop-${RD_VERSION_NUM}.aarch64.dmg
      name: Rancher.Desktop-arm64.dmg
    - path: https://github.com/rancher-sandbox/rancher-desktop/releases/download/${RANCHER_DESKTOP_VERSION}/Rancher.Desktop-${RD_VERSION_NUM}.x86_64.dmg
      name: Rancher.Desktop-amd64.dmg
    
    # Rancher Desktop for Windows
    - path: https://github.com/rancher-sandbox/rancher-desktop/releases/download/${RANCHER_DESKTOP_VERSION}/Rancher.Desktop.Setup.${RD_VERSION_NUM}.msi
      name: Rancher.Desktop.Setup.msi
EOF

echo "✓ Generated hauler manifest at ${MANIFEST_FILE}"
echo ""
echo "Images extracted from ESS Helm chart:"
extract_images "${CHART_VALUES}" | sed 's/^    - name: /  - /'
echo ""
echo "Note: Versions are fetched dynamically. Set environment variables to override."

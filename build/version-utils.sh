#!/bin/bash
# Version Utilities - Check latest versions of installers
# Functions to dynamically get the latest versions from GitHub releases and other sources

set -euo pipefail

# Get latest GitHub release version for a repository
# Usage: get_latest_github_release "owner/repo"
get_latest_github_release() {
    local repo="$1"
    local version=""
    
    # Try using GitHub API (no auth required for public repos)
    if command -v curl >/dev/null 2>&1; then
        version=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
    elif command -v wget >/dev/null 2>&1; then
        version=$(wget -qO- "https://api.github.com/repos/${repo}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
    fi
    
    echo "$version"
}

# Get latest K3s version
get_latest_k3s_version() {
    local version=$(get_latest_github_release "k3s-io/k3s")
    echo "$version"
}

# Get latest Rancher Desktop version
get_latest_rancher_desktop_version() {
    local version=$(get_latest_github_release "rancher-sandbox/rancher-desktop")
    echo "$version"
}

# Get latest kubectl version
get_latest_kubectl_version() {
    local version=""
    
    if command -v curl >/dev/null 2>&1; then
        version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    elif command -v wget >/dev/null 2>&1; then
        version=$(wget -qO- https://dl.k8s.io/release/stable.txt)
    fi
    
    echo "$version"
}

# Get latest Helm version
get_latest_helm_version() {
    local version=$(get_latest_github_release "helm/helm")
    echo "$version"
}

# Get latest k9s version
get_latest_k9s_version() {
    local version=$(get_latest_github_release "derailed/k9s")
    echo "$version"
}

# Get latest mkcert version
get_latest_mkcert_version() {
    local version=$(get_latest_github_release "FiloSottile/mkcert")
    echo "$version"
}

# Get latest Podman version
get_latest_podman_version() {
    local version=$(get_latest_github_release "containers/podman")
    echo "$version"
}

# Get latest Ansible version from PyPI
get_latest_ansible_version() {
    local version=""
    
    if command -v curl >/dev/null 2>&1; then
        version=$(curl -s https://pypi.org/pypi/ansible/json | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
    elif command -v wget >/dev/null 2>&1; then
        version=$(wget -qO- https://pypi.org/pypi/ansible/json | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
    fi
    
    echo "$version"
}

# Get latest zstd version
get_latest_zstd_version() {
    local version=$(get_latest_github_release "facebook/zstd")
    echo "$version"
}

# Get latest Hauler version
get_latest_hauler_version() {
    local version=$(get_latest_github_release "rancherfederal/hauler")
    echo "$version"
}

# Print all latest versions
print_all_latest_versions() {
    echo "Latest versions:"
    echo "  K3s:              $(get_latest_k3s_version)"
    echo "  Rancher Desktop:  $(get_latest_rancher_desktop_version)"
    echo "  kubectl:          $(get_latest_kubectl_version)"
    echo "  Helm:             $(get_latest_helm_version)"
    echo "  k9s:              $(get_latest_k9s_version)"
    echo "  mkcert:           $(get_latest_mkcert_version)"
    echo "  Podman:           $(get_latest_podman_version)"
    echo "  Ansible:          $(get_latest_ansible_version)"
    echo "  zstd:             $(get_latest_zstd_version)"
    echo "  Hauler:           $(get_latest_hauler_version)"
}

# If script is run directly (not sourced), print all versions
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_all_latest_versions
fi

#!/bin/bash
# Container Runtime Detection and Utilities
# Supports K3s, Rancher Desktop, Docker, Podman
# Source this script to use the functions

set -euo pipefail

# Detect available Kubernetes runtime
# Returns: k3s, rancher-desktop, docker, podman, podman-rootful, or empty string if none found
detect_k8s_runtime() {
    # Check for K3s first (Linux)
    if command -v k3s >/dev/null 2>&1; then
        if systemctl is-active k3s >/dev/null 2>&1 2>&1 || k3s kubectl get nodes >/dev/null 2>&1; then
            echo "k3s"
            return 0
        fi
    fi
    
    # Check for Rancher Desktop (macOS/Windows)
    if [ -d "/Applications/Rancher Desktop.app" ] || command -v rdctl >/dev/null 2>&1; then
        # Verify kubectl works with Rancher Desktop context
        if kubectl cluster-info >/dev/null 2>&1; then
            echo "rancher-desktop"
            return 0
        fi
    fi
    
    # Fall back to container runtimes (would need separate K8s setup)
    # Check for rootful podman first (requires sudo but can bind privileged ports)
    if command -v podman >/dev/null 2>&1 && sudo podman info >/dev/null 2>&1; then
        if sudo podman info 2>/dev/null | grep -q "rootless: false"; then
            echo "podman-rootful"
            return 0
        fi
    fi
    
    # Fall back to regular podman (rootless)
    if command -v podman >/dev/null 2>&1; then
        echo "podman"
        return 0
    fi
    
    # Fall back to docker
    if command -v docker >/dev/null 2>&1; then
        echo "docker"
        return 0
    fi
    
    # No runtime found
    echo ""
    return 1
}

# Detect available container runtime (for image operations)
# Returns: docker, podman, podman-rootful, or empty string if neither found
detect_container_runtime() {
    # Check for rootful podman first (requires sudo but can bind privileged ports)
    if command -v podman >/dev/null 2>&1 && sudo podman info >/dev/null 2>&1; then
        if sudo podman info 2>/dev/null | grep -q "rootless: false"; then
            echo "podman-rootful"
            return 0
        fi
    fi
    
    # Fall back to regular podman (rootless)
    if command -v podman >/dev/null 2>&1; then
        echo "podman"
        return 0
    fi
    
    # Fall back to docker
    if command -v docker >/dev/null 2>&1; then
        echo "docker"
        return 0
    fi
    
    # No container runtime found
    echo ""
    return 1
}

# Get the Kubernetes runtime to use
get_k8s_runtime() {
    local runtime=$(detect_k8s_runtime)
    if [ -z "$runtime" ]; then
        echo "ERROR: No Kubernetes runtime found. Install K3s or Rancher Desktop." >&2
        return 1
    fi
    echo "$runtime"
}

# Get the container runtime to use (prefer docker, fallback to podman)
get_container_runtime() {
    local runtime=$(detect_container_runtime)
    if [ -z "$runtime" ]; then
        echo "ERROR: No container runtime found. Install Docker or Podman." >&2
        return 1
    fi
    echo "$runtime"
}

# Get kubectl command for the current runtime
get_kubectl_cmd() {
    local runtime=$(detect_k8s_runtime)
    
    case "$runtime" in
        k3s)
            echo "k3s kubectl"
            ;;
        rancher-desktop|docker|podman*)
            echo "kubectl"
            ;;
        *)
            echo "kubectl"
            ;;
    esac
}

# Get kubeconfig path for the current runtime
get_kubeconfig_path() {
    local runtime=$(detect_k8s_runtime)
    
    case "$runtime" in
        k3s)
            echo "/etc/rancher/k3s/k3s.yaml"
            ;;
        rancher-desktop|docker|podman*)
            echo "${HOME}/.kube/config"
            ;;
        *)
            echo "${HOME}/.kube/config"
            ;;
    esac
}

# Load image with appropriate runtime
# Usage: container_load_image <image_file> <runtime>
container_load_image() {
    local image_file="$1"
    local runtime="${2:-}"
    
    if [ -z "$runtime" ]; then
        runtime=$(get_container_runtime) || return 1
    fi
    
    case "$runtime" in
        docker)
            docker load -i "$image_file"
            ;;
        podman|podman-rootful)
            if [ "$runtime" = "podman-rootful" ]; then
                sudo podman load -i "$image_file"
            else
                podman load -i "$image_file"
            fi
            ;;
        *)
            echo "ERROR: Unknown container runtime: $runtime" >&2
            return 1
            ;;
    esac
}

# Check Kubernetes cluster status
# Returns: 0 if cluster is ready, 1 if not
check_k8s_cluster() {
    local runtime=$(detect_k8s_runtime)
    local kubectl_cmd=$(get_kubectl_cmd)
    
    case "$runtime" in
        k3s)
            $kubectl_cmd get nodes >/dev/null 2>&1
            ;;
        rancher-desktop|docker|podman*)
            kubectl cluster-info >/dev/null 2>&1 && kubectl get nodes >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Get container runtime info
# Usage: container_info <runtime>
container_info() {
    local runtime="${1:-}"
    
    if [ -z "$runtime" ]; then
        runtime=$(get_container_runtime) || return 1
    fi
    
    case "$runtime" in
        docker)
            docker version
            ;;
        podman|podman-rootful)
            podman version
            ;;
        *)
            echo "ERROR: Unknown container runtime: $runtime" >&2
            return 1
            ;;
    esac
}

# Check if container runtime is available and working
# Usage: container_health_check <runtime>
# Returns: 0 if healthy, 1 if not
container_health_check() {
    local runtime="${1:-}"
    
    if [ -z "$runtime" ]; then
        runtime=$(get_container_runtime) || return 1
    fi
    
    case "$runtime" in
        docker)
            docker info >/dev/null 2>&1
            ;;
        podman|podman-rootful)
            podman info >/dev/null 2>&1
            ;;
        *)
            echo "ERROR: Unknown container runtime: $runtime" >&2
            return 1
            ;;
    esac
}

export -f detect_k8s_runtime
export -f detect_container_runtime
export -f get_k8s_runtime
export -f get_container_runtime
export -f get_kubectl_cmd
export -f get_kubeconfig_path
export -f container_load_image
export -f check_k8s_cluster
export -f container_info
export -f container_health_check

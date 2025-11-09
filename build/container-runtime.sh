#!/bin/bash
# Container Runtime Detection and Utilities
# Supports Docker, Podman, and provides fallback logic
# Source this script to use the functions

set -euo pipefail

# Detect available container runtime
# Returns: docker, podman, podman-rootful, or empty string if neither found
# Prefers rootful podman if available (for privileged port access)
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

# Get the container runtime to use (prefer docker, fallback to podman)
get_container_runtime() {
    local runtime=$(detect_container_runtime)
    if [ -z "$runtime" ]; then
        echo "ERROR: No container runtime found. Install Docker or Podman." >&2
        return 1
    fi
    echo "$runtime"
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

# Run kind cluster with appropriate runtime
# Usage: container_kind_create <cluster_name> <runtime> [additional_kind_args]
container_kind_create() {
    local cluster_name="$1"
    local runtime="${2:-}"
    shift 2
    local additional_args="$@"
    
    if [ -z "$runtime" ]; then
        runtime=$(get_container_runtime) || return 1
    fi
    
    case "$runtime" in
        docker)
            # Docker is the default for Kind
            kind create cluster --name "$cluster_name" $additional_args
            ;;
        podman-rootful)
            # Rootful Podman: set KIND_EXPERIMENTAL_PROVIDER and use sudo
            sudo -E KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name "$cluster_name" $additional_args
            ;;
        podman)
            # Rootless Podman: set KIND_EXPERIMENTAL_PROVIDER environment variable for older Kind versions
            # For newer Kind versions (0.22.0+) it auto-detects
            KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name "$cluster_name" $additional_args
            ;;
        *)
            echo "ERROR: Unknown container runtime: $runtime" >&2
            return 1
            ;;
    esac
}

# Run kind delete with appropriate runtime
# Usage: container_kind_delete <cluster_name> <runtime>
container_kind_delete() {
    local cluster_name="$1"
    local runtime="${2:-}"
    
    if [ -z "$runtime" ]; then
        runtime=$(get_container_runtime) || return 1
    fi
    
    case "$runtime" in
        docker)
            kind delete cluster --name "$cluster_name"
            ;;
        podman-rootful)
            # Rootful Podman: set KIND_EXPERIMENTAL_PROVIDER and use sudo
            sudo -E KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name "$cluster_name"
            ;;
        podman)
            # Rootless Podman: set KIND_EXPERIMENTAL_PROVIDER environment variable for older Kind versions
            KIND_EXPERIMENTAL_PROVIDER=podman kind delete cluster --name "$cluster_name"
            ;;
        *)
            echo "ERROR: Unknown container runtime: $runtime" >&2
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
        podman)
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
        podman)
            podman info >/dev/null 2>&1
            ;;
        *)
            echo "ERROR: Unknown container runtime: $runtime" >&2
            return 1
            ;;
    esac
}

export -f detect_container_runtime
export -f get_container_runtime
export -f container_load_image
export -f container_kind_create
export -f container_kind_delete
export -f container_info
export -f container_health_check

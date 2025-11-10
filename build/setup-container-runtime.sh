#!/usr/bin/env bash
# Setup container runtime based on platform
# Linux: Podman
# macOS/Windows: Docker Desktop or Rancher Desktop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if Docker is available
check_docker() {
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            echo -e "${GREEN}✓${NC} Docker is installed and running"
            return 0
        else
            echo -e "${YELLOW}!${NC} Docker is installed but not running"
            return 1
        fi
    fi
    return 1
}

# Check if Podman is available
check_podman() {
    if command -v podman &> /dev/null; then
        if podman info &> /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Podman is installed and running"
            return 0
        else
            echo -e "${YELLOW}!${NC} Podman is installed but not running properly"
            return 1
        fi
    fi
    return 1
}

# Check if Rancher Desktop is available
check_rancher_desktop() {
    if command -v rdctl &> /dev/null; then
        echo -e "${GREEN}✓${NC} Rancher Desktop is installed"
        return 0
    fi
    
    # Check if Rancher Desktop app exists on macOS
    if [[ "$(detect_os)" == "macos" ]] && [[ -d "/Applications/Rancher Desktop.app" ]]; then
        echo -e "${GREEN}✓${NC} Rancher Desktop app found"
        return 0
    fi
    
    return 1
}

# Setup for Linux
setup_linux() {
    echo -e "${BLUE}Setting up container runtime for Linux${NC}"
    
    # Check if Docker is available first
    if check_docker; then
        echo -e "${GREEN}✓${NC} Using Docker"
        return 0
    fi
    
    # Check if Podman is available
    if check_podman; then
        echo -e "${GREEN}✓${NC} Using Podman"
        # Set up Docker socket compatibility
        if ! systemctl --user is-active --quiet podman.socket 2>/dev/null; then
            echo -e "${BLUE}Enabling Podman socket for Docker compatibility${NC}"
            systemctl --user enable --now podman.socket || true
        fi
        return 0
    fi
    
    # Neither is available, install Podman
    echo -e "${YELLOW}No container runtime found. Installing Podman...${NC}"
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        echo -e "${BLUE}Installing Podman via apt${NC}"
        sudo apt-get update
        sudo apt-get install -y podman
    elif command -v dnf &> /dev/null; then
        # Fedora/RHEL
        echo -e "${BLUE}Installing Podman via dnf${NC}"
        sudo dnf install -y podman
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        echo -e "${BLUE}Installing Podman via pacman${NC}"
        sudo pacman -S --noconfirm podman
    else
        echo -e "${RED}✗${NC} Unable to detect package manager. Please install Podman manually:"
        echo "  - Debian/Ubuntu: sudo apt-get install podman"
        echo "  - Fedora/RHEL: sudo dnf install podman"
        echo "  - Arch: sudo pacman -S podman"
        return 1
    fi
    
    # Enable Podman socket
    systemctl --user enable --now podman.socket || true
    
    # Create Docker compatibility symlink
    if [[ ! -L "$HOME/.docker/run/docker.sock" ]]; then
        mkdir -p "$HOME/.docker/run"
        ln -s "/run/user/$(id -u)/podman/podman.sock" "$HOME/.docker/run/docker.sock" || true
    fi
    
    echo -e "${GREEN}✓${NC} Podman installed successfully"
    echo -e "${BLUE}ℹ${NC} Docker socket available at: $HOME/.docker/run/docker.sock"
}

# Setup for macOS
setup_macos() {
    echo -e "${BLUE}Setting up container runtime for macOS${NC}"
    
    # Check if Docker Desktop is available
    if check_docker; then
        echo -e "${GREEN}✓${NC} Using Docker Desktop"
        return 0
    fi
    
    # Check if Rancher Desktop is available
    if check_rancher_desktop; then
        echo -e "${GREEN}✓${NC} Using Rancher Desktop"
        return 0
    fi
    
    # Neither is available
    echo -e "${YELLOW}No container runtime found.${NC}"
    echo ""
    echo "Please install one of the following:"
    echo ""
    echo "Option 1: Docker Desktop (Recommended for macOS)"
    echo "  Download from: https://www.docker.com/products/docker-desktop"
    echo ""
    echo "Option 2: Rancher Desktop (Free, open source alternative)"
    echo "  Install via Homebrew: brew install --cask rancher"
    echo "  Or download from: https://rancherdesktop.io/"
    echo ""
    
    # Check if Homebrew is available
    if command -v brew &> /dev/null; then
        read -p "Install Rancher Desktop via Homebrew now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Installing Rancher Desktop...${NC}"
            brew install --cask rancher
            echo -e "${GREEN}✓${NC} Rancher Desktop installed"
            echo -e "${YELLOW}!${NC} Please start Rancher Desktop from Applications and complete the setup"
            return 0
        fi
    fi
    
    return 1
}

# Setup for Windows
setup_windows() {
    echo -e "${BLUE}Setting up container runtime for Windows${NC}"
    
    # Check if Docker Desktop is available
    if check_docker; then
        echo -e "${GREEN}✓${NC} Using Docker Desktop"
        return 0
    fi
    
    # Check if Rancher Desktop is available
    if check_rancher_desktop; then
        echo -e "${GREEN}✓${NC} Using Rancher Desktop"
        return 0
    fi
    
    # Neither is available
    echo -e "${YELLOW}No container runtime found.${NC}"
    echo ""
    echo "Please install one of the following:"
    echo ""
    echo "Option 1: Docker Desktop (Recommended for Windows)"
    echo "  Download from: https://www.docker.com/products/docker-desktop"
    echo ""
    echo "Option 2: Rancher Desktop (Free, open source alternative)"
    echo "  Download from: https://rancherdesktop.io/"
    echo "  Or check installers/windows/ directory for offline installer"
    echo ""
    
    return 1
}

# Main
main() {
    OS="$(detect_os)"
    
    echo -e "${BLUE}Container Runtime Setup${NC}"
    echo -e "${BLUE}════════════════════════${NC}"
    echo ""
    
    case "$OS" in
        linux)
            setup_linux
            ;;
        macos)
            setup_macos
            ;;
        windows)
            setup_windows
            ;;
        *)
            echo -e "${RED}✗${NC} Unsupported operating system"
            exit 1
            ;;
    esac
    
    EXIT_CODE=$?
    
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}✓${NC} Container runtime is ready"
        
        # Show which runtime is being used
        if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
            echo -e "${BLUE}ℹ${NC} Using: $(docker --version)"
        elif command -v podman &> /dev/null; then
            echo -e "${BLUE}ℹ${NC} Using: $(podman --version)"
        fi
    else
        echo ""
        echo -e "${YELLOW}!${NC} Please install a container runtime and run this script again"
    fi
    
    return $EXIT_CODE
}

main "$@"

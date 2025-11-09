# Justfile Documentation

This project uses [Just](https://github.com/casey/just) - a command runner for task automation.

## Installation

### Install Just

**macOS/Linux (via Homebrew):**
```bash
brew install just
```

**Windows (via Chocolatey):**
```powershell
choco install just
```

**Linux (via package manager):**
```bash
# Ubuntu/Debian
sudo apt-get install just

# Fedora
sudo dnf install just
```

**Or download directly:**
Visit https://github.com/casey/just/releases

## Quick Start

```bash
# View all available recipes
just help

# Install all dependencies
just install-deps

# Complete setup (one command)
just setup

# Check status
just status
```

## Recipes Overview

### 🔧 Dependency Management

| Recipe | Description |
|--------|-------------|
| `just check-deps` | Verify all required tools are installed |
| `just install-deps` | Install Homebrew dependencies (macOS/Linux) |

**Installs via Homebrew:**
- Docker
- Kind (Kubernetes in Docker)
- kubectl
- Helm
- k9s
- mkcert
- jq

### 📥 Download & Installation

| Recipe | Description |
|--------|-------------|
| `just download-current` | Download installers for current platform |
| `just download-all` | Download installers for all platforms (macos/linux/windows) |
| `just download-platform <os>` | Download for specific platform |

**Downloads (~700MB-1GB per platform):**
- Docker Desktop/Engine
- Kind
- kubectl
- Helm
- k9s
- mkcert

### ✅ Verification & Updates

| Recipe | Description |
|--------|-------------|
| `just verify-installers` | Check installer checksums against remote |
| `just verify-helm` | Verify Helm chart and extract image versions |
| `just verify-all` | Complete verification (installers + helm + cache) |
| `just update-helm` | Update/pull latest Helm chart |

### 📦 Image Caching

| Recipe | Description |
|--------|-------------|
| `just cache-images` | Cache all container images for offline use (~5-15GB) |
| `just cache-check` | Check cached images |

### 🏗️ Package Building

| Recipe | Description |
|--------|-------------|
| `just build-packages` | Build all platform packages (macos/linux/windows) |
| `just build-macos` | Build macOS package |
| `just build-linux` | Build Linux package |
| `just build-windows` | Build Windows package |

**Creates in `packages/` directory:**
- Platform-specific installation scripts
- Installation instructions (INSTALL.md)
- Extractor scripts for archives

### 📊 Maintenance

| Recipe | Description |
|--------|-------------|
| `just status` | Show current setup status |
| `just clean` | Remove generated packages |
| `just clean-all` | Remove packages, caches, and installers |

### 🚀 Complete Setup

| Recipe | Description |
|--------|-------------|
| `just setup` | **Complete setup in one command** |

This runs:
1. Checks dependencies
2. Downloads installers
3. Verifies checksums
4. Updates Helm chart
5. Caches images
6. Verifies everything
7. Builds packages

## Usage Examples

### First Time Setup

```bash
# 1. Install dependencies if not already installed
just install-deps

# 2. Run complete setup
just setup

# 3. Check status
just status
```

### Update Everything

```bash
# Update installers, helm chart, and cache images
just download-current
just update-helm
just cache-images
just verify-all
```

### Offline Preparation

```bash
# Download everything for all platforms
just download-all

# Cache images for offline use
just cache-images

# Verify everything is ready
just verify-all
```

### Build Packages for Distribution

```bash
# Build all platform packages
just build-packages

# Then find packages in: packages/{macos,linux,windows}/
ls -la packages/
```

### Check Current Status

```bash
just status

# Output example:
# Platform: linux/x86_64
#
# Installers:
#   ✓ Downloaded for linux
#     - kind-linux-amd64 (45.3M)
#     - kubectl (50.2M)
#     - mkcert-linux-amd64 (15.8M)
#
# Image Cache:
#   ✓ Container images cached
#   Size: 12.5G
#
# Helm Chart:
#   ✓ Helm chart cached
#   Version: v2.5.1
#
# Packages:
#   ✓ Packages built
#     - macos
#     - linux
#     - windows
```

## Directory Structure

```
ess-demo/
├── Justfile                      # This file!
├── installers/                   # Downloaded binaries
│   ├── macos/
│   ├── linux/
│   └── windows/
├── image-cache/                  # Cached container images
│   ├── kind-images/
│   ├── ess-images/
│   └── helm-charts/
├── packages/                     # Built distribution packages
│   ├── macos/
│   ├── linux/
│   └── windows/
└── demo-values/                  # Configuration
    ├── auth.yaml
    ├── hostnames.yaml
    ├── tls.yaml
    └── mrtc.yaml
```

## Advanced Features

### Platform-Specific Automation

The Justfile automatically detects your platform:

```bash
# On macOS/Linux
just status
# Shows macOS/arm64 or linux/x86_64

# On Windows (with Just installed)
just status
# Shows detection for Windows
```

### Colored Output

All recipes use color-coded messages:
- 🔵 **Blue** - Information
- 🟢 **Green** - Success
- 🟡 **Yellow** - Warnings
- 🔴 **Red** - Errors

### Custom Variables

You can override defaults:

```bash
# All variables are defined at top of Justfile
# For example, modifying versions would require editing the file

# Example of checking specific versions:
HELM_VERSION="v3.13.2"
KIND_VERSION="v0.20.0"
KUBECTL_VERSION="v1.28.4"
```

## Troubleshooting

### "just: command not found"

Install Just first:
```bash
brew install just
```

### Permission Denied on Scripts

The Justfile automatically sets permissions:
```bash
chmod +x script.sh
```

If needed manually:
```bash
chmod +x *.sh
```

### Download Failures

Check internet connection:
```bash
curl -I https://github.com
```

Try specific platform:
```bash
just download-platform linux
```

### Checksum Verification Fails

Download fresh:
```bash
rm installers/*/sha256_checksums
just verify-installers
```

### Cache Images Takes Too Long

Run in background or use screen/tmux:
```bash
screen -S cache
just cache-images

# Detach with Ctrl+A then D
# Reattach with: screen -r cache
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Build Packages
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Just
        run: cargo install just
      
      - name: Setup and Build
        run: just setup build-packages
      
      - name: Upload Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: packages
          path: packages/
```

## Common Workflows

### Weekly Refresh

```bash
#!/bin/bash
# refresh.sh - Update everything weekly

just download-current
just update-helm
just verify-all
just build-packages

# Optional: Upload to distribution server
# aws s3 cp packages/ s3://my-bucket/ess-demo/
```

### Development Cycle

```bash
# 1. Make changes to helm values
# 2. Verify chart still works
just verify-helm

# 3. Update cache if needed
just cache-images

# 4. Rebuild packages
just build-packages

# 5. Test on different platforms
```

### Air-Gapped Deployment

```bash
# On internet-connected machine
just download-all
just cache-images
just build-packages

# Transfer packages/ and image-cache/ to air-gapped system
# Then on air-gapped system:
just cache-check
./setup.sh --offline
```

## See Also

- [Just Documentation](https://github.com/casey/just)
- [ESS Documentation](https://element.io/server-suite)
- [Helm Documentation](https://helm.sh)
- [Kubernetes Documentation](https://kubernetes.io)

## Support

For issues or questions:
1. Check `just help` for available recipes
2. Review script output for detailed error messages
3. See TROUBLESHOOTING.md in repository root
4. Check GitHub issues

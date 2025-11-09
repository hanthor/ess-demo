# Changelog

All notable changes to this portable ESS demo will be documented in this file.

## [2.1.0] - 2025-11-09

### Enhanced Air-Gapped and Multi-Platform Support

This version adds comprehensive air-gapped deployment support and multi-platform installer downloads.

### Added
- **Multi-platform installer downloads**: Download installers for all platforms in one command
  - `download-installers.sh --all` / `download-installers.ps1 -All`
  - Downloads macOS (Intel + Apple Silicon), Linux (x86_64 + ARM64), and Windows installers
  - Perfect for preparing portable demos that work on any platform
- **Air-gapped deployment support**: Complete offline/disconnected environment deployment
  - `cache-images.sh` - Downloads and caches all container images (~3-4GB)
  - `load-cached-images.sh` - Loads cached images into Docker
  - Caches Kind node images, ESS components, NGINX Ingress, Helm chart
  - `setup.sh --offline` - Deploys using only cached resources
- **Software uninstall capability**: Clean removal of installed tools
  - `cleanup.sh --uninstall` / `cleanup.ps1 -Uninstall`
  - Removes Kind, kubectl, Helm, k9s, mkcert
  - Preserves Docker (may be used by other applications)
  - Cleans up system PATH entries
- **Comprehensive documentation**:
  - `AIR-GAPPED.md` - Complete air-gapped deployment guide
  - Enhanced `README.md` with new features
  - Updated troubleshooting guides

### Changed
- **Enhanced download scripts**:
  - Added `--all` flag to download for all platforms
  - Better error handling and progress reporting
  - Support for downloading from any platform (can download Windows binaries from Linux, etc.)
- **Enhanced setup scripts**:
  - Auto-detects and uses cached images if available
  - `--offline` flag for explicit air-gapped mode
  - Better handling of Kind node image selection
- **Enhanced cleanup scripts**:
  - `--uninstall` flag for complete software removal
  - Safer uninstall (checks if tools were installed by this demo)
  - Help flags for better usability

### Improved
- Image caching workflow for reproducible deployments
- Offline deployment reliability
- Multi-platform portability
- Documentation clarity

### File Structure
```
ess-demo/
├── installers/              # Downloaded binaries (3-4GB with --all)
│   ├── macos/              # macOS binaries (both architectures)
│   ├── linux/              # Linux binaries (both architectures)
│   └── windows/            # Windows binaries
├── image-cache/            # Cached container images (3-4GB)
│   ├── kind-images/        # Kind node image
│   ├── ess-images/         # ESS component images
│   ├── helm-charts/        # Cached Helm chart
│   └── MANIFEST.txt        # Cache inventory
├── Scripts:
│   ├── download-installers.sh/ps1  # Enhanced multi-platform download
│   ├── cache-images.sh             # NEW: Cache container images
│   ├── load-cached-images.sh       # NEW: Load cached images
│   ├── setup.sh/ps1                # Enhanced with --offline mode
│   ├── cleanup.sh/ps1              # Enhanced with --uninstall flag
│   └── verify.sh/ps1               # Status verification
└── Documentation:
    ├── README.md                   # Updated quick start
    ├── AIR-GAPPED.md              # NEW: Air-gapped deployment guide
    ├── PLATFORM-SETUP.md          # Platform-specific instructions
    ├── TROUBLESHOOTING.md         # Problem solving
    └── CHANGELOG.md               # This file
```

### Use Cases
- **Multi-platform demos**: Download once, deploy on any platform
- **Air-gapped environments**: Complete offline deployment capability
- **Secure environments**: No internet connectivity required after initial download
- **Portable presentations**: USB drive with full demo for any OS
- **Training environments**: Pre-cached images for fast, reliable setup

## [2.0.0] - 2025-11-09

### Major Rewrite - Portable Cross-Platform Demo

This version completely transforms the demo into a portable, offline-capable, cross-platform solution.

### Added
- **Cross-platform support**: macOS (Intel/Apple Silicon), Linux (x86_64/arm64), and Windows (amd64)
- **Offline installation**: Download installers once, use anywhere without internet
- **Automated setup scripts**: 
  - `setup.sh` for macOS/Linux
  - `setup.ps1` for Windows PowerShell
- **Installer download scripts**:
  - `download-installers.sh` for macOS/Linux
  - `download-installers.ps1` for Windows
- **Utility scripts**:
  - `cleanup.sh` / `cleanup.ps1` - Remove cluster and resources
  - `verify.sh` / `verify.ps1` - Check deployment status
- **Installer caching**: Store binaries locally in `installers/` directory
- **Platform detection**: Automatic OS and architecture detection
- **Interactive domain configuration**: Prompts user for custom domain names
- **Colored output**: Enhanced CLI experience with status indicators
- **Comprehensive documentation**:
  - Updated README.md with quick start guide
  - QUICK-REFERENCE.md for common commands
  - installers/README.md for offline setup details

### Changed
- Switched from k3s/Rancher to **Kind (Kubernetes in Docker)**
- Simplified certificate generation with improved `build-certs.sh`
- Auto-generated `hostnames.yaml` based on user input
- Enhanced `.gitignore` to exclude installers and certificates

### Technology Stack
- **Docker**: Container runtime (Desktop for macOS/Windows, Engine for Linux)
- **Kind v0.20.0**: Kubernetes in Docker
- **kubectl v1.28.4**: Kubernetes CLI
- **Helm v3.13.2**: Package manager
- **k9s v0.29.1**: Kubernetes TUI (optional)
- **mkcert v1.4.4**: Local CA and certificate generation

### Components Deployed
- Element Web
- Element Admin
- Synapse (Matrix homeserver)
- Matrix Authentication Service
- Matrix RTC (with LiveKit)
- PostgreSQL
- NGINX Ingress Controller

### Removed
- k3s references (replaced with Kind)
- Rancher Desktop requirements (replaced with Docker + Kind)
- Manual installation steps (now automated)
- Platform-specific limitations

## [1.0.0] - 2025-01-15

### Initial Version
- Basic ESS demo setup
- Manual installation instructions
- Platform-specific setup guides
- Rancher Desktop and k3s focus

---

## Version Format

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible changes
- **MINOR** version for added functionality (backwards-compatible)
- **PATCH** version for backwards-compatible bug fixes

## Software Versions

Current bundled software versions:
- Docker Desktop: Latest (downloaded at runtime)
- Kind: v0.20.0
- kubectl: v1.28.4
- Helm: v3.13.2
- k9s: v0.29.1
- mkcert: v1.4.4

ESS Components are pulled from: `oci://ghcr.io/element-hq/ess-helm/matrix-stack`

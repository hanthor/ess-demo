# ESS Demo Air-gapped Package - Complete Implementation

## Overview

Complete Ansible-based workflow for building and deploying ESS (Element Synapse Stack) in air-gapped environments. Creates self-contained packages for Linux, macOS, and Windows with all necessary binaries and container images included.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│         ESS Air-gapped Build Workflow                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Step 1: Download Installers (Multi-platform)           │
│  ├─ k3s (includes kubectl)                              │
│  ├─ helm                                                │
│  ├─ k9s, mkcert                                         │
│  ├─ hauler                                              │
│  └─ Rancher Desktop (macOS/Windows)                     │
│                                                          │
│  Step 2: Setup Local k3s Cluster                        │
│  ├─ Install k3s from binary (--disable traefik)        │
│  ├─ Wait for cluster ready                             │
│  └─ Copy kubeconfig                                     │
│                                                          │
│  Step 3: Deploy ESS to k3s                              │
│  ├─ Extract helm binary                                │
│  ├─ Install ingress-nginx                              │
│  ├─ Generate TLS certs with mkcert                     │
│  └─ Deploy matrix-stack Helm chart                     │
│                                                          │
│  Step 4: Capture Container Images                       │
│  ├─ Extract hauler binary                              │
│  ├─ Run: hauler store save -k                          │
│  │   (Captures ALL cluster images for linux/amd64 + arm64)
│  ├─ Generate hauler-installers-manifest.yaml           │
│  └─ Create hauler-store/ (OCI format)                  │
│                                                          │
│  Step 5: Package for Air-gapped Deployment              │
│  ├─ Create platform-specific packages:                 │
│  │  ├─ linux-airgap.tar.gz (amd64/arm64)              │
│  │  ├─ macos-airgap.tar.gz (arm64)                    │
│  │  └─ windows-airgap.zip (amd64)                     │
│  ├─ Include: installers/, hauler-store/, setup scripts │
│  ├─ Generate MANIFEST.json, README.md                  │
│  └─ Total: ~2 GB per platform                          │
│                                                          │
│  Step 6: Test Air-gapped Package                        │
│  ├─ Extract package to temp directory                  │
│  ├─ Verify structure and binaries                      │
│  ├─ Validate hauler store                              │
│  └─ Confirm ready for deployment                       │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Components

### 1. Ansible Roles

#### `installers` - Download All Binaries
- **Purpose**: Multi-platform binary downloads with checksums
- **Platforms**: Linux (amd64/arm64), macOS (arm64), Windows (amd64)
- **Binaries**:
  - k3s v1.33.5+k3s1 (includes bundled kubectl)
  - helm v3.19.0
  - k9s v0.32.7
  - mkcert v1.4.4
  - hauler v1.1.1
  - Rancher Desktop v1.16.0
- **Output**: 
  - `installers/` directory with per-OS subdirectories
  - `installers/index.json` manifest
- **Total Size**: ~1.9 GB

#### `k3s-local` - Setup Local k3s Cluster
- **Purpose**: Install and configure k3s from downloaded binary
- **Tasks**:
  1. Install k3s binary to `/usr/local/bin/`
  2. Run install script with `--disable traefik`
  3. Wait for cluster to become ready
  4. Copy kubeconfig to `k3s-kubeconfig.yaml`
- **Output**: Running k3s cluster accessible via kubectl/k3s

#### `ess-deploy` - Deploy ESS Stack
- **Purpose**: Deploy ESS (matrix-stack) to k3s cluster
- **Tasks**:
  1. Extract helm from tarball
  2. Add matrix-stack Helm repo
  3. Create TLS certificates with mkcert
  4. Install ingress-nginx (dependencies)
  5. Deploy matrix-stack chart with demo values
  6. Wait for all pods ready
- **Output**: 
  - ESS pods running in k3s
  - ingress-nginx for HTTP/HTTPS routing
  - TLS certificates in `certs/`

#### `hauler-capture` - Capture Container Images
- **Purpose**: Extract all cluster images into hauler store for offline reuse
- **Tasks**:
  1. Extract hauler binary
  2. Run `hauler store save -k --platform linux/amd64,linux/arm64`
   (Captures images for both Linux architectures)
  3. Generate `hauler-installers-manifest.yaml` with Files section
  4. Create OCI-format `hauler-store/`
- **Output**:
  - `hauler-store/` with all container images
  - `hauler-installers-manifest.yaml` manifest
  - `hauler-store/index.json` with image registry

#### `packaging` - Create Air-gapped Packages
- **Purpose**: Bundle everything into per-OS self-contained packages
- **Packages**:
  1. **linux-airgap.tar.gz** (amd64/arm64):
     - installers/ (all Linux binaries)
     - hauler-store/ (all images)
     - setup.sh (automated setup)
  2. **macos-airgap.tar.gz** (arm64):
     - installers/ (all macOS binaries)
     - hauler-store/ (all images)
     - setup.sh (setup guide)
  3. **windows-airgap.zip** (amd64):
     - installers/ (all Windows binaries)
     - hauler-store/ (all images)
     - setup.ps1 (setup guide)
- **Output**:
  - `packages/` directory with all three packages
  - `packages/MANIFEST.json` (metadata)
  - `packages/README.md` (quick start)
- **Total Size**: ~6 GB (2 GB per platform)

### 2. Playbooks

#### `setup-playbook.yml` - Main Build Orchestration
Runs all roles in sequence with tags for selective execution:
```yaml
roles:
  - role: installers      # tags: ['installers', 'download']
  - role: k3s-local       # tags: ['k3s', 'cluster']
  - role: ess-deploy      # tags: ['ess', 'deploy']
  - role: hauler-capture  # tags: ['hauler', 'capture']
  - role: packaging       # tags: ['packaging', 'package']
```

#### `test-airgapped.yml` - Package Validation
Tests that packages work without internet:
1. Extract package to temp directory
2. Verify structure and all binaries
3. Validate hauler store contents
4. Display setup instructions
5. Confirm ready for deployment

### 3. Justfile Recipes

**Build Workflow:**
- `just build` - Full build (all steps)
- `just download-installers` - Step 1 only
- `just setup-k3s` - Step 2 only
- `just deploy-ess` - Step 3 only
- `just capture-images` - Step 4 only
- `just package` - Step 5 only
- `just test-airgap` - Step 6 only

**Cluster Management:**
- `just status` - Check k3s cluster status
- `just kubeconfig` - Show kubeconfig location
- `just verify-store` - Verify hauler store contents

**Cleanup:**
- `just clean` - Remove all build artifacts
- `just clean-k3s` - Uninstall k3s only
- `just clean-all` - Remove everything including certs

**Information:**
- `just docs` - Show workflow documentation
- `just versions` - Show installed component versions
- `just disk-usage` - Show disk usage by component
- `just validate` - Validate Ansible syntax
- `just debug-role ROLE` - Debug specific role

## Deployment Scenarios

### Scenario 1: Build with Internet (Current Setup)
```bash
# Full build with internet access (requires ~30-60 mins)
just build

# Or step-by-step
just download-installers
just setup-k3s
just deploy-ess
just capture-images
just package
just test-airgap
```

### Scenario 2: Deploy in Air-gapped Environment
```bash
# On target machine (no internet required)
tar -xzf linux-airgap.tar.gz
cd linux-airgap
./setup.sh    # Automated setup (Linux)
# or
bash setup.sh  # Manual setup (macOS)
# or
.\\setup.ps1   # Manual setup (Windows)
```

### Scenario 3: Development Iteration
```bash
# Debug specific role
just debug-role installers -vvv

# Rebuild after changes
just clean-k3s
just setup-k3s

# Capture new images
just clean-hauler
just capture-images

# Repackage
just package
```

## Key Features

### ✅ Multi-architecture Support
- **Linux**: amd64, arm64 (x86, ARM)
- **macOS**: arm64 only (Apple Silicon)
- **Windows**: amd64 only (x86-64)

### ✅ Air-gapped Capability
- All container images captured in OCI format
- No Docker Hub/registry access needed after extraction
- Complete binary bundle included

### ✅ Single Runtime
- Linux: k3s only (includes kubectl)
- macOS: Rancher Desktop or Docker Desktop
- Windows: Rancher Desktop or Docker Desktop

### ✅ Automated Deployment
- Linux: Full automated setup with setup.sh
- macOS/Windows: Setup guides with step-by-step instructions

### ✅ Version Control
- All component versions pinned in roles/*/vars/main.yml
- Checksums verified for all downloads
- Manifest files track exact versions and contents

### ✅ Complete Documentation
- MANIFEST.json in each package
- README.md with quick start
- Inline comments in all Ansible files
- Justfile recipes with descriptions

## File Structure

```
ess-demo/
├── ansible/
│   ├── setup-playbook.yml          # Main orchestration playbook
│   ├── test-airgapped.yml          # Package validation playbook
│   ├── inventory.ini               # Ansible inventory (localhost)
│   └── roles/
│       ├── installers/             # Download binaries
│       │   ├── tasks/main.yml
│       │   └── vars/main.yml
│       ├── k3s-local/              # Setup k3s
│       │   ├── tasks/main.yml
│       │   └── vars/main.yml
│       ├── ess-deploy/             # Deploy ESS
│       │   ├── tasks/main.yml
│       │   └── vars/main.yml
│       ├── hauler-capture/         # Capture images
│       │   ├── tasks/main.yml
│       │   └── vars/main.yml
│       └── packaging/              # Create packages
│           ├── tasks/main.yml
│           └── vars/main.yml
├── Justfile                        # Build automation recipes
├── installers/                     # (Generated) Downloaded binaries
│   ├── linux/
│   ├── macos/
│   ├── windows/
│   └── index.json
├── hauler-store/                   # (Generated) OCI image store
│   ├── blobs/sha256/
│   ├── index.json
│   └── oci-layout
├── packages/                       # (Generated) Final air-gapped packages
│   ├── linux-airgap.tar.gz
│   ├── macos-airgap.tar.gz
│   ├── windows-airgap.zip
│   ├── MANIFEST.json
│   └── README.md
├── certs/                          # (Generated) TLS certificates
├── demo-values/                    # ESS Helm chart values
├── build/                          # Documentation and setup utilities
└── README.md                       # Main documentation
```

## Build Times & Sizes

**Build Times (approximate, with internet):**
- Download installers: 5-10 min
- Setup k3s: 2-3 min
- Deploy ESS: 10-15 min
- Capture images: 15-30 min
- Package: 5-10 min
- **Total: 45-70 minutes**

**Package Sizes:**
- Installers only: 1.9 GB
- Hauler store: 2-4 GB (varies by images)
- Linux package: ~2 GB
- macOS package: ~2 GB
- Windows package: ~2 GB

## Troubleshooting

### k3s fails to start
- Check: `systemctl status k3s` or `ps aux | grep k3s`
- Logs: `journalctl -u k3s -n 100`
- Ports: Ensure 6443, 10250 available

### Ingress-nginx CrashLoopBackOff
- Normal during setup (cert propagation delay)
- Check: `sudo k3s kubectl describe pod -n ingress-nginx`
- Usually resolves within 1-2 minutes

### Hauler store load fails
- Ensure Docker/container runtime running (macOS/Windows)
- Check: `docker version` or `rancher-desktop info`
- Verify hauler store path exists

### Package extraction fails
- Check disk space: Need ~3-5 GB free
- Linux: Use `tar -xzf` (not unzip)
- Windows: Use PowerShell `Expand-Archive` (not Windows Explorer)
- macOS: Use `tar -xzf` (not Archive Utility which may corrupt)

## Next Steps

### For Development
1. Modify ESS deployment values in `demo-values/`
2. Run: `just clean-k3s && just setup-k3s`
3. Re-run: `just deploy-ess && just capture-images && just package`

### For Production Deployment
1. Copy appropriate package (linux/macos/windows) to target environment
2. Extract package
3. Run setup script (fully automated on Linux)
4. Verify cluster: `sudo k3s kubectl get pods -A`

### For CI/CD Integration
1. Use `setup-playbook.yml` as workflow trigger
2. Tag each role for selective execution
3. Automate package distribution/upload
4. Run `test-airgapped.yml` in CI pipeline

## References

- **k3s**: https://docs.k3s.io/
- **Hauler**: https://hauler.dev/
- **Helm**: https://helm.sh/
- **Element Synapse Stack**: https://element.io/
- **Ansible**: https://docs.ansible.com/

---

**Version**: 1.0  
**Last Updated**: November 10, 2025  
**Status**: ✅ Complete and Tested

# Hauler Integration Guide

## Overview

Hauler is Rancher's tool for managing artifacts (container images, Helm charts, files) in air-gapped Kubernetes deployments. This integration provides an alternative to the current `cache-images.sh` and `download-installers.sh` approach.

## What is Hauler?

Hauler provides:
- **Unified Manifest**: Single YAML file defines all artifacts
- **Efficient Storage**: Compressed tar.zst format
- **Registry Serving**: Can serve as local Docker registry
- **Checksum Verification**: Built-in integrity checking
- **Simple Workflow**: Download → Package → Transfer → Extract

## Why Use Hauler?

### Current Approach (Bash Scripts)
```
1. Run download-installers.sh → Downloads binaries
2. Run cache-images.sh       → Downloads & saves images
3. Manually package          → Create tarball
4. Transfer                  → Copy to air-gapped environment
5. Manually extract          → Unpack and organize files
6. Run load-cached-images.sh → Load images into Docker
```

### Hauler Approach
```
1. Run hauler store sync    → Downloads everything from manifest
2. Run hauler store save    → Creates compressed package
3. Transfer                 → Copy single file to air-gapped environment
4. Run hauler store load    → Extract and ready to use
5. Run hauler store serve   → Optionally serve as registry
```

## Installation

### Quick Install

```bash
just install-hauler
```

Or manually:

```bash
./build/setup-hauler.sh
```

### Manual Installation

```bash
# Download Hauler (Linux example)
VERSION="1.0.7"
wget https://github.com/rancherfederal/hauler/releases/download/v${VERSION}/hauler_${VERSION}_linux_amd64.tar.gz

# Extract and install
tar -xzf hauler_${VERSION}_linux_amd64.tar.gz
sudo mv hauler /usr/local/bin/
sudo chmod +x /usr/local/bin/hauler

# Verify
hauler version
```

## Usage

### 1. Sync Artifacts

Download all artifacts defined in the manifest:

```bash
just hauler-sync
```

Or manually:

```bash
hauler store sync --files hauler-manifest.yaml
```

This creates a `hauler-store/` directory with all downloaded content.

### 2. Check Store Contents

```bash
just hauler-status
```

Or manually:

```bash
hauler store info --store hauler-store
```

### 3. Save Store to Archive

Create a portable compressed archive:

```bash
hauler store save --filename ess-hauler-store.tar.zst --store hauler-store
```

This creates a single compressed file containing all artifacts.

### 4. Transfer to Air-Gapped Environment

Copy the `.tar.zst` file to your air-gapped machine:

```bash
# USB drive
cp ess-hauler-store.tar.zst /Volumes/USB/

# SCP (if network available)
scp ess-hauler-store.tar.zst user@airgap-host:/tmp/

# Physical media, secure transfer, etc.
```

### 5. Load Store on Target Machine

On the air-gapped machine:

```bash
# Install Hauler first
./build/setup-hauler.sh

# Load the store
hauler store load ess-hauler-store.tar.zst
```

### 6. Extract or Serve Content

#### Option A: Extract Images to Docker

```bash
# Copy images from store to Docker
hauler store copy --store hauler-store registry://docker.io/kindest/node:v1.28.0
```

#### Option B: Serve as Local Registry

```bash
# Start local registry server
hauler store serve registry --store hauler-store
# Now available at: localhost:5000
```

Then configure Kind/K8s to pull from `localhost:5000` instead of remote registries.

## Hauler Manifest

The manifest (`hauler-manifest.yaml`) defines what to download:

```yaml
apiVersion: content.hauler.cattle.io/v1alpha1
kind: Images
metadata:
  name: ess-demo-images
spec:
  images:
    - name: docker.io/kindest/node:v1.28.0
    - name: registry.k8s.io/ingress-nginx/controller:v1.9.4
    # ... more images

---
apiVersion: content.hauler.cattle.io/v1alpha1
kind: Charts
metadata:
  name: ess-demo-charts
spec:
  charts:
    - name: matrix-stack
      repoURL: oci://ghcr.io/element-hq/ess-helm
      version: latest

---
apiVersion: content.hauler.cattle.io/v1alpha1
kind: Files
metadata:
  name: ess-demo-files
spec:
  files:
    - path: https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
      name: kind-linux-amd64
    # ... more files
```

## Customizing the Manifest

### Add Container Images

Edit `hauler-manifest.yaml` and add images:

```yaml
spec:
  images:
    - name: docker.io/your-image:tag
    - name: ghcr.io/your-org/app:v1.0.0
```

### Add Helm Charts

```yaml
spec:
  charts:
    - name: chart-name
      repoURL: https://charts.example.com
      version: 1.2.3
```

### Add Binary Files

```yaml
spec:
  files:
    - path: https://github.com/org/repo/releases/download/v1.0/binary
      name: binary-name
```

## Integration with Existing Workflow

### Replacing Current Scripts

Hauler can replace both `download-installers.sh` and `cache-images.sh`:

**Before (Current)**
```bash
./build/download-installers.sh --all  # ~5 minutes
./build/cache-images.sh               # ~10 minutes
./build/package-offline.sh            # ~2 minutes
# Total: ~17 minutes, multiple commands
```

**After (Hauler)**
```bash
just hauler-sync                      # ~12 minutes (does everything)
# Total: ~12 minutes, one command
```

### Parallel Usage

You can use Hauler alongside existing scripts:

```bash
# Traditional approach for installers
just download-all

# Hauler for images and charts
just hauler-sync

# Best of both worlds
```

## Advanced Usage

### Serve as Air-Gapped Registry

Start a local registry server:

```bash
hauler store serve registry \
  --store hauler-store \
  --port 5000
```

Update Kind config to use local registry:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["http://localhost:5000"]
```

### Copy Specific Images

```bash
# Copy one image to Docker
hauler store copy registry://docker.io/kindest/node:v1.28.0

# Copy all images
hauler store copy registry://
```

### Inspect Store

```bash
# List all content
hauler store info --store hauler-store

# Save content list to file
hauler store info --store hauler-store > manifest.txt
```

## Comparison with Current Approach

| Feature | Current Scripts | Hauler | Winner |
|---------|----------------|--------|---------|
| Single manifest | ❌ No | ✅ Yes | Hauler |
| Compression | Manual tar.gz | Built-in tar.zst | Hauler |
| Checksums | Custom script | Built-in | Hauler |
| Registry serving | ❌ No | ✅ Yes | Hauler |
| Learning curve | Low | Medium | Current |
| Maturity | Production | Stable | Current |
| Dependencies | None | Hauler binary | Current |

## Troubleshooting

### Hauler Command Not Found

```bash
# Install Hauler
just install-hauler

# Or manually
./build/setup-hauler.sh
```

### Sync Fails for Specific Image

Check if the image exists and is accessible:

```bash
# Test with Docker
docker pull <image-name>

# Check manifest syntax
cat hauler-manifest.yaml
```

### Store Directory Permission Issues

```bash
# Fix permissions
chmod -R 755 hauler-store/
```

### Large Store Size

Hauler stores are compressed but can still be large:

```bash
# Check size
du -sh hauler-store/
du -sh ess-hauler-store.tar.zst

# Reduce size by removing unnecessary images from manifest
```

## Best Practices

1. **Version Control Manifest**: Commit `hauler-manifest.yaml` to git
2. **Tag Store Archives**: Include date/version in filename
3. **Verify After Transfer**: Check file integrity on target machine
4. **Keep Manifest Updated**: Update when ESS versions change
5. **Document Custom Images**: Comment why each image is included

## Future Enhancements

Potential improvements for Hauler integration:

- [ ] Automatic manifest generation from Helm chart
- [ ] Integration with setup.sh to use Hauler store
- [ ] Hauler-based cleanup script
- [ ] Multi-architecture support in manifest
- [ ] Signature verification for artifacts

## References

- [Hauler Documentation](https://rancherfederal.github.io/hauler-docs/)
- [Hauler GitHub](https://github.com/rancherfederal/hauler)
- [Hauler Manifest Spec](https://rancherfederal.github.io/hauler-docs/docs/guides/airgap/)

## Quick Reference

```bash
# Install
just install-hauler

# Sync all artifacts
just hauler-sync

# Check status
just hauler-status

# Manual operations
hauler store sync --files hauler-manifest.yaml
hauler store save --filename ess-store.tar.zst
hauler store load ess-store.tar.zst
hauler store serve registry --port 5000
hauler store info
```

## Recommendation

**Use Case**: Hauler is recommended when:
- Setting up completely air-gapped environments
- Need for consistent artifact management
- Want single-file transfer workflow
- Require local registry serving capability

**Stick with scripts when**:
- Simple offline demo on single machine
- Already have working script-based workflow
- Want to minimize dependencies
- Team unfamiliar with Hauler

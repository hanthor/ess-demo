# Air-Gapped Deployment Guide

Complete guide for deploying ESS Community in air-gapped/offline environments.

## 📋 Overview

An air-gapped deployment means running the demo without any internet connectivity. This requires:
1. Pre-downloading all software installers
2. Pre-downloading all container images
3. Pre-downloading the Helm chart
4. Transferring everything to the target environment

## 🎯 Preparation (On Internet-Connected Machine)

### Step 1: Download All Platform Installers

Download binaries for all platforms (or just your target platform):

```bash
# Download for ALL platforms (recommended for maximum portability)
./download-installers.sh --all

# Or download for current platform only
./download-installers.sh
```

**Windows:**
```powershell
.\download-installers.ps1 -All
```

**Download size:** 
- Single platform: ~700MB - 1GB
- All platforms: ~3-4GB

### Step 2: Cache All Container Images

Run the image caching script to download all required Docker images:

```bash
./cache-images.sh
```

This will download and save:
- Kind node image (~400MB)
- ESS Helm chart
- All ESS component images (~2-3GB)
- NGINX Ingress images (~200MB)

**Total cache size:** ~3-4GB

The script creates:
```
image-cache/
├── kind-images/          # Kind node image
│   └── kind-node-*.tar
├── ess-images/           # All ESS component images
│   ├── *.tar
│   └── ...
├── helm-charts/          # Helm chart
│   └── matrix-stack.tgz
├── MANIFEST.txt          # List of all cached content
└── ess-images-list.txt   # List of image names
```

### Step 3: Verify Cache

Check that everything was downloaded:

```bash
cat image-cache/MANIFEST.txt
```

### Step 4: Package for Transfer

Create a tarball of the entire demo directory:

```bash
cd ..
tar czf ess-demo-airgapped.tar.gz ess-demo/
```

Or copy the directory directly to portable media (USB drive, external HDD):

```bash
cp -r ess-demo/ /path/to/usb/drive/
```

## 🚚 Transfer to Air-Gapped Environment

### Option 1: USB Drive / External Storage
1. Copy `ess-demo/` directory to USB drive
2. Transfer USB drive to air-gapped machine
3. Copy directory to air-gapped machine

### Option 2: Secure File Transfer
1. Use approved file transfer method (sneakernet, secure FTP, etc.)
2. Transfer the `ess-demo-airgapped.tar.gz` file
3. Extract on target machine:
   ```bash
   tar xzf ess-demo-airgapped.tar.gz
   cd ess-demo/
   ```

## 🔧 Deployment on Air-Gapped Machine

### Step 1: Verify Files

Ensure all cached files are present:

```bash
ls -lh installers/*/
ls -lh image-cache/
```

### Step 2: Load Cached Images into Docker

**Important:** Docker must be installed and running before this step.

Load all cached images:

```bash
./load-cached-images.sh
```

This will load:
- Kind node image
- All ESS component images
- NGINX Ingress images

**Verify images loaded:**
```bash
docker images | grep -E "kindest|element|matrix|nginx|postgres|redis"
```

### Step 3: Run Setup

Run the setup script in offline mode:

```bash
./setup.sh --offline
```

Or run normally (will detect and use cached images automatically):

```bash
./setup.sh
```

**Windows:**
```powershell
.\setup.ps1
```

The setup will:
1. Install tools from local installers
2. Use cached Kind node image
3. Create Kubernetes cluster
4. Deploy ESS using cached images (no internet pulls)

### Step 4: Verify Deployment

```bash
./verify.sh
```

Check that all pods are running:

```bash
kubectl get pods -n ess
```

## 📊 Disk Space Requirements

| Component | Size | Required |
|-----------|------|----------|
| Installers (all platforms) | ~3-4GB | Yes |
| Image cache | ~3-4GB | Optional but recommended |
| Kind cluster runtime | ~2-3GB | Yes (created during setup) |
| Total | ~8-11GB | |

**Minimum:** ~5GB (installers + cluster, images pulled if internet available)
**Recommended:** ~11GB (full air-gapped cache)

## 🔒 Security Considerations

### Image Verification

Verify image integrity before deploying to air-gapped environment:

```bash
# Generate checksums on internet-connected machine
cd image-cache
find . -name "*.tar" -type f -exec sha256sum {} \; > ../checksums.txt

# Verify on air-gapped machine
sha256sum -c checksums.txt
```

### Scanning Images

Scan images for vulnerabilities before deployment:

```bash
# Install trivy on internet-connected machine
# Scan all cached images
for img in image-cache/ess-images/*.tar; do
    echo "Scanning: $img"
    trivy image --input "$img"
done
```

## 🔧 Troubleshooting Air-Gapped Deployment

### Images Not Found

**Problem:** Setup tries to pull images from internet

**Solution:**
1. Verify images are loaded:
   ```bash
   docker images
   ```

2. Re-load cached images:
   ```bash
   ./load-cached-images.sh
   ```

3. Check image names match:
   ```bash
   cat image-cache/ess-images-list.txt
   ```

### Helm Chart Not Found

**Problem:** Helm tries to download chart

**Solution:**
1. Verify Helm chart cache exists:
   ```bash
   ls -lh image-cache/helm-charts/
   ```

2. Use local chart:
   ```bash
   helm install ess ./image-cache/helm-charts/matrix-stack/
   ```

### DNS Issues in Air-Gapped Environment

**Problem:** DNS resolution fails

**Solution:**
Use `.localhost` domains which resolve to 127.0.0.1 without DNS:
```
ess.localhost
chat.ess.localhost
matrix.ess.localhost
```

Or configure `/etc/hosts`:
```bash
# /etc/hosts
127.0.0.1 ess.local chat.ess.local matrix.ess.local
```

## 🔄 Updating Air-Gapped Deployment

### Updating Images

On internet-connected machine:

```bash
# Re-run cache script to get latest images
./cache-images.sh

# Package and transfer to air-gapped environment
tar czf ess-demo-update.tar.gz image-cache/

# On air-gapped machine
tar xzf ess-demo-update.tar.gz
./load-cached-images.sh
```

### Updating Software

```bash
# On internet-connected machine
./download-installers.sh --all

# Transfer and reinstall on air-gapped machine
./cleanup.sh --uninstall
./setup.sh
```

## 📝 Checklist for Air-Gapped Deployment

### Preparation Phase
- [ ] Downloaded all platform installers
- [ ] Cached all container images
- [ ] Verified cache with MANIFEST.txt
- [ ] Created transfer package
- [ ] Generated and saved checksums (optional)
- [ ] Scanned images for vulnerabilities (optional)

### Transfer Phase
- [ ] Transferred package to air-gapped environment
- [ ] Extracted package on target machine
- [ ] Verified all files present

### Deployment Phase
- [ ] Docker installed and running
- [ ] Loaded all cached images
- [ ] Verified images in Docker
- [ ] Ran setup script
- [ ] All pods running successfully
- [ ] Services accessible

## 🎯 Quick Reference

```bash
# PREPARATION (Internet-connected)
./download-installers.sh --all    # Download all installers
./cache-images.sh                 # Cache all images
tar czf ess-demo-airgapped.tar.gz ess-demo/  # Package

# TRANSFER
# Copy ess-demo-airgapped.tar.gz to target machine

# DEPLOYMENT (Air-gapped)
tar xzf ess-demo-airgapped.tar.gz  # Extract
cd ess-demo/
./load-cached-images.sh            # Load images
./setup.sh --offline               # Deploy
./verify.sh                        # Verify
```

## 📚 Additional Resources

- [Kind Air-Gapped Guide](https://kind.sigs.k8s.io/docs/user/working-offline/)
- [Helm Air-Gapped Installation](https://helm.sh/docs/topics/advanced/#working-with-airgapped-environments)
- [Docker Save/Load Reference](https://docs.docker.com/engine/reference/commandline/save/)

## ⚠️ Limitations

1. **Initial Setup:** Requires one-time internet connection to download installers and images
2. **Updates:** Must be manually transferred from internet-connected machine
3. **Dynamic Scaling:** Cannot pull new images if not pre-cached
4. **External Dependencies:** Some features requiring external services may not work

## ✅ Benefits

1. **Security:** No internet connectivity during deployment
2. **Speed:** No download time for images (everything local)
3. **Reliability:** Not dependent on external registries
4. **Compliance:** Meets air-gapped environment requirements
5. **Repeatability:** Same deployment every time

---

**For questions or issues with air-gapped deployment, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)**

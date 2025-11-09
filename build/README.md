# Build Scripts

This directory contains scripts used during the **build and preparation** phase of the ESS Demo offline package. These scripts are **not** included in the final distribution packages.

## Scripts

### download-installers.sh / download-installers.ps1
Downloads all required software installers for offline installation:
- Docker Desktop/Engine
- Kind (Kubernetes in Docker)
- kubectl
- Helm
- k9s
- mkcert

**Usage:**
```bash
# Download for current platform
./download-installers.sh

# Download for all platforms
./download-installers.sh --all

# Download for specific platform
./download-installers.sh --platform linux
```

### cache-images.sh
Caches all container images required for the ESS deployment for completely offline/air-gapped environments.

**Usage:**
```bash
./cache-images.sh -y
```

### load-cached-images.sh
Loads cached container images into Docker/Kind for offline deployment.

**Usage:**
```bash
./load-cached-images.sh
```

### package-offline.sh
Creates distributable offline packages for each platform.

**Usage:**
```bash
./package-offline.sh
```

### verify-offline.sh
Verifies that all required files are present for offline operation.

**Usage:**
```bash
./verify-offline.sh
```

## Workflow

1. **Download installers:**
   ```bash
   just download-all
   ```

2. **Cache container images:**
   ```bash
   just cache-images
   ```

3. **Verify everything:**
   ```bash
   just verify-all
   ```

4. **Build packages:**
   ```bash
   just build-packages
   ```

## See Also

- `/runtime` - Runtime scripts that are included in distribution packages
- `Justfile` - Automation recipes for the build process

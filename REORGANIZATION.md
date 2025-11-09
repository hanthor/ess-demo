# Directory Reorganization Summary

The ESS Demo project has been reorganized to separate build-time and runtime scripts.

## New Structure

```
ess-demo/
├── build/                          # Build-time scripts (NOT in distribution)
│   ├── README.md
│   ├── download-installers.sh      # Download installers for offline use
│   ├── download-installers.ps1     # Windows version
│   ├── cache-images.sh             # Cache container images
│   ├── load-cached-images.sh       # Load cached images into Kind
│   ├── package-offline.sh          # Build distribution packages
│   └── verify-offline.sh           # Verify offline readiness
│
├── runtime/                        # Runtime scripts (INCLUDED in distribution)
│   ├── README.md
│   ├── macos/
│   │   ├── setup.sh                # Install ESS on macOS
│   │   ├── verify.sh               # Verify installation
│   │   ├── cleanup.sh              # Remove ESS
│   │   └── build-certs.sh          # Generate certificates
│   ├── linux/
│   │   ├── setup.sh                # Install ESS on Linux
│   │   ├── verify.sh               # Verify installation
│   │   ├── cleanup.sh              # Remove ESS
│   │   └── build-certs.sh          # Generate certificates
│   └── windows/
│       ├── setup.ps1               # Install ESS on Windows
│       ├── verify.ps1              # Verify installation
│       └── cleanup.ps1             # Remove ESS
│
├── packages/                       # Generated distribution packages
│   ├── macos/
│   │   ├── INSTALL.md
│   │   ├── install.sh
│   │   ├── extract-installers.sh
│   │   ├── setup.sh                # <- Copied from runtime/macos/
│   │   ├── verify.sh               # <- Copied from runtime/macos/
│   │   ├── cleanup.sh              # <- Copied from runtime/macos/
│   │   └── build-certs.sh          # <- Copied from runtime/macos/
│   ├── linux/
│   │   ├── INSTALL.md
│   │   ├── install.sh
│   │   ├── extract-installers.sh
│   │   ├── setup.sh                # <- Copied from runtime/linux/
│   │   ├── verify.sh               # <- Copied from runtime/linux/
│   │   ├── cleanup.sh              # <- Copied from runtime/linux/
│   │   └── build-certs.sh          # <- Copied from runtime/linux/
│   └── windows/
│       ├── INSTALL.md
│       ├── install.ps1
│       ├── extract-installers.ps1
│       ├── setup.ps1               # <- Copied from runtime/windows/
│       ├── verify.ps1              # <- Copied from runtime/windows/
│       └── cleanup.ps1             # <- Copied from runtime/windows/
│
├── installers/                     # Downloaded binaries
├── image-cache/                    # Cached container images
├── demo-values/                    # Helm values
├── .just-templates/                # Package generation templates
├── Justfile                        # Build automation
└── JUSTFILE-README.md              # Just documentation
```

## Separation of Concerns

### Build Scripts (`/build`)
**Purpose:** Used by developers/builders to prepare offline packages

**When used:** During package creation process

**Not included in:** Final distribution packages

**Examples:**
- Downloading installers from the internet
- Caching container images
- Building packages
- Verifying offline readiness

### Runtime Scripts (`/runtime`)
**Purpose:** Used by end-users to install and manage ESS

**When used:** After receiving the offline package

**Included in:** Final distribution packages (platform-specific)

**Examples:**
- Installing ESS from offline installers
- Verifying the installation
- Cleaning up/uninstalling

## Workflow

### For Package Builders

1. **Download installers:**
   ```bash
   just download-all
   # Uses: build/download-installers.sh
   ```

2. **Cache images:**
   ```bash
   just cache-images
   # Uses: build/cache-images.sh
   ```

3. **Build packages:**
   ```bash
   just build-packages
   # Copies: runtime/{platform}/* → packages/{platform}/
   ```

### For End Users

1. **Receive package:**
   - Distributed as `packages/linux/` or `packages/macos/` or `packages/windows/`

2. **Extract and install:**
   ```bash
   cd packages/linux
   ./install.sh
   ```

3. **Run setup:**
   ```bash
   ./setup.sh
   # This is runtime/linux/setup.sh copied during build
   ```

4. **Verify:**
   ```bash
   ./verify.sh
   # This is runtime/linux/verify.sh copied during build
   ```

5. **Cleanup (optional):**
   ```bash
   ./cleanup.sh
   # This is runtime/linux/cleanup.sh copied during build
   ```

## Benefits

✅ **Clear separation** - Build vs. runtime scripts are in different directories
✅ **Smaller packages** - Build scripts not included in distribution
✅ **Platform-specific** - Each OS gets only its relevant scripts
✅ **Easy customization** - Modify runtime scripts per platform
✅ **Better organization** - Purpose of each script is clear from its location

## Migration Notes

### Scripts Moved to `/build`:
- `download-installers.sh` → `build/download-installers.sh`
- `download-installers.ps1` → `build/download-installers.ps1`
- `cache-images.sh` → `build/cache-images.sh`
- `load-cached-images.sh` → `build/load-cached-images.sh`
- `package-offline.sh` → `build/package-offline.sh`
- `verify-offline.sh` → `build/verify-offline.sh`

### Scripts Copied to `/runtime`:
- `setup.sh` → `runtime/{macos,linux}/setup.sh`
- `setup.ps1` → `runtime/windows/setup.ps1`
- `verify.sh` → `runtime/{macos,linux}/verify.sh`
- `verify.ps1` → `runtime/windows/verify.ps1`
- `cleanup.sh` → `runtime/{macos,linux}/cleanup.sh`
- `cleanup.ps1` → `runtime/windows/cleanup.ps1`
- `build-certs.sh` → `runtime/{macos,linux}/build-certs.sh`

### Justfile Updates:
- Added `BUILD_DIR` and `RUNTIME_DIR` variables
- Updated script paths in recipes
- Package templates now copy from `runtime/` to `packages/`

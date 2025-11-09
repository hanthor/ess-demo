# Runtime Scripts

This directory contains platform-specific scripts that are **included in the final distribution packages**. These scripts are used by end-users to install, manage, and uninstall the ESS Demo.

## Directory Structure

```
runtime/
├── macos/          # macOS-specific runtime scripts
│   ├── setup.sh
│   ├── verify.sh
│   ├── cleanup.sh
│   └── build-certs.sh
├── linux/          # Linux-specific runtime scripts
│   ├── setup.sh
│   ├── verify.sh
│   ├── cleanup.sh
│   └── build-certs.sh
└── windows/        # Windows-specific runtime scripts
    ├── setup.ps1
    ├── verify.ps1
    └── cleanup.ps1
```

## Scripts

### setup.sh / setup.ps1
Main installation script that:
- Installs prerequisites from the bundled installers
- Creates a Kind cluster
- Generates TLS certificates
- Deploys the ESS stack
- Configures local DNS/hosts

**Usage:**
```bash
# macOS/Linux
./setup.sh

# Windows (as Administrator)
.\setup.ps1
```

### verify.sh / verify.ps1
Verification script that checks:
- Cluster status
- Pod health
- Service availability
- Ingress configuration
- Certificate validity

**Usage:**
```bash
# macOS/Linux
./verify.sh

# Windows
.\verify.ps1
```

### cleanup.sh / cleanup.ps1
Cleanup script that:
- Deletes the Kind cluster
- Removes certificates
- Cleans up generated files
- (Optionally) removes installed tools

**Usage:**
```bash
# macOS/Linux
./cleanup.sh

# Windows
.\cleanup.ps1
```

### build-certs.sh (macOS/Linux only)
Certificate generation script that:
- Installs local CA using mkcert
- Generates wildcard certificates
- Creates Kubernetes secrets

**Usage:**
```bash
./build-certs.sh
```

## Package Distribution

During the build process (`just build-packages`), these scripts are:

1. **Copied** from their platform-specific directory (`runtime/{macos,linux,windows}/`)
2. **Bundled** into the platform-specific package (`packages/{macos,linux,windows}/`)
3. **Distributed** to end-users as part of the offline installation package

## Customization

To customize the runtime behavior for a specific platform:

1. Edit the script in the appropriate `runtime/{platform}/` directory
2. Run `just build-packages` to regenerate the distribution packages
3. Test the updated package

## See Also

- `/build` - Build-time scripts (not included in distribution)
- `/packages` - Generated distribution packages
- `Justfile` - Automation recipes

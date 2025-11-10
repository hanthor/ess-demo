# Quick Start Guide - ESS Demo Air-gapped Package

## 🚀 TL;DR

```bash
# Step 1: Download all binaries (1st time only, ~10-15 min)
just download-installers

# Step 2-4: Build air-gapped package (requires sudo, ~30-45 min)
just setup-k3s      # Install local k3s
just deploy-ess     # Deploy ESS to k3s
just capture-images # Capture images with hauler

# Or all at once:
just build

# Then: Create packages (TODO)
just package
```

## 📋 All Available Commands

### Main Workflow
| Command | Purpose |
|---------|---------|
| `just build` | Full build (download → k3s → ess → capture) |
| `just download-installers` | Download all binaries |
| `just setup-k3s` | Setup local k3s cluster |
| `just deploy-ess` | Deploy ESS to k3s |
| `just capture-images` | Capture cluster images with hauler |

### Inspection
| Command | Purpose |
|---------|---------|
| `just status` | Check k3s cluster status |
| `just kubeconfig` | Show kubeconfig location |
| `just verify-store` | Check hauler store contents |
| `just versions` | Show component versions |
| `just disk-usage` | Show disk usage |

### Cleanup
| Command | Purpose |
|---------|---------|
| `just clean` | Remove all build artifacts |
| `just clean-k3s` | Uninstall k3s only |
| `just clean-all` | Clean everything including certs |

### Development
| Command | Purpose |
|---------|---------|
| `just debug-role ROLE` | Run specific role with verbose output |
| `just validate` | Validate Ansible syntax |
| `just docs` | Show workflow documentation |

## 📦 Build Artifacts

After a complete build, you'll have:

```
installers/
├── linux/
│   ├── k3s
│   ├── k3s-arm64
│   ├── kubectl
│   ├── kubectl-arm64
│   ├── helm-linux-amd64.tar.gz
│   ├── helm-linux-arm64.tar.gz
│   ├── k9s_Linux_amd64.tar.gz
│   ├── k9s_Linux_arm64.tar.gz
│   ├── mkcert-linux-amd64
│   ├── mkcert-linux-arm64
│   ├── zstd-1.5.6.tar.gz
│   ├── hauler_linux_amd64.tar.gz
│   └── hauler_linux_arm64.tar.gz
├── macos/
│   ├── kubectl
│   ├── helm-darwin-arm64.tar.gz
│   ├── k9s_Darwin_arm64.tar.gz
│   ├── mkcert-darwin-arm64
│   ├── Rancher.Desktop.dmg
│   ├── zstd-1.5.6.tar.gz
│   └── hauler_darwin_arm64.tar.gz
├── windows/
│   ├── kubectl.exe
│   ├── helm-windows-amd64.zip
│   ├── k9s_Windows_amd64.tar.gz
│   ├── mkcert-windows-amd64.exe
│   ├── Rancher.Desktop.Setup.msi
│   └── hauler_windows_amd64.zip
└── index.json

hauler-store/              # OCI artifact store
├── index.json
├── oci-layout
└── blobs/
    └── sha256/...
```

## 🔧 Troubleshooting

### Download stuck?
```bash
# Check what's downloaded so far
du -sh installers/*/

# Resume (downloads are idempotent)
just download-installers
```

### k3s won't start?
```bash
# Check status
just status

# Check logs
sudo journalctl -u k3s -f

# Restart
sudo systemctl restart k3s
```

### Need kubeconfig?
```bash
# Show location
just kubeconfig

# Export for kubectl
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

### Clean up and start over
```bash
just clean-all
just build
```

## 📚 For More Information

- See `TODO.md` for task breakdown
- See `BUILD-STATUS.md` for current status
- See `Justfile` for all recipes
- See `ansible/setup-playbook.yml` for playbook structure

## 🎯 Next Steps

1. **Download installers** (currently running)
2. **Setup k3s** - `just setup-k3s` (requires sudo)
3. **Deploy ESS** - `just deploy-ess` (requires sudo)
4. **Capture images** - `just capture-images` (requires sudo)
5. **Create packages** - `just package` (TODO - Task 6)
6. **Test air-gapped** - `just test-airgap` (TODO - Task 7)

See `BUILD-STATUS.md` for detailed progress.

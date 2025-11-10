# ESS Community - Portable Cross-Platform Demo

A fully portable, offline-capable demo of Element Server Suite (ESS) Community that works on macOS, Windows, and Linux. This demo uses **K3s** (Linux), **Rancher Desktop** (macOS/Windows), and **Ansible** to provide a complete, idempotent local ESS environment.

## 🚀 Quick Start

### For Package Builders

If you're building offline distribution packages:

```bash
# Install Just (task runner) and Ansible
brew install just ansible  # macOS/Linux
# or choco install just  # Windows (then install Ansible via pip)

# Complete automated setup
just setup

# Or step by step:
just download-all      # Download installers for all platforms
just cache-images      # Cache container images
just build-packages    # Build distribution packages
```

See [`JUSTFILE-README.md`](JUSTFILE-README.md) for full automation documentation.

### For End Users - Ansible Deployment (Recommended)

The recommended deployment method uses Ansible for idempotent, resumable setup:

```bash
# Download installers first
./build/download-installers.sh

# Run Ansible playbook
cd ansible
ansible-playbook -i inventory.ini main-playbook.yml
```

See [`ansible/README.md`](ansible/README.md) for complete Ansible documentation.

### For End Users - Pre-built Packages

If you received a pre-built offline package, see the `INSTALL.md` in your platform package:
- `packages/macos/INSTALL.md`
- `packages/linux/INSTALL.md`
- `packages/windows/INSTALL.md`

## Prerequisites

- **Internet connection** (only for initial download of installers during build)
- **Administrator/sudo privileges** (for installation)
- **~10GB free disk space** (~15GB for full air-gapped cache)
- **Ansible** (recommended for deployment): `brew install ansible` or `pip install ansible`

## Build Process

### Step 1: Download Installers

Download all required software for offline use:

**macOS / Linux:**
```bash
# Download for current platform only
just download-current
# Or: build/download-installers.sh

# Or download for ALL platforms (macOS, Linux, Windows)
just download-all
# Or: build/download-installers.sh --all
```

**Windows (run PowerShell as Administrator):**
```powershell
# Download for Windows only
build\download-installers.ps1

# Or download for ALL platforms
build\download-installers.ps1 -All
```

This downloads (~700MB-1GB per platform, or ~3-4GB for all platforms):
- **K3s** (Linux only - lightweight Kubernetes)
- **Rancher Desktop** (macOS/Windows - includes Kubernetes + container runtime)
- **Podman** (alternative container runtime)
- **kubectl** (Kubernetes CLI)
- **Helm** (Package manager)
- **k9s** (Kubernetes TUI)
- **mkcert** (Local certificate authority)
- **Ansible** (automation/deployment tool)

### Step 2: Cache Images for Air-Gapped Deployment (Optional)

For completely offline/air-gapped deployment, cache all container images:

```bash
just cache-images
# Or: build/cache-images.sh -y
```

This downloads (~3-4GB):
- ESS Helm chart
- All ESS component images
- NGINX Ingress images

**Note:** This requires a container runtime to be running (Docker/Podman/K3s/Rancher Desktop).

### Step 3: Build Distribution Packages

```bash
just build-packages
# Builds: packages/macos/, packages/linux/, packages/windows/
```

Before going offline, verify all components are cached:

```bash
./verify-offline.sh
```

This checks for:
- Docker availability
- Cached installers for all platforms
- Cached container images
- Helm charts
- Configuration files

### Step 2: Run Setup

**macOS / Linux:**
```bash
# Default mode: uses cached images (offline mode)
./setup.sh

# To pull images from internet instead (online mode)
./setup.sh --online
```

**Windows (run PowerShell as Administrator):**
```powershell
.\setup.ps1
```

The setup script will:
1. ✓ Install all dependencies from local cache
2. ✓ Create a Kind Kubernetes cluster
3. ✓ Prompt you for a domain name (e.g., `ess.localhost`)
4. ✓ Generate SSL certificates using mkcert
5. ✓ Deploy ESS Community with all services
6. ✓ Configure ingress and networking

⏱️ **Setup time:** 5-10 minutes

## 📋 What's Included

This demo includes:

- **Element Web** - Modern Matrix web client
- **Element Admin** - Server administration interface
- **Synapse** - Matrix homeserver
- **Matrix Authentication Service** - User authentication and management
- **Matrix RTC** - Real-time communication (audio/video calls)
- **PostgreSQL** - Database backend
- **NGINX Ingress** - HTTP/HTTPS routing

## 🌐 Access Your Instance

After setup completes, access your ESS instance at:

- **Element Web:** `https://chat.<your-domain>`
- **Admin Portal:** `https://admin.<your-domain>`
- **Matrix Server:** `https://matrix.<your-domain>`
- **Authentication:** `https://auth.<your-domain>`

Replace `<your-domain>` with the domain you entered during setup.

## 🔧 Management Commands

### Download Software

```bash
# Download for current platform
./download-installers.sh

# Download for ALL platforms (great for preparing portable demos)
./download-installers.sh --all    # Unix
.\download-installers.ps1 -All    # Windows
```

### Cache Images for Air-Gapped Use

```bash
# Cache all container images
./cache-images.sh

# Load cached images (on target machine)
./load-cached-images.sh
```

### Check Status

**macOS / Linux:**
```bash
./verify.sh
```

**Windows:**
```powershell
.\verify.ps1
```

### View Resources

```bash
# View all pods
kubectl get pods -n ess

# Watch resources interactively with k9s
k9s -n ess

# View logs
kubectl logs -n ess -l app.kubernetes.io/name=synapse
```

### Cleanup

**macOS / Linux:**
```bash
# Remove Kind cluster only
./cleanup.sh

# Remove cluster AND uninstall all software
./cleanup.sh --uninstall
```

**Windows:**
```powershell
# Remove Kind cluster only
.\cleanup.ps1

# Remove cluster AND uninstall all software
.\cleanup.ps1 -Uninstall
```

## 📦 Portable Deployment

This demo is designed to be portable and can be distributed in two ways:

### Option 1: Manual Copy (Traditional)

1. **Download installers** once with internet connection:
   ```bash
   ./download-installers.sh --all  # All platforms
   ```

2. **Cache images** for air-gapped deployment:
   ```bash
   ./cache-images.sh -y
   ```

3. **Verify readiness**:
   ```bash
   ./verify-offline.sh
   ```

4. **Copy entire directory** to USB drive or portable storage

5. **Transfer to any machine** (macOS, Windows, or Linux)

6. **Run setup** - works completely offline!
   ```bash
   ./setup.sh  # Offline mode is default
   ```

### Option 2: Create Distribution Packages (Recommended)

For easier distribution, create platform-specific or universal packages:

```bash
# Create Linux-only package (~1.4GB)
./package-offline.sh linux

# Create macOS-only package (~1.6GB)
./package-offline.sh macos

# Create Windows-only package (~1.6GB)  
./package-offline.sh windows

# Create all platform-specific packages
./package-offline.sh --all

# Create one universal package with all platforms (~4.8GB)
./package-offline.sh --universal
```

Packages are created in `packages/` directory with SHA256 checksums.

**Distributing packages:**

Each package includes an installer script that automates extraction, verification, and setup:

1. Copy the `.tar.gz`, `.sha256`, and `-install.sh` files to target machine
2. Run the installer:
   ```bash
   chmod +x ess-demo-*-install.sh  # Make executable
   ./ess-demo-*-install.sh         # Run installer
   ```

The installer script will:
- ✓ Verify the package file exists
- ✓ Check SHA256 checksum integrity
- ✓ Extract the package
- ✓ Run offline verification
- ✓ Offer to run setup immediately

**Manual installation (if preferred):**
1. Verify: `sha256sum -c ess-demo-*.tar.gz.sha256`
2. Extract: `tar -xzf ess-demo-*.tar.gz`
3. Navigate: `cd ess-demo`
4. Run: `./setup.sh` (Linux/macOS) or `.\setup.ps1` (Windows)

### Directory Structure for Portability

```
ess-demo/
├── installers/          # Downloaded binaries (3-4GB with --all)
│   ├── macos/          # macOS binaries (Intel + Apple Silicon)
│   ├── linux/          # Linux binaries (x86_64 + ARM64)
│   └── windows/        # Windows binaries
├── image-cache/         # Cached container images (3-4GB)
│   ├── kind-images/    # Kind node image
│   ├── ess-images/     # ESS component images
│   └── helm-charts/    # Cached Helm chart
├── packages/            # Generated distribution packages
│   ├── ess-demo-linux-*.tar.gz
│   ├── ess-demo-macos-*.tar.gz
│   ├── ess-demo-windows-*.tar.gz
│   └── ess-demo-universal-*.tar.gz
├── setup.sh            # Setup script (Unix)
├── setup.ps1           # Setup script (Windows)
└── ...                 # Other scripts and configs
```

## � Security Notes

- Uses **mkcert** for local development certificates
- Certificates are automatically trusted on your machine
- **Not for production use** - this is a development/demo environment
- Browser may show certificate warnings on first access (click Advanced → Proceed)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Browser                         │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS (mkcert certs)
                     ↓
┌─────────────────────────────────────────────────────────┐
│              NGINX Ingress Controller                   │
│  ┌──────────┬──────────┬──────────┬──────────┐         │
│  │ chat.*   │ admin.*  │ matrix.* │ auth.*   │         │
│  └──────────┴──────────┴──────────┴──────────┘         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│           Kind Cluster (ess-demo)                       │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Element Web │  │ Element     │  │  Synapse    │    │
│  │             │  │ Admin       │  │             │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Matrix Auth │  │ Matrix RTC  │  │ PostgreSQL  │    │
│  │ Service     │  │             │  │             │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────────┘
                     │
                     ↓
              Docker Desktop/Engine
```

## � Configuration Files

All configuration is in `demo-values/`:

- `hostnames.yaml` - Domain and hostname configuration (auto-generated)
- `tls.yaml` - TLS/SSL certificate configuration
- `auth.yaml` - Authentication service settings
- `mrtc.yaml` - Matrix RTC configuration
- `pull-policy.yml` - Image pull policy

## � Troubleshooting

### Docker not running
**Error:** `Cannot connect to Docker daemon`

**Solution:**
- **macOS/Windows:** Start Docker Desktop
- **Linux:** `sudo systemctl start docker`

### Pods not starting
**Check status:**
```bash
kubectl get pods -n ess
kubectl describe pod <pod-name> -n ess
kubectl logs <pod-name> -n ess
```

### Certificate warnings
- Browser warnings are expected with self-signed certificates
- Click "Advanced" → "Proceed to site"
- mkcert certificates are trusted locally but not by other machines

### Port conflicts
If ports 80/443 are in use:
```bash
# Check what's using the ports
sudo lsof -i :80
sudo lsof -i :443

# Stop conflicting services
sudo systemctl stop apache2  # Example for Linux
```

## 🔄 Reinstalling

To completely reinstall:

```bash
# 1. Clean up existing installation
./cleanup.sh

# 2. Run setup again
./setup.sh
```

## 🔀 Alternative Deployment Methods

### Hauler (Air-Gapped Artifact Management)

For advanced air-gapped deployments, Hauler provides unified artifact management:

```bash
# Install Hauler
just install-hauler

# Sync all artifacts (images, charts, files)
just hauler-sync

# Check status
just hauler-status
```

Hauler provides:
- Single manifest for all artifacts
- Compressed storage (tar.zst)
- Built-in registry serving
- Checksum verification

See [HAULER.md](HAULER.md) for complete documentation.

### Ansible Playbooks (Optional)

For users who prefer Ansible or need remote deployment:

```bash
# Install Ansible
brew install ansible  # macOS
# or: sudo apt install ansible  # Linux

# Run setup playbook
cd ansible
ansible-playbook -i inventory.ini setup-playbook.yml
```

**Note**: Ansible is an **optional alternative**. The Bash scripts (`setup.sh`) are recommended for most users.

See [ansible/README.md](ansible/README.md) and [ANSIBLE-VS-BASH.md](ANSIBLE-VS-BASH.md) for details.

## 📚 Additional Resources

- [ESS Helm Chart](https://github.com/element-hq/ess-helm)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [mkcert GitHub](https://github.com/FiloSottile/mkcert)
- [kubectl Reference](https://kubernetes.io/docs/reference/kubectl/)
- [k9s Documentation](https://k9scli.io/)
- [Hauler Documentation](https://rancherfederal.github.io/hauler-docs/)

## 📖 Additional Documentation

- [HAULER.md](HAULER.md) - Hauler integration guide for air-gapped deployments
- [ANSIBLE-VS-BASH.md](ANSIBLE-VS-BASH.md) - Comparison of Ansible vs Bash approaches
- [AIR-GAPPED.md](AIR-GAPPED.md) - Traditional air-gapped deployment guide
- [JUSTFILE-README.md](JUSTFILE-README.md) - Just task runner documentation
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions

## 🤝 Support

For issues with:
- **This demo setup:** Check troubleshooting section above
- **ESS Community:** [ESS Helm GitHub Issues](https://github.com/element-hq/ess-helm/issues)
- **Kind:** [Kind GitHub Issues](https://github.com/kubernetes-sigs/kind/issues)

## 📜 License

This demo setup is provided as-is for demonstration purposes.

Element Server Suite (ESS) Community components have their own licenses - please refer to the [ESS Helm repository](https://github.com/element-hq/ess-helm) for details.

---

**Made portable with ❤️ for cross-platform Matrix deployments**


### Explaining the install process

#### Use kubectl to watch the pods
```
kubectl get pods -n ess -w
NAME                                                   READY   STATUS      RESTARTS   AGE
```

#### Watch in Rancher UI

![Rancher](assets/rancher.png)

#### Setup steps

1. The deployment markers run first, and make sure that the state of the installation is compatible with the values passed in the values files. For example, it would prevent disabling MAS once ESS is setup with MAS enabled.
  ```
  ess-deployment-markers-pre-6c75f                       0/1     Completed   0          11m
  ```
1. All the secrets that the chart is able to generate are initialized
  ```
  ess-init-secrets-kdh42                                 0/1     Completed   0          11m
  ```
1. A job runs before the main installation to check that runs basic checks against synapse configuration
  ```
  ess-synapse-check-config-69t7c                         0/1     Completed   0          11m
  ```
1. The main installation runs by setting up a couple of services in parallel.
  1. Postgres is automatically created by default, and hosts all the required databases used within ESS.
  ```
  ess-postgres-0                                         3/3     Running     0          10m
  ```
  1. HAProxy handles internal routing to Synapse and its workers
  ```
  ess-haproxy-7bbc94b855-mt6bj                           1/1     Running     0          10m
  ```
  1. Synapse starts with only a `main` process which should be enough for most simple homeservers.
  ```
  ess-synapse-main-0                                     1/1     Running     0          10m
  ```
  1. Matrix Authentication Service starts.
  ```
  ess-matrix-authentication-service-56597f54c5-fqd9b     1/1     Running     0          10m
  ```
  1. Matrix RTC is made of 2 services : The authorisation service and the SFU. The Authorisation service issues JWT tokens for Matrix users to authenticate against the SFU. The SFU handles the VoIP WebRTC traffic.
  ```
  ess-matrix-rtc-authorisation-service-9ff6d44d5-z7n2n   1/1     Running     0          10m
  ess-matrix-rtc-sfu-5896d47fd4-5dvs2                    1/1     Running     0          10m
  ```
  1. Element Web and Element Admin clients start.
  ```
  ess-element-admin-59b96c7fc8-p2thz                     1/1     Running     0          10m
  ess-element-web-56f99c8889-hszzj                       1/1     Running     0          10m
  ```
  1. Deployment Markers post-hook run to update the markers. Those will prevent you to pass breaking configuration to your ESS deployment.
  ```
  ess-deployment-markers-post-vwb7f                      0/1     Completed   0          10m
  ```

### First actions and checks

#### Create 1 initial admin user

Run the following command, and select "Set the admin status", "Set Password", and then "Create the user".

```
kubectl exec -n ess -it deploy/ess-matrix-authentication-service -- mas-cli manage register-user
```

#### Open the admin UI

Go to `https://<admin ui hostname>` and login with the credentials you just created.

#### Create a new registration token

From the Admin UI, create a new registration token. This can be used to register a new user.

#### Open the web client

Go to  `https://<web client hostname>` and register new users using registration tokens issued before.

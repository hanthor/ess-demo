# Ansible Setup for ESS Demo

This directory contains **comprehensive Ansible playbooks** for deploying ESS Community with K3s (Linux) or Rancher Desktop (macOS/Windows).

## Overview

The Ansible playbooks provide a **complete, idempotent, and resumable** setup process as the primary deployment method for ESS Demo. They support:

- **K3s** on Linux (lightweight Kubernetes)
- **Rancher Desktop** on macOS and Windows
- **Podman** as a fallback container runtime
- **Automatic version detection** and installation
- **Resumable deployments** (safe to re-run)
- **Declarative configuration**

## Prerequisites

### 1. Install Ansible

**macOS:**
```bash
brew install ansible
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install ansible
```

**RHEL/CentOS:**
```bash
sudo yum install ansible
```

**Via pip:**
```bash
pip install ansible
```

### 2. Download ESS Installers

Before running the playbook, download the required installers:

```bash
cd ..
./build/download-installers.sh
```

This downloads K3s, Rancher Desktop, kubectl, Helm, k9s, mkcert, and Ansible packages for offline installation.

## Usage

### Complete Setup (Recommended)

```bash
ansible-playbook -i inventory.ini main-playbook.yml
```

You will be prompted for:
- Domain name for your ESS instance (e.g., `ess.localhost`)

### Non-Interactive Setup

```bash
ansible-playbook -i inventory.ini main-playbook.yml \
  --extra-vars "domain_name=ess.localhost"
```

### Check Mode (Dry Run)

See what would change without making changes:

```bash
ansible-playbook -i inventory.ini main-playbook.yml --check
```

### Verbose Output

```bash
ansible-playbook -i inventory.ini main-playbook.yml -v
ansible-playbook -i inventory.ini main-playbook.yml -vv  # More verbose
ansible-playbook -i inventory.ini main-playbook.yml -vvv # Even more verbose
```

## What the Playbooks Do

### Main Playbook (`main-playbook.yml`)

The main setup playbook performs these tasks in order:

1. ✓ **Platform Detection** - Detects OS (macOS/Linux) and architecture (x86_64/arm64)
2. ✓ **Installer Verification** - Checks that installers are downloaded
3. ✓ **Container Runtime Setup** - Installs K3s (Linux) or Rancher Desktop (macOS)
   - Falls back to Podman if available
   - Uses existing Docker/Podman if already installed
4. ✓ **Kubernetes Tools** - Installs kubectl, Helm, k9s from local cache
5. ✓ **Certificate Setup** - Installs mkcert and generates SSL certificates
6. ✓ **Domain Configuration** - Prompts for and configures domain name
7. ✓ **Cluster Creation** - Creates Kubernetes cluster with K3s or Rancher Desktop
8. ✓ **ESS Deployment** - Deploys ESS Helm chart with all services
9. ✓ **Status Display** - Shows access URLs and useful commands

### Cleanup Playbook (`cleanup-playbook.yml`)

```bash
# Remove cluster only
ansible-playbook -i inventory.ini cleanup-playbook.yml

# Remove cluster AND uninstall all software
ansible-playbook -i inventory.ini cleanup-playbook.yml \
  --extra-vars "uninstall_software=true"
```

## Advantages of Ansible

- **Idempotent**: Safe to run multiple times - won't break existing setup
- **Resumable**: If interrupted, can continue from where it left off
- **Declarative**: Describes desired state, not procedural steps
- **Error Handling**: Clear task-by-task feedback and automatic rollback
- **Dry Run**: Preview changes with `--check` mode
- **Structured**: YAML is easier to read and maintain than bash
- **Version Control**: Configuration is code, easy to track changes
- **Extensible**: Easy to add new tasks or customize

## Container Runtime Strategy

The playbooks follow this strategy:

### Linux
1. Check for existing Docker/Podman
2. If none found, install **K3s** (lightweight Kubernetes)
3. K3s includes containerd runtime

### macOS
1. Check for existing Docker
2. If none found, install **Rancher Desktop** (includes Kubernetes + containerd)
3. Rancher Desktop provides GUI for container management

### Windows
1. Install **Rancher Desktop** (via MSI installer)
2. Rancher Desktop includes everything needed

### Fallback
- If nothing else works, install **Podman** as container runtime

## Files Structure

```
ansible/
├── inventory.ini              # Ansible inventory (localhost only)
├── main-playbook.yml          # Main setup playbook
├── cleanup-playbook.yml       # Cleanup playbook
├── setup-playbook.yml         # Legacy simplified playbook
├── tasks/                     # Task files (imported by main playbook)
│   ├── container-runtime.yml  # K3s/Rancher Desktop/Podman setup
│   ├── kubernetes-tools.yml   # kubectl, Helm, k9s installation
│   ├── certificates.yml       # mkcert and SSL certificate setup
│   ├── domain-config.yml      # Domain name configuration
│   ├── cluster-setup.yml      # Kubernetes cluster creation
│   └── ess-deployment.yml     # ESS Helm chart deployment
└── README.md                  # This file
```

## Resumability

The playbooks are designed to be resumed safely:

- **Installation checks**: Each tool checks if already installed before installing
- **Namespace creation**: Uses `--ignore-not-found` to prevent errors on re-run
- **Helm deployments**: Uses `helm upgrade --install` for idempotency
- **Certificate generation**: Only generates if not exists
- **Service checks**: Validates services are running before proceeding

## Troubleshooting

### Playbook fails partway through
```bash
# Simply re-run the playbook - it will resume from where it failed
ansible-playbook -i inventory.ini main-playbook.yml
```

### Check cluster status
```bash
# For K3s (Linux)
sudo k3s kubectl get pods -n ess

# For Rancher Desktop (macOS)
kubectl get pods -n ess
```

### View detailed logs
```bash
# Add verbose flag
ansible-playbook -i inventory.ini main-playbook.yml -vv
```

### K3s not starting (Linux)
```bash
# Check K3s service status
sudo systemctl status k3s

# View K3s logs
sudo journalctl -u k3s -f
```

### Rancher Desktop not ready (macOS)
```bash
# Start Rancher Desktop from Applications
# Wait for Kubernetes icon to turn green
# Then re-run the playbook
```

## Accessing Your ESS Instance

After successful deployment:

- **Element Web:** `https://chat.<your-domain>`
- **Admin Portal:** `https://admin.<your-domain>`
- **Matrix Server:** `https://matrix.<your-domain>`
- **Auth Service:** `https://auth.<your-domain>`

## Useful Commands

```bash
# View all pods
kubectl get pods -n ess

# Interactive monitoring with k9s
k9s -n ess

# View logs for a specific pod
kubectl logs -n ess <pod-name>

# Delete and redeploy
ansible-playbook -i inventory.ini cleanup-playbook.yml
ansible-playbook -i inventory.ini main-playbook.yml
```

## Comparison with Bash Scripts

| Feature | Ansible Playbooks | Bash Scripts |
|---------|------------------|--------------|
| Idempotency | ✅ Built-in | ⚠️ Manual |
| Resumability | ✅ Automatic | ❌ Must start over |
| Error Handling | ✅ Automatic rollback | ⚠️ Manual |
| Dry Run | ✅ `--check` mode | ❌ Not available |
| Readability | ✅ Declarative YAML | ⚠️ Procedural bash |
| Dependencies | Ansible required | None (just bash) |
| Platform Support | All (with Ansible) | All (native bash) |

**Recommendation**: Use Ansible playbooks for production and reproducible deployments. Both approaches are fully supported.

## Contributing

When adding new features:

1. Add tasks to appropriate file in `tasks/` directory
2. Ensure idempotency (safe to re-run)
3. Add checks before destructive operations
4. Update this README with new features
5. Test on both Linux and macOS

## Support

For issues:
- Check [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) in main directory
- Review Ansible verbose output with `-vv` flag
- Check container runtime logs (K3s/Rancher Desktop)
- Verify all installers are downloaded

## License

Same as main ESS Demo project.

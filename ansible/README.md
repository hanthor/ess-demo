# Ansible Alternative Setup

This directory contains an **optional** Ansible-based alternative to the Bash setup scripts.

## ⚠️ Note

The Bash scripts (`setup.sh`) are the **recommended and primary** setup method. These Ansible playbooks are provided as an alternative for users who:

- Already use Ansible in their infrastructure
- Prefer declarative configuration management
- Want to deploy across multiple machines
- Need integration with existing Ansible workflows

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

## Usage

### Basic Setup (Interactive)

```bash
ansible-playbook -i inventory.ini setup-playbook.yml
```

You will be prompted for:
- Domain name for your ESS instance

### Non-Interactive Setup

```bash
ansible-playbook -i inventory.ini setup-playbook.yml \
  --extra-vars "domain_name=ess.localhost"
```

### Check Mode (Dry Run)

See what would change without making changes:

```bash
ansible-playbook -i inventory.ini setup-playbook.yml --check
```

### Verbose Output

```bash
ansible-playbook -i inventory.ini setup-playbook.yml -v
ansible-playbook -i inventory.ini setup-playbook.yml -vv  # More verbose
ansible-playbook -i inventory.ini setup-playbook.yml -vvv # Even more verbose
```

## What the Playbook Does

The setup playbook performs these tasks:

1. ✓ Detects platform (macOS/Linux, architecture)
2. ✓ Verifies installers are downloaded
3. ✓ Checks for Docker/Podman
4. ✓ Installs Kind, kubectl, Helm, mkcert from local installers
5. ✓ Prompts for domain name
6. ✓ Generates configuration files
7. ✓ Creates Kind Kubernetes cluster
8. ✓ Displays setup status

## Advantages Over Bash

- **Idempotent**: Safe to run multiple times
- **Declarative**: Describes desired state, not steps
- **Better Error Handling**: Clear task-by-task feedback
- **Dry Run**: See changes before applying
- **Structured**: YAML is easier to read than complex bash

## Disadvantages vs Bash

- **Extra Dependency**: Requires Ansible installation
- **Startup Overhead**: ~2-3 seconds slower
- **Learning Curve**: Needs Ansible knowledge
- **Complexity**: Simple tasks become verbose

## Comparison with Bash Scripts

See [../ANSIBLE-VS-BASH.md](../ANSIBLE-VS-BASH.md) for detailed comparison.

**Summary**: Bash scripts are simpler and recommended for most users. Use Ansible if you already have it in your workflow.

## Current Status

**Note**: This is a **simplified prototype** demonstrating Ansible as an alternative. The full Bash implementation in `setup.sh` has more features and is more thoroughly tested.

### Implemented
- Platform detection
- Dependency installation from local installers
- Domain name configuration
- Basic setup workflow

### Not Yet Implemented in Ansible Version
- Full Docker installation (macOS DMG mounting, Linux daemon setup)
- Cached image loading
- Kind cluster creation with cached images
- NGINX Ingress installation
- Certificate generation with mkcert
- ESS Helm chart deployment
- Complete access information display

To get a fully working setup, use the Bash scripts instead:

```bash
cd ..
./setup.sh
```

## Files

- `inventory.ini` - Ansible inventory (localhost only)
- `setup-playbook.yml` - Main setup playbook (simplified)
- `README.md` - This file

## Future Enhancements (If Ansible adoption increases)

- Complete playbook with all features from setup.sh
- Cleanup playbook (equivalent to cleanup.sh)
- Verification playbook (equivalent to verify.sh)
- Role-based structure for better organization
- Support for remote deployments
- Multi-node Kind cluster setup

## Questions?

See the main project documentation in the parent directory:
- [README.md](../README.md) - Main project documentation
- [ANSIBLE-VS-BASH.md](../ANSIBLE-VS-BASH.md) - Detailed Ansible vs Bash analysis
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - General troubleshooting

## Recommendation

**For most users**: Use `../setup.sh` instead.

**Use this Ansible playbook if**: You're already an Ansible user and want to integrate ESS demo into your existing Ansible workflows.

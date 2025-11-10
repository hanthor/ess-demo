# Quick Reference: Justfile Ansible Arguments

## Quick Start

```bash
# Show all recipes
just

# Show documentation
just docs

# Show this help
cat ANSIBLE-ARGS.md
```

## Build Recipes with Ansible Args

All these recipes accept Ansible command-line arguments:

```bash
# Standard usage
just download-installers          # Default (no extra args)
just download-installers -vvv     # Verbose debugging
just download-installers -C       # Dry-run (check mode)

# Setup k3s with password prompt
just setup-k3s -K                 # Ask for sudo password
just setup-k3s -K -vvv            # Verbose + password

# Deploy ESS
just deploy-ess -vvv              # Verbose output
just deploy-ess -C -vvv           # Dry-run with details

# Capture images
just capture-images -vvv          # Verbose

# Package for air-gapped
just package -vvv                 # Verbose

# Test air-gapped deployment
just test-airgap -vvv             # Verbose
```

## Most Useful Arguments

| Arg | Use Case | Example |
|-----|----------|---------|
| `-vvv` | Debugging - see what's happening | `just deploy-ess -vvv` |
| `-K` | Running with sudo - ask for password | `just setup-k3s -K` |
| `-C` | Dry-run - see what would happen | `just deploy-ess -C` |
| `--check --diff` | Dry-run with differences | `just deploy-ess -C --diff` |
| `-e VAR=VALUE` | Override variables | `just download-installers -e 'use_latest_versions=true'` |
| `--list-tasks` | See all tasks (debug-role only) | `just debug-role installers --list-tasks` |
| `--step` | Step through each task | `just debug-role k3s-local --step` |

## Debug Recipes

```bash
# Debug specific role with verbose output
just debug-role installers        # Defaults to -vvv
just debug-role installers -vvv   # Explicitly verbose
just debug-role k3s-local --step  # Step through tasks

# List all tasks without running
just debug-role ess-deploy --list-tasks

# Dry-run specific role
just debug-role hauler-capture -C
```

## Common Workflows

### Troubleshooting a Failed Deploy
```bash
# Re-run with maximum verbosity
just deploy-ess -vvv

# Or dry-run first to see what would happen
just deploy-ess -C -vvv
```

### Testing Changes Without Applying
```bash
# Check what k3s setup would do
just setup-k3s -C -vvv

# Check what packaging would create
just package -C
```

### Running with Privilege Requirements
```bash
# Ask for sudo password upfront
just setup-k3s -K

# Or chain multiple commands
just setup-k3s -K && just deploy-ess -K
```

### Development & Iteration
```bash
# First validate syntax
just validate

# Then dry-run
just deploy-ess -C -vvv

# Then actual run
just deploy-ess -vvv
```

## Full Argument Reference

See **ANSIBLE-ARGS.md** for:
- Complete argument list with descriptions
- Real-world examples for each argument
- Troubleshooting guide
- Tips & tricks

## Syntax Rules

```bash
# ✅ Correct - single quotes for complex args
just deploy-ess -e 'key=value with spaces'

# ✅ Correct - combine multiple short args
just setup-k3s -K -vvv

# ✅ Correct - debug recipe has special syntax
just debug-role ROLE_NAME [ARGS...]

# ❌ Wrong - no quotes on complex values
just deploy-ess -e key=value with spaces

# ❌ Wrong - recipes with no args can't accept them
just status -vvv  (status doesn't support args)
```

## Recipes Overview

### Build Recipes (Accept Args)
- `just download-installers [ARGS]` - Download binaries
- `just setup-k3s [ARGS]` - Setup k3s cluster
- `just deploy-ess [ARGS]` - Deploy ESS to k3s
- `just capture-images [ARGS]` - Capture images with hauler
- `just package [ARGS]` - Create packages
- `just test-airgap [ARGS]` - Test packages
- `just build [ARGS]` - Run all steps
- `just debug-role ROLE [ARGS]` - Debug specific role

### Info Recipes (No Args)
- `just docs` - Show documentation
- `just status` - Check cluster status
- `just versions` - Show component versions
- `just disk-usage` - Show disk usage
- `just kubeconfig` - Show kubeconfig path
- `just verify-store` - Check hauler store

### Cleanup Recipes (No Args)
- `just clean` - Remove build artifacts
- `just clean-k3s` - Uninstall k3s
- `just clean-all` - Remove everything

## For More Help

```bash
# See full documentation
cat IMPLEMENTATION-SUMMARY.md

# See all Ansible arguments
cat ANSIBLE-ARGS.md

# See detailed tasks
cat TODO.md

# Get Ansible help
ansible-playbook --help
```

---

**TL;DR:**
- `just <recipe> -vvv` for debugging
- `just <recipe> -K` for password prompt
- `just <recipe> -C` for dry-run
- `just debug-role <role>` for role-specific debugging

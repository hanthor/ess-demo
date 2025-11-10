# Ansible Arguments with Justfile

## Overview

All Justfile recipes now accept optional Ansible command-line arguments. This allows you to pass flags like `-vvv` (verbose), `-K` (ask for password), `-C` (check/dry-run), and more.

## Usage Syntax

```bash
just <recipe> [ANSIBLE_ARGS]
```

Examples:
```bash
# Extra verbose output
just download-installers -vvv

# Ask for sudo password
just setup-k3s -K

# Dry-run (check mode)
just deploy-ess -C

# Combination of args
just capture-images -vvv -K -C

# Debug specific role with custom args
just debug-role installers -vvv
```

## Common Ansible Arguments

### Verbosity Control
```bash
-v      # Verbose - show task names
-vv     # More verbose - show results
-vvv    # Very verbose - show debugging info (most useful)
-vvvv   # Extreme verbosity (rarely needed)
```

Examples:
```bash
just download-installers -vvv
just setup-k3s -vv
just deploy-ess -v
```

### Become/Privilege Escalation
```bash
-K      # Ask for become (sudo) password interactively
-k      # Ask for connection password
--become-user=USER    # Run as specific user (default: root)
```

Examples:
```bash
# Most common - asks for sudo password
just setup-k3s -K

# Verbose + ask for password
just capture-images -vvv -K

# Become as specific user
just deploy-ess --become-user=appuser
```

### Check/Dry-run Mode
```bash
-C          # Check mode - show what would happen without making changes
--check     # Same as -C
--diff      # Show differences (works with -C for preview)
```

Examples:
```bash
# Dry-run to see what would happen
just deploy-ess -C

# Dry-run with verbose output to see details
just deploy-ess -C -vvv

# Show differences without applying
just capture-images --check --diff
```

### Variable Passing
```bash
-e VAR=VALUE        # Set extra variable
-e KEY=VALUE        # Multiple times for multiple vars
-e '@file.json'     # Load variables from JSON file
-e '@file.yml'      # Load variables from YAML file
```

Examples:
```bash
# Override a variable
just download-installers -e 'use_latest_versions=true'

# Multiple variables
just setup-k3s -K -e 'restart_k3s=true' -e 'debug_mode=yes'

# Load from file
just deploy-ess -e '@vars.yml'
```

### Other Useful Options
```bash
--syntax-check      # Validate playbook syntax only (fast check)
--step              # Step through each task (ask to continue)
--start-at-task=TASK # Start from specific task (skip earlier ones)
--list-tasks        # List all tasks without running
--list-hosts        # List all hosts that would be targeted
```

Examples:
```bash
# Validate syntax before running
just validate  # or use:
ansible-playbook --syntax-check ansible/setup-playbook.yml

# Debug specific role with step-through
just debug-role installers --step

# List all tasks in a playbook
just debug-role k3s-local --list-tasks

# Start capture-images from specific task
just capture-images --start-at-task="Extract hauler binary"
```

## Real-World Examples

### 1. Troubleshooting Deployment Failure
```bash
# Run with maximum verbosity to see exactly what's happening
just deploy-ess -vvv

# Or with dry-run first
just deploy-ess -vvv -C
```

### 2. Testing Setup Changes (Dry-run)
```bash
# Test k3s setup without actually making changes
just setup-k3s -C -vvv

# Test packaging without creating files
just package -C
```

### 3. Running with Sudo Prompt
```bash
# Setup k3s needs sudo, so ask for password upfront
just setup-k3s -K

# Multiple steps with password
just setup-k3s -K
just deploy-ess -K
```

### 4. Overriding Configuration
```bash
# Use latest versions instead of pinned versions
just download-installers -e 'use_latest_versions=true'

# Test with different installer directory
just download-installers -e 'installers_dir=/custom/path'
```

### 5. Debugging Specific Role
```bash
# Debug installers role with verbose output
just debug-role installers -vvv

# Step through each task
just debug-role k3s-local --step

# List all tasks without running
just debug-role ess-deploy --list-tasks

# Dry-run specific role
just debug-role hauler-capture -C -vvv
```

### 6. Sequential Debugging
```bash
# First check syntax
ansible-playbook --syntax-check ansible/setup-playbook.yml

# Then list what would run
just download-installers --list-tasks

# Then dry-run
just download-installers -C

# Finally run with verbose output
just download-installers -vvv
```

## Argument Passing Reference

### Build Workflow Recipes
All these recipes accept ANSIBLE_ARGS:
- `just download-installers [ARGS]`
- `just setup-k3s [ARGS]`
- `just deploy-ess [ARGS]`
- `just capture-images [ARGS]`
- `just package [ARGS]`
- `just test-airgap [ARGS]`

### Debug Recipe
Special format (first arg is ROLE, rest are ANSIBLE_ARGS):
- `just debug-role ROLE [ARGS]`

Default for debug-role is `-vvv` if no args provided.

### Fixed Recipes (No Args)
These recipes don't accept args:
- `just build` - Chains other recipes
- `just status` - Simple shell commands
- `just kubeconfig` - Shell commands
- `just verify-store` - Shell commands
- `just clean*` - Cleanup commands
- `just docs` - Display help
- `just versions` - Show versions
- `just disk-usage` - Show disk usage
- `just validate` - Static check (direct call)

## Tips & Tricks

### 1. Create an alias for verbose mode
```bash
# Add to ~/.bashrc or ~/.zshrc
alias just-debug='just'

# Use it as:
just-debug deploy-ess -vvv -K
```

### 2. Always ask for password with setup
```bash
# Create a wrapper script for setup-k3s:
#!/bin/bash
just setup-k3s -K "$@"
```

### 3. Check what a recipe would do before running
```bash
# Dry-run first (with verbose to see details)
just deploy-ess -C -vvv

# If output looks good, run it
just deploy-ess -vvv
```

### 4. Save complex commands as just aliases
```bash
# In Justfile, create a recipe:
setup-debug:
    just setup-k3s -K -vvv

# Use as:
just setup-debug
```

### 5. Combine with shell pipes for filtered output
```bash
# Show only errors/warnings
just deploy-ess -vvv 2>&1 | grep -i "error\|warning\|fatal"

# Show only task names
just deploy-ess -v 2>&1 | grep "^TASK"
```

## Troubleshooting Argument Issues

### "Unknown option" error
Make sure you're using valid Ansible options:
```bash
# ❌ Wrong - not an Ansible option
just deploy-ess --my-option

# ✅ Correct - valid Ansible option
just deploy-ess -vvv
```

### Arguments seem ignored
Check that recipe definition includes `{{ ARGS }}`:
```bash
# ✅ Correct recipe definition
deploy-ess ARGS='':
    ansible-playbook ... {{ ARGS }}

# ❌ Won't work - missing {{ ARGS }}
deploy-ess ARGS='':
    ansible-playbook ...
```

### Quotes needed for complex arguments
Use single quotes for shell safety:
```bash
# ✅ Correct - quoted properly
just deploy-ess -e 'key=value with spaces'

# May have issues without quotes
just deploy-ess -e key=value with spaces
```

---

**Quick Reference:**
```bash
just <recipe> -vvv           # Verbose debugging
just <recipe> -K             # Ask for sudo password
just <recipe> -C             # Dry-run (check mode)
just debug-role <ROLE> -vvv  # Debug specific role
```

For more Ansible options: `ansible-playbook --help`

#!/usr/bin/env bash
# Small wrapper to run the Ansible playbook in local mode
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_PLAYBOOK_CMD="ansible-playbook"
PLAYBOOK_PATH="$ROOT_DIR/ansible/playbook.yml"
INVENTORY="$ROOT_DIR/ansible/inventory/localhost.ini"

if ! command -v "$ANSIBLE_PLAYBOOK_CMD" &> /dev/null; then
    echo "ansible-playbook not found. Please install Ansible (pip install ansible-core) or use your package manager."
    exit 2
fi

echo "Running Ansible playbook: $PLAYBOOK_PATH"
"$ANSIBLE_PLAYBOOK_CMD" -i "$INVENTORY" "$PLAYBOOK_PATH" "$@"

#!/bin/bash
# Run RSAT installation playbook with logging
# Usage: ./run-rsat-install.sh

LOG_FILE="ansible/rsat-installation-$(date +%Y%m%d-%H%M%S).log"

echo "Running RSAT installation playbook..."
echo "Log file: $LOG_FILE"
echo ""

OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES \
  ansible-playbook \
  -i terraform/ansible/inventory/azure_windows.yml \
  ansible/playbooks/install-rsat.yml \
  2>&1 | tee "$LOG_FILE"

echo ""
echo "Playbook completed. Log saved to: $LOG_FILE"

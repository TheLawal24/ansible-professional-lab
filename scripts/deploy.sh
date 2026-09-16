#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

TARGET_HOST="${TARGET_HOST:-ubuntu-devops}"
ANSIBLE_TAGS="${ANSIBLE_TAGS:-webapp}"
VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-$HOME/.ansible/vault-pass.txt}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-}"
ANSIBLE_HOST_OVERRIDE="${ANSIBLE_HOST_OVERRIDE:-}"

if [[ -z "${SSH_PRIVATE_KEY}" && -f "$HOME/.ssh/google_compute_engine" ]]; then
  SSH_PRIVATE_KEY="$HOME/.ssh/google_compute_engine"
fi

echo "Target host: ${TARGET_HOST}"
echo "Ansible tags: ${ANSIBLE_TAGS}"

ANSIBLE_ARGS=(
  site.yml
  --limit "${TARGET_HOST}"
  --tags "${ANSIBLE_TAGS}"
  --vault-password-file "${VAULT_PASSWORD_FILE}"
)

if [[ -n "${SSH_PRIVATE_KEY}" ]]; then
  echo "SSH key: configured"
  ANSIBLE_ARGS+=(--private-key "${SSH_PRIVATE_KEY}")
else
  echo "ERROR: No SSH private key was provided."
  exit 1
fi

if [[ -n "${ANSIBLE_HOST_OVERRIDE}" ]]; then
  echo "Ansible host override: ${ANSIBLE_HOST_OVERRIDE}"
  ANSIBLE_ARGS+=(-e "ansible_host=${ANSIBLE_HOST_OVERRIDE}")
fi

ansible-playbook "${ANSIBLE_ARGS[@]}"

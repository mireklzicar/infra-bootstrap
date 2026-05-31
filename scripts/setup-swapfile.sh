#!/usr/bin/env bash
set -euo pipefail

SWAP_SIZE="${1:-8G}"
SWAP_FILE="${2:-/swapfile}"
SWAPPINESS="${SWAPPINESS:-10}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this as root, for example: sudo bash $0 ${SWAP_SIZE} ${SWAP_FILE}" >&2
  exit 1
fi

if swapon --show=NAME --noheadings | grep -Fxq "${SWAP_FILE}"; then
  echo "${SWAP_FILE} is already active as swap."
  swapon --show
  exit 0
fi

if [[ -e "${SWAP_FILE}" ]]; then
  echo "${SWAP_FILE} already exists but is not active swap; refusing to overwrite it." >&2
  exit 1
fi

swap_dir="$(dirname "${SWAP_FILE}")"
fs_type="$(findmnt -no FSTYPE -T "${swap_dir}")"

echo "Creating ${SWAP_SIZE} swapfile at ${SWAP_FILE} on ${fs_type}..."

if [[ "${fs_type}" == "btrfs" ]]; then
  if ! command -v btrfs >/dev/null 2>&1; then
    echo "Btrfs filesystem detected, but the btrfs tool is missing." >&2
    exit 1
  fi
  btrfs filesystem mkswapfile --size "${SWAP_SIZE}" "${SWAP_FILE}"
else
  fallocate -l "${SWAP_SIZE}" "${SWAP_FILE}"
  chmod 600 "${SWAP_FILE}"
  mkswap "${SWAP_FILE}"
fi

swapon "${SWAP_FILE}"

if ! grep -Eq "^[[:space:]]*${SWAP_FILE//\//\\/}[[:space:]]" /etc/fstab; then
  printf '%s none swap sw 0 0\n' "${SWAP_FILE}" >>/etc/fstab
fi

cat >/etc/sysctl.d/99-swap-protection.conf <<EOF
vm.swappiness=${SWAPPINESS}
EOF
sysctl "vm.swappiness=${SWAPPINESS}"

echo
echo "Swap is now active:"
swapon --show

echo
echo "Memory summary:"
free -h

echo
echo "Persistent fstab entry:"
grep -E "^[[:space:]]*${SWAP_FILE//\//\\/}[[:space:]]" /etc/fstab

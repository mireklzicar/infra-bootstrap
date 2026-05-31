#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this as root, for example: sudo bash $0" >&2
  exit 1
fi

if [[ ! -e /proc/pressure/memory ]]; then
  echo "Memory PSI is not available at /proc/pressure/memory; systemd-oomd cannot work on this kernel." >&2
  exit 1
fi

if [[ "$(stat -fc %T /sys/fs/cgroup)" != "cgroup2fs" ]]; then
  echo "This system is not using unified cgroup v2; systemd-oomd requires cgroup v2." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y systemd-oomd

install -d -m 0755 /etc/systemd/system/user.slice.d
cat >/etc/systemd/system/user.slice.d/50-managed-oomd.conf <<'EOF'
[Slice]
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=60%
EOF

systemctl daemon-reload
systemctl enable --now systemd-oomd.service

# Apply the same values to the already-running user.slice without restarting it.
systemctl set-property --runtime user.slice \
  ManagedOOMMemoryPressure=kill \
  ManagedOOMMemoryPressureLimit=60%

systemctl restart systemd-oomd.service

echo
echo "systemd-oomd service:"
systemctl status systemd-oomd.service --no-pager

echo
echo "user.slice managed OOM settings:"
systemctl show user.slice \
  -p ManagedOOMMemoryPressure \
  -p ManagedOOMMemoryPressureLimit \
  -p ManagedOOMSwap \
  -p MemoryAccounting \
  --no-pager

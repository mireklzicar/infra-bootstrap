#!/usr/bin/env bash
set -e

echo "[INFO] Updating apt..."
sudo apt-get update

echo "[INFO] Installing required build tools..."
sudo apt-get install -y dkms build-essential linux-headers-$(uname -r) ubuntu-drivers-common

echo "[INFO] Installing NVIDIA driver..."
sudo ubuntu-drivers install

# --- OPTIONAL PYTHON ---
if [[ "$1" == "--with-python" ]]; then
    echo "[INFO] Installing Python3 + pip + venv..."
    sudo apt-get install -y python3 python3-pip python3-venv
    python3 --version
    pip3 --version
fi

echo "[INFO] Done. Please reboot to load NVIDIA driver."
echo "After reboot, run: nvidia-smi"
#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[install_python] %s\n' "$*"
}

die() {
  printf '[install_python][error] %s\n' "$*" >&2
  exit 1
}

if ! command -v sudo >/dev/null 2>&1; then
  die "sudo is required to install system packages."
fi

log "Updating apt package index…"
sudo apt-get update

packages=(
  python3
  python3-pip
  python3-venv
  python3-dev
  build-essential
)

log "Installing Python tooling: ${packages[*]}…"
sudo apt-get install -y "${packages[@]}"

if command -v python3 >/dev/null 2>&1; then
  log "python3 version: $(python3 --version 2>&1)"
else
  die "python3 not found after installation."
fi

if command -v pip3 >/dev/null 2>&1; then
  log "pip3 version: $(pip3 --version 2>&1)"
else
  die "pip3 not found after installation."
fi

log "Python toolchain installation complete."

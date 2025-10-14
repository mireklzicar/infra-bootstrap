#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[install_gcloud] %s\n' "$*"
}

die() {
  printf '[install_gcloud][error] %s\n' "$*" >&2
  exit 1
}

if ! command -v sudo >/dev/null 2>&1; then
  die "sudo is required to install system packages."
fi

if ! command -v apt-get >/dev/null 2>&1; then
  die "This installer currently supports Debian/Ubuntu systems with apt-get."
fi

log "Updating apt package index…"
sudo apt-get update

log "Installing prerequisites…"
sudo apt-get install -y apt-transport-https ca-certificates gnupg curl

log "Configuring Google Cloud SDK apt repository…"
sudo install -m 0755 -d /usr/share/keyrings
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null

log "Refreshing package index with Google Cloud SDK repository…"
sudo apt-get update

log "Installing google-cloud-cli (includes gcloud and gsutil)…"
sudo apt-get install -y google-cloud-cli

if command -v gcloud >/dev/null 2>&1; then
  log "gcloud version: $(gcloud --version 2>/dev/null | head -n1)"
else
  die "gcloud not found on PATH after installation."
fi

if command -v gsutil >/dev/null 2>&1; then
  log "gsutil version: $(gsutil version 2>/dev/null | head -n1)"
else
  die "gsutil not found on PATH after installation."
fi

log "Google Cloud SDK installation complete. Run 'gcloud init' or use 'infr gc setup_project' to configure."

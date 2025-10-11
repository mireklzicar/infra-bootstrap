#!/usr/bin/env bash
set -euo pipefail

curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22 /usr/share/debsig/keyrings/AC2D62742012EA22
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null
curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
sudo apt update
sudo apt install -y 1password-cli

if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  if op whoami >/dev/null 2>&1; then
    printf '1Password CLI authenticated with provided service account token.\n'
  else
    printf 'Failed to validate OP_SERVICE_ACCOUNT_TOKEN. Check the value and try again.\n' >&2
    exit 1
  fi
else
  printf '1Password CLI installed. Export OP_SERVICE_ACCOUNT_TOKEN and re-run infr bootstrap, or sign in manually with `op signin`.\n'
fi

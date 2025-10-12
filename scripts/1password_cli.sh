#!/usr/bin/env bash
set -euo pipefail

curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22 /usr/share/debsig/keyrings/AC2D62742012EA22
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null
curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
sudo apt update
sudo apt install -y 1password-cli

persist_service_account_token() {
  local token="${OP_SERVICE_ACCOUNT_TOKEN:-}"
  [[ -n "$token" ]] || return 0

  local target_user="${SUDO_USER:-$USER}"
  local target_home
  if ! target_home="$(eval echo "~${target_user}")"; then
    printf 'Unable to locate home directory for %s; skipping token persistence.\n' "$target_user" >&2
    return 0
  fi

  local config_dir="${target_home}/.config/infr"
  local token_file="${config_dir}/op_token"
  mkdir -p "$config_dir"
  printf 'export OP_SERVICE_ACCOUNT_TOKEN=%q\n' "$token" >"$token_file"
  chmod 600 "$token_file"
  chown "$target_user":"$(id -gn "$target_user")" "$token_file" "$config_dir" >/dev/null 2>&1 || true

  local bashrc="${target_home}/.bashrc"
  if [[ ! -f "$bashrc" ]]; then
    touch "$bashrc"
    chown "$target_user":"$(id -gn "$target_user")" "$bashrc" >/dev/null 2>&1 || true
  fi
  if ! grep -Fqx 'source ~/.config/infr/op_token' "$bashrc"; then
    {
      printf '\n'
      printf '# Load 1Password service account token for infr workflows\n'
      printf 'source ~/.config/infr/op_token\n'
    } >>"$bashrc"
    chown "$target_user":"$(id -gn "$target_user")" "$bashrc" >/dev/null 2>&1 || true
  fi
}

if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  if op whoami >/dev/null 2>&1; then
    persist_service_account_token
    printf '1Password CLI authenticated with provided service account token.\n'
  else
    printf 'Failed to validate OP_SERVICE_ACCOUNT_TOKEN. Check the value and try again.\n' >&2
    exit 1
  fi
else
  printf '1Password CLI installed. Export OP_SERVICE_ACCOUNT_TOKEN and re-run infr bootstrap, or sign in manually with `op signin`.\n'
fi

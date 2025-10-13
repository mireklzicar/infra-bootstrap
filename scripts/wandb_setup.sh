#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/secret_helpers.sh"

current_user="$(id -un)"
target_user="${SUDO_USER:-$current_user}"

run_as_target() {
  if [[ "$target_user" == "$current_user" ]]; then
    "$@"
  else
    sudo -u "$target_user" -H "$@"
  fi
}

persist_api_key() {
  local api_key="$1"

  local target_home
  if ! target_home="$(eval echo "~${target_user}")"; then
    printf 'Unable to locate home directory for %s; skipping WANDB_API_KEY persistence.\n' "$target_user" >&2
    return 0
  fi

  local config_dir="${target_home}/.config/infr"
  local env_file="${config_dir}/wandb_env"
  mkdir -p "$config_dir"
  {
    printf 'export WANDB_API_KEY=%q\n' "$api_key"
    printf 'export WANDB_KEY=%q\n' "$api_key"
  } >"$env_file"
  chmod 600 "$env_file"
  chown "$target_user":"$(id -gn "$target_user")" "$env_file" "$config_dir" >/dev/null 2>&1 || true

  local bashrc="${target_home}/.bashrc"
  if [[ ! -f "$bashrc" ]]; then
    touch "$bashrc"
    chown "$target_user":"$(id -gn "$target_user")" "$bashrc" >/dev/null 2>&1 || true
  fi

  local source_line='source ~/.config/infr/wandb_env'
  if ! grep -Fqx "$source_line" "$bashrc"; then
    {
      printf '\n'
      printf '# Load Weights & Biases API key for infr workflows\n'
      printf '%s\n' "$source_line"
    } >>"$bashrc"
    chown "$target_user":"$(id -gn "$target_user")" "$bashrc" >/dev/null 2>&1 || true
  fi
}

pip install -U wandb

api_key="$(op_read_secret "${OP_WANDB_KEY_REF:-}" "Weights & Biases API key")"

run_as_target env WANDB_API_KEY="$api_key" WANDB_KEY="$api_key" wandb login --relogin --cloud "$api_key" >/dev/null
persist_api_key "$api_key"

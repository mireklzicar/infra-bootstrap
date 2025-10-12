#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/secret_helpers.sh"

pip install -U "huggingface_hub[cli]"

token="$(op_read_secret "${OP_HF_TOKEN_REF:-}" "Hugging Face token")"
current_user="$(id -un)"
target_user="${SUDO_USER:-$current_user}"

run_as_target() {
  if [[ "$target_user" == "$current_user" ]]; then
    "$@"
  else
    sudo -u "$target_user" -H "$@"
  fi
}

if ! run_as_target git config --global --get credential.helper >/dev/null 2>&1; then
  run_as_target git config --global credential.helper store
fi

run_as_target python3 - "$token" <<'PY'
import sys
from huggingface_hub import login
login(token=sys.argv[1], add_to_git_credential=True)
PY

if ! run_as_target huggingface-cli whoami >/dev/null 2>&1; then
  printf 'Failed to authenticate Hugging Face CLI for user %s.\n' "$target_user" >&2
  exit 1
fi

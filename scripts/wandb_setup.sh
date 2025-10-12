#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/secret_helpers.sh"

pip install -U wandb

api_key="$(op_read_secret "${OP_WANDB_KEY_REF:-}" "Weights & Biases API key")"
wandb login --relogin --cloud --apikey "$api_key" >/dev/null

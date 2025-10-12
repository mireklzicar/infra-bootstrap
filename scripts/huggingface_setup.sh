#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/secret_helpers.sh"

pip install -U "huggingface_hub[cli]"

if ! git config --global --get credential.helper >/dev/null 2>&1; then
  git config --global credential.helper store
fi

token="$(op_read_secret "${OP_HF_TOKEN_REF:-}" "Hugging Face token")"
python3 - "$token" <<'PY'
import sys
from huggingface_hub import login
login(token=sys.argv[1], add_to_git_credential=True)
PY

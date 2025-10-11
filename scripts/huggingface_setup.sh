#!/usr/bin/env bash
set -e
pip install -U "huggingface_hub[cli]"
python3 - "$(op read "$OP_HF_TOKEN_REF")" <<'PY'
import sys
from huggingface_hub import login
login(token=sys.argv[1], add_to_git_credential=True)
PY

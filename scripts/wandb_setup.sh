#!/usr/bin/env bash
set -e
pip install -U wandb
WANDB_API_KEY="$(op read "$OP_WANDB_KEY_REF")" wandb login --relogin --cloud >/dev/null

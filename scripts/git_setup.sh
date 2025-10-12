#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/secret_helpers.sh"

sudo mkdir -p -m 755 /etc/apt/keyrings && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
sudo apt update && sudo apt install -y gh
pat="$(op_read_secret "${OP_GIT_PAT_REF:-}" "GitHub personal access token")"
printf '%s\n' "$pat" | gh auth login --hostname github.com --git-protocol https --with-token >/dev/null
gh auth setup-git >/dev/null
git config --global user.name "$(gh api user --jq .login)"; git config --global user.email "$(gh api user/emails --jq 'map(select(.verified==true))[0].email // .[0].email')"

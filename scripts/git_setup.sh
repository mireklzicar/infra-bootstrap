#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/secret_helpers.sh"

sudo mkdir -p -m 755 /etc/apt/keyrings && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
sudo apt update && sudo apt install -y gh
pat=""
gh_host="${GH_HOST:-github.com}"
git_protocol="${GH_GIT_PROTOCOL:-https}"

gh_with_token() {
  if [[ -n "$pat" ]]; then
    GH_TOKEN="$pat" gh "$@"
  else
    gh "$@"
  fi
}

if ! gh auth status --hostname "$gh_host" >/dev/null 2>&1; then
  pat="$(op_read_secret "${OP_GIT_PAT_REF:-}" "GitHub personal access token")"
  GH_TOKEN="$pat" gh auth login --hostname "$gh_host" --git-protocol "$git_protocol" --with-token <<<"$pat" >/dev/null
fi

gh_with_token auth setup-git >/dev/null
git config --global user.name "$(gh_with_token api user --jq .login)"
git config --global user.email "$(gh_with_token api user/emails --jq 'map(select(.verified==true))[0].email // .[0].email')"

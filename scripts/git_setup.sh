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

ensure_pat() {
  if [[ -z "$pat" ]]; then
    pat="$(op_read_secret "${OP_GIT_PAT_REF:-}" "GitHub personal access token")"
  fi
}

run_gh() {
  if gh "$@"; then
    return 0
  fi
  ensure_pat
  GH_TOKEN="$pat" gh "$@"
}

if ! gh auth status --hostname "$gh_host" >/dev/null 2>&1; then
  ensure_pat
  printf '%s\n' "$pat" | gh auth login --hostname "$gh_host" --git-protocol "$git_protocol" --with-token >/dev/null
fi

run_gh auth setup-git >/dev/null
git config --global user.name "$(run_gh api user --jq .login)"
git config --global user.email "$(run_gh api user/emails --jq 'map(select(.verified==true))[0].email // .[0].email')"
unset pat

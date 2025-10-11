#!/usr/bin/env bash
set -e

# Install GH CLI if not already installed
if ! command -v gh &> /dev/null; then
  echo "GitHub CLI not found, installing..."
  (type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
    gh auth login --scopes "user"
else
  echo "GitHub CLI already installed."
fi

# Get the username (login) from GitHub
USER=$(gh api user --jq .login)

# Get the primary email from GitHub
EMAIL=$(gh api user/emails --jq '.[] | select(.primary==true and .verified==true) | .email')

# Set them globally
git config --global user.name "$USER"
git config --global user.email "$EMAIL"

echo "Git configured with:"
git config --global user.name
git config --global user.email
# infra-bootstrap

Bootstrap fresh Ubuntu environments with a single command.  
`install.sh` installs the `infr` CLI, wires up 1Password CLI, configures Git using your PAT, and provides an interactive ML tooling setup flow.

## Quick Start

1. Review `.env` and tweak any `op://` references if your vault paths differ. The file only stores item URLs, so it can live in version control.

2. Export the 1Password service account token (everything else is fetched automatically):
   ```bash
   export OP_SERVICE_ACCOUNT_TOKEN="<service-account-token>"
   ```
   The installer reads GitHub/Hugging Face/W&B credentials from 1Password using this token and validates it with `op whoami`.  
   If you prefer the classic email + Secret Key flow, skip the export and run `op signin` manually after installation.

3. Run the installer from the repository root:
   ```bash
   ./install.sh
   ```
   This copies helper scripts to `/usr/local/libexec/infr`, installs `/usr/local/bin/infr`, runs the core bootstrap (1Password + Git), and launches the interactive `infr setup` workflow.

## `infr` CLI

After installation you can invoke the CLI from anywhere. `infr` sources `/usr/local/libexec/infr/.env` (override with `INFR_ENV_FILE`) so all scripts share the same secret references:

- `infr` or `infr bootstrap` – install 1Password CLI and configure GitHub using the PAT pulled from 1Password.
- `infr setup` – run a fresh inspection, show the results, then prompt before installing any missing ML tooling (Python, CUDA, Docker, PyTorch stack, W&B, Hugging Face CLI). Override the virtualenv path with `ML_ENV_DIR=/path/to/venv`.
- `infr inspect` – print an environment & hardware report and refresh the component cache used by `setup`.
  - `infr inspect --cached` replays the last cached component inspection without touching the system.
- `infr update` – fetch and fast-forward the local infra-bootstrap repository, then refresh the installed helper scripts (skips the copy when already running from the repo).

All helper scripts live under `/usr/local/libexec/infr` (override with `INFR_LIB_DIR`).

## Managed Scripts

- `scripts/install_python.sh` – installs Python 3, pip, venv, headers, and build tools.
- `scripts/setup_cuda_python.sh` – installs NVIDIA drivers and (optionally) Python.
- `scripts/install_packages.sh` – provisions an ML-focused virtual environment (torch, transformers, wandb, etc.).
- `scripts/wandb_setup.sh` / `scripts/huggingface_setup.sh` – install CLIs and log in using the referenced secrets.
- `scripts/inspect_system.sh` – emits system/package/hardware diagnostics.
- `scripts/git_setup.sh` – installs GitHub CLI and configures Git using `GIT_PAT`.
- `scripts/1password_cli.sh` – installs 1Password CLI, validates `OP_SERVICE_ACCOUNT_TOKEN` when provided, and prints signin guidance otherwise.

## Tokens & Secrets

Secret references default to the following locations (override via the `OP_*_REF` env vars shown):

- `OP_GIT_PAT_REF=op://Developer/GitHub Personal Access Token/token`
- `OP_HF_TOKEN_REF=op://Developer/Huggingface WRITE lzicar2000/credential`
- `OP_WANDB_KEY_REF=op://Developer/Weights and Biases wandb.ai/credential`

Additional optional variables:

- `OP_SERVICE_ACCOUNT_TOKEN` – required for non-interactive runs (exported at runtime, not stored in `.env`)
- `OP_ACCOUNT_DOMAIN`, `OP_ACCOUNT_NAME` if you still use interactive `op signin --account <name>`
- `GIT_PAT`, `HUGGINGFACE_TOKEN_WRITE`, `WANDB_KEY` to bypass 1Password retrieval
- `ML_ENV_DIR` to override the ML tooling virtualenv location
- `GH_HOST`, `GH_GIT_PROTOCOL` to override the GitHub host or git protocol used during bootstrap

During `infr bootstrap` the PAT referenced by `OP_GIT_PAT_REF` feeds a headless `gh auth login`. When additional `gh` calls need the token during bootstrap, the script passes it transiently via `GH_TOKEN` and immediately clears it. `gh` persists the credential in `~/.config/gh`, so subsequent shells stay authenticated without re-exporting `GH_TOKEN`.
Run `infr --help` for a concise usage summary.

#!/usr/bin/env bash
# setup_python_env.sh
# Recreates the pip installs from your history in a reliable order.
# Safe-by-default: uses a virtual environment, upgrades pip, and installs packages individually
# with clear error messages. Includes optional CUDA/CPU selection for PyTorch.

set -Eeuo pipefail

# -----------------------
# Config (override via env)
# -----------------------
ENV_DIR="${ENV_DIR:-.venv}"
USE_VENV="${USE_VENV:-1}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TORCH_CHANNEL="${TORCH_CHANNEL:-auto}"   # auto|cpu|cu118|cu121|cu124|cu126|cu129
PIP_FLAGS="${PIP_FLAGS:---upgrade --no-cache-dir}"

# -----------------------
# Helpers
# -----------------------
log() { printf "\n[%s] %s\n" "$(date +'%H:%M:%S')" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing '$1'. Install it and re-run."; }

retry_pip() {
  # retry once with --use-pep517 if a build-backend fails
  local pkg="$1"
  if ! $PYTHON_BIN -m pip install $PIP_FLAGS $pkg; then
    log "Retrying $pkg with --use-pep517…"
    $PYTHON_BIN -m pip install $PIP_FLAGS --use-pep517 $pkg
  fi
}

install_torch() {
  # Decide channel and install torch/vision/audio as in your history
  local idx_flag=""
  local torch_pkgs=("torch" "torchvision" "torchaudio")

  case "$TORCH_CHANNEL" in
    auto)
      if command -v nvidia-smi >/dev/null 2>&1; then
        # Heuristic: prefer the newest CUDA repo commonly available.
        # Override explicitly via TORCH_CHANNEL if you need a specific one.
        idx_flag="--index-url https://download.pytorch.org/whl/cu129"
      else
        idx_flag="--index-url https://download.pytorch.org/whl/cpu"
      fi
      ;;
    cpu)   idx_flag="--index-url https://download.pytorch.org/whl/cpu" ;;
    cu118) idx_flag="--index-url https://download.pytorch.org/whl/cu118" ;;
    cu121) idx_flag="--index-url https://download.pytorch.org/whl/cu121" ;;
    cu124) idx_flag="--index-url https://download.pytorch.org/whl/cu124" ;;
    cu126) idx_flag="--index-url https://download.pytorch.org/whl/cu126" ;;
    cu129) idx_flag="--index-url https://download.pytorch.org/whl/cu129" ;;
    *)     die "Unknown TORCH_CHANNEL '$TORCH_CHANNEL'";;
  esac

  log "Installing PyTorch stack (${TORCH_CHANNEL})…"
  if ! $PYTHON_BIN -m pip install $PIP_FLAGS $idx_flag "${torch_pkgs[@]}"; then
    log "PyTorch install via '$idx_flag' failed. Falling back to PyPI default (may install CPU-only)…"
    $PYTHON_BIN -m pip install $PIP_FLAGS "${torch_pkgs[@]}"
  fi
}

# -----------------------
# Pre-flight
# -----------------------
need_cmd "$PYTHON_BIN"

if [[ "$USE_VENV" == "1" ]]; then
  log "Creating/using virtualenv at '$ENV_DIR'…"
  if [[ ! -d "$ENV_DIR" ]]; then
    "$PYTHON_BIN" -m venv "$ENV_DIR"
  fi
  # shellcheck disable=SC1090
  source "$ENV_DIR/bin/activate"
  PYTHON_BIN="python"
fi

log "Upgrading pip, setuptools, wheel…"
$PYTHON_BIN -m pip install --upgrade pip setuptools wheel

log "Python: $($PYTHON_BIN -V)"
log "Pip:    $($PYTHON_BIN -m pip -V)"

# -----------------------
# Installs (deduped & ordered)
# Mirrors your history, but grouped sanely and with retries.
# -----------------------

# Core scientific stack (from your history)
for pkg in numpy tqdm matplotlib prettytable pillow pandas; do
  log "Installing $pkg…"
  retry_pip "$pkg"
done

# Hugging Face ecosystem (datasets, transformers)
# Your freeze shows very new versions; installing latest is fine. Pin if you need exact reproducibility.
for pkg in datasets transformers; do
  log "Installing $pkg…"
  retry_pip "$pkg"
done

# Weights & Biases
log "Installing wandb…"
retry_pip "wandb"

# NVITOP
log "Installing nvitop…"
retry_pip "nvitop"

# PyTorch (+ torchvision + torchaudio) with CUDA/CPU selection
install_torch

# -----------------------
# Post checks
# -----------------------
log "Validating installation (pip check)…"
$PYTHON_BIN -m pip check || true

log "Reporting key versions…"
$PYTHON_BIN - <<'PY'
import importlib, sys
mods = ["torch","torchvision","torchaudio","transformers","datasets","numpy","pandas","matplotlib","tqdm","prettytable","wandb","nvitop"]
for m in mods:
    try:
        mod = importlib.import_module(m)
        ver = getattr(mod, "__version__", "unknown")
        extra = ""
        if m=="torch":
            try:
                import torch
                extra = f" | cuda_available={torch.cuda.is_available()}"
            except Exception:
                pass
        print(f"{m}: {ver}{extra}")
    except Exception as e:
        print(f"{m}: NOT INSTALLED ({e.__class__.__name__}: {e})", file=sys.stderr)
PY

log "Done."
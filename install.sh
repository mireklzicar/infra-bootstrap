#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[infra-bootstrap] %s\n' "$*"
}

die() {
  printf '[infra-bootstrap][error] %s\n' "$*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${INSTALL_PREFIX:-/usr/local/bin}"
LIB_DIR="${INFR_LIB_DIR:-/usr/local/libexec/infr}"
CLI_NAME="infr"
CLI_SOURCE="${SCRIPT_DIR}/scripts/${CLI_NAME}"

[[ -x "$CLI_SOURCE" ]] || die "CLI launcher not found at $CLI_SOURCE"

if ! command -v install >/dev/null 2>&1; then
  die "POSIX install utility is required. Install coreutils or run with a shell that provides it."
fi

SUDO=""
if [[ "$EUID" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    die "Root privileges are required. Re-run as root or install sudo."
  fi
fi

log "Preparing payload…"
tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

cp -R "${SCRIPT_DIR}/scripts" "$tmpdir/"
cp "${SCRIPT_DIR}/.env" "$tmpdir/.env"
rm -f "${tmpdir}/scripts/${CLI_NAME}"
find "${tmpdir}/scripts" -type d -name '__pycache__' -prune -exec rm -rf {} +

log "Installing support files to $LIB_DIR…"
$SUDO rm -rf "$LIB_DIR"
$SUDO mkdir -p "$LIB_DIR"
$SUDO cp -R "${tmpdir}/scripts/." "$LIB_DIR/"
$SUDO install -m 644 "${tmpdir}/.env" "$LIB_DIR/.env"

log "Installing CLI launcher to $BIN_DIR/${CLI_NAME}…"
$SUDO install -m 755 "$CLI_SOURCE" "$BIN_DIR/${CLI_NAME}"

if ! command -v "$CLI_NAME" >/dev/null 2>&1; then
  log "CLI not yet on PATH. Ensure $BIN_DIR is exported in PATH."
fi

log "Running base bootstrap (1Password + Git)…"
if ! "$BIN_DIR/${CLI_NAME}" bootstrap; then
  die "Bootstrap failed. Review the logs above for details."
fi

log "Launching interactive setup…"
if ! INFR_AUTO_INSTALL="${INFR_AUTO_INSTALL:-true}" "$BIN_DIR/${CLI_NAME}" setup; then
  die "Setup failed. Review the logs above for details."
fi

log "Installation complete. Use 'infr --help' for usage details."

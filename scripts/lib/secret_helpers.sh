#!/usr/bin/env bash

# Resolve a 1Password secret reference to its plaintext value.
# Usage: op_read_secret "op://..." "Human readable label"
op_read_secret() {
  local ref="${1:-}"
  local label="${2:-secret}"

  if [[ -z "$ref" ]]; then
    printf '[infra-bootstrap][error] Missing reference for %s.\n' "$label" >&2
    return 1
  fi

  if ! command -v op >/dev/null 2>&1; then
    printf '[infra-bootstrap][error] 1Password CLI is required to resolve %s.\n' "$label" >&2
    return 1
  fi

  local value
  if ! value="$(op read "$ref" 2>/dev/null)"; then
    printf '[infra-bootstrap][error] Failed to read %s from %s.\n' "$label" "$ref" >&2
    return 1
  fi

  # Strip trailing newlines and carriage returns that may confuse downstream CLIs.
  value="$(printf '%s' "$value" | tr -d '\r\n')"

  if [[ -z "$value" ]]; then
    printf '[infra-bootstrap][error] Retrieved empty value for %s (ref: %s).\n' "$label" "$ref" >&2
    return 1
  fi

  printf '%s' "$value"
}

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: upload_run_to_gcs.sh <gcs_base_path> <run_name> [options]

Required arguments:
  <gcs_base_path>   Destination prefix, e.g. gs://my-bucket/arc_2025/crm
  <run_name>        Run directory name, e.g. sudoku_176_controller_mixer_20251012_231612

Options:
  --wandb-run <dir>   Include a specific wandb run directory (e.g. run-20251012_231616-5thcz4g2)
  --extra-path <path> Include an additional file or directory (repeatable)
  --delete-local      Remove local copies after successful upload
  -h, --help          Show this message

The script expects run checkpoints and logs under runs/cellgru_variants/.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: $1 is not installed or not on PATH." >&2
    exit 1
  fi
}

WAND_RUN=""
DELETE_LOCAL=0
EXTRA_PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wandb-run)
      shift
      [[ $# -gt 0 ]] || { echo "Error: --wandb-run requires a value." >&2; exit 1; }
      WAND_RUN="$1"
      ;;
    --extra-path)
      shift
      [[ $# -gt 0 ]] || { echo "Error: --extra-path requires a value." >&2; exit 1; }
      EXTRA_PATHS+=("$1")
      ;;
    --delete-local)
      DELETE_LOCAL=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: unknown option $1" >&2
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
  shift
done

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

GCS_BASE="$1"
RUN_NAME="$2"

if [[ $GCS_BASE != gs://* ]]; then
  echo "Error: destination must start with gs:// (received: $GCS_BASE)." >&2
  exit 1
fi

require_cmd gsutil

RUN_DIR="runs/cellgru_variants/${RUN_NAME}"
CHECKPOINT_DIR="${RUN_DIR}/checkpoints"

if [[ ! -d "$CHECKPOINT_DIR" ]]; then
  echo "Error: checkpoints not found at $CHECKPOINT_DIR." >&2
  exit 1
fi

if [[ "$RUN_NAME" =~ ^(.*)_([0-9]{8}_[0-9]{6})$ ]]; then
  RUN_SLUG="${BASH_REMATCH[1]}"
  RUN_TS="${BASH_REMATCH[2]}"
else
  echo "Error: run name must end with _YYYYMMDD_HHMMSS (got $RUN_NAME)." >&2
  exit 1
fi

LOG_FILE="runs/cellgru_variants/${RUN_TS}_${RUN_SLUG}.log"
if [[ ! -f "$LOG_FILE" ]]; then
  echo "Warning: log file not found at $LOG_FILE; skipping." >&2
  LOG_FILE=""
fi

DEST_ROOT="${GCS_BASE%/}/${RUN_NAME}"

declare -a TARGETS=("$CHECKPOINT_DIR")
[[ -n "$LOG_FILE" ]] && TARGETS+=("$LOG_FILE")

if [[ -n "$WAND_RUN" ]]; then
  WAND_DIR="wandb/${WAND_RUN}"
  if [[ -d "$WAND_DIR" ]]; then
    TARGETS+=("$WAND_DIR")
  else
    echo "Warning: wandb directory $WAND_DIR not found; skipping." >&2
  fi
fi

for extra in "${EXTRA_PATHS[@]}"; do
  if [[ -e "$extra" ]]; then
    TARGETS+=("$extra")
  else
    echo "Warning: extra path $extra not found; skipping." >&2
  fi
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Nothing to upload." >&2
  exit 1
fi

echo "Uploading artifacts for run $RUN_NAME to $DEST_ROOT"

for path in "${TARGETS[@]}"; do
  base_name=$(basename "$path")
  if [[ -d "$path" ]]; then
    echo "Syncing directory $path -> ${DEST_ROOT}/${base_name}"
    gsutil -m rsync -r "$path" "${DEST_ROOT}/${base_name}"
  else
    echo "Copying file $path -> ${DEST_ROOT}/${base_name}"
    gsutil cp "$path" "${DEST_ROOT}/${base_name}"
  fi
done

if [[ $DELETE_LOCAL -eq 1 ]]; then
  echo "Removing local artifacts..."
  for path in "${TARGETS[@]}"; do
    if [[ -d "$path" ]]; then
      rm -rf "$path"
    else
      rm -f "$path"
    fi
  done
fi

echo "Done."

#!/usr/bin/env bash
set -euo pipefail

# This script wraps the standard gcloud steps for authenticating, selecting a project,
# and optionally linking a billing account so Storage APIs work for gsutil.
# Prerequisites:
#   * Google Cloud SDK must be installed (see https://cloud.google.com/sdk/docs/install).
#   * You need permissions to log in with gcloud, switch projects, and (optionally) manage billing.
# Steps mirrored in code below match the guidance shared previously.

usage() {
  cat <<'EOF'
Usage: setup_gcloud_project.sh <project_id> [--billing-account BILLING_ACCOUNT_ID] [--bucket BUCKET_NAME]

Arguments:
  <project_id>                Target GCP project, e.g. storage-infrastructure-475108

Options:
  --billing-account <id>      Optional billing account ID to link to the project (e.g. 0X0X0X-0X0X0X-0X0X0X)
  --bucket <name>             Optional bucket name (without gs://) to grant objectAdmin to the active user
  -h, --help                  Show this help message

What the script does:
  1. Confirm gcloud is installed.
  2. Trigger user authentication (same as running `gcloud auth login`).
     - If the VM lacks a browser, pass `--no-launch-browser` when prompted and follow the CLI instructions.
  3. Set the active project in your gcloud config.
  4. Link the project to a billing account when provided (requires Billing Admin or equivalent role).
  5. Enable the Cloud Storage JSON API, so gsutil/gcloud storage commands work.
  6. Optionally grant the authenticated user Storage Object Admin on the specified bucket.

To discover billing accounts you have access to:
  gcloud beta billing accounts list
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: $1 not found on PATH. Install the Google Cloud SDK first." >&2
    exit 1
  fi
}

BILLING_ACCOUNT=""
TARGET_BUCKET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --billing-account)
      shift
      [[ $# -gt 0 ]] || { echo "Error: --billing-account requires a value." >&2; exit 1; }
      BILLING_ACCOUNT="$1"
      ;;
    --bucket)
      shift
      [[ $# -gt 0 ]] || { echo "Error: --bucket requires a value." >&2; exit 1; }
      TARGET_BUCKET="$1"
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
      if [[ -z "${PROJECT_ID:-}" ]]; then
        PROJECT_ID="$1"
      else
        echo "Error: unexpected positional argument $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

require_cmd gcloud

ACTIVE_ACCOUNTS=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
if [[ -z "$ACTIVE_ACCOUNTS" ]]; then
  echo "No active gcloud credentials detected; launching login flow..."
  # Mirrors `gcloud auth login` so gsutil picks up credentials.
  gcloud auth login
else
  echo "Already authenticated with gcloud as: $ACTIVE_ACCOUNTS"
fi

if [[ -z "${PROJECT_ID:-}" ]]; then
  echo "No project ID provided. Available projects:"
  gcloud projects list
  echo "Re-run the script with one of the project IDs above."
  exit 0
fi

echo "Setting active project to ${PROJECT_ID}..."
gcloud config set project "${PROJECT_ID}"

if [[ -n "$BILLING_ACCOUNT" ]]; then
  echo "Linking project ${PROJECT_ID} with billing account ${BILLING_ACCOUNT}..."
  # Uses the beta command as billing APIs still live there.
  gcloud beta billing projects link "${PROJECT_ID}" \
    --billing-account="${BILLING_ACCOUNT}"
else
  echo "No billing account provided. Available billing accounts:"
  gcloud beta billing accounts list
  echo "Re-run the script with --billing-account <ACCOUNT_ID> to link billing."
fi

echo "Enabling Cloud Storage API on ${PROJECT_ID}..."
# Needed for gsutil and gcloud storage commands; idempotent if already enabled.
gcloud services enable storage.googleapis.com --project="${PROJECT_ID}"

if [[ -n "$TARGET_BUCKET" ]]; then
  if [[ -z "$ACTIVE_ACCOUNTS" ]]; then
    echo "Warning: no active account detected; skipping bucket IAM grant."
  else
    BUCKET_URI="gs://${TARGET_BUCKET}"
    echo "Granting the active user Storage Object Admin on ${BUCKET_URI}..."
    if ! gcloud storage buckets add-iam-policy-binding "${BUCKET_URI}" \
      --member="user:${ACTIVE_ACCOUNTS}" \
      --role="roles/storage.objectAdmin"; then
      echo "Warning: failed to update IAM policy for ${BUCKET_URI}. Ensure you have permission to manage bucket IAM." >&2
    fi
  fi
fi

echo "All done."

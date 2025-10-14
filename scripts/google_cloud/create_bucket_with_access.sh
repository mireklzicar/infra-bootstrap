#!/usr/bin/env bash
set -euo pipefail

# Creates a Cloud Storage bucket (if missing) and grants IAM access to a member.
# Requires the Google Cloud SDK and appropriate permissions (storage.buckets.create,
# storage.buckets.getIamPolicy, storage.buckets.setIamPolicy).

usage() {
  cat <<'EOF'
Usage: create_bucket_with_access.sh <bucket_name> [--project PROJECT_ID] [--location LOCATION] [--member MEMBER] [--role ROLE]

Arguments:
  <bucket_name>           Bucket name without gs:// (must be globally unique)

Options:
  --project <id>          GCP project ID to own the bucket (defaults to gcloud config)
  --location <region>     Location for new bucket (default: us-central1)
  --member <principal>    IAM principal to grant (default: user:<active-account>)
  --role <role>           IAM role to grant (default: roles/storage.objectAdmin)
  -h, --help              Show this help

Examples:
  ./create_bucket_with_access.sh trained_models --project storage-infrastructure-475108 \\
      --member user:lzicar2000@gmail.com
  ./create_bucket_with_access.sh my-team-bucket --location europe-west1 --role roles/storage.admin
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: $1 not found on PATH. Install the Google Cloud SDK first." >&2
    exit 1
  fi
}

BUCKET_NAME=""
PROJECT_ID=""
LOCATION="us-central1"
MEMBER=""
ROLE="roles/storage.objectAdmin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      shift
      [[ $# -gt 0 ]] || { echo "Error: --project requires a value." >&2; exit 1; }
      PROJECT_ID="$1"
      ;;
    --location)
      shift
      [[ $# -gt 0 ]] || { echo "Error: --location requires a value." >&2; exit 1; }
      LOCATION="$1"
      ;;
    --member)
      shift
      [[ $# -gt 0 ]] || { echo "Error: --member requires a value." >&2; exit 1; }
      MEMBER="$1"
      ;;
    --role)
      shift
      [[ $# -gt 0 ]] || { echo "Error: --role requires a value." >&2; exit 1; }
      ROLE="$1"
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
      if [[ -z "$BUCKET_NAME" ]]; then
        BUCKET_NAME="$1"
      else
        echo "Error: unexpected positional argument $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

if [[ -z "$BUCKET_NAME" ]]; then
  usage
  exit 1
fi

require_cmd gcloud

ACTIVE_ACCOUNTS=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
if [[ -z "$ACTIVE_ACCOUNTS" ]]; then
  echo "No active gcloud credentials detected; run gcloud auth login first." >&2
  exit 1
fi

if [[ -z "$PROJECT_ID" ]]; then
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
  if [[ -z "$PROJECT_ID" ]]; then
    echo "Error: no project specified and no default project configured." >&2
    exit 1
  fi
fi

if [[ -z "$MEMBER" ]]; then
  MEMBER="user:${ACTIVE_ACCOUNTS}"
fi

BUCKET_URI="gs://${BUCKET_NAME}"

echo "Ensuring bucket ${BUCKET_URI} exists in project ${PROJECT_ID} (location ${LOCATION})..."
if gcloud storage buckets list --project "${PROJECT_ID}" --format="value(NAME)" | grep -Fxq "${BUCKET_URI}"; then
  echo "Bucket already exists; skipping creation."
else
  gcloud storage buckets create "${BUCKET_URI}" \
    --project="${PROJECT_ID}" \
    --location="${LOCATION}"
fi

echo "Granting ${ROLE} to ${MEMBER} on ${BUCKET_URI}..."
gcloud storage buckets add-iam-policy-binding "${BUCKET_URI}" \
  --member="${MEMBER}" \
  --role="${ROLE}"

echo "Done."

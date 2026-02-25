#!/usr/bin/env bash
# Download a GGUF model from Hugging Face to nas-01
#
# Models are auto-discovered by llama-swap at service start,
# so no nix config changes are needed after downloading.
#
# Usage:
#   ./scripts/download-model.sh <repo_id> [quant_pattern] [--dry-run]
#
# Examples:
#   # Download all GGUF files from a repo
#   ./scripts/download-model.sh bartowski/Meta-Llama-3.1-8B-Instruct-GGUF
#
#   # Download only Q4_K_M quantization
#   ./scripts/download-model.sh bartowski/Meta-Llama-3.1-8B-Instruct-GGUF Q4_K_M
#
#   # Preview what would be downloaded
#   ./scripts/download-model.sh bartowski/Meta-Llama-3.1-8B-Instruct-GGUF Q4_K_M --dry-run

set -euo pipefail

MODEL_DIR="/models"
HOST="nas-01"

usage() {
  echo "Usage: $0 <repo_id> [quant_pattern] [--dry-run]"
  echo ""
  echo "Arguments:"
  echo "  repo_id        HuggingFace repo (e.g., bartowski/Meta-Llama-3.1-8B-Instruct-GGUF)"
  echo "  quant_pattern  Quantization filter (e.g., Q4_K_M, Q5_K_M, Q8_0). Default: all .gguf files"
  echo "  --dry-run      Preview what would be downloaded without downloading"
  echo ""
  echo "Examples:"
  echo "  $0 bartowski/Meta-Llama-3.1-8B-Instruct-GGUF Q4_K_M"
  echo "  $0 bartowski/Qwen2.5-72B-Instruct-GGUF Q4_K_M"
  echo "  $0 TheBloke/Llama-2-7B-GGUF Q4_K_M --dry-run"
  exit 1
}

REPO_ID="${1:-}"
QUANT="${2:-}"
DRY_RUN=""

if [ -z "$REPO_ID" ]; then
  usage
fi

# Check for --dry-run in any position
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN="yes"
    # Clear quant if it was --dry-run
    if [ "$QUANT" = "--dry-run" ]; then
      QUANT=""
    fi
  fi
done

# Build include pattern
if [ -n "$QUANT" ]; then
  INCLUDE="*${QUANT}*.gguf"
else
  INCLUDE="*.gguf"
fi

echo "Repository: $REPO_ID"
echo "Pattern:    $INCLUDE"
echo "Target:     $HOST:$MODEL_DIR"
echo ""

if [ -n "$DRY_RUN" ]; then
  echo "Listing matching files from HuggingFace API..."
  FILES=$(curl -sf "https://huggingface.co/api/models/${REPO_ID}" \
    | jq -r '.siblings[].rfilename' \
    | grep -i '\.gguf$' || true)

  if [ -n "$QUANT" ]; then
    FILES=$(echo "$FILES" | grep -i "$QUANT" || true)
  fi

  if [ -z "$FILES" ]; then
    echo "No matching .gguf files found in $REPO_ID"
  else
    echo "$FILES"
  fi
  echo ""
  echo "(dry-run mode - no files downloaded)"
  exit 0
fi

# Run download on nas-01 via SSH
echo "Downloading model files..."
ssh "root@${HOST}" "hf download '${REPO_ID}' --include '${INCLUDE}' --local-dir '${MODEL_DIR}'"

echo ""
echo "Download complete. Listing model files..."
echo ""

# List downloaded files
GGUF_FILES=$(ssh "root@${HOST}" "ls -1 ${MODEL_DIR}/*.gguf 2>/dev/null || true")

if [ -z "$GGUF_FILES" ]; then
  echo "WARNING: No .gguf files found in $MODEL_DIR"
  exit 1
fi

echo "$GGUF_FILES"
echo ""
echo "Models are auto-discovered by llama-swap. Restart the service to pick them up:"
echo "  ssh root@${HOST} systemctl restart llama-swap"
echo ""
echo "Then verify:"
echo "  curl -s http://${HOST}:8090/v1/models | jq '.data[].id'"

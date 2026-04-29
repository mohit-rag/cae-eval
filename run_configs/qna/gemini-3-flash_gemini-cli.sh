#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

HARBOR_BIN="$SCRIPT_DIR/../../harbor/.venv/bin/harbor"

"$HARBOR_BIN" run \
  -p ./data/qa \
  -a gemini-cli \
  -m "openai/vertex_ai/global/gemini-3-flash-preview" \
  -k 3 \
  -e modal \
  -n 8 \
  --ak reasoning_effort=high \
  -o harbor_results/cae/qa_task \
  --job-name "gemini-3-flash_gemini-cli"

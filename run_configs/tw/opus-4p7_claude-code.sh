#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

harbor run \
  -p ./data/tw \
  -a claude-code \
  -m "anthropic/claude-opus-4-7" \
  -k 3 \
  -e modal \
  -n 16 \
  --ak reasoning_effort=high \
  -o harbor_results/cae/tw_task \
  --job-name "opus-4p7_claude-code"

#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../../harbor/.env"
set +a

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

harbor run \
  -p ./data/qa_gtm_samples \
  -a claude-code \
  -m "anthropic/claude-opus-4-6" \
  -e modal \
  -n 16 \
  --ak reasoning_effort=high \
  -o harbor_results/cae/gtm_task \
  --job-name "opus-4p6_claude-code-gtm"

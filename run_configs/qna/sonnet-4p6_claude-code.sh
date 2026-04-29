#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

harbor run \
  -p ./data/qa \
  -a claude-code \
  -m "anthropic/claude-sonnet-4-6" \
  -k 3 \
  -e modal \
  -n 24 \
  --ak reasoning_effort=high \
  -o harbor_results/cae/qa_task \
  --job-name "sonnet-4p6_claude-code"

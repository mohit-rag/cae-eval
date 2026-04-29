#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

harbor run \
  -p ./data/rf \
  -a claude-code \
  -m "anthropic/claude-opus-4-6" \
  -k 3 \
  -e modal \
  -n 16 \
  --ak reasoning_effort=high \
  --ek registry_secret=aws-secret-agent-xiang-deng \
  -o harbor_results/cae/rf_task \
  --job-name "opus-4p6_claude-code"

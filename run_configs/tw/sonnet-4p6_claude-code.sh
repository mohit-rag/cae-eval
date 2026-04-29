#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

harbor run \
  -p ./data/tw \
  -a claude-code \
  -m "anthropic/claude-sonnet-4-6" \
  -k 3 \
  -e modal \
  -n 16 \
  --ak reasoning_effort=high \
  --ek registry_secret=aws-secret-agent-xiang-deng \
  -o harbor_results/cae/tw_task \
  --job-name "sonnet-4p6_claude-code"

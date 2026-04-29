#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

harbor run \
  -p ./data/tw \
  -a codex \
  -m "openai/gpt-5.4" \
  -k 3 \
  -e modal \
  -n 16 \
  --ak reasoning_effort=xhigh \
  --ek registry_secret=aws-secret-agent-xiang-deng \
  -o harbor_results/cae/tw_task \
  --job-name "gpt-5p4-xhigh_codex"
  
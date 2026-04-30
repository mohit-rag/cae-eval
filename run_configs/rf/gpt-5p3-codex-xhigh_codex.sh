#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

harbor run \
  -p ./data/rf \
  -a codex \
  -m "openai/gpt-5.3-codex" \
  -k 3 \
  -e modal \
  -n 26 \
  --ak reasoning_effort=xhigh \
  --ek registry_secret=aws-secret-agent-xiang-deng \
  -o harbor_results/cae/rf_task \
  --job-name "gpt-5p3-codex-xhigh_codex"

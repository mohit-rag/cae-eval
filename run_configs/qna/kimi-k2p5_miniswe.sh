#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

harbor run \
  -p ./data/qa \
  -a mini-swe-agent \
  -m "litellm_proxy/fireworks_ai/kimi-k2p5" \
  -k 3 \
  -e docker \
  -n 8 \
  --ak config_file="${SCRIPT_DIR}/../mswea_qa_config.yaml" \
  -o harbor_results/cae/qa_task \
  --job-name "kimi-k2p5_miniswe"

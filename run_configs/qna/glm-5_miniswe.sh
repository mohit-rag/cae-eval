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
  -m "litellm_proxy/fireworks_ai/glm-5" \
  -k 3 \
  -e modal \
  -n 12 \
  --ak config_file="${SCRIPT_DIR}/../mswea_qa_config.yaml" \
  -o harbor_results/cae/qa_task \
  --job-name "glm-5_miniswe"

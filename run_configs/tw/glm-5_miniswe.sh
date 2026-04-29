#!/bin/bash
set -euo pipefail

set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

harbor run \
  -p ./data/tw \
  -a mini-swe-agent \
  -m "litellm_proxy/fireworks_ai/glm-5" \
  -k 3 \
  -e modal \
  -n 16 \
  --ak config_file="${SCRIPT_DIR}/../mswea_tw_config.yaml" \
  --ek registry_secret=aws-secret-agent-xiang-deng \
  -o harbor_results/cae/tw_task \
  --job-name "glm-5_miniswe"

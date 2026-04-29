#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../../harbor/.env.nova"
set +a

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

harbor run \
  -p ./data/qa \
  -a mini-swe-agent \
  -m "litellm_proxy/nova/nova-2-pro-v1" \
  -e modal \
  -n 12 \
  -o harbor_results/cae/private_scrape/qa/ \
  --ak config_file="${SCRIPT_DIR}/../../mswea_qa_config_llama.yaml" \
  --job-name "nova-pro-2_miniswe"

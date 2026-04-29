#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../../harbor/.env.llama"
set +a

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

harbor run \
  -p ./data/qa/ \
  -a mini-swe-agent \
  -m "litellm_proxy/llama_experimental/quiet_basil" \
  -e docker \
  -k 2 \
  -n 6 \
  -o harbor_results/cae/private_scrape/qa/ \
  --ak config_file="${SCRIPT_DIR}/../mswea_qa_config_llama.yaml" \
  --job-name "llama-quiet-basil_miniswe"

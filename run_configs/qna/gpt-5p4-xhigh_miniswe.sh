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
  -m "openai/gpt-5.4" \
  -k 3 \
  -e modal \
  -n 24 \
  --ak reasoning_effort=xhigh \
  --ak config_file="${SCRIPT_DIR}/../mswea_qa_config_responses.yaml" \
  -o harbor_results/cae/qa_task \
  --job-name "gpt-5p4-xhigh_miniswe"

#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../../harbor/.env.llama"
set +a

# Verifier: keep Anthropic Opus judge on proxy
export EVAL_MODEL="${EVAL_MODEL:-anthropic/claude-opus-4-6}"

# Agent: Llama vendor endpoint/model
LLAMA_BASE_URL="${LLAMA_API_BASE_URL:-https://api.llama.com/v1alpha}"
LLAMA_KEY="${LLAMA_API_KEY:-}"
if [[ -z "${LLAMA_KEY}" ]]; then
  echo "ERROR: LLAMA_API_KEY is not set"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

harbor run \
  -p ./data/qa/ \
  -a mini-swe-agent \
  -m "openai/quiet_sand" \
  -e docker \
  -k 1 \
  -n 6 \
  -o harbor_results/cae/private_scrape/qa/ \
  --ae OPENAI_API_KEY="${LLAMA_KEY}" \
  --ae OPENAI_API_BASE="${LLAMA_BASE_URL}" \
  --ae OPENAI_BASE_URL="${LLAMA_BASE_URL}" \
  --ak api_base="${LLAMA_BASE_URL}" \
  --ak config_file="${SCRIPT_DIR}/../../mswea_qa_config_llama.yaml" \
  --job-name "llama-quiet-sand_miniswe_v2.1"

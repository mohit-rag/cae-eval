#!/bin/bash
set -euo pipefail

# Load shared credentials
set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# harbor run \
#   -p ./data/tw \
#   -a claude-code \
#   -m "anthropic/claude-3-opus-20240229" \
#   -e modal \
#   -n 16 \
#   -l 30 \
#   --ak reasoning_effort=high \
#   -o harbor_results/cae/runs_over_time \
#   --job-name "opus-3_claude-code"


# harbor run \
#   -p ./data/tw \
#   -a claude-code \
#   -m "anthropic/claude-opus-4-0" \
#   -e modal \
#   -n 16 \
#   -l 30 \
#   --ak reasoning_effort=high \
#   -o harbor_results/cae/runs_over_time \
#   --job-name "opus-4_claude-code"


# harbor run \
#   -p ./data/tw \
#   -a claude-code \
#   -m "anthropic/claude-opus-4-1" \
#   -e modal \
#   -n 16 \
#   -l 30 \
#   --ak reasoning_effort=high \
#   -o harbor_results/cae/runs_over_time \
#   --job-name "opus-4-1_claude-code"


harbor run \
  -p ./data/tw \
  -a claude-code \
  -m "anthropic/claude-opus-4-5" \
  -e modal \
  -n 16 \
  -l 30 \
  --ak reasoning_effort=high \
  -o harbor_results/cae/runs_over_time \
  --job-name "opus-4-5_claude-code"

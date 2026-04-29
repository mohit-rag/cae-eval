#!/bin/bash
set -euo pipefail

set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

harbor run \
  -p ./data/tw \
  -a oracle \
  -e modal \
  -n 90 \
  -k 1 \
  -o harbor_results/cae/oracle/ \
  --job-name "oracle_tw_90_ghcr_latest"

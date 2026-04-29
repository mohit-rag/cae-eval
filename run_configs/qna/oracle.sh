#!/bin/bash
set -euo pipefail

set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

harbor run \
  -p ./data/qa \
  -a oracle \
  -e modal \
  -n 124 \
  -k 1 \
  -o harbor_results/cae/oracle/ \
  --job-name "oracle_qna_120_ghcr_latest_verfier_fixed"

#!/bin/bash
set -euo pipefail

set -a
source "$(dirname "$0")/../../harbor/.env"
set +a

harbor run \
  -p ./data/rf \
  -a oracle \
  -e modal \
  -n 16 \
  -k 1 \
  -l 5 \
  --ek registry_secret=aws-secret-agent-xiang-deng \
  -o harbor_results/cae/oracle/ \
  --job-name "oracle_rf_debug"

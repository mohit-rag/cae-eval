#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== 5/7: GPT-5.3 Codex xhigh ==="
bash "$DIR/gpt-5p3-codex_miniswe.sh"

echo "=== 4/7: Sonnet 4.6 ==="
bash "$DIR/sonnet-4p6_miniswe.sh"
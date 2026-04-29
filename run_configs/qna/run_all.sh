#!/bin/bash
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

RUN_LABELS=(
  # Custom scaffolds first
  # "GPT-5.4 xhigh (Codex)"
  # "GPT-5.3 Codex xhigh (Codex)"
#   "Sonnet 4.6 (Claude Code)"
  "Opus 4.6 (Claude Code)"
  # Then mini-swe-agent runs
#   "GPT-5.4 xhigh (Mini-SWE)"
  "Opus 4.6 (Mini-SWE)"
#   "Sonnet 4.6 (Mini-SWE)"
  "Gemini 3.1 Pro (Mini-SWE)"
#   "Gemini 3 Flash (Mini-SWE)"
  "Kimi K2.5 (Mini-SWE)"
  # "GLM-5 (Mini-SWE)"
  "Minimax M2.5 (Mini-SWE)"
  # Then Gemini CLI runs
#   "Gemini 3.1 Pro (Gemini CLI)"
)

RUN_SCRIPTS=(
  # "gpt-5p4-xhigh_codex.sh"
  # "gpt-5p3-codex_codex.sh"
#   "sonnet-4p6_claude-code.sh"
  "opus-4p6_claude-code.sh"
#   "gpt-5p4-xhigh_miniswe.sh"
  "opus-4p6_miniswe.sh"
#   "sonnet-4p6_miniswe.sh"
  "gemini-3p1-pro_miniswe.sh"
#   "gemini-3-flash_miniswe.sh"
  "kimi-k2p5_miniswe.sh"
  # "glm-5_miniswe.sh"
  "minimax-m2p5_miniswe.sh"
#   "gemini-3p1-pro_gemini-cli.sh"
)

TOTAL="${#RUN_SCRIPTS[@]}"
if [ "${#RUN_LABELS[@]}" -ne "$TOTAL" ]; then
  echo "Configuration error: RUN_LABELS and RUN_SCRIPTS length mismatch."
  exit 2
fi

declare -a SUCCEEDED=()
declare -a FAILED=()

for idx in "${!RUN_SCRIPTS[@]}"; do
  number=$((idx + 1))
  label="${RUN_LABELS[$idx]}"
  script="${RUN_SCRIPTS[$idx]}"

  echo "=== ${number}/${TOTAL}: ${label} ==="
  if bash "$DIR/$script"; then
    echo ">>> SUCCESS: $script"
    SUCCEEDED+=("$script")
  else
    status=$?
    echo ">>> FAILURE (exit $status): $script"
    FAILED+=("$script (exit $status)")
  fi
  echo
done

echo "=== Run Summary ==="
echo "Total runs: $TOTAL"
echo "Succeeded: ${#SUCCEEDED[@]}"
echo "Failed: ${#FAILED[@]}"

if [ "${#SUCCEEDED[@]}" -gt 0 ]; then
  echo
  echo "Successful scripts:"
  for script in "${SUCCEEDED[@]}"; do
    echo "  - $script"
  done
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo
  echo "Failed scripts:"
  for script in "${FAILED[@]}"; do
    echo "  - $script"
  done
  exit 1
fi

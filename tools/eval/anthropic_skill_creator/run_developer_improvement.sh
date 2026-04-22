#!/usr/bin/env bash
# File responsibility: command-line entrypoint for the developer pilot of the
# Anthropic skill-creator local adapter.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ADAPTER_DIR="$ROOT/tools/eval/anthropic_skill_creator"
CONFIG="$ADAPTER_DIR/configs/developer.json"
OUTPUT_DIR=""
MODE="full"
MODEL=""
JUDGE_MODEL=""

usage() {
  cat <<'USAGE'
Usage:
  bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh [options]

Options:
  --dry-run          Prepare and print the planned workspace without run outputs.
  --eval-only        Run old_skill/new_skill eval, grading, benchmark, and viewer.
  --trigger-only     Run trigger eval and description optimization only.
  --output-dir DIR   Override result directory.
  --model MODEL      Model passed to codex/claude subprocesses.
  --judge-model M    Model passed to codex judge subprocesses.
  -h, --help         Show this help text.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --eval-only)
      MODE="eval-only"
      shift
      ;;
    --trigger-only)
      MODE="trigger-only"
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --judge-model)
      JUDGE_MODEL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '[anthropic-adapter][ERROR] unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

common_args=(--config "$CONFIG")
if [ -n "$OUTPUT_DIR" ]; then
  common_args+=(--output-dir "$OUTPUT_DIR")
fi
if [ -n "$MODEL" ]; then
  common_args+=(--model "$MODEL")
fi
if [ -n "$JUDGE_MODEL" ]; then
  common_args+=(--judge-model "$JUDGE_MODEL")
fi

case "$MODE" in
  dry-run)
    python3 "$ADAPTER_DIR/scripts/run_existing_skill_eval.py" "${common_args[@]}" --dry-run
    ;;
  eval-only)
    python3 "$ADAPTER_DIR/scripts/run_existing_skill_eval.py" "${common_args[@]}"
    ;;
  trigger-only)
    python3 "$ADAPTER_DIR/scripts/run_trigger_loop.py" "${common_args[@]}"
    ;;
  full)
    python3 "$ADAPTER_DIR/scripts/run_existing_skill_eval.py" "${common_args[@]}"
    python3 "$ADAPTER_DIR/scripts/run_trigger_loop.py" "${common_args[@]}"
    ;;
esac

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
REASONING_EFFORT=""
JUDGE_REASONING_EFFORT=""

usage() {
  cat <<'USAGE'
Usage:
  bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh [options]

Options:
  --dry-run          Prepare and print the planned workspace without run outputs.
  --eval-only        Run old_skill/new_skill eval, grading, benchmark, and viewer.
  --trigger-only     Run trigger eval and description optimization only.
  --output-dir DIR   Override result directory.
  --model MODEL      Model passed to codex/claude subprocesses; required for eval/trigger/full runs.
  --judge-model M    Model passed to codex judge subprocesses.
  --reasoning-effort E
                   Codex executor reasoning effort: low, medium, high, or xhigh.
  --judge-reasoning-effort E
                   Codex judge reasoning effort; defaults to --reasoning-effort when omitted.
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
      if [ "$#" -lt 2 ]; then
        printf '[anthropic-adapter][ERROR] --output-dir requires a value\n' >&2
        exit 1
      fi
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --model)
      if [ "$#" -lt 2 ]; then
        printf '[anthropic-adapter][ERROR] --model requires a value\n' >&2
        exit 1
      fi
      MODEL="$2"
      shift 2
      ;;
    --judge-model)
      if [ "$#" -lt 2 ]; then
        printf '[anthropic-adapter][ERROR] --judge-model requires a value\n' >&2
        exit 1
      fi
      JUDGE_MODEL="$2"
      shift 2
      ;;
    --reasoning-effort)
      if [ "$#" -lt 2 ]; then
        printf '[anthropic-adapter][ERROR] --reasoning-effort requires a value\n' >&2
        exit 1
      fi
      REASONING_EFFORT="$2"
      shift 2
      ;;
    --judge-reasoning-effort)
      if [ "$#" -lt 2 ]; then
        printf '[anthropic-adapter][ERROR] --judge-reasoning-effort requires a value\n' >&2
        exit 1
      fi
      JUDGE_REASONING_EFFORT="$2"
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

if [ "$MODE" != "dry-run" ] && [ -z "$MODEL" ]; then
  printf '[anthropic-adapter][ERROR] --model is required for eval/trigger/full runs\n' >&2
  exit 1
fi

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
if [ -n "$REASONING_EFFORT" ]; then
  common_args+=(--reasoning-effort "$REASONING_EFFORT")
fi
if [ -n "$JUDGE_REASONING_EFFORT" ]; then
  common_args+=(--judge-reasoning-effort "$JUDGE_REASONING_EFFORT")
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

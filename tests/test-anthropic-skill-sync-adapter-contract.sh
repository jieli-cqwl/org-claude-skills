#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

python3 - "$ROOT" "$TMP_DIR" <<'PY'
import importlib.util
import sys
from pathlib import Path

root = Path(sys.argv[1])
tmp_dir = Path(sys.argv[2])
module_path = root / "tools" / "community" / "sync_anthropic_skills_from_upstream.py"

spec = importlib.util.spec_from_file_location("sync_anthropic_skills_from_upstream", module_path)
if spec is None or spec.loader is None:
    raise SystemExit(f"cannot load module: {module_path}")

module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

module.DEST_CODEX_SKILLS = tmp_dir / "codex" / "skills"
module.generate_codex_adapters(["docx", "skill-creator"])

docx_adapter = module.DEST_CODEX_SKILLS / "docx" / "agents" / "openai.yaml"
skill_creator_adapter = module.DEST_CODEX_SKILLS / "skill-creator"

if not docx_adapter.is_file():
    raise SystemExit("expected adapter for regular Anthropic skill docx")

if not (skill_creator_adapter / "agents" / "openai.yaml").is_file():
    raise SystemExit("expected adapter for repository-managed skill-creator")
PY

echo "[PASS] anthropic skill sync adapter contract"

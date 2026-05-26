#!/usr/bin/env bash
# 文件职责：验证 Skill 标准真源与可执行质量审计工具保持当前资源边界。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARD="$ROOT/shared/skills/skill-refiner/references/quality-dimensions.md"
REFINER="$ROOT/shared/skills/skill-refiner/SKILL.md"
QUALITY_DIMENSIONS="$ROOT/shared/skills/skill-refiner/references/quality-dimensions.md"
SCAN_RULES="$ROOT/shared/skills/scan/references/skills-scan-rules.md"
SCAN_SKILL="$ROOT/shared/skills/scan/SKILL.md"
TOOL_MANIFEST="$ROOT/tools/skill_quality/manifest.json"
BODY_CHECKER="$ROOT/tools/skill_quality/check_skill_body_quality.py"
PACKAGE_CHECKER="$ROOT/tools/skill_quality/check_skill_package_quality.py"
ANTI_NOISE_CHECKER="$ROOT/tools/skill_quality/check_skill_anti_noise.py"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

required_files=(
  "$STANDARD"
  "$REFINER"
  "$QUALITY_DIMENSIONS"
  "$SCAN_RULES"
  "$SCAN_SKILL"
  "$TOOL_MANIFEST"
  "$BODY_CHECKER"
  "$PACKAGE_CHECKER"
  "$ANTI_NOISE_CHECKER"
)

retired_paths=(
  "$ROOT/shared/reference/Skill生命周期管理.md"
  "$ROOT/shared/reference/Skill质量标准.md"
  "$ROOT/shared/reference/Skill能力有效性标准.md"
  "$ROOT/shared/reference/Skill标准.md"
  "$ROOT/docs/skill-quality-standard-v2"
  "$ROOT/docs/deep-research/2026-04-28-skill-quality-standard"
)

for file in "${required_files[@]}"; do
  [ -s "$file" ] || fail "missing required Skill quality resource: ${file#"$ROOT"/}"
done

for path in "${retired_paths[@]}"; do
  [ ! -e "$path" ] || fail "retired Skill quality resource must not be active: ${path#"$ROOT"/}"
done

python3 - "$TOOL_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
scripts = manifest.get("scripts")
if not isinstance(scripts, list):
    raise SystemExit("tools/skill_quality/manifest.json: scripts must be an array")

required = {
    "check-body-quality": "tools/skill_quality/check_skill_body_quality.py",
    "check-package-quality": "tools/skill_quality/check_skill_package_quality.py",
    "check-anti-noise": "tools/skill_quality/check_skill_anti_noise.py",
}
entries = {item.get("id"): item for item in scripts if isinstance(item, dict)}
for script_id, path in required.items():
    item = entries.get(script_id)
    if not item:
        raise SystemExit(f"tools/skill_quality/manifest.json: missing {script_id}")
    if item.get("path") != path:
        raise SystemExit(f"tools/skill_quality/manifest.json: {script_id} path drift")
    if item.get("owner") != "skill-quality-tools":
        raise SystemExit(f"tools/skill_quality/manifest.json: {script_id} owner drift")
    if item.get("output_root") != "stdout":
        raise SystemExit(f"tools/skill_quality/manifest.json: {script_id} output_root drift")
    if not isinstance(item.get("allowed_args"), list) or not item["allowed_args"]:
        raise SystemExit(f"tools/skill_quality/manifest.json: {script_id} allowed_args required")
    if not isinstance(item.get("allowed_input_roots"), list) or "shared/skills" not in item["allowed_input_roots"]:
        raise SystemExit(f"tools/skill_quality/manifest.json: {script_id} must allow shared/skills input")
PY

python3 "$BODY_CHECKER" "$ROOT/shared/skills/product-manager" >"$TMP_DIR/body.json"
python3 "$ANTI_NOISE_CHECKER" --path "$ROOT/shared/skills/product-manager" >"$TMP_DIR/anti-noise.json"
python3 "$PACKAGE_CHECKER" "$ROOT/shared/skills/product-manager" >"$TMP_DIR/package.json"

python3 - "$TMP_DIR/body.json" "$TMP_DIR/anti-noise.json" "$TMP_DIR/package.json" <<'PY'
import json
import sys
from pathlib import Path

expected = {
    "body": ("skill-body-quality-static-audit", "static_pass"),
    "anti_noise": ("skill-anti-noise-audit", "static_pass"),
    "package": ("skill-quality-package-audit", "static_pass"),
}
for label, path_arg in zip(expected, sys.argv[1:]):
    data = json.loads(Path(path_arg).read_text(encoding="utf-8"))
    artifact_type, status = expected[label]
    if data.get("artifact_type") != artifact_type:
        raise SystemExit(f"{label}: artifact_type drift")
    if data.get("status") != status:
        raise SystemExit(f"{label}: expected {status}, got {data.get('status')}")
    if data.get("finding_count") != 0:
        raise SystemExit(f"{label}: expected zero findings")
PY

printf '[PASS] skill quality standard\n'

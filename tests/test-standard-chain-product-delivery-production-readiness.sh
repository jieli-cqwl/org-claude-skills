#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MATRIX="$ROOT/docs/superpowers/specs/2026-05-31--standard-chain-product-to-delivery-production-readiness--field-decision-matrix.md"
VALIDATOR="$ROOT/tools/community/validate_standard_chain_field_decision_matrix.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

[ -f "$MATRIX" ] || fail "missing field decision matrix"
[ -f "$VALIDATOR" ] || fail "missing matrix validator"

python3 "$VALIDATOR" --matrix "$MATRIX"

python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])

forbidden_runtime_fields = {"active_plan_version_ref"}
forbidden_canonical_noise_fields = {
    "parent_refs",
    "related_issue_ids",
    "title",
    "stage",
    "sort_key",
    "filter_tags",
    "jump_anchor",
}
scoped_fixture_roots = [
    root / "tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature",
    root / "tests/fixtures/standard-chain-foundation/runtime",
    root / "tests/fixtures/standard-chain-pilots/login-homepage-pilot",
    root / "tests/fixtures/standard-chain-pilots/feedback-thanks-pilot",
]
scoped_template_roots = [
    root / "shared/skills/product-manager/templates",
    root / "shared/skills/tech-lead/templates",
    root / "shared/skills/developer/templates",
    root / "shared/skills/verify/templates",
    root / "shared/skills/review/templates",
    root / "shared/skills/qa/templates",
    root / "shared/skills/consistency-audit/templates",
    root / "shared/skills/delivery-owner/templates",
]
runtime_artifacts = {
    "developer-report.json",
    "verify-result.json",
    "code-review-result.json",
    "qa-result.json",
    "consistency-audit-result.json",
}
catalog = json.loads((root / "shared/runtime/standard-chain-catalog.json").read_text(encoding="utf-8"))
template_authoritative_fields = {
    artifact_type: json.loads((root / entry["template_path"]).read_text(encoding="utf-8")).get("authoritative_fields", [])
    for artifact_type, entry in catalog["artifacts"].items()
}


def json_files_under(roots):
    for scan_root in roots:
        for path in sorted(scan_root.rglob("*.json")):
            yield path


for path in json_files_under(scoped_fixture_roots + scoped_template_roots):
    payload = json.loads(path.read_text(encoding="utf-8"))
    if path.name in runtime_artifacts:
        overlap = forbidden_runtime_fields & set(payload)
        if overlap:
            raise SystemExit(f"{path} keeps forbidden runtime fields: {sorted(overlap)}")
    if path.name != "phase-operational.projection-manifest.json" and "replay" not in path.parts and "views" not in path.parts:
        overlap = forbidden_canonical_noise_fields & set(payload)
        if overlap:
            raise SystemExit(f"{path} keeps canonical presentation fields: {sorted(overlap)}")
    artifact_type = payload.get("artifact_type")
    if "history" not in path.parts and artifact_type in template_authoritative_fields:
        fixture_fields = set(payload.get("authoritative_fields", []))
        missing_authoritative_fields = [
            field
            for field in template_authoritative_fields[artifact_type]
            if isinstance(field, str)
            and field.startswith("$.")
            and field[2:].split(".", 1)[0].split("[", 1)[0] in payload
            and field not in fixture_fields
        ]
        if missing_authoritative_fields:
            raise SystemExit(
                f"{path} authoritative_fields missing template fields: {missing_authoritative_fields}"
            )
PY

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 - "$MATRIX" "$TMP_DIR/missing-evidence.md" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="utf-8")
bad = source.replace("| Cleanup surface | Decision evidence |", "| Cleanup surface / evidence |", 1)
Path(sys.argv[2]).write_text(bad, encoding="utf-8")
PY
if python3 "$VALIDATOR" --matrix "$TMP_DIR/missing-evidence.md" >"$TMP_DIR/matrix_missing_evidence.out" 2>&1; then
  cat "$TMP_DIR/matrix_missing_evidence.out" >&2
  fail "matrix validator must reject collapsed cleanup/evidence column"
fi

python3 - "$MATRIX" "$TMP_DIR/needs-human-decision.md" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="utf-8")
bad = source.replace("| C-001 |", "| BAD-001 |", 1).replace("| keep |", "| needs-human-decision |", 1)
Path(sys.argv[2]).write_text(bad, encoding="utf-8")
PY
if python3 "$VALIDATOR" --matrix "$TMP_DIR/needs-human-decision.md" >"$TMP_DIR/matrix_human_decision.out" 2>&1; then
  cat "$TMP_DIR/matrix_human_decision.out" >&2
  fail "matrix validator must reject unresolved needs-human-decision rows"
fi

printf '[PASS] standard-chain product-delivery production readiness matrix\n'

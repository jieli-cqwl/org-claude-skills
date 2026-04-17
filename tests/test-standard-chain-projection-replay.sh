#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIEW_CONFIG="$ROOT/shared/runtime/projection-views.json"
REPLAY_CONFIG="$ROOT/shared/runtime/replay-profiles.json"
EXPECTED_FEATURE_ROOT="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
EXPECTED_PHASE_DIR="$EXPECTED_FEATURE_ROOT/phase-1"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_diff_clean() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  local diff_out
  diff_out="$(mktemp "$TMP_DIR/diff.XXXXXX")"
  if ! diff -u "$expected" "$actual" >"$diff_out"; then
    cat "$diff_out" >&2
    fail "$label mismatch"
  fi
}

for path in \
  "$VIEW_CONFIG" \
  "$REPLAY_CONFIG" \
  "$ROOT/tools/community/materialize_canonical_html.py" \
  "$ROOT/tools/community/replay_canonical_phase.py" \
  "$EXPECTED_FEATURE_ROOT/brief.json" \
  "$EXPECTED_PHASE_DIR/phase-prd.json" \
  "$EXPECTED_PHASE_DIR/design.json" \
  "$EXPECTED_PHASE_DIR/plan.json" \
  "$EXPECTED_PHASE_DIR/tasks.json" \
  "$EXPECTED_PHASE_DIR/code-review-result.json" \
  "$EXPECTED_PHASE_DIR/qa-result.json" \
  "$EXPECTED_PHASE_DIR/delivery-state.json" \
  "$EXPECTED_PHASE_DIR/artifact-registry.json" \
  "$EXPECTED_PHASE_DIR/history/plan-v1.json" \
  "$EXPECTED_PHASE_DIR/history/tasks-v1.json" \
  "$EXPECTED_PHASE_DIR/history/delivery-state-replan-pending.json" \
  "$EXPECTED_PHASE_DIR/signoff-package.json" \
  "$EXPECTED_PHASE_DIR/user-decision.json" \
  "$EXPECTED_PHASE_DIR/evidence/authority-proof.json" \
  "$EXPECTED_PHASE_DIR/units/UNIT-1.json" \
  "$EXPECTED_PHASE_DIR/unit-1/test-cases.json" \
  "$EXPECTED_PHASE_DIR/unit-1/tasks/T1/developer-report.json" \
  "$EXPECTED_PHASE_DIR/unit-1/tasks/T1/verify-result.json" \
  "$EXPECTED_PHASE_DIR/views/phase-operational.html" \
  "$EXPECTED_PHASE_DIR/views/phase-operational.projection-manifest.json" \
  "$EXPECTED_PHASE_DIR/replay/phase-operational.replay-oracle.json"; do
  [ -f "$path" ] || fail "missing projection/replay file: ${path#"$ROOT"/}"
done

python3 - "$EXPECTED_PHASE_DIR/artifact-registry.json" "$EXPECTED_PHASE_DIR/delivery-state.json" <<'PY'
import json
import sys
from pathlib import Path

registry = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
delivery_state = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
rev1 = registry["revisions"][0]["entries"]
rev2 = registry["revisions"][1]["entries"]

assert rev1[0]["version"] == "plan-v1"
assert rev1[0]["artifact_path"] == "history/plan-v1.json"
assert rev1[1]["version"] == "tasks-v1"
assert rev1[1]["artifact_path"] == "history/tasks-v1.json"
assert rev1[2]["artifact_path"] == "history/delivery-state-replan-pending.json"
assert rev2[0]["version"] == "plan-v2"
assert rev2[1]["version"] == "tasks-v2"
assert delivery_state["active_plan_version_ref"].endswith("@plan-v2#plan-version")
assert delivery_state["active_tasks_version_ref"].endswith("@tasks-v2#task-registry")
PY

ACTUAL_FEATURE_ROOT="$TMP_DIR/sample-feature"
cp -R "$EXPECTED_FEATURE_ROOT" "$ACTUAL_FEATURE_ROOT"
ACTUAL_PHASE_DIR="$ACTUAL_FEATURE_ROOT/phase-1"

python3 "$ROOT/tools/community/materialize_canonical_html.py" \
  --phase-dir "$ACTUAL_PHASE_DIR" \
  --views "$VIEW_CONFIG" \
  --generated-at "2026-04-14T04:10:00Z" >/dev/null \
  || fail "materializer should pass for golden pilot"

assert_diff_clean \
  "$EXPECTED_PHASE_DIR/views/phase-operational.html" \
  "$ACTUAL_PHASE_DIR/views/phase-operational.html" \
  "rendered html"

assert_diff_clean \
  "$EXPECTED_PHASE_DIR/views/phase-operational.projection-manifest.json" \
  "$ACTUAL_PHASE_DIR/views/phase-operational.projection-manifest.json" \
  "projection manifest"

python3 - "$ACTUAL_PHASE_DIR" <<'PY'
import json
import sys
from pathlib import Path

phase_dir = Path(sys.argv[1])
manifest = json.loads((phase_dir / "views/phase-operational.projection-manifest.json").read_text(encoding="utf-8"))
scenario = {
    "artifacts": [manifest],
    "projection": {
        "manifest_artifact_id": manifest["artifact_id"],
        "rendered_artifact_path": "views/phase-operational.html",
        "available_source_refs": manifest["source_artifact_refs"],
    },
}
(phase_dir / "scenario.json").write_text(
    json.dumps(scenario, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

python3 "$ROOT/tools/community/validate_projection_manifest.py" --phase-dir "$ACTUAL_PHASE_DIR" >/dev/null \
  || fail "projection validator should pass for golden pilot"

ESCAPE_ROOT="$TMP_DIR/escape-check"
mkdir -p "$ESCAPE_ROOT"
cp -R "$EXPECTED_FEATURE_ROOT" "$ESCAPE_ROOT/"
ESCAPE_PHASE_DIR="$ESCAPE_ROOT/sample-feature/phase-1"
python3 - "$ESCAPE_PHASE_DIR/delivery-state.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["summary_text"] = "</pre><script>alert(1)</script>"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$ROOT/tools/community/materialize_canonical_html.py" \
  --phase-dir "$ESCAPE_PHASE_DIR" \
  --views "$VIEW_CONFIG" \
  --generated-at "2026-04-14T04:10:00Z" >/dev/null \
  || fail "materializer should escape rendered content"
grep -q "&lt;/pre&gt;&lt;script&gt;alert(1)&lt;/script&gt;" "$ESCAPE_PHASE_DIR/views/phase-operational.html" \
  || fail "rendered html should escape dangerous content"
if grep -q "<script>alert(1)</script>" "$ESCAPE_PHASE_DIR/views/phase-operational.html"; then
  fail "rendered html must not embed raw script tags"
fi

BAD_ANCHOR_ROOT="$TMP_DIR/bad-anchor-check"
BAD_ANCHOR_VIEW="$TMP_DIR/bad-anchor-views.json"
mkdir -p "$BAD_ANCHOR_ROOT"
cp -R "$EXPECTED_FEATURE_ROOT" "$BAD_ANCHOR_ROOT/"
BAD_ANCHOR_PHASE_DIR="$BAD_ANCHOR_ROOT/sample-feature/phase-1"
cp "$VIEW_CONFIG" "$BAD_ANCHOR_VIEW"
python3 - "$BAD_ANCHOR_VIEW" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["views"][0]["section_sources"]["gate-verdicts"]["source_artifact_refs"][0] = (
    "artifact://qa-result/{feature}.phase-{N}.qa@active#wrong-anchor"
)
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/materialize_canonical_html.py" \
  --phase-dir "$BAD_ANCHOR_PHASE_DIR" \
  --views "$BAD_ANCHOR_VIEW" >/tmp/t5_anchor_fail.out 2>&1; then
  cat /tmp/t5_anchor_fail.out >&2
  fail "materializer should reject mismatched source anchors"
fi

ACTUAL_ORACLE="$TMP_DIR/phase-operational.replay-oracle.actual.json"
python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$ACTUAL_PHASE_DIR" \
  --profiles "$REPLAY_CONFIG" \
  --write-oracle "$ACTUAL_ORACLE" >/dev/null \
  || fail "replay oracle writer should pass for golden pilot"

assert_diff_clean \
  "$EXPECTED_PHASE_DIR/replay/phase-operational.replay-oracle.json" \
  "$ACTUAL_ORACLE" \
  "replay oracle"

python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$ACTUAL_PHASE_DIR" \
  --profiles "$REPLAY_CONFIG" \
  --oracle "$EXPECTED_PHASE_DIR/replay/phase-operational.replay-oracle.json" >/dev/null \
  || fail "replay oracle verification should pass for golden pilot"

python3 - "$EXPECTED_PHASE_DIR/replay/phase-operational.replay-oracle.json" <<'PY'
import json
import sys
from pathlib import Path

oracle = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert "authority-conflict" in oracle["profiles"]
assert "quarantined-restore" in oracle["profiles"]
assert oracle["artifacts"]["signoff-package"]["waiver_entries[].waiver_id"] == ["WAIVER-1"]
assert oracle["artifacts"]["artifact-registry"]["restore_basis_refs"] == [
    "artifact://evidence/sample-feature.phase-1.restore@ev-restore#root"
]
assert oracle["artifacts"]["projection-manifest"]["rendered_artifact_ref"].endswith(
    "#html-output:phase-operational.html"
)
PY

NA_PHASE_DIR="$TMP_DIR/not-applicable-phase"
NA_ORACLE="$TMP_DIR/not-applicable.replay-oracle.json"
cp -R "$ACTUAL_PHASE_DIR" "$NA_PHASE_DIR"
python3 - "$NA_PHASE_DIR/signoff-package.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["goal_closure"].append(
    {
        "goal_ref": "artifact://brief/sample-feature.brief@v1#goal-003",
        "result": "N_A",
        "reason_code": "OUT_OF_SCOPE"
    }
)
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$NA_PHASE_DIR" \
  --profiles "$REPLAY_CONFIG" \
  --write-oracle "$NA_ORACLE" >/dev/null \
  || fail "replay oracle should support not-applicable profile"
python3 - "$NA_ORACLE" <<'PY'
import json
import sys
from pathlib import Path

oracle = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert "not-applicable" in oracle["profiles"]
assert oracle["artifacts"]["signoff-package"]["goal_closure[].reason_code"] == ["OUT_OF_SCOPE"]
PY
python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$NA_PHASE_DIR" \
  --profiles "$REPLAY_CONFIG" \
  --oracle "$NA_ORACLE" >/dev/null \
  || fail "replay oracle verification should support not-applicable profile"

BAD_PROJECTION_DIR="$TMP_DIR/bad-projection"
cp -R "$ACTUAL_PHASE_DIR" "$BAD_PROJECTION_DIR"
python3 - "$BAD_PROJECTION_DIR/scenario.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["projection"]["available_source_refs"] = []
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_projection_manifest.py" --phase-dir "$BAD_PROJECTION_DIR" >/tmp/t5_projection_fail.out 2>&1; then
  cat /tmp/t5_projection_fail.out >&2
  fail "projection validator should reject undeclared sources"
fi

BAD_CONFIG_ROOT="$TMP_DIR/bad-config-check"
mkdir -p "$BAD_CONFIG_ROOT"
cp -R "$EXPECTED_FEATURE_ROOT" "$BAD_CONFIG_ROOT/"
BAD_CONFIG_PROJECTION_DIR="$BAD_CONFIG_ROOT/sample-feature/phase-1"
python3 "$ROOT/tools/community/materialize_canonical_html.py" \
  --phase-dir "$BAD_CONFIG_PROJECTION_DIR" \
  --views "$VIEW_CONFIG" \
  --generated-at "2026-04-14T04:10:00Z" >/dev/null \
  || fail "materializer should pass before projection config drift mutation"
python3 - "$BAD_CONFIG_PROJECTION_DIR" <<'PY'
import json
import sys
from pathlib import Path

phase_dir = Path(sys.argv[1])
manifest = json.loads((phase_dir / "views/phase-operational.projection-manifest.json").read_text(encoding="utf-8"))
scenario = {
    "artifacts": [manifest],
    "projection": {
        "manifest_artifact_id": manifest["artifact_id"],
        "rendered_artifact_path": "views/phase-operational.html",
        "available_source_refs": manifest["source_artifact_refs"],
    },
}
(phase_dir / "scenario.json").write_text(
    json.dumps(scenario, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY
python3 - "$BAD_CONFIG_PROJECTION_DIR/views/phase-operational.projection-manifest.json" "$BAD_CONFIG_PROJECTION_DIR/scenario.json" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
scenario_path = Path(sys.argv[2])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["section_source_map"]["blocked-state"]["source_artifact_refs"] = [
    "artifact://user-decision/sample-feature.phase-1.decision@active#signoff-status"
]
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

scenario = json.loads(scenario_path.read_text(encoding="utf-8"))
scenario["artifacts"][0] = manifest
scenario_path.write_text(json.dumps(scenario, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_projection_manifest.py" --phase-dir "$BAD_CONFIG_PROJECTION_DIR" >/tmp/t5_projection_config_fail.out 2>&1; then
  cat /tmp/t5_projection_config_fail.out >&2
  fail "projection validator should reject section_source_map drift"
fi

BAD_AUTHORITY_ORACLE="$TMP_DIR/bad-authority-oracle.json"
cp "$EXPECTED_PHASE_DIR/replay/phase-operational.replay-oracle.json" "$BAD_AUTHORITY_ORACLE"
python3 - "$BAD_AUTHORITY_ORACLE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["proof"]["verified_actor_id"] = "user-999"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$ACTUAL_PHASE_DIR" \
  --profiles "$REPLAY_CONFIG" \
  --oracle "$BAD_AUTHORITY_ORACLE" >/tmp/t5_authority_fail.out 2>&1; then
  cat /tmp/t5_authority_fail.out >&2
  fail "replay should reject authority-conflict mismatch"
fi

BAD_REF_DIR="$TMP_DIR/bad-ref"
cp -R "$ACTUAL_PHASE_DIR" "$BAD_REF_DIR"
python3 - "$BAD_REF_DIR/views/phase-operational.projection-manifest.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["source_artifact_refs"][0] = "artifact://qa-result/sample-feature.phase-1.missing@active#gate-result"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$BAD_REF_DIR" \
  --profiles "$REPLAY_CONFIG" \
  --oracle "$EXPECTED_PHASE_DIR/replay/phase-operational.replay-oracle.json" >/tmp/t5_ref_break_fail.out 2>&1; then
  cat /tmp/t5_ref_break_fail.out >&2
  fail "replay should reject missing canonical ref target"
fi
grep -q "missing canonical ref target" /tmp/t5_ref_break_fail.out \
  || fail "ref-break failure should use configured message"

BAD_MIXED_DIR="$TMP_DIR/bad-mixed"
cp -R "$ACTUAL_PHASE_DIR" "$BAD_MIXED_DIR"
python3 - "$BAD_MIXED_DIR/user-decision.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["active_tasks_version_ref"] = "artifact://tasks/sample-feature.phase-1.tasks@tasks-v1#task-registry"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$BAD_MIXED_DIR" \
  --profiles "$REPLAY_CONFIG" \
  --oracle "$EXPECTED_PHASE_DIR/replay/phase-operational.replay-oracle.json" >/tmp/t5_mixed_fail.out 2>&1; then
  cat /tmp/t5_mixed_fail.out >&2
  fail "replay should reject mixed-version drift"
fi
grep -q "schema/chain/version mismatch" /tmp/t5_mixed_fail.out \
  || fail "mixed-version failure should use configured message"

echo "[PASS] standard chain projection replay"

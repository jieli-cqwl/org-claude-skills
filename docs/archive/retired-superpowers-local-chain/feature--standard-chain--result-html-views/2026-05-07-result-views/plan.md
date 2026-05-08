# Standard Chain HTML Result Views Implementation Plan

> **For agentic workers:** REQUIRED NEXT STEP: run `implementation-router`. Implement only after `execution-route.json` chooses `serial` or `parallel`.

**Goal:** Build deterministic, source-mapped HTML result views for standard-chain phases and remove active standard-chain Markdown projections.

**Architecture:** The implementation is contract first. A result-view registry and manifest schema define the display contract; deterministic renderer and validator tooling materialize five static HTML pages from canonical JSON; replay/readiness migrate from the legacy single `phase-operational` projection to the configured result-view manifest set; a closed UX review report proves human readability without becoming runtime truth.

**Tech Stack:** Python 3 deterministic tooling, JSON Schema draft 2020-12, Bash regression tests, existing standard-chain fixtures, static HTML/CSS, standard-chain artifact registry and replay validators.

---

### Task 1: Result-view registry and manifest contract [T1]

Context: The design introduces a new active display contract. This task locks the registry, manifest schema, template, and catalog shape before any renderer writes HTML.

Files:
- Create: `shared/runtime/result-views.json`
- Modify: `shared/skills/delivery-owner/contracts/projection-manifest.schema.json`
- Modify: `shared/skills/delivery-owner/templates/projection-manifest.template.json`
- Modify: `shared/runtime/standard-chain-catalog.json`
- Modify: `tools/community/build_standard_chain_catalog.py`
- Create: `tests/test-standard-chain-result-view-contract.sh`

1. [T1] Write the failing contract test.

Run: `bash tests/test-standard-chain-result-view-contract.sh`
Expected: FAIL because `shared/runtime/result-views.json` does not exist and manifest schema does not require `result_view_registry_digest`.

2. [T1] Create `tests/test-standard-chain-result-view-contract.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="$ROOT/shared/runtime/result-views.json"
SCHEMA="$ROOT/shared/skills/delivery-owner/contracts/projection-manifest.schema.json"
TEMPLATE="$ROOT/shared/skills/delivery-owner/templates/projection-manifest.template.json"
CATALOG="$ROOT/shared/runtime/standard-chain-catalog.json"
BUILDER="$ROOT/tools/community/build_standard_chain_catalog.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$REGISTRY" || fail "missing result-views registry"

jq -e '
  .view_set_id == "standard-chain-result-views"
  and .schema_version == 1
  and (.views | map(.view_id) | sort) == [
    "design-result",
    "execution-result",
    "product-result",
    "release-result",
    "result-index"
  ]
  and all(.views[]; (.html_path | test("^views/.+\\.html$")) and (.manifest_path | test("^views/.+\\.projection-manifest\\.json$")))
  and all(.views[]; (.sections | length) > 0)
  and all(.views[]; all(.sections[]; has("section_id") and has("title_zh") and has("audience") and has("source_artifact_refs") and has("json_pointers") and has("required")))
  and all(.enum_mappings | keys[] as $k | (.[$k] | type == "object"))
' "$REGISTRY" >/dev/null || fail "result-views registry shape invalid"

jq -e '
  .. | objects | select(has("required")) | .required
  | index("result_view_registry_digest")
' "$SCHEMA" >/dev/null || fail "projection manifest schema must require result_view_registry_digest"

jq -e '.result_view_registry_digest | test("^sha256:[0-9a-f]{64}$")' "$TEMPLATE" >/dev/null \
  || fail "projection manifest template missing registry digest placeholder"

jq -e '
  .artifacts["projection-manifest"].default_path
  | contains("{view_id}.projection-manifest.json")
' "$CATALOG" >/dev/null || fail "catalog must expose dynamic result view manifest path"

rg -n 'view_id.+projection-manifest|result-view' "$BUILDER" >/dev/null \
  || fail "catalog builder must know result-view manifest metadata"

printf '[PASS] standard-chain result-view contract\n'
```

3. [T1] Create `shared/runtime/result-views.json` with the five configured views.

```json
{
  "schema_version": 1,
  "view_set_id": "standard-chain-result-views",
  "chain_version": "standard-chain/v1",
  "views": [
    {
      "view_id": "result-index",
      "html_path": "views/result-index.html",
      "manifest_path": "views/result-index.projection-manifest.json",
      "title_zh": "阶段结果总览",
      "audience": ["业务", "产品", "产研", "交付", "工程审计"],
      "sections": [
        {
          "section_id": "phase-status",
          "title_zh": "当前阶段状态",
          "audience": ["业务", "产品", "交付"],
          "source_artifact_refs": [
            "artifact://delivery-state/{feature}.phase-{N}.delivery-state@active#phase-summary",
            "artifact://signoff-package/{feature}.phase-{N}.signoff@active#release-recommendation"
          ],
          "json_pointers": ["/summary_text", "/current_stage", "/control_action", "/release_recommendation"],
          "required": true
        }
      ]
    },
    {
      "view_id": "product-result",
      "html_path": "views/product-result.html",
      "manifest_path": "views/product-result.projection-manifest.json",
      "title_zh": "产品结果闭环",
      "audience": ["业务", "产品", "产研"],
      "sections": [
        {
          "section_id": "background-goals-scope",
          "title_zh": "背景、目标与范围",
          "audience": ["业务", "产品", "产研"],
          "source_artifact_refs": [
            "artifact://brief/{feature}.brief@active#product-result",
            "artifact://phase-prd/{feature}.phase-{N}.prd@active#product-result"
          ],
          "json_pointers": ["/root_problem", "/business_goals", "/scope_boundaries", "/non_goals", "/phase_goal"],
          "required": true
        },
        {
          "section_id": "flows-units-acceptance",
          "title_zh": "业务流程、交付单元与验收标准",
          "audience": ["业务", "产品", "产研"],
          "source_artifact_refs": [
            "artifact://phase-prd/{feature}.phase-{N}.prd@active#flows",
            "artifact://unit-definition/{feature}.phase-{N}.unit-1@active#unit"
          ],
          "json_pointers": ["/business_flows", "/user_paths", "/rule_mappings", "/unit_index", "/acceptance_criteria", "/verification_plan"],
          "required": true
        }
      ]
    },
    {
      "view_id": "design-result",
      "html_path": "views/design-result.html",
      "manifest_path": "views/design-result.projection-manifest.json",
      "title_zh": "设计结果闭环",
      "audience": ["产品", "产研", "架构", "工程审计"],
      "sections": [
        {
          "section_id": "design-closure",
          "title_zh": "设计决策、边界与验证映射",
          "audience": ["产品", "产研", "架构"],
          "source_artifact_refs": ["artifact://design/{feature}.phase-{N}.design@active#design-result"],
          "json_pointers": ["/key_decisions", "/modules", "/interfaces", "/data_architecture", "/quality_attributes", "/verification_mapping", "/rollback_plan"],
          "required": true
        }
      ]
    },
    {
      "view_id": "execution-result",
      "html_path": "views/execution-result.html",
      "manifest_path": "views/execution-result.projection-manifest.json",
      "title_zh": "执行结果闭环",
      "audience": ["产研", "交付", "工程审计"],
      "sections": [
        {
          "section_id": "plan-task-evidence",
          "title_zh": "计划、任务与执行证据",
          "audience": ["产研", "交付", "工程审计"],
          "source_artifact_refs": [
            "artifact://plan/{feature}.phase-{N}.plan@active#plan-version",
            "artifact://tasks/{feature}.phase-{N}.tasks@active#task-registry",
            "artifact://code-review-result/{feature}.phase-{N}.code-review@active#review-conclusion"
          ],
          "json_pointers": ["/plan_version", "/task_list", "/tasks", "/gate_result", "/review_conclusion"],
          "required": true
        }
      ]
    },
    {
      "view_id": "release-result",
      "html_path": "views/release-result.html",
      "manifest_path": "views/release-result.projection-manifest.json",
      "title_zh": "发布结果闭环",
      "audience": ["业务", "产品", "QA", "交付"],
      "sections": [
        {
          "section_id": "release-signoff-risk",
          "title_zh": "QA、发布建议、签核与风险接受",
          "audience": ["业务", "产品", "QA", "交付"],
          "source_artifact_refs": [
            "artifact://qa-result/{feature}.phase-{N}.qa@active#gate-result",
            "artifact://delivery-state/{feature}.phase-{N}.delivery-state@active#phase-summary",
            "artifact://signoff-package/{feature}.phase-{N}.signoff@active#release-recommendation",
            "artifact://user-decision/{feature}.phase-{N}.decision@active#signoff-status"
          ],
          "json_pointers": ["/gate_result", "/release_recommendation", "/status", "/control_action", "/sign_off_status", "/business_risk_acceptance_status", "/residual_risk"],
          "required": true
        }
      ]
    }
  ],
  "enum_mappings": {
    "gate_result": {
      "PASS": "已通过",
      "WARN": "有警告",
      "FAIL": "未通过"
    },
    "release_recommendation": {
      "ALLOW": "允许发布",
      "CONDITIONAL_ALLOW": "有条件允许",
      "BLOCK": "不建议发布"
    },
    "sign_off_status": {
      "SIGNED_OFF": "已签署",
      "PENDING": "待签核",
      "REJECTED": "已拒绝"
    }
  }
}
```

4. [T1] Update `projection-manifest.schema.json` so `result_view_registry_digest` is a required digest field.

```json
"result_view_registry_digest": {
  "type": "string",
  "pattern": "^sha256:[0-9a-f]{64}$"
}
```

Add `"result_view_registry_digest"` to the same required array that already contains `renderer_version` and `rendered_content_digest`.

5. [T1] Update the projection manifest template with a digest placeholder that tests can replace.

```json
"result_view_registry_digest": "sha256:3333333333333333333333333333333333333333333333333333333333333333"
```

6. [T1] Update catalog metadata and builder to express dynamic result-view manifest paths.

Use default path:

```json
"default_path": "docs/{feature}/phase-{N}/views/{view_id}.projection-manifest.json"
```

7. [T1] Run the contract test.

Run: `bash tests/test-standard-chain-result-view-contract.sh`
Expected: `[PASS] standard-chain result-view contract`

### Task 2: Deterministic result-view renderer and validator [T2]

Context: The renderer is the only fact transformation layer. It must read canonical JSON, apply registry-defined labels, escape values, write five HTML pages, and write manifests with stable provenance.

Files:
- Create: `tools/community/materialize_standard_chain_result_views.py`
- Create: `tools/community/validate_result_view_manifests.py`
- Create: `tests/test-standard-chain-result-view-renderer.sh`
- Modify: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/views/`

1. [T2] Write the failing renderer test.

Run: `bash tests/test-standard-chain-result-view-renderer.sh`
Expected: FAIL because the renderer script does not exist.

2. [T2] Create `tests/test-standard-chain-result-view-renderer.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

PHASE_SRC="$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1"
PHASE_DIR="$TMP_DIR/sample-feature/phase-1"
mkdir -p "$TMP_DIR/sample-feature"
cp -R "$PHASE_SRC" "$PHASE_DIR"

python3 "$ROOT/tools/community/materialize_standard_chain_result_views.py" \
  --phase-dir "$PHASE_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" \
  --generated-at "2026-05-07T00:00:00Z" >/dev/null

for view in result-index product-result design-result execution-result release-result; do
  test -f "$PHASE_DIR/views/$view.html" || fail "missing $view.html"
  test -f "$PHASE_DIR/views/$view.projection-manifest.json" || fail "missing $view manifest"
  jq -e --arg view "$view" '
    .artifact_type == "projection-manifest"
    and .view_id == $view
    and (.result_view_registry_digest | test("^sha256:[0-9a-f]{64}$"))
    and (.rendered_content_digest | test("^sha256:[0-9a-f]{64}$"))
    and (.section_source_map | length > 0)
  ' "$PHASE_DIR/views/$view.projection-manifest.json" >/dev/null || fail "$view manifest invalid"
done

python3 "$ROOT/tools/community/validate_result_view_manifests.py" \
  --phase-dir "$PHASE_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" >/dev/null

ESCAPE_DIR="$TMP_DIR/escape/sample-feature/phase-1"
mkdir -p "$TMP_DIR/escape/sample-feature"
cp -R "$PHASE_SRC" "$ESCAPE_DIR"
python3 - "$ESCAPE_DIR/delivery-state.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["summary_text"] = "</section><script>alert(1)</script>"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "$ROOT/tools/community/materialize_standard_chain_result_views.py" \
  --phase-dir "$ESCAPE_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" >/dev/null
if rg -n '<script>alert\(1\)</script>' "$ESCAPE_DIR/views"; then
  fail "raw script must not appear in rendered HTML"
fi
rg -n '&lt;/section&gt;&lt;script&gt;alert\(1\)&lt;/script&gt;' "$ESCAPE_DIR/views" >/dev/null \
  || fail "escaped script text should be visible as escaped text"

MISSING_DIR="$TMP_DIR/missing/sample-feature/phase-1"
mkdir -p "$TMP_DIR/missing/sample-feature"
cp -R "$PHASE_SRC" "$MISSING_DIR"
python3 - "$MISSING_DIR/delivery-state.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload.pop("control_action", None)
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/materialize_standard_chain_result_views.py" \
  --phase-dir "$MISSING_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" >/tmp/result_view_missing.out 2>&1; then
  cat /tmp/result_view_missing.out >&2
  fail "missing required pointer should fail"
fi
rg -n 'missing required pointer' /tmp/result_view_missing.out >/dev/null \
  || fail "missing pointer failure should be explicit"

DRIFT_DIR="$TMP_DIR/drift/sample-feature/phase-1"
mkdir -p "$TMP_DIR/drift/sample-feature"
cp -R "$PHASE_SRC" "$DRIFT_DIR"
python3 "$ROOT/tools/community/materialize_standard_chain_result_views.py" \
  --phase-dir "$DRIFT_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" >/dev/null
python3 - "$DRIFT_DIR/views/product-result.projection-manifest.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["rendered_content_digest"] = "sha256:" + "0" * 64
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
if python3 "$ROOT/tools/community/validate_result_view_manifests.py" \
  --phase-dir "$DRIFT_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" >/tmp/result_view_digest.out 2>&1; then
  cat /tmp/result_view_digest.out >&2
  fail "digest drift should fail"
fi
rg -n 'digest mismatch' /tmp/result_view_digest.out >/dev/null \
  || fail "digest drift failure should be explicit"

printf '[PASS] standard-chain result-view renderer\n'
```

3. [T2] Implement `materialize_standard_chain_result_views.py` with focused helpers.

Required public helper names:

```python
def load_views(path: Path) -> dict:
    return load_json(path)

def registry_digest(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()

def infer_feature_phase(phase_dir: Path) -> tuple[str, str]:
    phase_name = phase_dir.name
    feature_name = phase_dir.parent.name
    if not phase_name.startswith("phase-"):
        raise ValueError(f"cannot infer phase from {phase_dir}")
    return feature_name, phase_name.removeprefix("phase-")

def resolve_source_ref(ref: str, feature: str, phase_number: str) -> str:
    return ref.replace("{feature}", feature).replace("{N}", phase_number)

def extract_pointer(payload: dict, pointer: str) -> object:
    value: object = payload
    for token in pointer.strip("/").split("/"):
        if token == "":
            continue
        if not isinstance(value, dict):
            raise KeyError(pointer)
        value = value[token]
    return value

def resolve_active_payload(ref: str, registry_index: dict[tuple[str, str], dict], phase_dir: Path) -> dict:
    artifact_type, versioned = ref.split("://", 1)[1].split("/", 1)
    artifact_id = versioned.split("@", 1)[0]
    entry = registry_index[(artifact_type, artifact_id)]
    return load_json(phase_dir / entry["artifact_path"])

def load_catalog_digest() -> str:
    catalog = load_json(ROOT / "shared/runtime/standard-chain-catalog.json")
    return catalog["chain_registry_digest"]

def render_view(view: dict, phase_dir: Path, registry_index: dict, registry_hash: str, generated_at: str) -> tuple[str, dict]:
    feature, phase_number = infer_feature_phase(phase_dir)
    html_sections: list[str] = []
    section_source_map: dict[str, dict] = {}
    all_source_refs: set[str] = set()
    for section in view["sections"]:
        resolved_refs = [resolve_source_ref(ref, feature, phase_number) for ref in section["source_artifact_refs"]]
        all_source_refs.update(resolved_refs)
        values: list[dict] = []
        resolved_pointers: set[str] = set()
        for ref in resolved_refs:
            payload = resolve_active_payload(ref, registry_index, phase_dir)
            for pointer in section["json_pointers"]:
                try:
                    value = extract_pointer(payload, pointer)
                except KeyError:
                    continue
                values.append({"source_ref": ref, "json_pointer": pointer, "value": value})
                resolved_pointers.add(pointer)
        missing = [pointer for pointer in section["json_pointers"] if pointer not in resolved_pointers]
        if section["required"] and missing:
            raise KeyError(f"missing required pointer: {view['view_id']}.{section['section_id']} {', '.join(missing)}")
        escaped_values = html.escape(json.dumps(values, ensure_ascii=False, indent=2))
        html_sections.append(f"<section id=\"{html.escape(section['section_id'])}\"><h2>{html.escape(section['title_zh'])}</h2><pre>{escaped_values}</pre></section>")
        section_source_map[section["section_id"]] = {"source_artifact_refs": resolved_refs, "json_pointers": section["json_pointers"]}
    body = "".join(html_sections)
    rendered = f"<html><body><main>{body}</main></body></html>\n"
    digest = "sha256:" + hashlib.sha256(rendered.encode("utf-8")).hexdigest()
    artifact_id = f"{feature}.phase-{phase_number}.{view['view_id']}.projection-manifest"
    manifest = {
        "artifact_type": "projection-manifest",
        "artifact_id": artifact_id,
        "schema_version": "1.0.0",
        "producer": "materialize-standard-chain-result-views",
        "produced_at": generated_at,
        "chain_version": "standard-chain/v1",
        "chain_registry_digest": load_catalog_digest(),
        "authority_scope": "artifact",
        "authoritative_fields": ["$.source_artifact_refs", "$.section_source_map"],
        "view_id": view["view_id"],
        "source_artifact_refs": sorted(all_source_refs),
        "section_source_map": section_source_map,
        "generated_at": generated_at,
        "renderer_version": "1.0.0",
        "result_view_registry_digest": registry_hash,
        "rendered_artifact_ref": f"artifact://projection-manifest/{artifact_id}@v1#html-output:{view['view_id']}.html",
        "rendered_content_digest": digest
    }
    return rendered, manifest
```

The script must use `html.escape` for every canonical value before writing HTML. It must fail with `missing required pointer: {view_id}.{section_id} {pointer}` when a required pointer is absent from all configured source artifacts for a section.

4. [T2] Implement `validate_result_view_manifests.py`.

Required checks:

```python
def validate_expected_view_set(phase_dir: Path, views: dict) -> None:
    missing = [view["view_id"] for view in views["views"] if not (phase_dir / view["manifest_path"]).is_file()]
    if missing:
        raise FileNotFoundError(f"missing result-view manifests: {', '.join(missing)}")

def validate_manifest_sources(manifest: dict, expected_section_map: dict) -> None:
    if manifest.get("section_source_map") != expected_section_map:
        raise ValueError(f"section source map drift: {manifest.get('view_id')}")

def validate_rendered_digest(phase_dir: Path, manifest: dict, html_path: Path) -> None:
    actual = "sha256:" + hashlib.sha256(html_path.read_bytes()).hexdigest()
    if manifest.get("rendered_content_digest") != actual:
        raise ValueError(f"digest mismatch: {html_path}")
```

The validator must fail when a configured view is missing, top-level sources differ from the registry-derived set, section source maps differ, rendered digest differs, or `result_view_registry_digest` differs from the current registry digest.

5. [T2] Generate golden fixture result views.

Run:

```bash
python3 tools/community/materialize_standard_chain_result_views.py \
  --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1 \
  --views shared/runtime/result-views.json \
  --generated-at "2026-05-07T00:00:00Z"
```

Expected: five HTML files and five manifest files are written under the fixture `views/` directory.

6. [T2] Run the renderer test.

Run: `bash tests/test-standard-chain-result-view-renderer.sh`
Expected: `[PASS] standard-chain result-view renderer`

### Task 3: Replay, readiness, and fixture cutover [T3]

Context: Current replay and readiness paths assume `views/phase-operational.projection-manifest.json`. This task migrates them to the configured result-view manifest set.

Files:
- Modify: `tools/community/replay_canonical_phase.py`
- Modify: `tools/community/validate_standard_chain_readiness.py`
- Modify: `tools/community/validate_standard_chain_phase.py`
- Modify: `tools/community/normalize_canonical_artifact.py`
- Modify: `tests/test-standard-chain-projection-replay.sh`
- Create: `tests/test-standard-chain-result-view-replay.sh`
- Modify: `tests/test-standard-chain-readiness-gate.sh`
- Modify: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/replay/phase-operational.replay-oracle.json`

1. [T3] Write the failing result-view replay test.

Run: `bash tests/test-standard-chain-result-view-replay.sh`
Expected: FAIL because replay still reads the single `phase-operational` manifest.

2. [T3] Create `tests/test-standard-chain-result-view-replay.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

PHASE_DIR="$TMP_DIR/sample-feature/phase-1"
mkdir -p "$TMP_DIR/sample-feature"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1" "$PHASE_DIR"

python3 "$ROOT/tools/community/materialize_standard_chain_result_views.py" \
  --phase-dir "$PHASE_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" >/dev/null

ORACLE="$TMP_DIR/result-view.replay-oracle.json"
python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$PHASE_DIR" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" \
  --write-oracle "$ORACLE" >/dev/null

jq -e '
  .artifacts["projection-manifest-set"].view_ids
  | sort == ["design-result","execution-result","product-result","release-result","result-index"]
' "$ORACLE" >/dev/null || fail "oracle must include result-view manifest set"

python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$PHASE_DIR" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" \
  --oracle "$ORACLE" >/dev/null

python3 - "$PHASE_DIR/views/product-result.projection-manifest.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["source_artifact_refs"][0] = "artifact://brief/other-feature.brief@active#product-result"
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

if python3 "$ROOT/tools/community/replay_canonical_phase.py" \
  --phase-dir "$PHASE_DIR" \
  --profiles "$ROOT/shared/runtime/replay-profiles.json" \
  --oracle "$ORACLE" >/tmp/result_view_replay_drift.out 2>&1; then
  cat /tmp/result_view_replay_drift.out >&2
  fail "replay should reject result-view source drift"
fi
rg -n 'result-view source drift|missing canonical ref target' /tmp/result_view_replay_drift.out >/dev/null \
  || fail "replay drift failure should be explicit"

printf '[PASS] standard-chain result-view replay\n'
```

3. [T3] Update replay oracle building to collect result-view manifests.

Add a helper in `replay_canonical_phase.py`:

```python
def load_result_view_manifests(phase_dir: Path) -> dict[str, dict]:
    views = load_json(Path("shared/runtime/result-views.json"))["views"]
    manifests = {}
    for view in views:
        manifest_path = phase_dir / view["manifest_path"]
        manifests[view["view_id"]] = load_json(manifest_path)
    return manifests
```

Use this helper to populate `artifacts["projection-manifest-set"]` with `view_ids`, `source_artifact_refs_by_view`, `section_source_map_by_view`, `rendered_artifact_ref_by_view`, and `rendered_content_digest_by_view`.

4. [T3] Update readiness and phase validation required file checks.

Replace single-manifest checks with iteration over `shared/runtime/result-views.json`. `validate_standard_chain_phase.py` and `validate_standard_chain_readiness.py` must fail when any configured manifest or HTML file is missing.

5. [T3] Update normalization helper so scenario fixtures collect the manifest set.

`normalize_canonical_artifact.py` must add all configured result-view manifests to fixture scenarios and stop hard-coding only `views/phase-operational.projection-manifest.json` for active result-view fixtures.

6. [T3] Regenerate golden replay oracle.

Run:

```bash
python3 tools/community/replay_canonical_phase.py \
  --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1 \
  --profiles shared/runtime/replay-profiles.json \
  --write-oracle tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/replay/phase-operational.replay-oracle.json
```

Expected: oracle contains `projection-manifest-set` and no active assertion depends only on `phase-operational`.

7. [T3] Run replay and readiness tests.

Run:

```bash
bash tests/test-standard-chain-result-view-replay.sh
bash tests/test-standard-chain-readiness-gate.sh
```

Expected: both commands pass.

### Task 4: UX review report contract and validator [T4]

Context: The sub agent reviews human readability only. This task makes that review mechanical enough for the main agent to consume without reading prose.

Files:
- Create: `tools/community/validate_result_ux_review.py`
- Create: `tests/test-result-view-ux-review-contract.sh`
- Create: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/views/result-ux-review.json`

1. [T4] Write the failing UX review contract test.

Run: `bash tests/test-result-view-ux-review-contract.sh`
Expected: FAIL because the validator and fixture do not exist.

2. [T4] Create `tests/test-result-view-ux-review-contract.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

PHASE_DIR="$TMP_DIR/sample-feature/phase-1"
mkdir -p "$TMP_DIR/sample-feature"
cp -R "$ROOT/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1" "$PHASE_DIR"

python3 "$ROOT/tools/community/materialize_standard_chain_result_views.py" \
  --phase-dir "$PHASE_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" >/dev/null

python3 "$ROOT/tools/community/validate_result_ux_review.py" \
  --phase-dir "$PHASE_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" >/tmp/ux_missing.out 2>&1 && fail "missing UX review should fail"
rg -n 'missing result-ux-review.json' /tmp/ux_missing.out >/dev/null \
  || fail "missing UX review failure should be explicit"

python3 - "$PHASE_DIR/views/result-ux-review.json" "$PHASE_DIR/views" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

review_path = Path(sys.argv[1])
views_dir = Path(sys.argv[2])
digests = []
for view in ["result-index", "product-result", "design-result", "execution-result", "release-result"]:
    digest = hashlib.sha256((views_dir / f"{view}.projection-manifest.json").read_bytes()).hexdigest()
    digests.append(f"sha256:{digest}")
review = {
    "artifact_type": "result-ux-review",
    "view_set_id": "standard-chain-result-views",
    "gate_result": "PASS",
    "reviewed_view_ids": ["result-index", "product-result", "design-result", "execution-result", "release-result"],
    "input_manifest_digests": digests,
    "findings": [],
    "reviewed_at": "2026-05-07T00:00:00Z",
    "reviewer": "sub-agent"
}
review_path.write_text(json.dumps(review, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 "$ROOT/tools/community/validate_result_ux_review.py" \
  --phase-dir "$PHASE_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" >/dev/null

python3 - "$PHASE_DIR/views/result-ux-review.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
payload["gate_result"] = "PASS"
payload["findings"] = [
    {
        "severity": "BLOCKER",
        "dimension": "terminology",
        "view_id": "product-result",
        "message": "业务读者无法理解主标题"
    }
]
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

if python3 "$ROOT/tools/community/validate_result_ux_review.py" \
  --phase-dir "$PHASE_DIR" \
  --views "$ROOT/shared/runtime/result-views.json" >/tmp/ux_blocker.out 2>&1; then
  cat /tmp/ux_blocker.out >&2
  fail "BLOCKER finding should fail"
fi
rg -n 'UX_REVIEW_BLOCKED' /tmp/ux_blocker.out >/dev/null \
  || fail "blocker failure should be explicit"

printf '[PASS] result-view UX review contract\n'
```

3. [T4] Implement `validate_result_ux_review.py`.

Required checks:

```python
EXPECTED_GATE_RESULTS = {"PASS", "BLOCK"}
EXPECTED_SEVERITIES = {"BLOCKER", "WARN", "INFO"}
EXPECTED_DIMENSIONS = {
    "terminology",
    "visual_hierarchy",
    "navigation",
    "evidence_discoverability",
    "accessibility",
    "audience_fit",
}
```

The validator must read `views/result-ux-review.json`, compare `reviewed_view_ids` with registry view ids, compare `input_manifest_digests` with current manifest file digests, reject unknown enums, reject `BLOCK` gate result, and reject any `BLOCKER` finding.

4. [T4] Write the golden UX review fixture.

Use the PASS JSON shape from the test and commit it under the golden fixture `views/` directory after generating the five manifests.

5. [T4] Run the UX contract test.

Run: `bash tests/test-result-view-ux-review-contract.sh`
Expected: `[PASS] result-view UX review contract`

### Task 5: Standard-chain Markdown projection cutover [T5]

Context: The old Markdown projection templates must stop being active standard-chain display contracts. This task deletes or rehomes the listed paths and updates runtime instructions/tests to point to HTML result views.

Files:
- Delete: `shared/skills/product-manager/projections/brief-template.md`
- Delete: `shared/skills/product-manager/projections/phase-prd-template.md`
- Delete: `shared/skills/product-manager/projections/product-manager-review-template.md`
- Delete: `shared/skills/design/projections/design-template.md`
- Delete or rehome: `shared/skills/design/projections/adr-spec.md`
- Delete: `shared/skills/test-design/projections/test-cases-template.md`
- Delete: `shared/skills/tech-lead/projections/plan-template.md`
- Delete: `shared/skills/tech-lead/projections/design-review-template.md`
- Delete or rehome: `shared/skills/review/projections/code-review-report-template.md`
- Delete or rehome: `shared/skills/qa/projections/qa-report-template.md`
- Delete or rehome: `shared/skills/consistency-audit/projections/consistency-report-template.md`
- Delete or rehome: `shared/skills/fix/projections/fix-report-template.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/review/SKILL.md`
- Modify: `shared/skills/qa/SKILL.md`
- Modify: `shared/skills/consistency-audit/SKILL.md`
- Modify: `shared/skills/fix/SKILL.md`
- Create: `tests/test-standard-chain-result-view-cutover.sh`
- Modify: standard-chain tests that currently assert `.md` projection contents

1. [T5] Write the failing cutover test.

Run: `bash tests/test-standard-chain-result-view-cutover.sh`
Expected: FAIL because standard-chain skill text and tests still reference `.md` projection templates.

2. [T5] Create `tests/test-standard-chain-result-view-cutover.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

STANDARD_CHAIN_FILES=(
  "$ROOT/shared/skills/product-manager/SKILL.md"
  "$ROOT/shared/skills/design/SKILL.md"
  "$ROOT/shared/skills/test-design/SKILL.md"
  "$ROOT/shared/skills/tech-lead/SKILL.md"
  "$ROOT/shared/skills/review/SKILL.md"
  "$ROOT/shared/skills/qa/SKILL.md"
  "$ROOT/shared/skills/consistency-audit/SKILL.md"
  "$ROOT/shared/skills/fix/SKILL.md"
  "$ROOT/tools/community/validate_standard_chain_phase.py"
  "$ROOT/tools/community/validate_standard_chain_readiness.py"
  "$ROOT/tools/community/replay_canonical_phase.py"
)

REMOVED_PATHS=(
  "shared/skills/product-manager/projections/brief-template.md"
  "shared/skills/product-manager/projections/phase-prd-template.md"
  "shared/skills/product-manager/projections/product-manager-review-template.md"
  "shared/skills/design/projections/design-template.md"
  "shared/skills/test-design/projections/test-cases-template.md"
  "shared/skills/tech-lead/projections/plan-template.md"
  "shared/skills/tech-lead/projections/design-review-template.md"
)

for rel in "${REMOVED_PATHS[@]}"; do
  test ! -e "$ROOT/$rel" || fail "active standard-chain Markdown projection remains: $rel"
done

if rg -n 'projections/(brief-template|phase-prd-template|product-manager-review-template|design-template|test-cases-template|plan-template|design-review-template)\.md' "${STANDARD_CHAIN_FILES[@]}"; then
  fail "standard-chain runtime files still reference removed Markdown projections"
fi

rg -n 'result-index\.html|product-result\.html|design-result\.html|execution-result\.html|release-result\.html' \
  "$ROOT/shared/skills/product-manager/SKILL.md" \
  "$ROOT/shared/skills/design/SKILL.md" \
  "$ROOT/shared/skills/tech-lead/SKILL.md" >/dev/null \
  || fail "standard-chain skills should mention HTML result views as display-only outputs"

if rg -n 'projections/(code-review-report-template|qa-report-template|consistency-report-template|fix-report-template|adr-spec)\.md' "$ROOT/shared/skills" "$ROOT/tools" "$ROOT/tests" >/tmp/result_view_projection_refs.out; then
  if ! rg -n 'non-standard-chain|standalone display|legacy-only' /tmp/result_view_projection_refs.out >/dev/null; then
    cat /tmp/result_view_projection_refs.out >&2
    fail "standalone projection references must be rehomed or marked outside standard-chain"
  fi
fi

printf '[PASS] standard-chain result-view cutover\n'
```

3. [T5] Update standard-chain skill wording.

Use this replacement wording where skills currently direct agents to read Markdown projections:

```markdown
人类展示只使用 `views/*.html` 结果视图。结果视图由 deterministic renderer 在 canonical JSON 验证通过后生成；它不是 runtime 真源，也不是下游控制输入。
```

4. [T5] Delete listed active standard-chain Markdown projection templates.

Use `apply_patch` delete hunks or `git rm` for the listed files after confirming no standard-chain runtime test still needs them.

5. [T5] Rehome standalone display templates only when needed.

If `adr-spec.md`, `code-review-report-template.md`, `qa-report-template.md`, `consistency-report-template.md`, or `fix-report-template.md` still supports non-standard-chain standalone usage, move it to a clearly named non-standard-chain display path and add a header:

```markdown
> Standalone display only. Not part of standard-chain active result-view contract.
```

6. [T5] Update tests that asserted Markdown projection content.

Replace assertions for `.md` projection templates with assertions for `shared/runtime/result-views.json`, result-view renderer tests, or result-view cutover tests.

7. [T5] Run cutover tests.

Run:

```bash
bash tests/test-standard-chain-result-view-cutover.sh
bash tests/test-skill-output-and-gate-contract.sh
bash tests/test-standard-chain-cutover.sh
bash tests/test-standard-chain-skill-structure.sh
```

Expected: all commands pass.

### Task 6: Route, regression, and context handoff [T6]

Context: This task proves the plan is internally consistent, refreshes implementation routing, and updates worklog handoff after the planning artifacts stabilize.

Files:
- Modify: `docs/feature--standard-chain--result-html-views/worklog.md`
- Create: `docs/feature--standard-chain--result-html-views/2026-05-07-result-views/execution-route.json`

1. [T6] Run the task-plan consistency checker.

Run:

```bash
python3 tools/community/check_task_plan_consistency.py \
  docs/feature--standard-chain--result-html-views/2026-05-07-result-views/tasks.md \
  docs/feature--standard-chain--result-html-views/2026-05-07-result-views/plan.md
```

Expected: output starts with `[PASS] tasks-plan consistency (6 tasks,` and reports a positive numbered step count.

2. [T6] Run the implementation router.

Run:

```bash
python3 tools/community/implementation_router.py \
  --repo-root . \
  --feature-path docs/feature--standard-chain--result-html-views \
  --workset 2026-05-07-result-views \
  --force-refresh
```

Expected: `execution-route.json` is written with a non-blocked decision. The expected route is `serial` because schema, validator, replay, readiness, fixtures, and skill cutover all share contract-grade surfaces.

3. [T6] Run context and contract validation.

Run:

```bash
python3 tools/community/validate_context_contract.py --repo-root .
bash tools/validate-contracts.sh
```

Expected: both commands pass.

4. [T6] Run all targeted proving commands.

Run:

```bash
bash tests/test-standard-chain-result-view-contract.sh
bash tests/test-standard-chain-result-view-renderer.sh
bash tests/test-standard-chain-result-view-replay.sh
bash tests/test-result-view-ux-review-contract.sh
bash tests/test-standard-chain-result-view-cutover.sh
bash tests/test-standard-chain-readiness-gate.sh
bash tests/test-skill-output-and-gate-contract.sh
bash tests/test-standard-chain-cutover.sh
bash tests/test-standard-chain-skill-structure.sh
```

Expected: every command exits 0.

5. [T6] Append the plan-stage worklog record.

Append to `docs/feature--standard-chain--result-html-views/worklog.md`:

```markdown
## 2026-05-07 00:00

- actor: Codex
- context_owner: feature-runtime-owner
- mode: small-chain
- stage: plan
- scope_ref: 2026-05-07-result-views/tasks.md
- handoff_status: doing
- state_ref: 2026-05-07-result-views/tasks.md
- next: Implementation plan and routing input are ready; next step is implementation routing.
- next_ref: 2026-05-07-result-views/execution-routing-input.json
```

6. [T6] Commit the planning artifacts after validation.

Run:

```bash
git add \
  docs/feature--standard-chain--result-html-views/2026-05-07-result-views/tasks.md \
  docs/feature--standard-chain--result-html-views/2026-05-07-result-views/plan.md \
  docs/feature--standard-chain--result-html-views/2026-05-07-result-views/execution-routing-input.json \
  docs/feature--standard-chain--result-html-views/2026-05-07-result-views/execution-route.json \
  docs/feature--standard-chain--result-html-views/worklog.md
git commit -m "docs: plan standard chain HTML result views"
```

Expected: only planning artifacts and worklog updates are committed.

# 全房通首页入口中心 Standard-Chain Dogfood Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把全房通首页入口中心改造设计落成一次可派发、可验收、可签收的 `standard-chain/v1` live dogfood 执行计划。

**Architecture:** 本计划不把原型实现当成唯一目标，而是先建立 feature context、证据包和 canonical artifact 骨架，再按 `product-director -> product-manager -> design -> test-design -> tech-lead -> developer -> review -> verify -> qa -> consistency-auditor -> delivery-owner` 串行推进。所有阶段都必须留下站内验收、下游 intake 和 evidence refs，返修只能回 owner route，不用弱证据替代通过。

**Tech Stack:** Markdown/JSON/YAML artifact、静态 HTML/CSS/JS 原型、Python `http.server` 本地预览、浏览器自动化截图、项目现有 shell gate。

---

## Scope Check

本 spec 覆盖一个集成链路试跑，不拆成多个独立子项目。可并行的只有只读 review；artifact 生产、证据采集、计划冻结、原型实现、QA 和 signoff 存在严格依赖，按顺序执行。

## File Structure

- Modify: `contracts/active-doc-scope.yaml`，登记 `docs/feature--quanfangtong-homepage-entry-center` active scope。
- Create: `docs/feature--quanfangtong-homepage-entry-center/worklog.md`，保存 context validator 要求的最新 handoff 时间块。
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/tasks.json`，最小 bootstrap task registry，供 worklog canonical ref 解析。
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/artifact-registry.json`，最小 bootstrap registry，供 context contract 解析 active ref。
- Create: `docs/feature--quanfangtong-homepage-entry-center/standard-chain-dogfood-observation.md`，记录需求问题、链路问题、环境问题。
- Create: `docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/`，保存当前页面截图、文本和 `capture-manifest.json`。
- Create: `docs/feature--quanfangtong-homepage-entry-center/brief.json`、`product-director-ledger.json`、`phase-1/phase-prd.json`、`phase-1/units/UNIT-1.json`。
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/design.json`、`phase-1/unit-1/test-cases.json`。
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/plan.json`、`phase-1/tasks.json`、`phase-1/artifact-registry.json`。
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/prototype/index.html`、`styles.css`、`app.js`。
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/unit-1/tasks/T1/developer-report.json`、`verify-result.json`。
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/code-review-result.json`、`qa-result.json`、`consistency-audit-result.json`、`delivery-state.json`、`signoff-package.json`、`user-decision.json`。
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/views/phase-operational.projection-manifest.json` 和 `phase-operational.html`。

## Execution Gate

- [ ] **Gate 0: Freeze user-reviewed spec before execution**

Run: `rg -n '用户 review 本设计文档后|Planning 完成判据' docs/superpowers/specs/2026-05-26--quanfangtong-homepage-entry-center--standard-chain-dogfood-design.md`
Expected: both lines are present. If the user has not confirmed this spec as execution input in the conversation, stop before Task 1 and ask for that decision. Do not create feature artifacts before this gate is satisfied.

### Task 1: Feature Context And Scope Registry

**Files:**
- Modify: `contracts/active-doc-scope.yaml`
- Create: `docs/feature--quanfangtong-homepage-entry-center/worklog.md`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/tasks.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/artifact-registry.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/standard-chain-dogfood-observation.md`

- [ ] **Step 1: Write a failing scope check**

Run:
```bash
python3 - <<'PY'
from pathlib import Path
text = Path('contracts/active-doc-scope.yaml').read_text(encoding='utf-8')
assert 'docs/feature--quanfangtong-homepage-entry-center' in text
PY
```
Expected: FAIL with `AssertionError` before the scope entry exists.

- [ ] **Step 2: Add the active scope entry**

Append this item under `scope_entries:` in `contracts/active-doc-scope.yaml`:
```yaml
  - feature_path: docs/feature--quanfangtong-homepage-entry-center
    mode: standard-chain
    management_status: managed
    layout: phase-tree
    entry_ref: worklog.md
    context_owner: delivery-owner
```

`entry_ref` is relative to `feature_path`; using the full feature path here makes `context_contract_validator.py` resolve a duplicated path.

- [ ] **Step 3: Create context bootstrap files**

Create `docs/feature--quanfangtong-homepage-entry-center/phase-1/tasks.json`:
```json
{
  "artifact_type": "tasks",
  "artifact_id": "quanfangtong-homepage-entry-center.phase-1.tasks",
  "schema_version": "1.0.0",
  "producer": "tech-lead",
  "produced_at": "2026-05-26T00:00:00Z",
  "chain_version": "standard-chain/v1",
  "authority_scope": "phase",
  "authoritative_fields": ["$.plan_version", "$.tasks"],
  "plan_version": "tasks-bootstrap-r1",
  "tasks": []
}
```

Create `docs/feature--quanfangtong-homepage-entry-center/phase-1/artifact-registry.json`:
```json
{
  "artifact_type": "artifact-registry",
  "artifact_id": "quanfangtong-homepage-entry-center.phase-1.artifact-registry",
  "schema_version": "1.0.0",
  "producer": "artifact-registry-writer",
  "produced_at": "2026-05-26T00:00:00Z",
  "chain_version": "standard-chain/v1",
  "authority_scope": "phase",
  "authoritative_fields": ["$.scope_ref", "$.registry_revision", "$.active_revision_id", "$.revisions"],
  "scope_ref": "artifact://tasks/quanfangtong-homepage-entry-center.phase-1.tasks@tasks-bootstrap-r1#task-registry",
  "registry_revision": "bootstrap-r1",
  "active_revision_id": "bootstrap-r1",
  "revisions": [
    {
      "revision_id": "bootstrap-r1",
      "appended_at": "2026-05-26T00:00:00Z",
      "entries": [
        {
          "scope_ref": "artifact://tasks/quanfangtong-homepage-entry-center.phase-1.tasks@tasks-bootstrap-r1#task-registry",
          "artifact_id": "quanfangtong-homepage-entry-center.phase-1.tasks",
          "artifact_type": "tasks",
          "version": "tasks-bootstrap-r1",
          "artifact_path": "tasks.json",
          "lifecycle_state": "FINALIZED",
          "active_for_consumption": true,
          "produced_by": "tech-lead",
          "restore_basis_refs": []
        }
      ]
    }
  ]
}
```

Create `docs/feature--quanfangtong-homepage-entry-center/worklog.md`:
```markdown
# 全房通首页入口中心 Worklog

## 2026-05-26T00:00:00Z

- actor: task1-implementer
- context_owner: delivery-owner
- mode: standard-chain
- stage: PLANNING
- scope_ref: docs/feature--quanfangtong-homepage-entry-center
- handoff_status: doing
- state_ref: canonical:phase-1/artifact-registry.json::artifact://tasks/quanfangtong-homepage-entry-center.phase-1.tasks@tasks-bootstrap-r1#task-registry
- next: continue standard-chain dogfood execution from Task 1 scope bootstrap to evidence capture
- next_ref: canonical:phase-1/artifact-registry.json::artifact://tasks/quanfangtong-homepage-entry-center.phase-1.tasks@tasks-bootstrap-r1#task-registry
```

The `state_ref` and `next_ref` must use `canonical:<registry>::artifact://...`; plain file paths fail `validate_context_contract.py`.

- [ ] **Step 4: Create observation report shell**

Create `docs/feature--quanfangtong-homepage-entry-center/standard-chain-dogfood-observation.md`:
```markdown
# 全房通首页入口中心标准链路试跑观察报告

## 观察项

| id | stage | category | severity | status | owner | blocking | artifact_ref | evidence | next_step | closed_evidence |
|---|---|---|---|---|---|---|---|---|---|---|
```

- [ ] **Step 5: Verify scope entry**

Run:
```bash
python3 - <<'PY'
from pathlib import Path
text = Path('contracts/active-doc-scope.yaml').read_text(encoding='utf-8')
for term in ['docs/feature--quanfangtong-homepage-entry-center', 'mode: standard-chain', 'management_status: managed', 'layout: phase-tree', 'entry_ref: worklog.md']:
    assert term in text, term
PY
bash tests/test-active-doc-scope-lifecycle.sh
python3 tools/community/validate_context_contract.py --repo-root "$PWD"
```
Expected: all three commands PASS.

- [ ] **Step 6: Stage-ready checkpoint**

Run: `git diff -- contracts/active-doc-scope.yaml docs/feature--quanfangtong-homepage-entry-center/worklog.md docs/feature--quanfangtong-homepage-entry-center/standard-chain-dogfood-observation.md`
Expected: diff only contains the scope entry and the two new context files. Do not commit unless the user explicitly authorizes a commit.

### Task 2: Current Homepage Evidence Pack

**Files:**
- Create: `docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/capture-manifest.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/desktop-homepage.png`
- Create: `docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/mobile-homepage.png`
- Create: `docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/page-text.md`
- Create: `docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/capture-failure-log.md`

- [ ] **Step 1: Create evidence directory**

Run: `mkdir -p docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage`
Expected: directory exists.

- [ ] **Step 2: Capture desktop page**

Use a real browser session to open `https://www.quanfangtongvip.com/` at desktop viewport `1440x1000`, then save screenshot to `desktop-homepage.png`.
Expected: screenshot shows the current full房通 page or the failure is recorded in `capture-failure-log.md`.

- [ ] **Step 3: Capture mobile page**

Use the same real browser session with mobile viewport `390x844`, then save screenshot to `mobile-homepage.png`.
Expected: screenshot shows the mobile rendering or the failure is recorded in `capture-failure-log.md`.

- [ ] **Step 4: Capture page text**

Save visible text into `page-text.md` with this heading:
```markdown
# 全房通当前页面文本抓取

source_url: https://www.quanfangtongvip.com/
```
Expected: file includes observed text such as `全房通公寓管理系统`, `自助续费`, `登录`, `忘记密码`, `联系客服`, or the real observed alternatives.

- [ ] **Step 5: Write capture manifest**

Generate `capture-manifest.json` with stable entries and one real UTC timestamp from the capture session:
```bash
python3 - <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import json

captured_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')
root = Path('docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage')
manifest = {
    "artifact_type": "current-homepage-evidence-pack",
    "feature": "feature--quanfangtong-homepage-entry-center",
    "source_url": "https://www.quanfangtongvip.com/",
    "entries": [
        {
            "entry_id": "QFT-ASIS-001",
            "source_type": "screenshot",
            "source_ref": "desktop-homepage.png",
            "screenshot_ref": "docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/desktop-homepage.png",
            "viewport": "desktop-1440x1000",
            "captured_at": captured_at,
            "status": "captured",
            "supports": ["desktop_current_homepage", "as_is_entry_center"],
        },
        {
            "entry_id": "QFT-ASIS-002",
            "source_type": "screenshot",
            "source_ref": "mobile-homepage.png",
            "screenshot_ref": "docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/mobile-homepage.png",
            "viewport": "mobile-390x844",
            "captured_at": captured_at,
            "status": "captured",
            "supports": ["mobile_current_homepage", "responsive_baseline"],
        },
        {
            "entry_id": "QFT-ASIS-003",
            "source_type": "text",
            "source_ref": "page-text.md",
            "observed_text_ref": "docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage/page-text.md",
            "captured_at": captured_at,
            "status": "captured",
            "supports": ["visible_text", "as_is_flows"],
        },
    ],
}
(root / 'capture-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
PY
```
Expected: manifest exists and each entry has the same real capture timestamp.

- [ ] **Step 6: Verify evidence references**

Run:
```bash
python3 - <<'PY'
import json
from pathlib import Path
root = Path('docs/feature--quanfangtong-homepage-entry-center/evidence/current-homepage')
data = json.loads((root / 'capture-manifest.json').read_text(encoding='utf-8'))
ids = {entry['entry_id'] for entry in data['entries']}
assert {'QFT-ASIS-001', 'QFT-ASIS-002', 'QFT-ASIS-003'} <= ids
for entry in data['entries']:
    assert entry['captured_at'].endswith('Z')
    assert entry['status'] in {'captured', 'failed'}
PY
```
Expected: PASS.

### Task 3: Product And Requirement Artifacts

**Files:**
- Create: `docs/feature--quanfangtong-homepage-entry-center/product-director-ledger.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/brief.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/phase-prd.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/units/UNIT-1.json`

- [ ] **Step 1: Write product-director ledger as support artifact**

Create JSON with `artifact_type: "product-director-ledger"`, `producer: "product-director"`, `control_input: false`, decisions for entry-center direction, prototype boundary, and finalization basis referencing this spec.
Expected: ledger is not listed as canonical control handoff.

- [ ] **Step 2: Write `brief.json`**

Create canonical brief with goals, non-goals, target users, success standards, and refs to `QFT-ASIS-001`, `QFT-ASIS-002`, `QFT-ASIS-003`.
Expected: no implementation HOW appears in Director-owned fields.

- [ ] **Step 3: Write `phase-prd.json` and `UNIT-1.json`**

`phase-prd.json` must include AS-IS/TO-BE, AC for login method switching, renewal prompt, download entry, support entry, announcement display, desktop/mobile response, and prototype-only boundaries. `UNIT-1.json` must define one unit: `UNIT-1` for the entry center prototype.
Expected: every AC that touches real backend capability is marked `prototype_only` or `not_integrated`.

- [ ] **Step 4: Verify product artifacts**

Run:
```bash
python3 -m json.tool docs/feature--quanfangtong-homepage-entry-center/brief.json >/dev/null
python3 -m json.tool docs/feature--quanfangtong-homepage-entry-center/phase-1/phase-prd.json >/dev/null
python3 -m json.tool docs/feature--quanfangtong-homepage-entry-center/phase-1/units/UNIT-1.json >/dev/null
rg -n 'QFT-ASIS-001|QFT-ASIS-002|QFT-ASIS-003|prototype_only|not_integrated' docs/feature--quanfangtong-homepage-entry-center/brief.json docs/feature--quanfangtong-homepage-entry-center/phase-1/phase-prd.json docs/feature--quanfangtong-homepage-entry-center/phase-1/units/UNIT-1.json
```
Expected: JSON parsing PASS and all required evidence/prototype markers appear.

### Task 4: Design And Test-Design Artifacts

**Files:**
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/design.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/unit-1/test-cases.json`

- [ ] **Step 1: Write `design.json`**

Create design with two compared approaches: static prototype and existing frontend stack. Select static prototype unless an existing frontend app is proven available. Define modules `entry-layout`, `login-switcher`, `renewal-banner`, `download-entry`, `support-entry`, `announcement-entry`, and `responsive-shell`.
Expected: design inherits WHAT from PM and does not introduce backend integration.

- [ ] **Step 2: Write `test-cases.json`**

Create test obligations for every AC, including desktop/mobile browser paths, login tab switching, renewal prompt dismiss/restore, download click feedback, support click feedback, announcement visibility, repeat clicks, and refresh recovery.
Expected: obligations mapped to real browser evidence; no obligation uses Mock to prove integration.

- [ ] **Step 3: Verify traceability terms**

Run:
```bash
python3 -m json.tool docs/feature--quanfangtong-homepage-entry-center/phase-1/design.json >/dev/null
python3 -m json.tool docs/feature--quanfangtong-homepage-entry-center/phase-1/unit-1/test-cases.json >/dev/null
rg -n 'login-switcher|renewal-banner|download-entry|support-entry|responsive-shell|real_browser|prototype_only' docs/feature--quanfangtong-homepage-entry-center/phase-1/design.json docs/feature--quanfangtong-homepage-entry-center/phase-1/unit-1/test-cases.json
```
Expected: JSON parsing PASS and all terms appear.

### Task 5: Tech-Lead Plan, Tasks, Registry Bootstrap, Projection Manifest

**Files:**
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/plan.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/tasks.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/artifact-registry.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/views/phase-operational.projection-manifest.json`

- [ ] **Step 1: Write `plan.json`**

Create `plan.json` with `producer: "tech-lead"`, `plan_version: "plan-v1"`, ordered WBS for feature context, evidence, product artifacts, design, tests, prototype, review, verify, QA, consistency audit, and delivery-owner signoff.
Expected: blocking gaps remain blockers and are not converted to developer tasks.

- [ ] **Step 2: Write `tasks.json`**

Create one developer task `T1` with allowed paths limited to `phase-1/prototype/**` and `phase-1/unit-1/tasks/T1/developer-report.json`; AC covers the six prototype interactions and responsive behavior; proving command is `python3 -m http.server 4173 --directory docs/feature--quanfangtong-homepage-entry-center/phase-1/prototype` plus browser QA commands.
Expected: task has `task_id`, `depends_on`, `acceptance_targets`, `proving_command`, `evidence_target`, and `mock_boundary_note`.

- [ ] **Step 3: Write artifact registry bootstrap**

Create `artifact-registry.json` with `producer: "artifact-registry-writer"`, `registry_revision: "bootstrap-r1"`, active refs for every existing canonical artifact, evidence pack refs, and explicit missing refs for later artifacts.
Expected: bootstrap does not mark `delivery-state` as RUN and does not claim signoff readiness.

- [ ] **Step 4: Write projection manifest**

Create manifest for `phase-operational.html` with materialize owner `delivery-owner`, validate owner `consistency-auditor`, source refs to plan/tasks/artifact-registry, and output path `docs/feature--quanfangtong-homepage-entry-center/phase-1/views/phase-operational.html`.
Expected: projection manifest is canonical handoff and names both materialize and validate responsibility.

- [ ] **Step 5: Verify tech-lead outputs**

Run:
```bash
python3 -m json.tool docs/feature--quanfangtong-homepage-entry-center/phase-1/plan.json >/dev/null
python3 -m json.tool docs/feature--quanfangtong-homepage-entry-center/phase-1/tasks.json >/dev/null
python3 -m json.tool docs/feature--quanfangtong-homepage-entry-center/phase-1/artifact-registry.json >/dev/null
python3 -m json.tool docs/feature--quanfangtong-homepage-entry-center/phase-1/views/phase-operational.projection-manifest.json >/dev/null
rg -n 'bootstrap-r1|artifact-registry-writer|phase-operational.html|T1|mock_boundary_note|review/fix/re-review' docs/feature--quanfangtong-homepage-entry-center/phase-1
```
Expected: JSON parsing PASS and all required routing terms appear.

### Task 6: Developer Prototype And Report

**Files:**
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/prototype/index.html`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/prototype/styles.css`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/prototype/app.js`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/unit-1/tasks/T1/developer-report.json`

- [ ] **Step 1: Create prototype HTML**

Create semantic sections for header brand, renewal banner, login tabs, QR panel, download entry, support entry, announcement entry, and footer record text. Use buttons for interactive entries and `data-testid` attributes for browser checks.
Expected: opening `index.html` shows the usable entry center as first screen, not a marketing landing page.

- [ ] **Step 2: Create responsive CSS**

Define desktop two-column layout and mobile single-column layout at `max-width: 720px`; no decorative gradient or nested UI cards; stable dimensions for tab buttons and entry buttons.
Expected: text does not overlap at 390px width.

- [ ] **Step 3: Create JS interactions**

Implement tab switching for `password`, `sms`, `qr`; renewal banner dismiss; download button status text; support button status text; announcement expand/collapse; refresh-safe default state.
Expected: interactions update visible UI state without backend calls.

- [ ] **Step 4: Run local server**

Run: `python3 -m http.server 4173 --directory docs/feature--quanfangtong-homepage-entry-center/phase-1/prototype`
Expected: server starts on port 4173. If port is occupied, use the next free port and record the actual port in `developer-report.json`.

- [ ] **Step 5: Browser smoke test**

Use a real browser to visit the local URL, switch every login mode, dismiss renewal prompt, click download/support, expand announcement, and resize to mobile viewport.
Expected: every action produces visible feedback and no console error.

- [ ] **Step 6: Write developer report**

Create `developer-report.json` with changed files, AC mapping, proving command, browser smoke evidence refs, blocked items, and prototype boundary statement.
Expected: every AC has current proof or an explicit blocker.

### Task 7: Review, Verify, QA, And Fix Loop

**Files:**
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/code-review-result.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/unit-1/tasks/T1/verify-result.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/qa-result.json`
- Create if needed: `docs/feature--quanfangtong-homepage-entry-center/phase-1/fix-result.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/evidence/prototype-qa/desktop.png`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/evidence/prototype-qa/mobile.png`

- [ ] **Step 1: Run code review**

Review prototype behavior, security, scope, maintainability, artifact evidence, and contract boundaries. Save findings to `code-review-result.json` with severity, evidence, owner action, and PASS/BLOCKING result.
Expected: PASS only means review found no blocking issue.

- [ ] **Step 2: Run verifier**

Verify each T1 AC against `developer-report.json` and live prototype behavior. Save `verify-result.json` with per-AC status and fresh proof references.
Expected: verifier does not change implementation.

- [ ] **Step 3: Run QA browser obligations**

Use real desktop and mobile browser paths. Save screenshots to `prototype-qa/desktop.png` and `prototype-qa/mobile.png`; write `qa-result.json` with obligation results including `criticality`, `release_gate`, browser name/version, viewport, steps, expected result, actual result, timestamp, evidence refs, and blocker owner.
Expected: critical obligations for login switch, renewal, download, support, responsive, evidence truth, prototype boundary, and signoff readiness all have evidence refs.

- [ ] **Step 4: Route fixes through `fix-result.json`**

If review, verify, or QA finds blocking implementation issues, assign `fix`, write `fix-result.json`, update implementation, then repeat review, verify, and QA before delivery-owner signoff.
Expected: delivery-owner and signoff basis reference active `fix-result.json` whenever a fix occurred.

### Task 8: Consistency Audit And Delivery Signoff

**Files:**
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/consistency-audit-result.json`
- Modify: `docs/feature--quanfangtong-homepage-entry-center/phase-1/artifact-registry.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/delivery-state.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/signoff-package.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/user-decision.json`
- Create: `docs/feature--quanfangtong-homepage-entry-center/phase-1/views/phase-operational.html`
- Modify: `docs/feature--quanfangtong-homepage-entry-center/standard-chain-dogfood-observation.md`

- [ ] **Step 1: Run final consistency audit**

Check L1-L7 scope, requirement, design, test, plan, execution, verification, QA, registry, signoff traceability. Save `consistency-audit-result.json` with JSON pointers, evidence, owner action, and result.
Expected: no blocking trace gaps remain before signoff.

- [ ] **Step 2: Append artifact registry revision**

Append `delivery-owner` revision after QA and final audit. Active revision must include every canonical artifact, evidence pack, QA evidence, review, verify, fix result when present, and signoff package.
Expected: bootstrap revision remains in history; active revision is delivery-owner owned.

- [ ] **Step 3: Materialize phase operational projection**

Create `phase-operational.html` summarizing active state, blockers, artifact refs, QA critical obligation status, and recommendation. Validate it against projection manifest refs.
Expected: projection is derived from canonical artifacts and does not become a control input.

- [ ] **Step 4: Write delivery state and signoff package**

Create `delivery-state.json` and `signoff-package.json` with release recommendation `ALLOW`, `ALLOW_WITH_CONDITIONS`, or `BLOCK`, goal closure, waiver entries, runtime snapshot, active blockers, decision basis refs, prototype boundary statement, residual risks, and acceptance status.
Expected: recommendation maps to the three allowed投入判定 categories in the spec.

- [ ] **Step 5: Import user decision**

Create `user-decision.json` only from an explicit user decision in the conversation. If the user has not accepted signoff, record `acceptance.status: "PENDING_USER_DECISION"` in `signoff-package.json` and keep `user-decision.json` absent.
Expected: authorization basis never replaces user acceptance.

- [ ] **Step 6: Final proving commands**

Run:
```bash
python3 - <<'PY'
from pathlib import Path
import json
root = Path('docs/feature--quanfangtong-homepage-entry-center')
json_files = list(root.rglob('*.json'))
assert json_files
for path in json_files:
    json.loads(path.read_text(encoding='utf-8'))
PY
bash tests/test-active-doc-scope-lifecycle.sh
bash tests/test-standard-chain-login-homepage-pilot.sh
bash tests/run-all.sh --quick
```
Expected: JSON parse and targeted tests PASS. `tests/run-all.sh --quick` must PASS before claiming completion; if it fails on pre-existing target-outside issues, record exact failure as environment risk and do not claim full completion without user risk acceptance.

## Self-Review

- Spec coverage: Tasks cover feature context, active scope, evidence pack, runtime/artifact paths, projection manifest, prototype path, browser QA evidence, review/fix/re-review loop, plan/tasks boundaries, signoff package, and three档投入判定.
- Dynamic values: capture timestamps, browser version, screenshots, and user decision must come from real execution evidence.
- Known risk: current repository has unrelated hook/lint/complexity warnings. They are not fixed by this plan unless they block target-scoped proving commands or the user expands scope.

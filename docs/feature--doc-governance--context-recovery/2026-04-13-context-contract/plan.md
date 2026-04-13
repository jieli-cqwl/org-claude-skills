# Active Doc Context Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 把活跃文档上下文契约从设计文档落成仓库里的 validator、completion gate、small-chain skill 链路和回归测试。

**Architecture:** 保持现有 `docs/{feature}`、`contracts/active-doc-scope.yaml` 与 `small-chain` 主干不变，用“feature root + worklog + dated active workset”作为 small-chain 兼容桥接，同时让 `phase-tree` 的 full-chain 也能接入同一套 registry 与 validator。实现上先补单一 context validator 和 registry helper，再让 `brainstorming / writing-plans / product / verify-change / archive` 只做事件适配，并补一个 `report-only` audit 入口和 README/CI drift 收口，最后用 hooks、sync tool 和回归测试把路径与门禁接线收口。

**Tech Stack:** Python validator + registry helper, shell completion checks, report-only audit wrapper, Markdown skill docs, JSON hook registry, repo contract tests.

---

## 需求

当前设计已经冻结，但真实运行面仍有 4 个断点：

- `contracts/active-doc-scope.yaml` 还没有被运行时 validator 真正消费，也没有合法的 bootstrap / adopt / archive 写路径
- `brainstorming / writing-plans / product` 还没有把 `worklog.md + registry` 当成强制入口工件
- `verify-change / archive` 还停留在旧的 change-dir 归档语义，也没有承接 `approval_ref`
- README、repo proving path 和 audit entrypoint 还没有把新 contract 当成默认口径

这次计划只解决这些真实断点，不再扩展新的设计抽象。

## 目标

- 让 validator 能准确识别 managed active scope、small-chain/full-chain layout、worklog 引用和场景目录规则。
- 让 planning 与 product 入口技能具备真实 completion gate，而不是只靠文案提醒。
- 让 closeout / archive / subagent 执行链路全部回到 `worklog.md + active workset + branch-finalization`。
- 让 sync、install、runtime、audit、README 与 tests 全部消费同一套路径与门禁语义。

## 验收标准

- `tests/test-context-contract-validator.sh` 与 `tests/test-active-doc-scope-lifecycle.sh` 覆盖 validator 输入输出、registry 生命周期和正反向 fixture，并由 `tools/dev/validate-contracts.sh` 调用。
- 安装后的 runtime 会为 `brainstorming` 与 `writing-plans` 渲染 completion gate；shared product gate 会对 managed full-chain feature 执行最小骨架校验。
- `archive` 技能和 closeout 路由不再引用 `docs/{feature}/CHANGELOG.md` 或只移动 change 子目录。
- `branch-finalization` 能为无 `principal_id` 的运行面提供 `approved_by / approved_at / approval_ref` 承载。
- 回归测试矩阵全部通过，且不引入新的 runtime 引用漂移。
- `periodic audit` 至少拥有一个可手动执行的 report-only entrypoint，不再悬空在设计文档里。

## 实施顺序

- 第一批：validator 与 registry 生命周期真源
- 第二批：entry/bootstrap gate
- 第三批：verify / closeout / archive 链路迁移
- 第四批：sync / install / runtime / regression 收口

### Task 1: 落地 context contract validator、结构化 I/O 与 registry 生命周期写路径 [T1]

Files:
- Create: `tools/community/validate_context_contract.py`
- Create: `tools/community/update_active_doc_scope.py`
- Modify: `tools/dev/validate-contracts.sh`
- Create: `tools/dev/run-context-contract-audit.sh`
- Create: `tests/test-context-contract-validator.sh`
- Create: `tests/test-active-doc-scope-lifecycle.sh`
- Create: `tests/test-context-contract-audit.sh`

1. [T1] 先写 RED 测试，把 validator contract 和 registry 生命周期都跑成可复现失败。

```bash
cat >"$TMP_DIR/payload.json" <<EOF
{
  "repo_root": "$TMP_DIR",
  "trigger": "pre-commit",
  "changed_paths": ["docs/feature--doc-governance--context-recovery/worklog.md"],
  "runtime_context": {
    "tool_name": "Edit",
    "cwd": "$TMP_DIR",
    "active_skill": "brainstorming"
  },
  "approval_context": {}
}
EOF

python3 "$ROOT/tools/community/validate_context_contract.py" <"$TMP_DIR/payload.json"
python3 "$ROOT/tools/community/update_active_doc_scope.py" bootstrap \
  --registry "$TMP_DIR/contracts/active-doc-scope.yaml" \
  --feature-path "docs/feature--doc-governance--context-recovery" \
  --mode small-chain \
  --layout dated-workset \
  --rollout-phase phase-1-pilot \
  --owner feature-runtime-owner \
  --primary-workset-relpath "2026-04-13-context-contract"
```

2. [T1] 在 `tools/community/validate_context_contract.py` 实现冻结过的最小输入输出、结果对象和退出码映射，先把 validator 作为单一规则真源立起来。

```python
payload = json.loads(sys.stdin.read())
required_keys = {"repo_root", "trigger", "changed_paths"}
missing = sorted(required_keys - payload.keys())
if missing:
    raise SystemExit(json.dumps({
        "validator_id": "context-contract",
        "contract_version": 1,
        "decision": "block",
        "scope": "repo",
        "findings": [{"rule_id": "validator-input", "severity": "error", "message": f"missing keys: {missing}"}],
    }))
```

3. [T1] 实现 registry、feature、worklog、scene docs、waiver 的分层校验函数，并明确“只对 managed/migrated 条目阻断，legacy 仅报告；full-chain 的 phase-tree 也受同一 validator 约束”。

```python
def validate_scope_entry(entry: dict, repo_root: Path) -> list[Finding]:
    findings: list[Finding] = []
    if entry["status"] not in {"managed", "migrated", "legacy"}:
        findings.append(block("scope-status", entry["feature_path"], "status 非法"))
    if entry["layout"] == "dated-workset" and not entry.get("primary_workset_relpath"):
        findings.append(block("primary-workset", entry["feature_path"], "缺少 primary_workset_relpath"))
    return findings

def should_enforce(entry: dict) -> bool:
    return entry.get("status") in {"managed", "migrated"}
```

4. [T1] 在 `tools/community/validate_context_contract.py` 补齐 `worklog.md` 更新纪律校验，避免“字段齐了但写法违约”的假通过。

```python
def validate_worklog_discipline(doc: WorklogDoc, diff: str) -> list[Finding]:
    findings: list[Finding] = []
    if not doc.timestamps_match("%Y-%m-%d %H:%M"):
        findings.append(block("worklog-time-format", doc.path, "time 必须使用 YYYY-MM-DD HH:mm"))
    if not is_append_only(diff):
        findings.append(block("worklog-append-only", doc.path, "根 worklog.md 只能追加，不允许回写历史记录"))
    if doc.latest_entry.has_no_handoff_signal():
        findings.append(warn("worklog-trigger", doc.path, "未识别到阶段/状态/引用/接手变化"))
    return findings
```

5. [T1] 在 `tools/community/update_active_doc_scope.py` 实现 `bootstrap / adopt / archive` 三种写路径，让 registry 写入不再靠手工改 YAML。

```python
def archive_entry(entry: dict, archived_feature_path: str) -> dict:
    entry = dict(entry)
    entry["feature_path"] = archived_feature_path
    entry["status"] = "legacy"
    return entry
```

6. [T1] 把 validator 接入 `tools/dev/validate-contracts.sh`，同时修正社区技能扫描路径，让 repo 级 proving path 真正覆盖到 `community/superpowers/skills`。

```python
community_skills_dir = os.path.join(base_dir, "community", "superpowers", "skills")
chain_files = [
    os.path.join(base_dir, "contracts", "skill-chain.yaml"),
    os.path.join(base_dir, "contracts", "small-chain.yaml"),
]
```

7. [T1] 为 `periodic audit` 补最小 report-only entrypoint，让设计里的 audit 层有实际落点，但不引入 scheduler。

```bash
python3 "$ROOT/tools/community/validate_context_contract.py" <<EOF
{"repo_root":"$ROOT","trigger":"audit","changed_paths":[],"runtime_context":{},"approval_context":{}}
EOF
```

8. [T1] 跑本任务 proving commands，先确认 validator、registry helper 与 audit 入口可以独立工作，再确认 repo 总验证不回归。

```bash
bash tests/test-context-contract-validator.sh
bash tests/test-active-doc-scope-lifecycle.sh
bash tests/test-context-contract-audit.sh
bash tools/dev/validate-contracts.sh
```

### Task 2: 落地 `brainstorming / writing-plans / product` 的 bootstrap runtime gate [T2]

Files:
- Modify: `community/superpowers/skills/brainstorming/SKILL.md`
- Create: `community/superpowers/skills/brainstorming/scripts/completion_check.sh`
- Modify: `community/superpowers/skills/writing-plans/SKILL.md`
- Create: `community/superpowers/skills/writing-plans/scripts/completion_check.sh`
- Modify: `shared/skills/product/SKILL.md`
- Modify: `shared/skills/product/scripts/completion_check.sh`
- Modify: `shared/hooks/registry.json`
- Modify: `tools/community/render_hook_registry.py`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-chain-completeness.sh`

1. [T2] 先补 RED 断言，要求安装后 runtime 能找到三个相关 gate，且 gate 只做事件适配，不再手写第二套 contract 规则。

```bash
assert_runtime_present 'skills/brainstorming/scripts/completion_check.sh' "$runtime_dir/hooks.json"
assert_runtime_present 'skills/writing-plans/scripts/completion_check.sh' "$runtime_dir/hooks.json"
assert_runtime_present 'docs/\\{feature\\}/worklog\\.md' \
  "$ROOT/shared/skills/product/SKILL.md"
assert_runtime_present 'docs/\\{feature\\}/worklog\\.md' \
  "$ROOT/community/superpowers/skills/brainstorming/SKILL.md"
```

2. [T2] 为 `brainstorming` 编写 bootstrap gate：先通过 registry helper 补最小骨架，再调用单一 validator，不在 shell 里重复实现 contract 规则。

```bash
REL_FEATURE_DIR="$(printf '%s' "$TOOL_FILE_PATH" | sed -nE 's#^(docs/[^/]+)/.*#\1#p')"
WORKSET_BASENAME="$(printf '%s' "$TOOL_FILE_PATH" | sed -nE 's#^docs/[^/]+/([^/]+)/design\.md#\1#p')"
REL_WORKSET_DIR="$REL_FEATURE_DIR/$WORKSET_BASENAME"
FEATURE_OWNER="${FEATURE_OWNER:-feature-runtime-owner}"

python3 "$REPO_ROOT/tools/community/update_active_doc_scope.py" bootstrap \
  --registry "$REPO_ROOT/contracts/active-doc-scope.yaml" \
  --feature-path "$REL_FEATURE_DIR" \
  --mode small-chain \
  --layout dated-workset \
  --rollout-phase phase-1-pilot \
  --owner "$FEATURE_OWNER" \
  --primary-workset-relpath "$WORKSET_BASENAME"

python3 "$REPO_ROOT/tools/community/validate_context_contract.py" <<EOF
{"repo_root":"$REPO_ROOT","trigger":"runtime-stop","changed_paths":["$REL_FEATURE_DIR/worklog.md","$REL_WORKSET_DIR/design.md"],"runtime_context":{"tool_name":"Edit","cwd":"$CWD","active_skill":"brainstorming","session_id":"${SESSION_ID:-}"},"approval_context":{}}
EOF
```

3. [T2] 为 `writing-plans` 编写 gate：先调 validator，再做 `tasks/plan` 一致性补充校验。

```bash
REL_FEATURE_DIR="$(printf '%s' "$TOOL_FILE_PATH" | sed -nE 's#^(docs/[^/]+)/.*#\1#p')"
WORKSET_BASENAME="$(printf '%s' "$TOOL_FILE_PATH" | sed -nE 's#^docs/[^/]+/([^/]+)/design\.md#\1#p')"
REL_WORKSET_DIR="$REL_FEATURE_DIR/$WORKSET_BASENAME"
TASKS_FILE="$REPO_ROOT/$REL_WORKSET_DIR/tasks.md"
PLAN_FILE="$REPO_ROOT/$REL_WORKSET_DIR/plan.md"

python3 "$REPO_ROOT/tools/community/validate_context_contract.py" <<EOF
{"repo_root":"$REPO_ROOT","trigger":"runtime-stop","changed_paths":["$REL_FEATURE_DIR/worklog.md","$REL_WORKSET_DIR/design.md","$REL_WORKSET_DIR/tasks.md","$REL_WORKSET_DIR/plan.md"],"runtime_context":{"tool_name":"Edit","cwd":"$CWD","active_skill":"writing-plans","session_id":"${SESSION_ID:-}"},"approval_context":{}}
EOF
python3 "$REPO_ROOT/tools/community/check_task_plan_consistency.py" \
  "$TASKS_FILE" "$PLAN_FILE" >/dev/null 2>&1 || add_failure "tasks/plan 映射校验失败"
```

4. [T2] 更新 `product` gate 与文档，让 managed full-chain feature 在 `/product` 阶段也走同一套 bootstrap/validator。

```bash
REL_FEATURE_DIR="$(printf '%s' "$TOOL_FILE_PATH" | sed -nE 's#^(docs/[^/]+)/.*#\1#p')"
FEATURE_OWNER="${FEATURE_OWNER:-feature-runtime-owner}"

python3 "$REPO_ROOT/tools/community/update_active_doc_scope.py" bootstrap \
  --registry "$REPO_ROOT/contracts/active-doc-scope.yaml" \
  --feature-path "$REL_FEATURE_DIR" \
  --mode full-chain \
  --layout phase-tree \
  --rollout-phase phase-1-pilot \
  --owner "$FEATURE_OWNER"
```

5. [T2] 更新 `shared/hooks/registry.json` 与 `render_hook_registry.py`，让这几个 gate 被渲染到 Claude/Codex runtime。

```json
{
  "skill": "brainstorming",
  "handler_rel": "skills/brainstorming/scripts/completion_check.sh",
  "timeout_sec": 15,
  "claude": { "supported": true, "event": "PostToolUse", "matcher": "Edit|Write" },
  "codex": { "supported": true }
}
```

6. [T2] 更新相关 SKILL 文档的输入输出、完成条件和流程导航，然后跑 runtime 与 full-chain 入口验证。

```bash
bash tests/test-runtime-integrity.sh
bash tests/test-chain-completeness.sh
bash tools/dev/validate-contracts.sh
```

### Task 3: 对齐 verify / closeout / archive 链路到新 small-chain 语义 [T3]

Files:
- Modify: `community/superpowers/skills/using-superpowers/SKILL.md`
- Modify: `community/superpowers/skills/verify-change/SKILL.md`
- Modify: `community/superpowers/skills/finishing-a-development-branch/SKILL.md`
- Modify: `community/superpowers/skills/archive/SKILL.md`
- Modify: `community/superpowers/skills/subagent-driven-development/SKILL.md`
- Modify: `contracts/small-chain.yaml`
- Modify: `tests/test-small-chain-boundary.sh`
- Modify: `tests/test-closeout-routing.sh`
- Modify: `tests/test-subagent-context-contract.sh`

1. [T3] 先写 RED 断言，把旧的 `CHANGELOG.md` 归档语义、缺失 `approval_ref` 的 branch-finalization 和只移动 change 子目录的说法全部变成失败条件。

```bash
assert_absent 'docs/\\{feature\\}/CHANGELOG\\.md' \
  "$ROOT/community/superpowers/skills/archive/SKILL.md"
assert_present 'docs/\\{feature\\}/worklog\\.md' \
  "$ROOT/community/superpowers/skills/verify-change/SKILL.md"
assert_present 'docs/archive/\\{feature\\}/' \
  "$ROOT/community/superpowers/skills/archive/SKILL.md"
assert_present 'approved_by / approved_at / approval_ref' \
  "$ROOT/community/superpowers/skills/finishing-a-development-branch/SKILL.md"
```

2. [T3] 更新 `verify-change`，让它先读 `worklog.md`，再按 `contracts/active-doc-scope.yaml` 解析当前 active workset，而不是假设只有一个 dated 目录。

```md
- Required artifacts:
  - `docs/{feature}/worklog.md`
  - `contracts/active-doc-scope.yaml`
  - `docs/{feature}/YYYY-MM-DD-{change}/design.md`
  - `docs/{feature}/YYYY-MM-DD-{change}/tasks.md`
  - `docs/{feature}/YYYY-MM-DD-{change}/plan.md`
  - 先运行 context validator，再运行 `scripts/check_task_plan_consistency.py`
```

3. [T3] 更新 `finishing-a-development-branch` 与 `contracts/small-chain.yaml`，让 `branch-finalization` 能承接无 `principal_id` 时的 owner acknowledgement。

```md
- `branch-finalization` must record: `approved_by`, `approved_at`, `approval_ref`
- `approval_ref` priority: PR review URL/ID > `branch-finalization#anchor`
```

4. [T3] 更新 `archive`、`using-superpowers`、`finishing-a-development-branch`、`subagent-driven-development`，统一到 feature-root archive 与 registry archive 写路径。

```md
- Archive source: `docs/{feature}/`
- Archive destination: `docs/archive/{feature}/`
- Required before archive: `change-verification` + `branch-finalization`
- Preserve: `worklog.md` + active workset + relative refs
```

5. [T3] 跑 closeout / boundary / subagent 回归，确认链路文字合同已经完全转到新语义。

```bash
bash tests/test-small-chain-boundary.sh
bash tests/test-closeout-routing.sh
bash tests/test-subagent-context-contract.sh
```

### Task 4: 收口 sync / install / runtime / regression 矩阵 [T4]

Files:
- Modify: `README.md`
- Modify: `tools/community/sync_canonical_from_upstream.py`
- Modify: `tests/run-all.sh`
- Modify: `tests/test-community-tools.sh`
- Modify: `tests/test-codex-skill-adapter.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Modify: `tests/test-small-chain-boundary.sh`

1. [T4] 先写 RED 断言，要求 upstream patch、本地 runtime 安装和 hooks 渲染都能看见 `worklog.md + dated workset` 约定。

```bash
grep -Fq 'docs/{feature}/worklog.md' "$ROOT/community/superpowers/skills/brainstorming/SKILL.md" \
  || fail "brainstorming skill 应暴露稳定入口路径"
grep -Fq 'skills/brainstorming/scripts/completion_check.sh' "$TMP_HOME/.codex/hooks.json" \
  || fail "codex runtime 应渲染 brainstorming gate"
```

2. [T4] 更新 `tools/community/sync_canonical_from_upstream.py` 的 local override，让它在 patch upstream superpowers 时同步修正 `brainstorming / writing-plans` 的新路径约定。

```python
text = replace_or_fail(
    text,
    "docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md",
    "docs/{feature}/YYYY-MM-DD-{change}/design.md",
    label="brainstorming design path",
)
if "docs/{feature}/worklog.md" not in text:
    text += "\n\n- Stable entry: `docs/{feature}/worklog.md`\n"
```

3. [T4] 更新 `README.md`、`tests/test-small-chain-boundary.sh` 与 `tests/run-all.sh`，让 README drift 和 repo-wide proving path 不再绕开新 contract。

```bash
grep -Fq 'contracts/active-doc-scope.yaml' "$ROOT/README.md" \
  || fail "README 必须显式声明 active scope registry"
grep -Fq 'test-active-doc-scope-lifecycle.sh' "$ROOT/tests/run-all.sh" \
  || fail "run-all 必须纳入 active scope 生命周期回归"
grep -Fq 'test-context-contract-audit.sh' "$ROOT/tests/run-all.sh" \
  || fail "run-all 必须纳入 report-only audit 回归"
```

4. [T4] 更新社区工具、runtime 安装与 codex adapter 回归测试，确保 hooks、skill 文档、registry helper 和 patch tool 都指向同一 contract。

```bash
bash tests/test-community-tools.sh
bash tests/test-runtime-integrity.sh
bash tests/test-codex-skill-adapter.sh
```

5. [T4] 跑最终 proving commands，确认 validator、planning gate、closeout 路由、audit 入口和 runtime 安装全部一起通过。

```bash
bash tests/test-context-contract-validator.sh
bash tests/test-active-doc-scope-lifecycle.sh
bash tests/test-context-contract-audit.sh
bash tests/test-chain-completeness.sh
bash tests/test-small-chain-boundary.sh
bash tests/test-closeout-routing.sh
bash tests/test-community-tools.sh
bash tests/test-runtime-integrity.sh
bash tests/test-codex-skill-adapter.sh
bash tests/test-subagent-context-contract.sh
bash tests/run-all.sh
bash tools/dev/validate-contracts.sh
```

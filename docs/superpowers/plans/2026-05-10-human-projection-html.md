# Human Projection HTML Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建确定性、可追踪来源的 `phase-human-review` HTML 审阅界面，覆盖产品、架构、测试、计划、交付五个角色。

**Architecture:** canonical JSON 继续作为唯一真源。先扩展 projection registry 和 manifest 契约，再把 role view-model 与 HTML renderer 拆成独立模块，最后迁移 validator、fixture、readiness、replay 和主链 Markdown projection 引用。

**Tech Stack:** Python 标准库、JSON Schema、Bash 契约测试、静态 HTML/CSS、现有 standard-chain validator/replay 工具链。

---

## 文件结构

- Create: `tools/community/human_projection_view_model.py`，从 canonical artifacts 构造角色 view-model。
- Create: `tools/community/human_projection_renderer.py`，从 view-model 渲染静态 HTML/CSS。
- Modify: `tools/community/materialize_canonical_html.py`，按 `view_id` 分发，并写入 registry 配置的输出路径。
- Modify: `tools/community/validate_projection_manifest.py`，校验 render metadata 和 registry digest。
- Modify: `shared/runtime/projection-views.json`，新增 `phase-human-review`。
- Modify: `shared/skills/delivery-owner/contracts/projection-manifest.schema.json` 和 template，要求 `projection_view_registry_digest` 与 section render metadata。
- Modify: `tools/community/normalize_canonical_artifact.py`、`replay_canonical_phase.py`、`validate_standard_chain_phase.py`、`validate_standard_chain_readiness.py`、catalog builder 和 catalog 默认路径，支持配置化 projection view 集合。
- Test: `tests/test-standard-chain-human-projection.sh`，锁定新人类审阅界面行为。
- Modify: 只在仍硬编码 `phase-operational` 的地方修改现有 projection/replay tests。
- Final cutover: 只有 HTML replacement 被测试证明后，才移除 active standard-chain Markdown projection 引用。

## Task 1: 契约红灯测试

**Files:**
- Create: `tests/test-standard-chain-human-projection.sh`
- Modify: `tests/run-all.sh`

- [ ] **Step 1: 新增失败测试**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

REGISTRY="$ROOT/shared/runtime/projection-views.json"
SCHEMA="$ROOT/shared/skills/delivery-owner/contracts/projection-manifest.schema.json"
TEMPLATE="$ROOT/shared/skills/delivery-owner/templates/projection-manifest.template.json"

jq -e '.views[] | select(.view_id == "phase-human-review")
  | .output_path == "docs/{feature}/phase-{N}/views/phase-human-review.html"
  and .manifest_path == "docs/{feature}/phase-{N}/views/phase-human-review.projection-manifest.json"
  and (.roles | map(.role_id) == ["product","architecture","test","plan","delivery"])' "$REGISTRY" >/dev/null \
  || fail "phase-human-review registry entry missing or invalid"

rg -n '"projection_view_registry_digest"|render_mode|structure_level|missing_fields|consumer_role' "$SCHEMA" "$TEMPLATE" >/dev/null \
  || fail "manifest contract must include registry digest and section render metadata"
```

- [ ] **Step 2: 运行并确认红灯**

Run: `bash tests/test-standard-chain-human-projection.sh`

Expected: FAIL，原因是 `phase-human-review` registry 和 manifest 字段还不存在。

- [ ] **Step 3: 加入总测试入口**

在 `tests/run-all.sh` 的 standard-chain 测试区域加入：

```bash
run_test tests/test-standard-chain-human-projection.sh
```

Expected: `bash tests/run-all.sh` 能跑到新测试，并在新契约断言处失败。

## Task 2: Registry 与 Manifest 契约

**Files:**
- Modify: `shared/runtime/projection-views.json`
- Modify: `shared/skills/delivery-owner/contracts/projection-manifest.schema.json`
- Modify: `shared/skills/delivery-owner/templates/projection-manifest.template.json`
- Modify: `tools/community/build_standard_chain_catalog.py`
- Modify: `shared/runtime/standard-chain-catalog.json`

- [ ] **Step 1: 注册 `phase-human-review`**

在 `shared/runtime/projection-views.json` 增加第二个 view：

```json
{
  "view_id": "phase-human-review",
  "output_path": "docs/{feature}/phase-{N}/views/phase-human-review.html",
  "manifest_path": "docs/{feature}/phase-{N}/views/phase-human-review.projection-manifest.json",
  "roles": [
    {"role_id": "product", "label": "产品"},
    {"role_id": "architecture", "label": "架构"},
    {"role_id": "test", "label": "测试"},
    {"role_id": "plan", "label": "计划"},
    {"role_id": "delivery", "label": "交付"}
  ]
}
```

- [ ] **Step 2: 扩展 manifest schema**

top-level 必须要求 `projection_view_registry_digest`。`section_source_map` 每行允许并校验 `render_mode`、`structure_level`、`missing_fields`、`consumer_role`。

- [ ] **Step 3: 更新 template 与 catalog**

template 示例改成 `phase-human-review`。catalog builder/default catalog 不再只能表达 `phase-operational.projection-manifest.json`，要能表达配置化 view manifest。

- [ ] **Step 4: 验证绿灯**

Run: `bash tests/test-standard-chain-human-projection.sh`

Expected: registry/schema/template 断言 PASS；renderer 断言在 Task 4 引入。

## Task 3: Human View-Model

**Files:**
- Create: `tools/community/human_projection_view_model.py`
- Modify: `tests/test-standard-chain-human-projection.sh`

- [ ] **Step 1: 增加 view-model 断言**

在测试里用 golden phase 调用 `build_human_projection_view_model(phase_dir, feature, phase_number)`。断言 roles 精确等于 `product`、`architecture`、`test`、`plan`、`delivery`；每个 role 都有 `critical_facts`、`sections`、`source_refs`；降级 section 必须含 `missing_fields`。

- [ ] **Step 2: 实现 view-model 模块**

创建公共函数 `build_human_projection_view_model(phase_dir, feature, phase_number)`、`role_status(role)`、`source_entry(ref, pointer)`。只读取已有 JSON artifact；runtime artifact 缺失时输出 missing-data section，不抛无意义空白页。

- [ ] **Step 3: 验证**

Run: `bash tests/test-standard-chain-human-projection.sh`

Expected: view-model shape 与 degraded-state 断言 PASS。

## Task 4: Human HTML Renderer

**Files:**
- Create: `tools/community/human_projection_renderer.py`
- Modify: `tools/community/materialize_canonical_html.py`
- Modify: `tests/test-standard-chain-human-projection.sh`

- [ ] **Step 1: 增加 renderer 断言**

扩展测试，运行：

```bash
python3 "$ROOT/tools/community/materialize_canonical_html.py" \
  --phase-dir "$PHASE_DIR" \
  --view-id phase-human-review
```

断言生成 HTML 含角色导航标签、没有把 raw JSON `<pre>` 当主体、含关键事实 section、含 `data-source-ref`，并会 escape 不可信值。

- [ ] **Step 2: 实现静态 renderer**

渲染这些语义组件：role rail、`ArtifactStatusStrip`、`CriticalFacts`、`DiagramPanel`、`TraceMatrix`、`MissingDataCard`、`DegradedViewNotice`、source badges。CSS 内嵌到 HTML，保证文件可独立打开。

- [ ] **Step 3: 按 `view_id` 分发**

保留 `phase-operational` 兼容行为。`phase-human-review` 调用新 view-model 和 renderer，并按 registry 写入 HTML 与 manifest 路径。

- [ ] **Step 4: 验证**

Run:

```bash
bash tests/test-standard-chain-human-projection.sh
bash tests/test-standard-chain-projection-replay.sh
```

Expected: human view 测试 PASS，legacy projection replay 仍 PASS。

## Task 5: Manifest Validation 与 Replay

**Files:**
- Modify: `tools/community/validate_projection_manifest.py`
- Modify: `tools/community/normalize_canonical_artifact.py`
- Modify: `tools/community/replay_canonical_phase.py`
- Modify: `tools/community/validate_standard_chain_phase.py`
- Modify: `tools/community/validate_standard_chain_readiness.py`
- Modify: `tests/test-standard-chain-projection-replay.sh`

- [ ] **Step 1: 增加 drift 负例**

新增缺失 `projection_view_registry_digest`、registry digest 改变、非法 `render_mode`、空 `consumer_role`、degraded section 缺 `missing_fields` 的负例。

- [ ] **Step 2: 更新 validators**

validators 改为遍历配置化 projection views。兼容期继续接受 `phase-operational`，但人类审阅 readiness 必须要求 `phase-human-review`。

- [ ] **Step 3: 更新 replay scenario**

projection manifests 用 `view_id` keyed set 表达，同时保留 legacy oracle 字段直到 fixture 迁移完成。

- [ ] **Step 4: 验证**

Run:

```bash
bash tests/test-standard-chain-projection-replay.sh
bash tests/test-standard-chain-validator-stack.sh
```

Expected: 正向 fixture PASS；每个 drift 负例都以明确 projection error FAIL。

## Task 6: Golden Fixtures

**Files:**
- Modify: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/views/*`
- Modify: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/replay/*`
- Modify: 需要 readiness 的 pilot fixture views。

- [ ] **Step 1: 生成 human projection fixture**

对 golden pilot phase 运行 `materialize_canonical_html.py --view-id phase-human-review`，写入 `phase-human-review.html` 和 manifest。

- [ ] **Step 2: 重新生成 replay oracle**

manifest-set 支持落地后，重新生成 replay oracle。

- [ ] **Step 3: 验证 readiness**

Run:

```bash
bash tests/test-standard-chain-validator-stack.sh
bash tests/test-standard-chain-projection-replay.sh
bash tests/test-standard-chain-login-homepage-pilot.sh
bash tests/test-standard-chain-feedback-thanks-pilot.sh
```

Expected: fixture-backed projection 与 replay gates 全部 PASS。

## Task 7: 主链 Markdown Projection Cutover

**Files:**
- Modify: 引用 active human Markdown projection 的 standard-chain skill files。
- Modify: 断言 active `projections/*.md` 使用的 tests。
- Delete: 只删除已被 `phase-human-review` 完整替代的 Markdown projection templates。

- [ ] **Step 1: 增加 cutover guard**

新增测试：HTML replacement 之后，product-manager、design、test-design、tech-lead、delivery-owner、review、verify、QA、consistency-audit、fix 的 standard-chain 指令不得再要求 active Markdown projection templates。

- [ ] **Step 2: 更新指令**

人类展示统一指向 `phase-human-review.html` 和 canonical JSON。research、overview、UX、refactor 等非 standard-chain projection templates 不动。

- [ ] **Step 3: 删除已替代模板**

只删除职责被完整替代且测试覆盖的路径。不得按目录名批量删除 `projections/`。

- [ ] **Step 4: 全面验证**

Run:

```bash
bash tests/run-all.sh
```

Expected: 没有 active standard-chain contract 消费已删除 Markdown projection 路径；HTML projection tests 与 validator stack PASS。

## Self-Review

Spec coverage: registry identity、manifest digest、role layout、五个角色页、degraded diagrams、禁止 HTML 编辑、Markdown cutover 都被 Task 1-7 覆盖。

空泛项检查：计划包含精确文件、命令、预期失败、切换门槛。

Type consistency: `phase-human-review`、`projection_view_registry_digest`、`render_mode`、`structure_level`、`missing_fields`、`consumer_role` 在 registry、manifest、renderer、validator、tests 中一致。

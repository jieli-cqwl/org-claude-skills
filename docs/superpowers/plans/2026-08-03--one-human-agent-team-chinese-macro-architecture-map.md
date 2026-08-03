# One-Human + Agent Team Chinese Macro Architecture Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and obtain human acceptance for one professional, Chinese, desktop-readable macro architecture map that faithfully projects the approved `L0-R3` one-human-plus-Agent-Team operating architecture without introducing Owner, Skill, runtime, or project-specific detail.

**Architecture:** Keep the approved `L0-R3` Markdown specification as the only semantic source of truth. Create one hand-authored semantic SVG as the sole editable visual projection and one adjacent PNG as a byte-derived review format; do not reuse Graphviz layout or the rejected R4 visual suite. Stable `data-*` markers and one standard-library Python test protect the organization/lifecycle ontology, role ownership, deployment boundaries, cross-cutting assurance, and forbidden-detail boundary without turning the test into a second prose specification.

**Tech Stack:** SVG 2, Chinese system fonts, Python 3 standard-library `unittest` and `xml.etree.ElementTree`, librsvg `rsvg-convert` 2.60-compatible rendering, ImageMagick 7 inspection, `xmllint`, repository gate-plan runner.

## Global Constraints

- Normative semantic source: `docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md`, approved as `L0-R3` on 2026-08-03.
- The visual is one navigation map, not a second architecture specification.
- Show one Human Governance Layer, one provider-replaceable Agent Team, five professional delivery stages, two human-controlled deployment boundaries, one shared coordination and assurance foundation, and one generic accountable return and safe-stop law.
- The five stages are lifecycle boundaries, not five Teams or five independently invocable runtime units.
- Stage Result Integrators own consistency, decision-view assembly, and route preparation; they cannot waive or overwrite a specialist Professional Owner conclusion.
- Product Definition is an iterative convergence loop. `Product Director → Product Manager → Impact Owner` must not look like a one-pass waterfall.
- Target behavior, preserved behavior, and forbidden behavior must remain visibly connected to proof design, implementation, independent quality, and production verification.
- `UX Owner` and `Architecture Owner` are conditional roles.
- Professional Owner and Executor role types must be visibly different. `Delivery Assurance Owner` is cross-cutting and must not look like the product `Quality Owner` or a sixth delivery stage.
- The human co-creates, authorizes, triggers, executes prepared deployment actions, performs business acceptance, and records final Phase/Demand dispositions. The human does not coordinate Executors, assemble context, audit every professional result, or diagnose technical failures.
- The final stage must keep production verification, business acceptance, Product Director recommendation, and Human Phase/Demand disposition as four separate facts.
- Show the exact target-status text: `M0 manual learning mode · not runtime-active`.
- Do not show flow IDs, route IDs, schemas, state machines, detailed finding types, Task Packets, retry counts, incident subflows, automation mechanics, or the `qft-tenants` solution.
- Do not encode detailed Owner procedures, Skill prompts, field names, provider behavior, deployment commands, activation checklists, or runtime orchestration.
- The existing `2026-07-30` R4 DOT/SVG/PNG suite remains untouched historical evidence. Its layout, labels, IDs, and four-view scope are not implementation inputs.
- Use the current branch as the user requested. Do not create a worktree.
- Execution prerequisite: this implementation-plan file itself must be committed in a dedicated planning commit and `git status --short` must be empty before Task 1 starts. Do not weaken the clean-worktree guards in Tasks 2–3 to accommodate an untracked plan.

---

## Scope and Existing-Path Decision

### Capability owner

The approved `L0-R3` specification owns architecture semantics. The new SVG owns only the accepted human projection; its PNG owns nothing and is regenerated from the SVG.

### Existing-path reuse

Do not extend the old asset directory. Its own README says the R4 suite failed human acceptance, depends on superseded V1.2 semantics, and must not be used as the next visual input. Reusing that directory would blur historical and current authority.

### New-path exception

Create one date- and baseline-specific asset directory because no current accepted visual path exists:

```text
docs/superpowers/specs/assets/
  2026-08-03--one-human-agent-team-operating-architecture-l0/
    README.md
    one-human-agent-team-architecture-map.svg
    one-human-agent-team-architecture-map.png
```

The old DOT/SVG/PNG assets remain recoverable and byte-identical; only their README historical pointer may be updated after approval. The new map never becomes an independent semantic or authorization source: after explicit human semantic and visual approval in Task 3 it becomes the accepted, non-normative navigation projection of the still-sole-authoritative `L0-R3` specification.

## File Structure

### Create

- `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/README.md` — projection provenance, editable/derived relationship, render command, renderer version, and acceptance status only; it must not restate the architecture.
- `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg` — sole editable visual projection with Chinese visible copy and stable semantic markers.
- `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png` — 1920×1200 review render derived from the SVG.
- `tests/test-one-human-agent-team-architecture-map.py` — structural, ontology, forbidden-detail, self-containment, and PNG-dimension checks.

### Modify during candidate construction

- `tests/gate-plan.json` — register the map contract under area `docs`, tier `full`; the `docs-context` profile still runs it directly without increasing the already-over-budget quick suite.
- `tests/run-all.sh` — include the new Python test in syntax compilation.

### Modify only after explicit human map approval

- `docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md` — record accepted visual status and link/embed the map without changing `L0-R3` semantics.
- `docs/product-dirrctor-session.md` — replace the now-stale “planning only” continuation pointer with the accepted map and next allowed stage.
- `docs/superpowers/plans/2026-07-30--one-human-agent-operating-architecture-visual-redesign.md` — point its historical warning to the accepted replacement.
- `docs/superpowers/specs/2026-07-30--one-human-agent-operating-architecture-visual-redesign--design.md` — point its rejected-design warning to the accepted replacement.
- `docs/superpowers/specs/2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md` — keep V1.2 superseded while replacing the stale “planning only” sentence.
- `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/README.md` — point historical readers to the accepted replacement.

Do not modify `docs/superpowers/specs/2026-07-30--product-director-decision-case--design.md` in this visual scope. Its realignment block remains accurate and it already reaches the sole canonical baseline; only the later Product Director realignment may change that dynamic status.

## Projection Contract

### Fixed canvas and visual grammar

Use `viewBox="0 0 1920 1200"`, `width="1920"`, and `height="1200"`. The composition has one dominant top-to-bottom layer hierarchy and one dominant left-to-right delivery path:

| Region | Coordinates | Meaning |
|---|---:|---|
| Header | `x=60, y=36, w=1800, h=66` | title, one-line operating proposition, target-status badge |
| Human Governance Layer | `x=60, y=118, w=1800, h=164` | consequential human authority and explicit non-responsibilities |
| One Agent Team | `x=60, y=302, w=1800, h=592` | five delivery-stage cards and the two deployment boundaries |
| Shared Foundation | `x=60, y=914, w=1800, h=202` | recoverable control, minimum-sufficient context, isolation, Delivery Assurance |
| Return / Stop Law | `x=60, y=1134, w=1800, h=46` | one generic accountable return and safe-stop rule |

Use five stage cards at `x=130, 472, 814, 1156, 1498`, each with `y=378`, `w=292`, and `h=438`. The 50-pixel gaps carry forward arrows; the gaps between Stages 3–4 and 4–5 also carry the test- and production-deployment boundary markers. The stage cards are siblings inside one `data-kind="agent-team"` group.

Draw the test-deployment gate line at `x=1131` and the production-deployment gate line at `x=1473`. Anchor their three-line callouts above the card row at `x=1001, y=310, w=260, h=60` and `x=1343, y=310, w=260, h=60`; the vertical gate line remains in the inter-stage gap so neither callout can be mistaken for a sixth stage.

Use a flat architecture-diagram grammar, not a poster or dashboard:

| Semantic type | Fill | Border / text | Non-color marker |
|---|---|---|---|
| Human Governance | `#FFF6DC` | `#9A6700` | `人` badge and solid top rail |
| Agent Team container | `#F7FAFF` | `#173B63` | explicit `一个 Agent Team` title |
| Delivery stage | `#FFFFFF` | `#B7C5D8` | stage number `01`–`05` |
| Stage Result Integrator | `#E8F1FF` | `#1E5AA8` | `阶段整合者` label |
| Specialist Professional Owner | `#EAF7F5` | `#0F766E` | `专业 Owner` label |
| Executor | `#F0F2F5` | `#596579` | `执行者` label |
| Conditional Owner | `#F5F1FF` | `#6D5BD0` | dashed border and `按需` label |
| Human deployment boundary | `#FFF0CC` | `#B7791F` | gate line plus `人工部署边界` label |
| Shared foundation | `#F4F0FF` | `#6750A4` | bottom cross-cutting band |
| Return / safe stop | `#FFF1F0` | `#B42318` | explicit return arrow and stop marker |

Use `Hiragino Sans GB, PingFang SC, Noto Sans CJK SC, Microsoft YaHei, sans-serif`. The recorded PNG must be rendered where `fc-match 'Hiragino Sans GB'` resolves to `Hiragino Sans GB`; the committed SVG keeps the remaining fallbacks for other viewers. Title is 38–42 px, layer titles 22–24 px, stage titles 19–21 px, body text 16–17 px, and status/legend text no smaller than 14 px. Use no remote fonts, images, JavaScript, gradients, 3-D decoration, or paragraph-sized labels.

### Exact visible-copy map

Visible prose is Chinese. Canonical English role names remain visible beside short Chinese responsibility labels to preserve unambiguous role identity.

#### Header

- Title: `一人 + Agent Team 架构`
- Proposition: `人掌握关键决策与外部动作，Agent Team 承担专业交付与责任闭环`
- Status badge: `M0 manual learning mode · not runtime-active`

#### Human Governance Layer

- Layer title: `人类治理层｜业务最终责任与关键行动`
- Cell 1: `共创与裁决` / `产品方向 · 重大架构取舍 · 价值与约束`
- Cell 2: `授权与触发` / `审阅决策视图 · 授权推荐路线 · M0 手动触发下一 Owner`
- Cell 3: `部署控制` / `授权、执行并如实记录已准备的测试 / 生产部署动作`
- Cell 4: `业务终局` / `业务验收 · Phase / Demand 最终处置`
- Transition strip: `专业 Owner GO → 阶段整合者推荐下一 Owner 并准备视图 → 人工 AUTHORIZE / 触发 → 接收方 ACCEPT`
- Negative boundary: `人不负责任务编排、上下文拼装、专业审计或技术归因`

#### One Agent Team header

- `一个可替换的 Agent Team｜5 个专业交付阶段（不是 5 个 Team）`
- Accountability badge: `阶段整合者负责一致性与路线；不得覆盖专业 Owner 结论`
- Legend items: `阶段整合者`, `专业 Owner`, `执行者`, `按需 Owner`, `人工部署边界`

#### Stage cards

| Stage | Purpose | Integrator | Professional Owners / Executors | Stage result |
|---|---|---|---|---|
| `01 产品定义收敛` | `从模糊需求收敛出值得做、可验收、影响可解释且保护存量行为的产品定义` | `Product Director｜产品定义整合` | `Product Manager｜业务流程与产品行为`; `Impact Owner｜影响与保留义务`; `UX Owner｜按需`; `Architecture Owner｜按需`; `目标行为 · 保留行为 · 禁止副作用` | `产品定义就绪` |
| `02 验证与计划` | `把每项产品义务转成证明方案，以及可实施、可部署、可观测、可恢复的计划` | `Tech Lead｜验证与计划整合` | `Test Design Owner｜先定义证明义务 → Tech Lead｜再形成实施与部署计划` | `验证与计划就绪` |
| `03 开发交付` | `TDD 实施，并由隔离上下文完成验证与评审，固定精确发布身份` | `Development Owner｜开发交付整合` | `Developer`; `Verifier`; `Code Reviewer`; `修复能力｜开发域内` | `可提测发布身份 + 开发证据` |
| `04 独立质量验收` | `对测试环境中的精确发布身份做独立质量判断；Quality 不修改代码` | `Quality Owner｜质量验收整合` | `QA Executor`; `缺陷回到具体责任 Owner` | `可发布身份 + 独立质量结论` |
| `05 生产验证与产品阶段决策` | `验证线上精确身份，并对真实业务结果作诚实处置` | `Product Director｜产品收口整合` | four separate fact cells defined below | `真实生产结果 + 产品阶段决策` |

Stage 1 contains a visible loop labelled:

```text
Product Director ↔ Product Manager ↔ Impact Owner
              ↕ 按需 UX / Architecture
```

Do not render that relation as four serial forward arrows.

Across the lower edge of the five stage cards, show one compact obligation trace:

```text
目标行为 · 保留行为 · 禁止副作用 → 证明设计 → 实施与独立验证 → 独立质量 → 生产验证
```

This is a trace relationship, not a sixth workflow lane or an artifact schema.

Stage 5 contains four separate, equally weighted cells:

1. `Quality Owner｜生产验证事实`
2. `Human｜业务验收`
3. `Product Director｜收口建议`
4. `Human｜Phase / Demand 最终处置`

Do not merge the four cells into a generic `GO`, `上线成功`, or `需求完成` box.

#### Deployment boundaries

- Between Stages 3 and 4: `人工测试部署边界` / `Quality 核验实际身份` / `失败 / 部分 / 错版 / 未知 → 停止`
- Between Stages 4 and 5: `人工生产部署边界` / `部署 ≠ 生产验证 ≠ 业务成功` / `失败 / 部分 / 错版 / 未知 → 停止`

#### Shared Coordination and Assurance Foundation

- Foundation title: `共享协调与保障底座｜不是第六阶段`
- Block 1: `交付控制记录` / `当前阶段与 Owner · 权威版本 · 发布身份 · 证据有效性 · 阻塞 · 回流目标 · 待人工动作`
- Block 2: `最小充分上下文` / `Owner 权威成果 → 接收方视图 → 人类决策视图 → 接收校验`
- Block 3: `权限与独立性` / `最小权限 · 敏感信息隔离 · 独立角色使用新上下文`
- Block 4: `Delivery Assurance Owner｜Agent Team 横向交付保障` / `独立检查路由、状态连续性、上下文、权限、追踪与安全停止；不同于 Quality Owner，不属于五阶段`

#### Generic return and stop law

```text
保留证据 → 最早的具体责任 Owner 接责 → 修正后由原独立方复验
无新证据 / 责任不明 / 必需证据不可用 → 安全停止并升级；非 GO、待观察或未知不得伪装成功
```

## Machine-Readable SVG Contract

Use the following stable markers. They are projection structure, not runtime IDs and are not visible on the map.

| Element | Required markers |
|---|---|
| root | `data-architecture="one-human-agent-team"`, `data-baseline="L0-R3"`, `data-status="m0-manual-not-runtime-active"`; after the first render, `data-png-sha256` contains the exact 64-character SHA-256 of the adjacent PNG |
| header | `data-concept="map-header"`; it owns the visible title, operating proposition, and exact M0 status text so status cannot be satisfied from `<defs>` or hidden metadata |
| human band | `data-concept="human-governance"`, `data-kind="governance-layer"`; its exact region rect uses `data-visual="human-governance-layer"` |
| Human action groups | `data-concept="human-co-creation|human-route-authorization|human-deployment-control|human-business-disposition|human-non-responsibilities"` |
| forward-control strip | parent `data-concept="forward-control-law"`; visible children `forward-producer-go`, `forward-integrator-route`, `forward-human-authorize`, `forward-recipient-accept` with `data-order="1..4"`; each child rect uses `data-visual="forward-fact"` and increasing `x` |
| Agent Team band | `data-concept="agent-team"`, `data-kind="agent-team"`; its exact region rect uses `data-visual="agent-team-container"` |
| stages | `data-concept="stage-product-definition|stage-verification-planning|stage-development-delivery|stage-independent-quality|stage-production-closeout"`, `data-kind="delivery-stage"`, `data-order="1..5"`, exact `data-integrator`; each exact card rect uses `data-visual="stage-card"` |
| convergence loop | `data-concept="product-definition-convergence"`, `data-flow="iterative"`; it contains one visible non-zero path with `data-relation="reopen-forward"` and one oppositely directed, vertically separated visible non-zero path with `data-relation="reopen-return"` |
| proof-before-plan | `data-concept="proof-before-implementation-plan"` inside Stage 2 |
| role groups | `data-role-id`, `data-role-type="professional-owner|executor"`; conditional roles also use `data-activation="conditional"` |
| no-overwrite rule | `data-concept="specialist-accountability-rule"` |
| obligation trace | `data-concept="behavior-obligation-trace"` |
| deployment gates | `data-concept="test-deployment|production-deployment"`, `data-kind="deployment-boundary"`, `data-controlled-by="human"`, `data-between="3-4|4-5"`; gate line uses `data-visual="deployment-gate"` and callout rect uses `data-visual="deployment-callout"` |
| foundation | `data-concept="shared-foundation"`, `data-kind="cross-cutting-foundation"`, exact region rect `data-visual="shared-foundation-layer"`; visible child groups are `delivery-control-record`, `minimum-sufficient-context`, `permission-context-isolation`, and `agent-workflow-evaluation` |
| assurance | `data-role-id="delivery-assurance-owner"`, `data-placement="cross-cutting"`, `data-team-membership="agent-team"` |
| return/stop | `data-concept="accountable-return-safe-stop"`, `data-kind="return-stop-law"`, exact region rect `data-visual="return-stop-layer"`; visible ordered children are `return-finding-custody`, `return-earliest-owner`, `return-corrective-accept`, `return-independent-reverify`, and `return-safe-stop`, each with an increasing `data-visual="return-fact"` rect |
| final facts | `data-concept="production-verification|business-acceptance|product-director-recommendation|phase-demand-disposition"` with exact `data-owner="quality-owner|human|product-director|human"` respectively; each has a distinct `data-visual="final-fact"` rect |

The implementation test treats the concept and kind manifests as closed sets: no unlisted `data-concept`, extra governance layer, extra Agent Team, third deployment boundary, sixth delivery stage, or ad-hoc coordinator is permitted. Every semantic group must contain its own minimum canonical visible wording, not merely an arbitrary descendant `<text>`. All required `<text>` nodes use explicit numeric `x`, `y`, and `font-size` (minimum 14) plus an explicit visible `fill`; all required semantic drawables use explicit visible paint. This deliberately keeps the static oracle deterministic. Same-canvas occlusion and higher-order visual ambiguity remain independent raster, fresh-context, cold-reader, and owner-approval gates in Task 2.

---

### Task 1: Build the Semantic SVG Candidate and Regression Gate

**Files:**

- Create: `tests/test-one-human-agent-team-architecture-map.py`
- Create: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/README.md`
- Create: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg`
- Create: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png`
- Modify: `tests/gate-plan.json`
- Modify: `tests/run-all.sh`

**Interfaces:**

- Consumes: the approved `L0-R3` source and the fixed Projection Contract above.
- Produces: one structurally valid map candidate, one derived PNG, and a gate that rejects ontology drift or forbidden implementation detail.

- [ ] **Step 0: Prove the committed-plan prerequisite and freeze the historical-asset baseline**

Run before any Task 1 edit:

```bash
set -euo pipefail
MAP_PLAN="docs/superpowers/plans/2026-08-03--one-human-agent-team-chinese-macro-architecture-map.md"
OLD_ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
git ls-files --error-unmatch "$MAP_PLAN" >/dev/null
test -z "$(git status --short)"
MAP_PRE_MAP_COMMIT="$(git rev-parse HEAD)"
test "$(git ls-tree -r "$MAP_PRE_MAP_COMMIT" -- "$OLD_ASSET_DIR" | awk '$4 ~ /\.(dot|svg|png)$/ {count++} END {print count+0}')" = "12"
printf 'PRE_MAP_COMMIT=%s\n' "$MAP_PRE_MAP_COMMIT"
```

Expected: the plan is tracked, the worktree is clean, exactly 12 historical R4 DOT/SVG/PNG blobs exist at the pre-map commit, and one full 40-character commit is printed. Copy that literal commit into the draft asset README in Step 4; it is the immutable comparison base used in Task 3.

- [ ] **Step 1: Add the structural regression test**

Create `tests/test-one-human-agent-team-architecture-map.py` with this complete test contract:

```python
from __future__ import annotations

import binascii
import hashlib
import re
import struct
import unittest
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = (
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "assets"
    / "2026-08-03--one-human-agent-team-operating-architecture-l0"
)
SVG_PATH = ASSET_DIR / "one-human-agent-team-architecture-map.svg"
PNG_PATH = ASSET_DIR / "one-human-agent-team-architecture-map.png"
README_PATH = ASSET_DIR / "README.md"
CANONICAL_SPEC = (
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "2026-08-03--one-human-agent-team-operating-architecture-l0--design.md"
)
CANONICAL_POINTERS = (
    ROOT / "docs" / "product-dirrctor-session.md",
    ROOT
    / "docs"
    / "superpowers"
    / "plans"
    / "2026-07-30--one-human-agent-operating-architecture-visual-redesign.md",
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "2026-07-30--one-human-agent-operating-architecture-visual-redesign--design.md",
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md",
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "2026-07-30--product-director-decision-case--design.md",
    ROOT
    / "docs"
    / "superpowers"
    / "specs"
    / "assets"
    / "2026-07-30--one-human-agent-team-operating-architecture-v1.2"
    / "README.md",
)

STAGES = (
    ("stage-product-definition", "1", "product-director", 130.0),
    ("stage-verification-planning", "2", "tech-lead", 472.0),
    ("stage-development-delivery", "3", "development-owner", 814.0),
    ("stage-independent-quality", "4", "quality-owner", 1156.0),
    ("stage-production-closeout", "5", "product-director", 1498.0),
)
LAYER_GEOMETRY = {
    "human-governance": ("governance-layer", "human-governance-layer", (60.0, 118.0, 1800.0, 164.0)),
    "agent-team": ("agent-team", "agent-team-container", (60.0, 302.0, 1800.0, 592.0)),
    "shared-foundation": (
        "cross-cutting-foundation",
        "shared-foundation-layer",
        (60.0, 914.0, 1800.0, 202.0),
    ),
    "accountable-return-safe-stop": (
        "return-stop-law",
        "return-stop-layer",
        (60.0, 1134.0, 1800.0, 46.0),
    ),
}
GATES = (
    ("test-deployment", "3-4", 1131.0, 1001.0),
    ("production-deployment", "4-5", 1473.0, 1343.0),
)
PROFESSIONAL_OWNERS = {
    "product-director",
    "product-manager",
    "impact-owner",
    "ux-owner",
    "architecture-owner",
    "test-design-owner",
    "tech-lead",
    "development-owner",
    "quality-owner",
    "delivery-assurance-owner",
}
EXECUTORS = {
    "developer",
    "verifier",
    "code-reviewer",
    "repair-capability",
    "qa-executor",
}
ROLE_STAGE_REQUIREMENTS = {
    "product-director": {"stage-product-definition", "stage-production-closeout"},
    "product-manager": {"stage-product-definition"},
    "impact-owner": {"stage-product-definition"},
    "ux-owner": {"stage-product-definition"},
    "architecture-owner": {"stage-product-definition"},
    "test-design-owner": {"stage-verification-planning"},
    "tech-lead": {"stage-verification-planning"},
    "development-owner": {"stage-development-delivery"},
    "developer": {"stage-development-delivery"},
    "verifier": {"stage-development-delivery"},
    "code-reviewer": {"stage-development-delivery"},
    "repair-capability": {"stage-development-delivery"},
    "quality-owner": {"stage-independent-quality", "stage-production-closeout"},
    "qa-executor": {"stage-independent-quality"},
}
FINAL_FACTS = {
    "production-verification": "quality-owner",
    "business-acceptance": "human",
    "product-director-recommendation": "product-director",
    "phase-demand-disposition": "human",
}
HUMAN_ACTIONS = {
    "human-co-creation",
    "human-route-authorization",
    "human-deployment-control",
    "human-business-disposition",
    "human-non-responsibilities",
}
FORWARD_FACTS = (
    ("forward-producer-go", "1"),
    ("forward-integrator-route", "2"),
    ("forward-human-authorize", "3"),
    ("forward-recipient-accept", "4"),
)
FOUNDATION_FACTS = {
    "delivery-control-record",
    "minimum-sufficient-context",
    "permission-context-isolation",
    "agent-workflow-evaluation",
}
RETURN_FACTS = (
    ("return-finding-custody", "1"),
    ("return-earliest-owner", "2"),
    ("return-corrective-accept", "3"),
    ("return-independent-reverify", "4"),
    ("return-safe-stop", "5"),
)
CONCEPT_VISIBLE_TOKENS = {
    "map-header": (
        "一人 + Agent Team 架构",
        "人掌握关键决策与外部动作",
        "M0 manual learning mode · not runtime-active",
    ),
    "human-governance": ("人类治理层", "业务最终责任与关键行动"),
    "human-co-creation": ("共创与裁决", "产品方向", "重大架构取舍"),
    "human-route-authorization": ("授权与触发", "审阅决策视图", "手动触发下一 Owner"),
    "human-deployment-control": ("部署控制", "授权、执行并如实记录", "测试 / 生产部署动作"),
    "human-business-disposition": ("业务终局", "业务验收", "Phase / Demand 最终处置"),
    "human-non-responsibilities": ("人不负责任务编排", "上下文拼装", "技术归因"),
    "forward-control-law": ("专业 Owner GO", "阶段整合者推荐下一 Owner", "接收方 ACCEPT"),
    "forward-producer-go": ("专业 Owner GO",),
    "forward-integrator-route": ("阶段整合者推荐下一 Owner", "准备视图"),
    "forward-human-authorize": ("人工 AUTHORIZE / 触发",),
    "forward-recipient-accept": ("接收方 ACCEPT",),
    "agent-team": ("一个可替换的 Agent Team", "5 个专业交付阶段", "不是 5 个 Team"),
    "stage-product-definition": ("01 产品定义收敛", "从模糊需求收敛", "产品定义就绪"),
    "stage-verification-planning": ("02 验证与计划", "证明方案", "验证与计划就绪"),
    "stage-development-delivery": ("03 开发交付", "TDD 实施", "可提测发布身份"),
    "stage-independent-quality": ("04 独立质量验收", "Quality 不修改代码", "独立质量结论"),
    "stage-production-closeout": ("05 生产验证与产品阶段决策", "真实业务结果", "产品阶段决策"),
    "product-definition-convergence": (
        "Product Director ↔ Product Manager ↔ Impact Owner",
        "按需 UX / Architecture",
    ),
    "proof-before-implementation-plan": ("先定义证明义务", "再形成实施与部署计划"),
    "specialist-accountability-rule": ("不得覆盖专业 Owner 结论",),
    "behavior-obligation-trace": (
        "目标行为 · 保留行为 · 禁止副作用",
        "证明设计",
        "独立质量",
        "生产验证",
    ),
    "test-deployment": ("人工测试部署边界", "Quality 核验实际身份", "未知 → 停止"),
    "production-deployment": ("人工生产部署边界", "部署 ≠ 生产验证 ≠ 业务成功", "未知 → 停止"),
    "shared-foundation": ("共享协调与保障底座", "不是第六阶段"),
    "delivery-control-record": ("交付控制记录", "当前阶段与 Owner", "证据有效性", "回流目标"),
    "minimum-sufficient-context": ("最小充分上下文", "Owner 权威成果", "接收方视图", "接收校验"),
    "permission-context-isolation": ("权限与独立性", "最小权限", "独立角色使用新上下文"),
    "agent-workflow-evaluation": ("Delivery Assurance Owner", "独立检查路由", "安全停止"),
    "accountable-return-safe-stop": ("最早的具体责任 Owner 接责", "安全停止并升级", "不得伪装成功"),
    "return-finding-custody": ("保留证据",),
    "return-earliest-owner": ("最早的具体责任 Owner 接责",),
    "return-corrective-accept": ("修正后",),
    "return-independent-reverify": ("原独立方复验",),
    "return-safe-stop": ("安全停止并升级", "不得伪装成功"),
    "production-verification": ("Quality Owner", "生产验证事实"),
    "business-acceptance": ("Human", "业务验收"),
    "product-director-recommendation": ("Product Director", "收口建议"),
    "phase-demand-disposition": ("Human", "Phase / Demand 最终处置"),
}
KIND_MANIFEST = {
    "governance-layer": {"human-governance"},
    "agent-team": {"agent-team"},
    "delivery-stage": {concept for concept, _, _, _ in STAGES},
    "deployment-boundary": {name for name, _, _, _ in GATES},
    "cross-cutting-foundation": {"shared-foundation"},
    "return-stop-law": {"accountable-return-safe-stop"},
}
ROLE_INSTANCE_VISIBLE_TOKENS = {
    ("product-director", "stage-product-definition"): ("Product Director", "产品定义整合"),
    ("product-director", "stage-production-closeout"): ("Product Director", "产品收口整合"),
    ("product-manager", "stage-product-definition"): ("Product Manager", "业务流程与产品行为"),
    ("impact-owner", "stage-product-definition"): ("Impact Owner", "影响与保留义务"),
    ("ux-owner", "stage-product-definition"): ("UX Owner", "按需"),
    ("architecture-owner", "stage-product-definition"): ("Architecture Owner", "按需"),
    ("test-design-owner", "stage-verification-planning"): ("Test Design Owner", "先定义证明义务"),
    ("tech-lead", "stage-verification-planning"): ("Tech Lead", "验证与计划整合"),
    ("development-owner", "stage-development-delivery"): ("Development Owner", "开发交付整合"),
    ("developer", "stage-development-delivery"): ("Developer",),
    ("verifier", "stage-development-delivery"): ("Verifier",),
    ("code-reviewer", "stage-development-delivery"): ("Code Reviewer",),
    ("repair-capability", "stage-development-delivery"): ("修复能力", "开发域内"),
    ("quality-owner", "stage-independent-quality"): ("Quality Owner", "质量验收整合"),
    ("quality-owner", "stage-production-closeout"): ("Quality Owner", "生产验证事实"),
    ("qa-executor", "stage-independent-quality"): ("QA Executor",),
    ("delivery-assurance-owner", None): ("Delivery Assurance Owner", "横向交付保障"),
}
FORBIDDEN_VISIBLE_PATTERNS = (
    re.compile(r"\b(?:F|R|IR)[-_]?\d+\b", re.IGNORECASE),
    re.compile(r"\b(?:flow|route)[-_ ]?(?:id|\d+|[A-Z])\b", re.IGNORECASE),
)
FORBIDDEN_CANONICAL_PATTERNS = (
    re.compile(r"(?:f|r|ir)\d+", re.IGNORECASE),
    re.compile(r"(?:flow|route)id", re.IGNORECASE),
)
FORBIDDEN_CANONICAL_FRAGMENTS = {
    "taskpacket",
    "schema",
    "statemachine",
    "findingtype",
    "retry",
    "incident",
    "automation",
    "prompt",
    "token",
    "persistence",
    "dependencyalgorithm",
    "deploymentcommand",
    "providerspecific",
    "providerbehavior",
    "ownerprocedure",
    "skillinstruction",
    "runtimeorchestration",
    "flowid",
    "routeid",
    "codex",
    "claude",
    "portfolio",
    "roadmap",
    "activationchecklist",
    "budget",
    "runbook",
    "fieldname",
    "任务包",
    "字段结构",
    "字段名",
    "状态机",
    "缺陷类型",
    "重试",
    "事故子流程",
    "自动编排",
    "提示词",
    "持久化",
    "依赖算法",
    "部署命令",
    "供应商特定",
    "供应商行为",
    "角色内部流程",
    "运行时编排",
    "流程编号",
    "路由编号",
    "组合规划",
    "路线图",
    "激活清单",
    "预算",
    "恢复手册",
    "qfttenants",
    "全局协调器",
    "端到端协调器",
}


def local_name(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


def numeric(element: ET.Element, attribute: str) -> float:
    return float(element.attrib[attribute])


def compact_text(value: str) -> str:
    return re.sub(r"\s+", "", value)


def canonical_forbidden_text(value: str) -> str:
    return "".join(character.casefold() for character in value if character.isalnum())


def style_properties(element: ET.Element) -> dict[str, str]:
    properties = {}
    for declaration in element.attrib.get("style", "").split(";"):
        if ":" in declaration:
            name, value = declaration.split(":", 1)
            properties[name.strip().lower()] = value.strip()
    return properties


def parse_number(value: str) -> float:
    match = re.fullmatch(r"-?(?:\d+(?:\.\d+)?|\.\d+)", value.strip())
    if match is None:
        raise AssertionError(f"expected unitless numeric SVG value, got {value!r}")
    return float(value)


def markdown_targets(source: Path) -> list[Path]:
    targets = []
    for raw_target in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", source.read_text(encoding="utf-8")):
        destination = raw_target.strip().strip("<>").split("#", 1)[0]
        if (
            not destination
            or destination.startswith("/")
            or re.match(r"^[a-z][a-z0-9+.-]*:", destination, re.IGNORECASE)
        ):
            continue
        target = (source.parent / destination).resolve()
        if not target.is_relative_to(ROOT.resolve()):
            continue
        targets.append(target)
    return targets


class OneHumanAgentTeamArchitectureMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not SVG_PATH.is_file():
            raise AssertionError(f"missing canonical SVG projection: {SVG_PATH}")
        cls.tree = ET.parse(SVG_PATH)
        cls.root = cls.tree.getroot()
        cls.elements = list(cls.root.iter())
        cls.source_text = SVG_PATH.read_text(encoding="utf-8")
        cls.parent = {
            child: parent for parent in cls.elements for child in list(parent)
        }

    @classmethod
    def concept(cls, name: str) -> ET.Element:
        matches = [
            element
            for element in cls.elements
            if element.attrib.get("data-concept") == name
        ]
        if len(matches) != 1:
            raise AssertionError(f"expected one concept {name!r}, found {len(matches)}")
        return matches[0]

    @classmethod
    def is_inside(cls, node: ET.Element, ancestor: ET.Element) -> bool:
        parent = cls.parent.get(node)
        while parent is not None:
            if parent is ancestor:
                return True
            parent = cls.parent.get(parent)
        return False

    @classmethod
    def stage_ancestor(cls, node: ET.Element) -> str | None:
        parent = cls.parent.get(node)
        while parent is not None:
            if parent.attrib.get("data-kind") == "delivery-stage":
                return parent.attrib.get("data-concept")
            parent = cls.parent.get(parent)
        return None

    @classmethod
    def ancestors_inclusive(cls, node: ET.Element) -> list[ET.Element]:
        result = [node]
        parent = cls.parent.get(node)
        while parent is not None:
            result.append(parent)
            parent = cls.parent.get(parent)
        return result

    @classmethod
    def property_value(cls, node: ET.Element, name: str) -> str | None:
        for current in cls.ancestors_inclusive(node):
            inline = style_properties(current)
            if name in inline:
                return inline[name]
            if name in current.attrib:
                return current.attrib[name]
        return None

    @classmethod
    def is_structurally_visible(cls, node: ET.Element) -> bool:
        for current in cls.ancestors_inclusive(node):
            if local_name(current) == "defs":
                return False
            display = style_properties(current).get("display", current.attrib.get("display", ""))
            visibility = style_properties(current).get(
                "visibility", current.attrib.get("visibility", "")
            )
            if display.strip().lower() == "none":
                return False
            if visibility.strip().lower() in {"hidden", "collapse"}:
                return False
            for name in ("opacity", "fill-opacity", "stroke-opacity"):
                value = style_properties(current).get(name, current.attrib.get(name))
                if value is not None and parse_number(value) <= 0.0:
                    return False
        return True

    @classmethod
    def is_renderable_text(cls, node: ET.Element) -> bool:
        if local_name(node) != "text" or not cls.is_structurally_visible(node):
            return False
        if not "".join(node.itertext()).strip():
            return False
        required = {name: node.attrib.get(name) for name in ("x", "y", "font-size", "fill")}
        if any(value is None for value in required.values()):
            return False
        x = parse_number(required["x"] or "")
        y = parse_number(required["y"] or "")
        font_size = parse_number(required["font-size"] or "")
        fill = (required["fill"] or "").strip().lower()
        return 0.0 <= x <= 1920.0 and 0.0 <= y <= 1200.0 and font_size >= 14.0 and fill not in {
            "none",
            "transparent",
        }

    @classmethod
    def drawable_points(cls, node: ET.Element) -> list[tuple[float, float]]:
        name = local_name(node)
        if name == "rect":
            x, y, width, height = (numeric(node, key) for key in ("x", "y", "width", "height"))
            if width <= 0.0 or height <= 0.0:
                return []
            return [(x, y), (x + width, y + height)]
        if name == "line":
            return [
                (numeric(node, "x1"), numeric(node, "y1")),
                (numeric(node, "x2"), numeric(node, "y2")),
            ]
        if name == "circle":
            cx, cy, radius = numeric(node, "cx"), numeric(node, "cy"), numeric(node, "r")
            return [] if radius <= 0.0 else [(cx - radius, cy - radius), (cx + radius, cy + radius)]
        if name in {"path", "polyline"}:
            source = node.attrib.get("d", "") if name == "path" else node.attrib.get("points", "")
            numbers = [float(value) for value in re.findall(r"-?(?:\d+(?:\.\d+)?|\.\d+)", source)]
            return list(zip(numbers[0::2], numbers[1::2])) if len(numbers) >= 4 and len(numbers) % 2 == 0 else []
        return []

    @classmethod
    def is_renderable_drawable(cls, node: ET.Element) -> bool:
        if local_name(node) not in {"rect", "path", "line", "polyline", "circle"}:
            return False
        if not cls.is_structurally_visible(node):
            return False
        fill = (cls.property_value(node, "fill") or "").strip().lower()
        stroke = (cls.property_value(node, "stroke") or "").strip().lower()
        if fill in {"", "none", "transparent"} and stroke in {"", "none", "transparent"}:
            return False
        points = cls.drawable_points(node)
        if len(points) < 2 or len(set(points)) < 2:
            return False
        return all(0.0 <= x <= 1920.0 and 0.0 <= y <= 1200.0 for x, y in points)

    def rendered_text(self, element: ET.Element) -> str:
        return " ".join(
            " ".join("".join(node.itertext()).split())
            for node in element.iter()
            if self.is_renderable_text(node)
        )

    def assert_visible_tokens(
        self,
        element: ET.Element,
        tokens: tuple[str, ...],
        label: str,
    ) -> None:
        visible = compact_text(self.rendered_text(element))
        for token in tokens:
            self.assertIn(compact_text(token), visible, f"{label} missing visible token {token!r}")

    def assert_rendered_group(
        self,
        element: ET.Element,
        label: str,
        tokens: tuple[str, ...] = (),
    ) -> None:
        self.assertEqual(local_name(element), "g", label)
        self.assertTrue(self.is_structurally_visible(element), label)
        self.assertTrue(
            any(self.is_renderable_text(node) for node in element.iter()),
            f"{label} needs renderable text",
        )
        self.assertTrue(
            any(self.is_renderable_drawable(node) for node in element.iter()),
            f"{label} needs a painted, non-zero, on-canvas drawable",
        )
        self.assert_visible_tokens(element, tokens, label)

    def visual_rect(self, group: ET.Element, marker: str) -> tuple[float, float, float, float]:
        matches = [
            node
            for node in group.iter()
            if local_name(node) == "rect" and node.attrib.get("data-visual") == marker
        ]
        self.assertEqual(len(matches), 1, marker)
        rect = matches[0]
        self.assertTrue(self.is_renderable_drawable(rect), marker)
        return tuple(numeric(rect, key) for key in ("x", "y", "width", "height"))

    def visible_text(self) -> str:
        return self.rendered_text(self.root)

    def assert_inside_rect(
        self,
        geometry: tuple[float, float, float, float],
        container: tuple[float, float, float, float],
        label: str,
    ) -> None:
        x, y, width, height = geometry
        cx, cy, cwidth, cheight = container
        self.assertGreater(width, 0.0, label)
        self.assertGreater(height, 0.0, label)
        self.assertGreaterEqual(x, cx, label)
        self.assertGreaterEqual(y, cy, label)
        self.assertLessEqual(x + width, cx + cwidth, label)
        self.assertLessEqual(y + height, cy + cheight, label)

    def assert_horizontal_non_overlap(
        self,
        geometries: list[tuple[float, float, float, float]],
        container: tuple[float, float, float, float],
        label: str,
    ) -> None:
        for geometry in geometries:
            self.assert_inside_rect(geometry, container, label)
        for left, right in zip(geometries, geometries[1:]):
            self.assertLessEqual(left[0] + left[2] + 4.0, right[0], label)

    @staticmethod
    def rectangles_overlap(
        left: tuple[float, float, float, float],
        right: tuple[float, float, float, float],
    ) -> bool:
        lx, ly, lw, lh = left
        rx, ry, rw, rh = right
        return not (
            lx + lw <= rx or rx + rw <= lx or ly + lh <= ry or ry + rh <= ly
        )

    def test_root_declares_exact_baseline_and_fixed_canvas(self) -> None:
        self.assertEqual(self.root.attrib.get("data-architecture"), "one-human-agent-team")
        self.assertEqual(self.root.attrib.get("data-baseline"), "L0-R3")
        self.assertEqual(
            self.root.attrib.get("data-status"),
            "m0-manual-not-runtime-active",
        )
        self.assertEqual(self.root.attrib.get("viewBox"), "0 0 1920 1200")
        self.assertEqual(self.root.attrib.get("width"), "1920")
        self.assertEqual(self.root.attrib.get("height"), "1200")
        self.assertRegex(self.root.attrib.get("data-png-sha256", ""), r"^[0-9a-f]{64}$")
        header = self.concept("map-header")
        self.assertIs(self.parent.get(header), self.root)
        self.assert_rendered_group(header, "map-header", CONCEPT_VISIBLE_TOKENS["map-header"])

    def test_semantic_markers_are_rendered_and_not_hidden(self) -> None:
        forbidden_elements = {
            "a",
            "foreignObject",
            "image",
            "script",
            "use",
            "switch",
            "clipPath",
            "mask",
            "filter",
            "feImage",
        }
        self.assertFalse(any(local_name(element) in forbidden_elements for element in self.elements))
        self.assertFalse(any("transform" in element.attrib for element in self.elements))
        source_casefold = self.source_text.casefold()
        for forbidden_declaration in ("<?xml-stylesheet", "<!doctype", "<!entity"):
            self.assertNotIn(forbidden_declaration, source_casefold)
        style_source = " ".join(
            "".join(element.itertext())
            for element in self.elements
            if local_name(element) == "style"
        ).casefold()
        for external_css in ("@import", "@font-face", "http://", "https://", "data:", "file:"):
            self.assertNotIn(external_css, style_source)
        for reference in re.findall(r"url\(([^)]+)\)", style_source, re.IGNORECASE):
            self.assertTrue(reference.strip(" '\"").startswith("#"), reference)
        normalized_style = re.sub(r"\s+", "", style_source)
        for concealed_css in (
            "display:none",
            "visibility:hidden",
            "visibility:collapse",
            "opacity:0",
            "fill-opacity:0",
            "stroke-opacity:0",
            "font-size:0",
            "clip-path:",
            "mask:",
            "filter:",
        ):
            self.assertNotIn(concealed_css, normalized_style)

        for element in self.elements:
            for attribute, value in element.attrib.items():
                attribute_name = attribute.rsplit("}", 1)[-1].lower()
                self.assertFalse(attribute_name.startswith("on"), attribute_name)
                if attribute_name == "href":
                    self.assertTrue(value.startswith("#"), value)
                for reference in re.findall(r"url\(([^)]+)\)", value, re.IGNORECASE):
                    self.assertTrue(reference.strip(" '\"").startswith("#"), reference)
            if local_name(element) == "text":
                self.assertTrue(self.is_renderable_text(element), ET.tostring(element, encoding="unicode"))

        concepts = [
            element.attrib["data-concept"]
            for element in self.elements
            if "data-concept" in element.attrib
        ]
        self.assertEqual(len(concepts), len(CONCEPT_VISIBLE_TOKENS))
        self.assertEqual(set(concepts), set(CONCEPT_VISIBLE_TOKENS))
        for concept, tokens in CONCEPT_VISIBLE_TOKENS.items():
            self.assert_rendered_group(self.concept(concept), concept, tokens)

        kinds: dict[str, set[str | None]] = {}
        for element in self.elements:
            if "data-kind" in element.attrib:
                kinds.setdefault(element.attrib["data-kind"], set()).add(
                    element.attrib.get("data-concept")
                )
        self.assertEqual(kinds, KIND_MANIFEST)

    def test_layers_stages_and_gates_use_the_real_left_to_right_geometry(self) -> None:
        for concept, (kind, visual, expected_geometry) in LAYER_GEOMETRY.items():
            group = self.concept(concept)
            self.assertEqual(group.attrib.get("data-kind"), kind)
            self.assertIs(self.parent.get(group), self.root, concept)
            self.assertEqual(self.visual_rect(group, visual), expected_geometry)

        agent_team = self.concept("agent-team")
        teams = [
            element
            for element in self.elements
            if element.attrib.get("data-kind") == "agent-team"
        ]
        self.assertEqual(len(teams), 1)

        delivery_stages = [
            element
            for element in self.elements
            if element.attrib.get("data-kind") == "delivery-stage"
        ]
        self.assertEqual(len(delivery_stages), 5)
        self.assertEqual(
            {element.attrib.get("data-concept") for element in delivery_stages},
            {concept for concept, _, _, _ in STAGES},
        )

        stage_x_positions = []
        for concept, order, integrator, expected_x in STAGES:
            stage = self.concept(concept)
            self.assertEqual(stage.attrib.get("data-kind"), "delivery-stage")
            self.assertEqual(stage.attrib.get("data-order"), order)
            self.assertEqual(stage.attrib.get("data-integrator"), integrator)
            self.assertIs(self.parent.get(stage), agent_team, concept)
            geometry = self.visual_rect(stage, "stage-card")
            self.assertEqual(geometry, (expected_x, 378.0, 292.0, 438.0))
            stage_x_positions.append(geometry[0])
        self.assertEqual(stage_x_positions, sorted(stage_x_positions))
        self.assertEqual(len(set(stage_x_positions)), 5)

        stage_geometries = {
            concept: self.visual_rect(self.concept(concept), "stage-card")
            for concept, _, _, _ in STAGES
        }
        for name, between, line_x, callout_x in GATES:
            boundary = self.concept(name)
            self.assertEqual(boundary.attrib.get("data-kind"), "deployment-boundary")
            self.assertEqual(boundary.attrib.get("data-controlled-by"), "human")
            self.assertEqual(boundary.attrib.get("data-between"), between)
            self.assertIs(self.parent.get(boundary), agent_team, name)
            gate_lines = [
                node
                for node in boundary.iter()
                if local_name(node) == "line" and node.attrib.get("data-visual") == "deployment-gate"
            ]
            self.assertEqual(len(gate_lines), 1, name)
            self.assertEqual(numeric(gate_lines[0], "x1"), line_x)
            self.assertEqual(numeric(gate_lines[0], "x2"), line_x)
            self.assertEqual(
                self.visual_rect(boundary, "deployment-callout"),
                (callout_x, 310.0, 260.0, 60.0),
            )
        self.assertLess(
            stage_geometries["stage-development-delivery"][0] + 292.0,
            1131.0,
        )
        self.assertLess(1131.0, stage_geometries["stage-independent-quality"][0])
        self.assertLess(
            stage_geometries["stage-independent-quality"][0] + 292.0,
            1473.0,
        )
        self.assertLess(1473.0, stage_geometries["stage-production-closeout"][0])

    def test_role_types_conditions_and_assurance_placement_are_explicit(self) -> None:
        by_role: dict[str, list[ET.Element]] = {}
        for element in self.elements:
            role_id = element.attrib.get("data-role-id")
            if role_id:
                by_role.setdefault(role_id, []).append(element)

        self.assertEqual(set(by_role), PROFESSIONAL_OWNERS | EXECUTORS)
        for role_id, stage_concepts in ROLE_STAGE_REQUIREMENTS.items():
            nodes = by_role[role_id]
            expected_type = "professional-owner" if role_id in PROFESSIONAL_OWNERS else "executor"
            self.assertEqual(len(nodes), len(stage_concepts), role_id)
            self.assertTrue(all(node.attrib.get("data-role-type") == expected_type for node in nodes))
            self.assertEqual({self.stage_ancestor(node) for node in nodes}, stage_concepts)
            for node in nodes:
                stage_concept = self.stage_ancestor(node)
                self.assert_rendered_group(
                    node,
                    f"{role_id}@{stage_concept}",
                    ROLE_INSTANCE_VISIBLE_TOKENS[(role_id, stage_concept)],
                )
        for role_id in ("ux-owner", "architecture-owner"):
            self.assertEqual(by_role[role_id][0].attrib.get("data-activation"), "conditional")

        self.assertEqual(len(by_role["delivery-assurance-owner"]), 1)
        assurance = by_role["delivery-assurance-owner"][0]
        self.assertEqual(assurance.attrib.get("data-role-type"), "professional-owner")
        self.assertEqual(assurance.attrib.get("data-placement"), "cross-cutting")
        self.assertEqual(assurance.attrib.get("data-team-membership"), "agent-team")
        self.assertIsNone(self.stage_ancestor(assurance))
        self.assertTrue(self.is_inside(assurance, self.concept("shared-foundation")))
        self.assert_rendered_group(
            assurance,
            "delivery-assurance-owner",
            ROLE_INSTANCE_VISIBLE_TOKENS[("delivery-assurance-owner", None)],
        )

    def test_forward_convergence_foundation_return_and_final_facts_remain_distinct(self) -> None:
        human = self.concept("human-governance")
        for concept in HUMAN_ACTIONS:
            self.assertTrue(self.is_inside(self.concept(concept), human), concept)
        forward = self.concept("forward-control-law")
        self.assertTrue(self.is_inside(forward, human))
        forward_geometries = []
        for concept, order in FORWARD_FACTS:
            fact = self.concept(concept)
            self.assertTrue(self.is_inside(fact, forward), concept)
            self.assertEqual(fact.attrib.get("data-order"), order)
            forward_geometries.append(self.visual_rect(fact, "forward-fact"))
        self.assert_horizontal_non_overlap(
            forward_geometries,
            LAYER_GEOMETRY["human-governance"][2],
            "forward facts",
        )

        stage_one = self.concept("stage-product-definition")
        convergence = self.concept("product-definition-convergence")
        self.assertEqual(convergence.attrib.get("data-flow"), "iterative")
        self.assertTrue(self.is_inside(convergence, stage_one))
        convergence_paths = {
            node.attrib["data-relation"]: node
            for node in convergence.iter()
            if local_name(node) == "path" and node.attrib.get("data-relation")
        }
        self.assertEqual(set(convergence_paths), {"reopen-forward", "reopen-return"})
        self.assertEqual(
            len(
                [
                    node
                    for node in convergence.iter()
                    if local_name(node) == "path" and node.attrib.get("data-relation")
                ]
            ),
            2,
        )
        convergence_endpoints = {}
        stage_one_geometry = self.visual_rect(stage_one, "stage-card")
        for relation, path in convergence_paths.items():
            self.assertTrue(self.is_renderable_drawable(path), relation)
            points = self.drawable_points(path)
            self.assertGreaterEqual(len(points), 2, relation)
            self.assertNotEqual(points[0], points[-1], relation)
            for point in points:
                self.assert_inside_rect((point[0], point[1], 0.1, 0.1), stage_one_geometry, relation)
            convergence_endpoints[relation] = (points[0], points[-1])
        forward_start, forward_end = convergence_endpoints["reopen-forward"]
        return_start, return_end = convergence_endpoints["reopen-return"]
        self.assertLess(forward_start[0], forward_end[0])
        self.assertGreater(return_start[0], return_end[0])
        self.assertGreaterEqual(
            min(abs(forward_start[1] - return_start[1]), abs(forward_end[1] - return_end[1])),
            8.0,
        )
        self.assertTrue(
            self.is_inside(self.concept("proof-before-implementation-plan"), self.concept("stage-verification-planning"))
        )
        agent_team = self.concept("agent-team")
        self.assertTrue(self.is_inside(self.concept("specialist-accountability-rule"), agent_team))
        self.assertTrue(self.is_inside(self.concept("behavior-obligation-trace"), agent_team))

        foundation = self.concept("shared-foundation")
        for concept in FOUNDATION_FACTS:
            self.assertTrue(self.is_inside(self.concept(concept), foundation), concept)

        return_law = self.concept("accountable-return-safe-stop")
        return_geometries = []
        for concept, order in RETURN_FACTS:
            fact = self.concept(concept)
            self.assertTrue(self.is_inside(fact, return_law), concept)
            self.assertEqual(fact.attrib.get("data-order"), order)
            return_geometries.append(self.visual_rect(fact, "return-fact"))
        self.assert_horizontal_non_overlap(
            return_geometries,
            LAYER_GEOMETRY["accountable-return-safe-stop"][2],
            "return facts",
        )

        stage_five = self.concept("stage-production-closeout")
        stage_five_geometry = self.visual_rect(stage_five, "stage-card")
        final_geometries = []
        for concept, owner in FINAL_FACTS.items():
            fact = self.concept(concept)
            self.assertTrue(self.is_inside(fact, stage_five), concept)
            self.assertEqual(fact.attrib.get("data-owner"), owner)
            geometry = self.visual_rect(fact, "final-fact")
            self.assert_inside_rect(geometry, stage_five_geometry, concept)
            final_geometries.append(geometry)
        self.assertEqual(len({(geometry[2], geometry[3]) for geometry in final_geometries}), 1)
        for index, left in enumerate(final_geometries):
            for right in final_geometries[index + 1 :]:
                self.assertFalse(self.rectangles_overlap(left, right), "final facts overlap")

    def test_svg_is_self_contained_and_excludes_deferred_detail(self) -> None:
        visible_text = self.visible_text()
        self.assertIn("M0 manual learning mode · not runtime-active", visible_text)
        for pattern in FORBIDDEN_VISIBLE_PATTERNS:
            self.assertIsNone(pattern.search(visible_text), pattern.pattern)
        forbidden_text = canonical_forbidden_text(visible_text)
        for pattern in FORBIDDEN_CANONICAL_PATTERNS:
            self.assertIsNone(pattern.search(forbidden_text), pattern.pattern)
        for fragment in FORBIDDEN_CANONICAL_FRAGMENTS:
            self.assertNotIn(fragment.casefold(), forbidden_text, fragment)

    def test_png_is_complete_decodable_and_bound_to_the_svg(self) -> None:
        payload = PNG_PATH.read_bytes()
        self.assertEqual(payload[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(hashlib.sha256(payload).hexdigest(), self.root.attrib["data-png-sha256"])

        offset = 8
        chunks: list[tuple[bytes, bytes]] = []
        while offset < len(payload):
            self.assertGreaterEqual(len(payload) - offset, 12)
            length = struct.unpack(">I", payload[offset : offset + 4])[0]
            chunk_type = payload[offset + 4 : offset + 8]
            chunk_end = offset + 12 + length
            self.assertLessEqual(chunk_end, len(payload))
            chunk_data = payload[offset + 8 : offset + 8 + length]
            recorded_crc = struct.unpack(">I", payload[offset + 8 + length : chunk_end])[0]
            calculated_crc = binascii.crc32(chunk_type + chunk_data) & 0xFFFFFFFF
            self.assertEqual(recorded_crc, calculated_crc, chunk_type)
            chunks.append((chunk_type, chunk_data))
            offset = chunk_end
            if chunk_type == b"IEND":
                break

        self.assertEqual(offset, len(payload))
        self.assertEqual(chunks[0][0], b"IHDR")
        self.assertEqual(chunks[-1], (b"IEND", b""))
        ihdr = chunks[0][1]
        self.assertEqual(len(ihdr), 13)
        width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
            ">IIBBBBB", ihdr
        )
        self.assertEqual((width, height), (1920, 1200))
        self.assertEqual(bit_depth, 8)
        self.assertIn(color_type, {2, 6})
        self.assertEqual((compression, filtering, interlace), (0, 0, 0))
        compressed = b"".join(data for chunk_type, data in chunks if chunk_type == b"IDAT")
        self.assertTrue(compressed)
        decoded = zlib.decompress(compressed)
        channels = {2: 3, 6: 4}[color_type]
        self.assertEqual(len(decoded), height * (1 + width * channels))

    def test_canonical_and_historical_links_resolve_without_a_second_semantic_source(self) -> None:
        canonical = CANONICAL_SPEC.resolve()
        self.assertTrue(CANONICAL_SPEC.is_file())
        self.assertFalse(CANONICAL_SPEC.is_symlink())
        for pointer in CANONICAL_POINTERS:
            self.assertTrue(pointer.is_file(), pointer)
            self.assertFalse(pointer.is_symlink(), pointer)
            self.assertIn(canonical, markdown_targets(pointer), pointer)

        if "Projection status: `APPROVED" not in README_PATH.read_text(encoding="utf-8"):
            return
        canonical_targets = markdown_targets(CANONICAL_SPEC)
        for asset in (SVG_PATH, PNG_PATH):
            self.assertTrue(asset.is_file(), asset)
            self.assertFalse(asset.is_symlink(), asset)
            self.assertIn(asset.resolve(), canonical_targets, asset)


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [ ] **Step 2: Register the test in the existing repository gate path**

Add this exact entry to `tests/gate-plan.json` without reordering unrelated steps:

```json
{
  "id": "one-human-agent-team-architecture-map",
  "command": [
    "python3",
    "tests/test-one-human-agent-team-architecture-map.py"
  ],
  "area": "docs",
  "tier": "full",
  "tags": [
    "docs",
    "python"
  ],
  "parallel_safe": true,
  "timeout_sec": 60
}
```

Add this line to `run_bash_syntax_checks()` in `tests/run-all.sh` beside the other Python test compilation lines:

```bash
python3 -m py_compile "$ROOT/tests/test-one-human-agent-team-architecture-map.py"
```

- [ ] **Step 3: Run the new test and prove the projection is missing**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 tests/test-one-human-agent-team-architecture-map.py
```

Expected: FAIL before tests run with `missing canonical SVG projection`.

- [ ] **Step 4: Create the asset provenance file in draft state**

Create `README.md` with this exact boundary:

```markdown
# L0-R3 Chinese Macro Architecture Map

- Semantic source: `../../2026-08-03--one-human-agent-team-operating-architecture-l0--design.md`
- Editable projection: `one-human-agent-team-architecture-map.svg`
- Derived review render: `one-human-agent-team-architecture-map.png`
- Projection status: `DRAFT — pending human semantic and visual acceptance`
- Pre-map baseline commit: `<copy the literal 40-character PRE_MAP_COMMIT printed by Step 0>`
- Renderer used for the recorded PNG: `rsvg-convert 2.60.0`, `1920×1200`

The Markdown specification remains the architecture source of truth. The SVG is one human navigation projection; the PNG owns no semantics and must be regenerated from the SVG. Do not use the rejected 2026-07-30 R4 suite as an input.

Render from the repository root:

```bash
rsvg-convert -f png -w 1920 -h 1200 \
  -o docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg
```
```

- [ ] **Step 5: Create the semantic SVG candidate**

Use `apply_patch` to create the SVG. Start with this exact self-contained root and definitions, then implement every region, marker, coordinate, and visible-copy row in the Projection Contract:

```svg
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="1920"
     height="1200"
     viewBox="0 0 1920 1200"
     role="img"
     aria-labelledby="map-title map-description"
     data-architecture="one-human-agent-team"
     data-baseline="L0-R3"
     data-status="m0-manual-not-runtime-active">
  <title id="map-title">一人 + Agent Team 架构</title>
  <desc id="map-description">一个人类治理层、一个 Agent Team、五个专业交付阶段、两个人工部署边界，以及共享协调与保障底座。</desc>
  <defs>
    <marker id="arrow-forward" markerWidth="10" markerHeight="10" refX="8" refY="5" orient="auto">
      <path d="M0,0 L10,5 L0,10 Z" fill="#46627F"/>
    </marker>
    <marker id="arrow-return" markerWidth="10" markerHeight="10" refX="2" refY="5" orient="auto">
      <path d="M10,0 L0,5 L10,10 Z" fill="#B42318"/>
    </marker>
    <style>
      text { font-family: "Hiragino Sans GB", "PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", sans-serif; }
      .layer { stroke-width: 1.5; }
      .stage { fill: #FFFFFF; stroke: #B7C5D8; stroke-width: 1.5; }
      .forward { fill: none; stroke: #46627F; stroke-width: 2.5; marker-end: url(#arrow-forward); }
      .return { fill: none; stroke: #B42318; stroke-width: 2.5; marker-end: url(#arrow-return); }
      .conditional { stroke-dasharray: 7 5; }
    </style>
  </defs>
  <rect width="1920" height="1200" fill="#F4F7FB"/>
  <g data-concept="map-header">
    <rect x="60" y="36" width="1800" height="66" rx="12" fill="#FFFFFF" stroke="#B7C5D8"/>
    <text x="84" y="79" font-size="40" fill="#173B63">一人 + Agent Team 架构</text>
    <text x="560" y="64" font-size="16" fill="#46627F">人掌握关键决策与外部动作，Agent Team 承担专业交付与责任闭环</text>
    <text x="560" y="88" font-size="14" fill="#6750A4">M0 manual learning mode · not runtime-active</text>
  </g>
  <!-- All semantic groups below are projections of the approved L0-R3 source. -->
</svg>
```

The completed SVG must implement every semantic row in the Machine-Readable SVG Contract and every visible-copy row in the Projection Contract. Put each marker on the group that draws its visible shapes and text; do not create empty marker groups, hidden prose, off-canvas nodes, or zero-opacity elements merely to satisfy the test. Required semantic `<text>` nodes must repeat explicit numeric `x`, `y`, and `font-size` plus a visible `fill`; required semantic shapes and convergence paths must repeat explicit visible `fill` or `stroke` even when a CSS class supplies the same style.

- [ ] **Step 6: Render the PNG and make the structural test pass**

Render once and print the actual PNG digest:

```bash
set -euo pipefail
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
MAP_CJK_FONT="$(fc-match -f '%{family[0]}\n' 'Hiragino Sans GB')"
test "$MAP_CJK_FONT" = "Hiragino Sans GB"
rsvg-convert -f png -w 1920 -h 1200 -o "$MAP_PNG" "$MAP_SVG"
shasum -a 256 "$MAP_PNG"
```

Use `apply_patch` to add `data-png-sha256` to the SVG root with the exact 64-character first field printed by `shasum`. Then rerender and run the complete structural checks:

```bash
set -euo pipefail
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
rsvg-convert -f png -w 1920 -h 1200 -o "$MAP_PNG" "$MAP_SVG"
PYTHONDONTWRITEBYTECODE=1 python3 tests/test-one-human-agent-team-architecture-map.py
xmllint --noout "$MAP_SVG"
```

Expected: eight unittest cases PASS and `xmllint` exits `0` without output. If adding the non-rendered digest attribute changes the PNG bytes in the installed renderer, update the attribute to the new digest, render once more, and require two consecutive identical digest values before proceeding.

- [ ] **Step 7: Prove the focused gate sees the new test**

Run:

```bash
set -euo pipefail
bash tests/run-focused.sh docs-context --list
bash tests/run-focused.sh docs-context
```

Expected: the list includes `one-human-agent-team-architecture-map`; the profile passes the new map check and every existing docs/context check. The known Product Manager context-budget warning may remain a warning, not a failure.

- [ ] **Step 8: Commit the structurally valid candidate**

Run:

```bash
set -euo pipefail
git diff --check
git add \
  tests/test-one-human-agent-team-architecture-map.py \
  tests/gate-plan.json \
  tests/run-all.sh \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/README.md \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png
git commit -m "docs: add L0 agent team architecture map candidate"
```

Expected: one commit containing only the candidate projection, its provenance, and its focused regression gate.

---

### Task 2: Prove Semantic Fidelity and Human Readability

**Files:**

- Modify on each failed rejection check: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg`
- Regenerate after every change: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png`

**Interfaces:**

- Consumes: the Task 1 semantic candidate and the approved cold-reader contract.
- Produces: one internally accepted review candidate; it still remains `DRAFT` until the human explicitly approves it.

After every SVG change, repeat Task 1 Step 6: render the PNG, update the root `data-png-sha256` with the actual digest using `apply_patch`, rerender, and require the structural test to pass before creating proofs. SVG and PNG are one bound projection pair; changing only one is an invalid candidate.

- [ ] **Step 1: Verify deterministic rendering and exact dimensions**

Run:

```bash
set -euo pipefail
MAP_ASSET_DIR="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0"
MAP_PROOF_DIR="$(mktemp -d /tmp/one-human-agent-team-map.XXXXXX)"
case "$MAP_PROOF_DIR" in
  /tmp/one-human-agent-team-map.*) ;;
  *) printf 'unsafe proof directory: %s\n' "$MAP_PROOF_DIR" >&2; exit 1 ;;
esac
MAP_CJK_FONT="$(fc-match -f '%{family[0]}\n' 'Hiragino Sans GB')"
test "$MAP_CJK_FONT" = "Hiragino Sans GB"
rsvg-convert -f png -w 1920 -h 1200 \
  -o "$MAP_PROOF_DIR/render-a.png" \
  "$MAP_ASSET_DIR/one-human-agent-team-architecture-map.svg"
rsvg-convert -f png -w 1920 -h 1200 \
  -o "$MAP_PROOF_DIR/render-b.png" \
  "$MAP_ASSET_DIR/one-human-agent-team-architecture-map.svg"
cmp "$MAP_PROOF_DIR/render-a.png" "$MAP_PROOF_DIR/render-b.png"
cmp "$MAP_PROOF_DIR/render-a.png" "$MAP_ASSET_DIR/one-human-agent-team-architecture-map.png"
magick identify -format '%wx%h\n' "$MAP_PROOF_DIR/render-a.png"
magick "$MAP_PROOF_DIR/render-a.png" -resize 1440x900 \
  "$MAP_PROOF_DIR/desktop-1440.png"
magick "$MAP_PROOF_DIR/render-a.png" -colorspace Gray \
  "$MAP_PROOF_DIR/grayscale.png"
printf 'FULL_PROOF=%s\n' "$MAP_PROOF_DIR/render-a.png"
printf 'DESKTOP_PROOF=%s\n' "$MAP_PROOF_DIR/desktop-1440.png"
printf 'GRAYSCALE_PROOF=%s\n' "$MAP_PROOF_DIR/grayscale.png"
printf 'PROOF_DIR=%s\n' "$MAP_PROOF_DIR"
```

Expected: the Chinese-font assertion and all `cmp` checks exit `0`; ImageMagick prints `1920x1200`; four absolute proof paths are printed. A font fallback mismatch or committed-PNG mismatch blocks the recorded render because glyph presence, text layout, and source/render identity would otherwise be accidental.

- [ ] **Step 2: Inspect full-scale, normal-desktop, and grayscale proofs**

Use `view_image` on the literal `FULL_PROOF`, `DESKTOP_PROOF`, and `GRAYSCALE_PROOF` paths printed by Step 1. Do not type an unresolved shell variable into the image tool.

Reject and revise the SVG if any of the following is true:

- the first reading layer is not `人类治理层 → 一个 Agent Team / 五阶段 → 共享底座 → 回流/停止`;
- a first-time reader can mistake the five stages for five Teams;
- a deployment boundary looks like an Agent-owned stage;
- Stage 1 looks one-way rather than convergent;
- the optional UX/Architecture roles look mandatory or missing;
- Professional Owner, Executor, conditional Owner, Human action, and Delivery Assurance rely on color alone;
- Delivery Assurance looks nested in Quality or appears as a sixth stage;
- any of the Stage 5 facts looks equivalent to another or to Demand completion;
- any key label is clipped, overlaps another label, crosses an arrow, or requires zoom at the 1440-wide proof;
- grayscale removes the Human, conditional, assurance, deployment, or failure distinction;
- visual decoration competes with the delivery path.

Revise only the SVG, regenerate the PNG, and repeat Tasks 2.1–2.2 until all rejection conditions are false.

- [ ] **Step 3: Run two fresh-context image-only reviews**

Dispatch two independent reviewers with only the 1920×1200 PNG, not the specification or prior conversation.

Reviewer A receives these questions:

```text
请只看这张图回答：
1. 团队形态是什么？图中有几个 Agent Team、几个交付阶段？
2. 五个阶段按什么顺序推进，各自解决什么问题？
3. 人在哪些地方共创、授权、部署、验收和做最终决定？
4. 人是否负责调度 Developer / QA、拼上下文或判断技术根因？
```

Reviewer B receives these questions:

```text
请只看这张图回答：
1. 每个阶段由谁整合结果，专业 Owner 的结论能否被整合者覆盖？
2. Product Definition 是单向链还是收敛循环？UX / Architecture 是固定还是按需？
3. 当前阶段、版本身份、证据有效性和回流目标从哪里恢复？
4. Delivery Assurance Owner 与 Quality Owner 有什么区别？
5. 生产验证、业务验收、Product Director 建议、Phase / Demand 处置是否为同一个结论？
6. 失败后如何回流，什么情况下停止？
```

Acceptance: neither reviewer may produce a material ontology error, ownership inversion, deployment-authority error, Quality/Assurance conflation, or false-completion interpretation. Copy or hierarchy confusion is a map defect; do not explain the answer to rescue the map.

- [ ] **Step 4: Re-run semantic and repository checks after visual revisions**

Run:

```bash
set -euo pipefail
PYTHONDONTWRITEBYTECODE=1 python3 tests/test-one-human-agent-team-architecture-map.py
bash tests/run-focused.sh docs-context
git diff --check
```

Expected: the map test and docs/context profile pass; only the existing Product Manager soft-budget warning may remain.

- [ ] **Step 5: Commit the internally accepted review candidate**

If Task 2 changed the candidate, run:

```bash
set -euo pipefail
git add \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png
git commit -m "docs: refine L0 agent team architecture map"
```

If no files changed, do not create an empty commit.

After the candidate commit exists, bind the exact bytes that will be reviewed:

```bash
set -euo pipefail
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
MAP_CANDIDATE_COMMIT="$(git log -1 --format=%H -- "$MAP_SVG" "$MAP_PNG")"
test -n "$MAP_CANDIDATE_COMMIT"
git show "$MAP_CANDIDATE_COMMIT:$MAP_SVG" | cmp - "$MAP_SVG"
git show "$MAP_CANDIDATE_COMMIT:$MAP_PNG" | cmp - "$MAP_PNG"
test -z "$(git status --short)"
printf 'CANDIDATE_COMMIT=%s\n' "$MAP_CANDIDATE_COMMIT"
shasum -a 256 "$MAP_SVG" "$MAP_PNG"
```

Expected: both committed-path comparisons and the clean-worktree assertion pass; the full candidate commit plus distinct SVG and PNG SHA-256 values are printed.

- [ ] **Step 6: Run the required Chinese business/product cold-reader check**

Give only the literal `DESKTOP_PROOF` path printed by Step 1 to one Chinese-speaking business or product reader who has not read the specification or this conversation. Do not explain the architecture before the check.

Use these observable tasks:

```text
10 秒：指出图中有几个人类治理层、几个 Agent Team、几个交付阶段，并按顺序读出五阶段。
60 秒：指出每阶段整合者、人类的部署边界、状态恢复位置、Delivery Assurance 与 Quality 的区别，
以及生产验证、业务验收、Product Director 建议、Phase / Demand 处置是否为同一事实。
```

Acceptance: every count, order, ownership, boundary, and distinction is correct without narration, zoom, glossary, or a second diagram. Record the exact image path, `1440×900` scale, expected answers, observed answers, and elapsed time in the execution report. A fresh Agent is useful but is not evidence for this human-reader requirement. If no independent reader is available, report the candidate as `cold-reader evidence pending`; do not claim full visual acceptance.

- [ ] **Step 7: Stop for explicit human owner semantic and visual approval**

Display the committed PNG directly in the Codex response and link both SVG and PNG. In the same approval request, quote the literal full candidate commit, SVG SHA-256, and PNG SHA-256 printed by Step 5. State explicitly that the map is still a candidate and ask the human to approve those exact bytes or identify changes.

Do not execute Task 3 on `看起来差不多`, silence, or inferred approval. Required gate: explicit written approval such as `架构图批准`, `GO`, or an equally unambiguous statement.

If rejected, change only the SVG and regenerated PNG, repeat all Task 2 checks, and present the revised map again. Do not expand into additional diagrams or Owner-detail views.

After the cold-reader and owner reviews no longer need the proofs, copy the literal `PROOF_DIR` path printed by Step 1, verify that it begins `/tmp/one-human-agent-team-map.`, and remove only that exact directory. Never run cleanup with an empty or unresolved variable.

---

### Task 3: Publish the Human-Accepted Projection and Close Visual Governance

**Files:**

- Modify: `docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/README.md`
- Modify: `docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md`
- Modify: `docs/product-dirrctor-session.md`
- Modify: `docs/superpowers/plans/2026-07-30--one-human-agent-operating-architecture-visual-redesign.md`
- Modify: `docs/superpowers/specs/2026-07-30--one-human-agent-operating-architecture-visual-redesign--design.md`
- Modify: `docs/superpowers/specs/2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md`
- Modify: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/README.md`

**Interfaces:**

- Consumes: explicit human approval of the exact committed SVG/PNG revision.
- Produces: one accepted visual projection reachable from the canonical baseline; historical docs remain historical and no Owner/runtime work is silently authorized.

- [ ] **Step 1: Record projection acceptance without copying architecture content**

From the approval request that the human explicitly answered, copy the literal full candidate commit, SVG SHA-256, and PNG SHA-256 into the shell variables `MAP_APPROVED_COMMIT`, `MAP_APPROVED_SVG_SHA256`, and `MAP_APPROVED_PNG_SHA256`. Do not derive any approved value from current `HEAD`. Run this guard in the same shell after defining those variables:

```bash
set -euo pipefail
: "${MAP_APPROVED_COMMIT:?copy the literal commit from the approved review request}"
: "${MAP_APPROVED_SVG_SHA256:?copy the literal SVG digest from the approved review request}"
: "${MAP_APPROVED_PNG_SHA256:?copy the literal PNG digest from the approved review request}"
[[ "$MAP_APPROVED_COMMIT" =~ ^[0-9a-f]{40}$ ]]
[[ "$MAP_APPROVED_SVG_SHA256" =~ ^[0-9a-f]{64}$ ]]
[[ "$MAP_APPROVED_PNG_SHA256" =~ ^[0-9a-f]{64}$ ]]
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
MAP_CURRENT_COMMIT="$(git log -1 --format=%H -- "$MAP_SVG" "$MAP_PNG")"
test "$MAP_CURRENT_COMMIT" = "$MAP_APPROVED_COMMIT"
git show "$MAP_APPROVED_COMMIT:$MAP_SVG" | cmp - "$MAP_SVG"
git show "$MAP_APPROVED_COMMIT:$MAP_PNG" | cmp - "$MAP_PNG"
test "$(shasum -a 256 "$MAP_SVG" | awk '{print $1}')" = "$MAP_APPROVED_SVG_SHA256"
test "$(shasum -a 256 "$MAP_PNG" | awk '{print $1}')" = "$MAP_APPROVED_PNG_SHA256"
test -z "$(git status --short)"
```

Expected: every identity, digest, committed-byte, and clean-worktree assertion passes. Any mismatch invalidates the prior approval and returns to Task 2; it must not be repaired inside Task 3.

Change the new asset README status to this exact line:

```markdown
- Projection status: `APPROVED — explicit human semantic and visual acceptance recorded before publication`
```

Using `apply_patch`, add `Accepted projection commit`, `Accepted SVG SHA-256`, and `Accepted PNG SHA-256` provenance lines with the three literal values that passed the guard. Do not write current `HEAD` unless it is exactly the approved candidate commit.

Do not add role lists, flow prose, or a second acceptance contract to the README.

- [ ] **Step 2: Link the accepted map from the canonical baseline**

In the canonical Status section, add:

```markdown
- Visual projection status: `APPROVED — explicit human semantic and visual acceptance recorded before publication`.
```

Update `Current authority` so it says the approved `L0-R3` specification alone permits the next separately designed Owner-domain step, while the accepted macro map closes only the human-navigation visual gate. State explicitly that the map is non-normative and neither source authorizes Owner implementation, Skill changes, or runtime automation.

Immediately under `## Chinese Macro Architecture Map Contract`, add:

```markdown
Accepted projection:

- [Editable SVG](assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg)
- [PNG review render](assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png)

![一人 + Agent Team 中文宏观架构图](assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png)
```

Keep the contract itself intact; do not rewrite `L0-R3` architecture semantics to match drawing convenience.

- [ ] **Step 3: Synchronize historical pointers**

Update the current handoff pointer `docs/product-dirrctor-session.md` so it identifies the `2026-08-03` `L0-R3` specification as the sole semantic and next-design authority, and the SVG/PNG pair as its accepted non-normative navigation projection. It may identify the next allowed action, but must not authorize implementation.

Update only the immutable tombstone facts in these four historical locations: the closed R4 plan, rejected R4 design, superseded V1.2 design, and historical R4 asset README. Each must retain its rejected/superseded status and no-forward-use boundary, link to the canonical `L0-R3` baseline, and explain that the accepted map is reachable from that canonical baseline. Do not copy dynamic claims such as the current Product Director block, “Owner work has not started,” or the current next stage into historical tombstones; those would become stale the moment later work begins.

Leave `docs/superpowers/specs/2026-07-30--product-director-decision-case--design.md` untouched. Its own block remains true and the permanent link-regression test still proves that it reaches the canonical baseline.

Do not modify or delete the old DOT/SVG/PNG assets.

- [ ] **Step 4: Prove link, ontology, render, and document-governance consistency**

Run:

```bash
set -euo pipefail
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
MAP_README="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/README.md"
OLD_ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
test -f "$MAP_SVG"
test -f "$MAP_PNG"
MAP_PRE_MAP_COMMIT="$(python3 - "$MAP_README" <<'PY'
import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r"^- Pre-map baseline commit: `([0-9a-f]{40})`$", source, re.MULTILINE)
if match is None:
    raise SystemExit("missing exact pre-map baseline commit provenance")
print(match.group(1))
PY
)"
git cat-file -e "$MAP_PRE_MAP_COMMIT^{commit}"
BASELINE_R4_TREE="$(git ls-tree -r "$MAP_PRE_MAP_COMMIT" -- "$OLD_ASSET_DIR" | awk '$4 ~ /\.(dot|svg|png)$/')"
CURRENT_R4_TREE="$(git ls-tree -r HEAD -- "$OLD_ASSET_DIR" | awk '$4 ~ /\.(dot|svg|png)$/')"
test "$(printf '%s\n' "$BASELINE_R4_TREE" | awk 'NF {count++} END {print count+0}')" = "12"
test "$BASELINE_R4_TREE" = "$CURRENT_R4_TREE"
git diff --quiet -- \
  ':(glob)docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/*.dot' \
  ':(glob)docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/*.svg' \
  ':(glob)docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/*.png'
PYTHONDONTWRITEBYTECODE=1 python3 tests/test-one-human-agent-team-architecture-map.py
xmllint --noout "$MAP_SVG"
bash tests/run-focused.sh docs-context
git diff --check
```

Expected:

- eight map unittest cases PASS;
- valid XML;
- docs/context profile PASS, apart from the existing non-blocking Product Manager soft-budget warning;
- `git diff --check` exits `0`;
- the permanent map test resolves every named Markdown pointer and, once approved, both canonical map links as in-repository regular files;
- the exact 12 old R4 DOT/SVG/PNG tree entries match the frozen pre-map commit and have no worktree diff.

Inspect the Task 3 Markdown diff directly and verify: the canonical baseline remains the sole semantic and next-design authority; the map is accepted but non-normative; the current handoff points to the next allowed design step without authorizing implementation; and the four historical tombstones contain only stable rejected/superseded facts plus a canonical link. This is a bounded human document-governance review, not a shell assertion over natural-language Markdown.

- [ ] **Step 5: Run the broad quick regression and classify any unrelated failure honestly**

Run:

```bash
bash tests/run-all.sh --quick
```

Expected target after unrelated baseline repair: PASS. On the current baseline, two independent pre-map blockers are already evidenced: missing `docs/rule-runtime--team-readiness/acceptance-pack.json`, and a 40-step quick plan violating the runner contract's `<=36` budget. Do not repair, suppress, or reclassify either inside this visual scope. Confirm the new map gate remains `tier=full` and therefore does not increase the quick-step count; report the broad gate as blocked by those historical failures while retaining the passing map-specific and docs/context evidence. Any new failure touching the map files, test, full/docs gate-plan selection, syntax path, or document references blocks completion.

- [ ] **Step 6: Commit accepted visual governance**

Run:

```bash
set -euo pipefail
MAP_SVG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.svg"
MAP_PNG="docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/one-human-agent-team-architecture-map.png"
git diff --check
git status --short
git diff --quiet -- "$MAP_SVG" "$MAP_PNG"
git add \
  docs/superpowers/specs/assets/2026-08-03--one-human-agent-team-operating-architecture-l0/README.md \
  docs/superpowers/specs/2026-08-03--one-human-agent-team-operating-architecture-l0--design.md \
  docs/product-dirrctor-session.md \
  docs/superpowers/plans/2026-07-30--one-human-agent-operating-architecture-visual-redesign.md \
  docs/superpowers/specs/2026-07-30--one-human-agent-operating-architecture-visual-redesign--design.md \
  docs/superpowers/specs/2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md \
  docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/README.md
git diff --cached --quiet -- "$MAP_SVG" "$MAP_PNG"
git commit -m "docs: accept L0 agent team architecture map"
```

Expected: one governance-only commit; no map bytes change after the human-approved visual revision.

## Final Acceptance Evidence

Do not claim the map complete until all of these are current and direct:

1. structural map unittest PASS;
2. valid XML and deterministic 1920×1200 render;
3. full-scale, 1440-wide, and grayscale inspection PASS;
4. two fresh-context image-only reviews with no material semantic error;
5. one unbriefed Chinese business/product reader passes the timed 1440×900 cold-reader check;
6. explicit human owner semantic and visual approval of the exact committed candidate;
7. canonical and historical pointers synchronized;
8. docs/context focused gate PASS;
9. broad quick gate PASS, or its two known historical blockers proven unrelated and reported without weakening the completion claim;
10. clean post-commit worktree.

The completion claim is only: **the single Chinese macro architecture map is semantically and visually accepted as the human navigation projection of approved `L0-R3`.** It does not prove any Owner design, Skill, orchestration runtime, deployment capability, or `qft-tenants` delivery path.

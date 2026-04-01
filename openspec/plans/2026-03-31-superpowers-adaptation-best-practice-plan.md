# Superpowers Adaptation Best Practice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking and MUST include task-id tags like `[T1]`.

**Goal:** 把当前仓库从“社区正文 + 本地自由改写”的维护模式，收敛到“上游优先 + 薄适配 + 显式分叉 + 自动校验”的最佳实践模式。

**Architecture:** 以 `community/superpowers` 作为 upstream-aligned runtime 基线，以 `community-first` 的 wrapper/contract 承接默认链和本地 handoff，以 OpenSpec 的 proposal/design/tasks/verify/archive 语义作为概念来源并下沉到模板、contract 与 validator，而不是继续把 `community/openspec` 作为未来运行时真源。若 `community/openspec` 仍保留，只作为兼容库存或迁移过渡资产，不再承担未来编排职责。`shared/rules`、`shared/reference`、`contracts`、`tests` 负责组织治理与验证。执行顺序遵循“先止血、再分层、后迁移、最后自动化”的节奏，避免把脏状态直接制度化。

**Tech Stack:** Markdown docs, shell scripts, existing `tools/community/*`, `tests/*`, repo contracts, source lock file `community/SOURCES.yaml`

---

### Task 1: 建立可信基线并先止血

**Files:**
- Modify: `community/superpowers/skills/requesting-code-review/SKILL.md`
- Modify: `community/superpowers/skills/brainstorming/spec-document-reviewer-prompt.md`
- Modify: `community/superpowers/skills/subagent-driven-development/SKILL.md`
- Modify: `community/superpowers/skills/**`
- Modify: `docs/community-first/README.md`
- Modify: `README.md`
- Reference: `community/SOURCES.yaml`

- [ ] [T1] **Step 1: 全量扫描当前显性漂移点**

Run:
```bash
rg -n "Error 500|docs/superpowers/specs|docs/superpowers/plans|openspec/designs|openspec/plans" community/superpowers README.md docs/community-first
```

Expected:
- 能列出正文损坏文本
- 能列出旧路径残留
- 能列出新旧路径混用位置

- [ ] [T1] **Step 2: 修正文损坏与最明显的错误残留**

Action:
- 删除 `community/superpowers/skills/requesting-code-review/SKILL.md` 中的异常 `Error 500` 文本
- 把显然错误的乱码/误抓取内容全部恢复为正常正文

Expected:
- `requesting-code-review/SKILL.md` 不再包含任何非语义噪音

- [ ] [T1] **Step 3: 统一第一批路径口径**

Action:
- 记录当前计划期内的路径裁决：哪些路径是现行路径，哪些仅是历史兼容路径，哪些必须清理
- 把所有未声明的 `docs/superpowers/...` 示例替换、迁移，或明确纳入兼容清单
- 若存在暂时无法迁移的历史路径，必须在后续 machine-readable contract 中显式声明

Expected:
- 仓库内不存在“同一职责同时指向两套路径”的未说明状态

- [ ] [T1] **Step 4: 运行最小健康检查**

Run:
```bash
rg -n "Error 500|docs/superpowers/specs|docs/superpowers/plans" community/superpowers
```

Expected:
- 损坏文本为 0
- 历史路径残留仅保留在明确允许的兼容位置

### Task 2: 固化四层边界

**Files:**
- Modify: `README.md`
- Modify: `docs/community-first/README.md`
- Modify: `docs/superpowers-adaptation-boundary/research-report.md`
- Create or Modify: `docs/community-first/boundary-contract.md`

- [ ] [T2] **Step 1: 写出单一边界合同**

Content must define:
- `community/superpowers`：upstream-aligned runtime
- `community-first` wrapper/contract：默认链、handoff、本地状态机
- OpenSpec：proposal/design/tasks/verify/archive 工件语义来源，不作为未来运行时真源
- `community/openspec`：兼容库存或迁移过渡资产；若保留，必须明确其非主运行时身份
- `shared/rules` / `shared/reference` / `contracts` / `tests`：组织治理与验证

Expected:
- 仓库内存在一份单一真源文档，能回答“什么该放哪”

- [ ] [T2] **Step 2: 把 README 和 community-first 总览对齐到该边界**

Action:
- `README.md` 只保留高层定位
- `docs/community-first/README.md` 只描述默认链与运行面，不再混写 implementation detail

Expected:
- 新人只看 README + boundary contract 就能理解四层分工

- [ ] [T2] **Step 3: 标记禁止继续混写的位置**

Action:
- 在边界合同中明确写出：
  - 不再把本地 handoff 直接写进 upstream skill 正文
  - 不再把组织治理条款直接写进 `community/superpowers` 正文
  - 不再把 `community/openspec` 作为未来默认编排真源

Expected:
- 后续新增改动有清晰落点，不靠口头约定

### Task 3: 外移深分叉

**Files:**
- Modify: `community/superpowers/skills/brainstorming/SKILL.md`
- Modify: `community/superpowers/skills/brainstorming/spec-document-reviewer-prompt.md`
- Modify: `community/superpowers/skills/writing-plans/SKILL.md`
- Modify: `community/superpowers/skills/subagent-driven-development/SKILL.md`
- Modify: `community/superpowers/skills/requesting-code-review/SKILL.md`
- Create or Modify: `contracts/community-first-chain.yaml`
- Modify: `docs/community-first/boundary-contract.md`

- [ ] [T3] **Step 1: 识别需要外移的深分叉语义**

Must identify at least:
- `brainstorming -> opsx:*` 或其他本地 handoff 语义
- `writing-plans` 的 `tasks.md` 强一致契约
- community-first 默认链状态机
- prompt 模板和示例中的历史路径/历史真源残留
- `community/openspec` 现有资产的最终去向：兼容保留、冻结，或后续归档

Expected:
- 有一份“深分叉清单”，不再与“中文化差异”混在一起

- [ ] [T3] **Step 2: 把默认链与 handoff 移到 wrapper/contract**

Action:
- `community/superpowers` 尽量回到 upstream-ish 语义
- 本地链路改由 `docs/community-first/boundary-contract.md` 与 `contracts/community-first-chain.yaml` 明确声明
- 若仍保留 `community/openspec` 资产，必须在边界合同中标记为兼容库存而非主编排入口

Expected:
- `community/superpowers` 不再承担仓库默认链编排职责
- 默认链的单一真源只存在于 wrapper/contract

- [ ] [T3] **Step 3: 把 `tasks.md` 强一致下沉到本地工件层**

Action:
- `tasks.md`、`task-id`、一致性校验器属于本地工件模型
- 不再让 `writing-plans` 正文承担主要规范定义职责
- 同步清理 prompt 模板和示例里的旧路径、旧真源暗示

Expected:
- 计划技能回归“如何写计划”
- 强一致契约回到 `openspec` / contract / validator

### Task 4: 建立可再生机制

**Files:**
- Modify: `tools/community/sync_canonical_from_upstream.py`
- Modify: `tools/community/render_canonical.py`
- Modify: `tools/community/source_lock_check.py`
- Modify: `community/SOURCES.yaml`
- Create or Modify: `contracts/superpowers-boundary.yaml`

- [ ] [T4] **Step 1: 定义“上游基线 + 本地 overlay”模型并落机器可读真源**

Action:
- upstream baseline 来源仅由 `community/SOURCES.yaml` 指定
- 中文化、metadata、tool mapping、manual-only 策略进入 overlay
- 创建 `contracts/superpowers-boundary.yaml`，至少定义：
  - `canonical_targets`
  - `declared_forks`
  - `allowed_legacy_paths`
  - `overlay_files`

Expected:
- 能清楚区分“这是 upstream 内容”还是“这是本地覆盖”
- T5 可以基于同一份 YAML 合同编写测试

- [ ] [T4] **Step 2: 让工具能检测未声明分叉**

Run target:
```bash
python3 tools/community/source_lock_check.py
```

Expected:
- 工具能指出哪些文件偏离了锁定 ref
- 偏离若未在 `contracts/superpowers-boundary.yaml` 的 overlay 或分叉清单声明，则视为异常

- [ ] [T4] **Step 3: 为中文 canonical 增加再生成路径**

Action:
- 明确哪些文件可自动渲染
- 哪些文件必须人工维护但要有校验
- 历史兼容路径若仍存在，必须来自 `allowed_legacy_paths`

Expected:
- 后续升级 upstream 时，不需要人工全文比对所有 skill

### Task 5: 建立自动回归门禁

**Files:**
- Modify: `tests/test-community-tools.sh`
- Modify: `tests/test-runtime-integrity.sh`
- Create or Modify: `tests/test-superpowers-boundary.sh`
- Create or Modify: `tests/test-community-first-boundary.sh`

- [ ] [T5] **Step 1: 增加正文完整性检查**

Must check:
- 异常噪音文本
- 非法占位残留
- 非预期抓取内容

Expected:
- 正文损坏不能再静默进入主分支

- [ ] [T5] **Step 2: 增加路径一致性检查**

Must check:
- skill 正文中的路径是否符合当前合同
- 同一职责是否出现未在 `contracts/superpowers-boundary.yaml` 声明的双路径体系

Expected:
- 历史路径漂移能被直接发现

- [ ] [T5] **Step 3: 增加深分叉边界检查**

Must check:
- `community/superpowers` 中是否继续混入本地 workflow state machine
- 本地 handoff 是否只出现在 `docs/community-first/boundary-contract.md`、`contracts/community-first-chain.yaml` 或 `contracts/superpowers-boundary.yaml` 声明位置

Expected:
- 分层一旦建立，后续不会再次无声回退

- [ ] [T5] **Step 4: 运行回归并确认通过**

Run:
```bash
bash tests/run-all.sh
```

Expected:
- 相关新增测试通过
- 既有 community/runtime 相关测试不回归

## Execution Notes

- 先做 T1，再做 T2；没有边界合同前，不要进入大规模迁移。
- T3 是本计划的核心，必须以“外移语义”为原则，不允许只是换个位置继续复制同样的混写。
- T4 与 T5 可以并行准备，但在 T3 收口前不要宣称完成。
- 所有“完成”声明都必须以测试和扫描输出为证据。

## Recommended Rollout

1. 第 1 周：完成 T1 + T2  
2. 第 2 周：完成 T3  
3. 第 3 周：完成 T4 + T5  
4. 第 4 周：做一次上游升级演练，验证新机制是否真的降低维护成本

## Success Criteria

- `community/superpowers` 里剩下的改动大多是中文化、来源标记、平台适配
- 默认链逻辑只在 contract/wrapper 中有单一真源
- `community/openspec` 若保留，只被标记为兼容库存或迁移过渡资产，不再承担未来编排职责
- `tasks.md` 强一致定义只在本地工件层出现，不再多处散落
- 任一正文损坏、路径漂移、未声明分叉都能被测试阻断
- 新人只看少量入口文档就能理解仓库分层

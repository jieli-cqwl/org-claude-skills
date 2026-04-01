# Small Chain 最佳实践重构方案

## Context

当前 superpowers（10 个 skill）和 openspec（5 个 skill）两套体系并存，存在多处职责重叠：执行重叠（SDD vs apply-change）、探索重叠（brainstorming vs explore）、执行方式二选一（executing-plans vs SDD）、openspec CLI 运行时依赖、tasks-plan 双状态持有。

**目标**：融合两套体系为一条 6 步无重叠的半自动化链路（small chain）。superpowers 负责执行，openspec 的文档沉淀概念融入其中（去 CLI 依赖）。本次只重构 small chain，标准链同步对齐规范但不改流程。

## 对齐的核心决策

| 决策 | 结论 | 理由 |
|------|------|------|
| propose 独立 skill？ | 不需要，brainstorming 直接输出 design.md | 同会话上下文共享，渐进式加载模板 reference，省上下文预算 |
| executing-plans？ | 直接废弃 | 减少上下文噪音，SDD 唯一执行方式 |
| 链路命名 | community-first → **small chain** | 更简洁直观 |
| 重构范围 | 只改 small chain，标准链同步对齐规范 | 先跑通验证再推广 |
| brainstorming 产出 | 直接输出 design.md（渐进式加载模板） | 无中间 draft/brief，零冗余 |
| tasks.md 生成时机 | writing-plans 同时产出 tasks.md + plan.md | tasks.md 的 AC 需要基于 design.md 细节定义 |
| proposal.md？ | 合并到 design.md 的 Why/Scope section | 轻量链不需要独立 proposal |
| skill 内容语言 | 英文原文 + 轻量适配，不翻译 | LLM 对英文指令遵循精度更高，避免翻译歧义 |
| 工件内容语言 | design.md/tasks.md 用中文，plan.md 英文为主 | design 给人看，plan 给 LLM 子代理执行 |
| 废弃 skill 处理 | 彻底删除，不保留 deprecated 标记 | 不留噪音，减少上下文干扰 |
| SKILL 编写格式 | 本次一起统一（dot 流程图 + 标题换行子弹点 + 加粗稀缺性） | best-practice 第 10 节规范一并落地 |
| 文档质量保障 | 三层自审内建：brainstorming 自审 design.md + writing-plans 自审 tasks.md/plan.md + verify 校验实现一致性 | 每层质量保障内建在 skill 里，不靠人工检查点 |

---

## 一、统一流程链路（6 步）

```
brainstorming（需求澄清 + 方案探索 + 输出 design.md）
    |  用户批准设计（HARD-GATE）         ← 人工介入点 1
    |  渐进式加载 design 模板 reference，按模板输出 design.md
    |  自动调用
    v
writing-plans（读 design.md，输出 tasks.md + plan.md）
    |  内置自审：映射完整性 + AC 可验证性 + design 覆盖度 + 占位符扫描
    |  自动调用
    v
using-git-worktrees（创建隔离工作分支，可选）
    |  自动调用
    v
subagent-driven-development（逐 task 执行 + 两阶段审查 + 更新 tasks.md）
    |  内置：TDD + code-review + verification-before-completion
    |  全部 task 完成后自动 → finishing-a-development-branch
    |  自动调用
    v
verify-change（分级报告：CRITICAL / WARNING / SUGGESTION）  ← 新建
    |  无 CRITICAL → 自动推荐 archive
    |  有 CRITICAL → 自动阻断，等人工处理  ← 自动兜底
    v
archive（归档 + CHANGELOG 追加）         ← 人工介入点 2（确认归档）
```

### 自动流转原则

- **人工介入点 2 个**：设计批准（brainstorming HARD-GATE）+ 归档确认（archive）
- **自动兜底 1 个**：verify 发现 CRITICAL 时自动阻断
- **中间环节全自动**：brainstorming 批准后 → writing-plans → SDD → finishing → verify 一气呵成
- **质量保障内建**：每个 skill 自身的约束（writing-plans 模板校验、SDD 两阶段审查、verify 分级报告）负责质量，不靠人工检查点

### 重叠消解

| 重叠 | 保留 | 废弃 | 理由 |
|------|------|------|------|
| brainstorming vs openspec-explore | brainstorming | openspec-explore | HARD-GATE "只思考不实现"已覆盖 |
| SDD vs openspec-apply-change | SDD | openspec-apply-change | 执行收口在 superpowers，SDD 有两阶段审查 |
| SDD vs executing-plans | SDD | executing-plans（直接废弃） | 减少上下文噪音，统一执行方式 |

### 自动流转

| 衔接点 | 方式 | 实现机制 |
|--------|------|---------|
| brainstorming → writing-plans | 自动调用 | SKILL.md 终态直接调用 Skill tool |
| writing-plans → worktree → SDD | 自动调用 | 链式 Skill tool 调用 |
| SDD 内部每 task | 自动 | 控制器自动派发子代理 + 审查 + 更新 tasks.md |
| SDD → finishing | 自动 | SDD 内置流转 |
| finishing → verify | 自动调用 | Skill tool 调用 |
| verify → archive | 无 CRITICAL: 自动推荐 / 有 CRITICAL: 阻断 | verify 终态判断分级后决定 |
| archive | 人工确认后执行 | 归档是状态变更 |

---

## 二、文档工件体系

### 2.1 目录结构

```
docs/
  {feature}/                              # 英文 kebab-case
    YYYY-MM-DD-{change}/                  # 日期前缀 change 目录
      design.md                           # why + how（设计真源）
      tasks.md                            # 验收清单（唯一进度真源）
      plan.md                             # 执行计划（引用 task-id，不持有完成状态）
    CHANGELOG.md                          # feature 级变更日志（派生摘要）
  archive/                                # 全局归档区
    {feature}/                            # 保持原结构
```

### 2.2 工件产出关系

```
brainstorming 产出: design.md（设计真源，含 why/scope/approach/decisions）
    ↓ design.md 作为输入
writing-plans 产出: tasks.md（验收清单）+ plan.md（执行计划）
    ↓ plan.md + tasks.md 作为输入
SDD 执行: 逐 task 实现，更新 tasks.md checkbox
```

### 2.3 引用规则

- plan.md 每条 step 必须带 `[task-id]` 引用 tasks.md
- tasks.md 中每个 task 必须被 plan.md 引用（双向覆盖）
- **plan.md 不持有完成状态**（不用 `- [ ]` checkbox）
- **tasks.md 是唯一完成状态真源**

### 2.4 工件模板

**design.md**（brainstorming 产出，中文，消费者：人 + LLM）
```markdown
# Design — {change-name}
创建日期: YYYY-MM-DD

## Why
{为什么要做这个变更，1-3 句话}

## Scope
- 范围内: {做什么}
- 不做: {明确排除什么}

## Approach
{选定方案的技术描述}

## Alternatives Considered
| 方案 | 优势 | 劣势 | 结论 |
|------|------|------|------|

## Key Decisions
- D1: {决策} — 理由: {why}

## Success Criteria
- {可验证的成功标准}
```

**tasks.md**（writing-plans 产出，中文，消费者：LLM spec-reviewer）
```markdown
# Tasks — {change-name}
创建日期: YYYY-MM-DD
关联 plan: ./plan.md

## 验收清单

- [ ] T1 {交付物描述}
  - AC: {可验证标准，如：运行 `npm test` 全部通过}
  - AC: {可验证标准，如：`/api/login` 返回 200 且 body 含 token}
- [ ] T2 {交付物描述}
  - AC: {可验证标准}

## 完成定义

所有 task 勾选完成 = 可进入 verify 阶段。
```

**plan.md**（writing-plans 产出，英文为主，消费者：LLM 子代理）
```markdown
# {Change Name} Implementation Plan

**Goal:** {one sentence}
**Tech Stack:** {key technologies}

---

### Task 1: {Component Name} [T1]

**Files:**
- Create: `src/auth/oauth.ts`
- Modify: `src/routes/login.ts:23-45`

1. [T1] Write failing test: ...
2. [T1] Implement: ...
3. [T1] Verify: run `npm test -- --grep oauth`
4. [T1] Commit

### Task 2: {Component Name} [T2]
...
```

---

## 三、Skill 改造清单

### 3.1 需要修改的 Skill（按依赖顺序）

**Step 1: brainstorming** (`community/superpowers/skills/brainstorming/SKILL.md`)
- 保留英文原文，轻量适配：
  - 输出路径：`openspec/designs/*-draft.md` → `docs/{feature}/YYYY-MM-DD-{change}/design.md`
  - 终态：从"调用 writing-plans" 保持不变（去掉了 propose 中间环节）
  - 去掉对 openspec 目录的引用
  - 增加：用户批准设计后，渐进式加载 design 模板 reference，按模板输出 design.md
  - 修订翻译歧义（"视觉伴侣"→"可视化助手"、"承诺"→"已 commit 到"等）

**Step 2: writing-plans** (`community/superpowers/skills/writing-plans/SKILL.md`)
- 保留英文原文，轻量适配：
  - 输入路径：从 `openspec/designs/` → `docs/{feature}/YYYY-MM-DD-{change}/design.md`
  - 输出路径：tasks.md + plan.md 到同一 change 目录
  - 新增职责：同时产出 tasks.md（从 design.md 提取可验证交付物 + AC）
  - plan.md 去掉 `- [ ]` checkbox，改为编号列表
  - plan checklist 必须引用 task-id
  - 执行交接去掉 executing-plans 选项，仅推荐 SDD
  - **新增自审步骤**（产出后、流转前自动执行，发现问题自动修复）：
    1. task-plan 映射完整性：tasks.md 每个 T 都被 plan.md 引用，plan.md 每个 [T] 都在 tasks.md 中存在
    2. AC 可验证性：每个 AC 包含可执行验证手段（命令/文件检查/API），无"用户确认"等主观判定
    3. design.md 覆盖度：design.md success criteria 是否都有对应 task
    4. 占位符扫描：无 TBD/TODO/待定

**Step 3: subagent-driven-development** (`community/superpowers/skills/subagent-driven-development/SKILL.md`)
- 保留英文原文，轻量适配：
  - 读取 plan.md + tasks.md，建立 task-id 映射
  - implementer-prompt 注入 tasks.md 更新职责
  - 控制器在两阶段审查通过后更新 tasks.md 对应 task 为 `[x]`
  - 去掉对 executing-plans 作为替代的引用

**Step 4: 新建 verify-change** (`community/superpowers/skills/verify-change/SKILL.md`)
- 英文编写，吸收 openspec-verify-change 的分级报告概念
- 不依赖 CLI，直接读取 `docs/{feature}/YYYY-MM-DD-{change}/` 下的工件
- 校验维度：
  1. tasks.md 完成度（是否还有 `- [ ]`）
  2. task-plan 映射完整性（双向覆盖）
  3. design.md success criteria 与实现对照
- 输出分级报告：CRITICAL（阻断归档）/ WARNING / SUGGESTION

**Step 5: 新建 archive** (`community/superpowers/skills/archive/SKILL.md`)
- 英文编写，吸收 openspec-archive-change 的归档闭环概念
- 归档前检查：tasks.md 所有 task 已完成 + verify 无 CRITICAL
- 目录移动：`docs/{feature}/YYYY-MM-DD-{change}/` → `docs/archive/{feature}/YYYY-MM-DD-{change}/`
- CHANGELOG 追加（从 design.md 的 Why/Scope 提取）

**Step 6: using-superpowers** (`community/superpowers/skills/using-superpowers/SKILL.md`)
- 链路流程图更新，反映 6 步链路（去掉 propose、executing-plans）

**Step 7: 合同与配置更新 + 删除 + 格式统一**
- `contracts/community-first-chain.yaml` → 重命名为 `contracts/small-chain.yaml`，更新链路
- `contracts/superpowers-boundary.yaml` → 更新 overlay_files
- `check_task_plan_consistency.py` → 迁移到 `community/superpowers/skills/verify/scripts/`，改为单真源 + 映射完整性检查
- 彻底删除 3.2 中列出的所有废弃 skill 目录和文件
- 清理所有引用废弃 skill 的文档和配置（contracts、SOURCES.yaml 等）
- **修改 install.sh**（评审发现的严重问题）：
  1. 移除第 107-108 行 openspec skills 目录存在断言
  2. 移除或条件化 `ensure_openspec_cli_ready` 调用（第 1269 行附近）
  3. 移除或条件化 `copy_openspec_skills` 函数调用（第 502、529 行）
  4. 移除第 1174 行 Quick Check 中对 `openspec-propose/SKILL.md` 的断言
  5. 更新安装逻辑：新建的 verify/archive skill 需要被正确复制到安装目标
- **修改测试套件**（评审发现的严重问题）：
  1. `tests/test-runtime-integrity.sh`：移除第 96-97、106-107 行对 openspec skill 的断言，新增对 verify/archive skill 的断言
  2. `tests/test-install-smoke.sh`：移除第 30-31、38-39、72-73 行对 openspec skill 的断言，新增对新 skill 的断言
- **修改 tools/community/sync_canonical_from_upstream.py**：
  1. 移除第 31-34 行 openspec skills 列表引用
  2. 移除第 197-199 行 openspec-propose 路径引用
  3. 移除第 400-432 行 `sync_openspec` 函数
- **修改 finishing-a-development-branch SKILL.md**：
  1. 移除第 199 行对 `superpowers:executing-plans` 的引用
- **新建 design 模板 reference 文件**（评审发现缺失）：
  1. 创建 `community/superpowers/skills/brainstorming/references/design-template.md`
  2. 内容：design.md 的模板结构（Why/Scope/Approach/Alternatives/Key Decisions/Success Criteria）
  3. 在 brainstorming SKILL.md 中添加渐进式加载此 reference 的指令

**Step 8: SKILL 编写格式统一**（best-practice 第 10 节规范）
- 对本次修改/新建的所有 skill 统一应用：
  1. 流程图统一为 **Graphviz dot**（不用 Mermaid）——LLM 解析准确性更高
  2. 步骤描述格式统一为**编号标题 + 换行 + 子弹点**，禁止单行长句
  3. 加粗使用**稀缺性原则**：全文加粗行数 ≤ 10%，仅用于 HARD-GATE/STOP/终止条件

### 3.2 删除的 Skill（彻底删除，不保留文件）

| Skill | 删除理由 |
|-------|---------|
| `community/openspec/skills/openspec-explore/` | 被 brainstorming 覆盖 |
| `community/openspec/skills/openspec-apply-change/` | 执行收口在 SDD |
| `community/openspec/skills/openspec-propose/` | brainstorming 直接输出 design.md |
| `community/openspec/skills/openspec-verify-change/` | 被新 verify 替代（保留 scripts/check_task_plan_consistency.py 迁移到新位置） |
| `community/openspec/skills/openspec-archive-change/` | 被新 archive 替代 |
| `community/superpowers/skills/executing-plans/` | 直接废弃，SDD 唯一执行方式 |
| `community/openspec/claude/commands/opsx/` | 对应 openspec skill 的 slash commands，一并删除 |

### 3.3 不变的 Skill

test-driven-development、verification-before-completion、requesting-code-review、finishing-a-development-branch、using-git-worktrees — 确认路径兼容即可，无需修改。

---

## 四、实施顺序

```
Step 1: 修改 brainstorming（路径 + 终态 + design.md 模板输出）
  ↓
Step 2: 修改 writing-plans（新增 tasks.md 产出 + plan.md 格式改造）
  ↓
Step 3: 修改 SDD（tasks.md 联动 + 去 executing-plans 引用）
  ↓
Step 4: 新建 verify
  ↓
Step 5: 新建 archive
  ↓
Step 6: 更新 using-superpowers 链路图
  ↓
Step 7: 合同更新 + 彻底删除废弃 skill + 清理引用
  ↓
Step 8: SKILL 编写格式统一（dot 流程图 + 标题换行子弹点 + 加粗稀缺性）
  ↓
Step 9: 系统性评审（全链路一致性检查 + 交叉引用验证）
  ↓
Step 10: 验收流程（用"登录+首页"需求跑完整 6 步链路）
  ↓
Step 11: 修复评审/验收中发现的问题（如有）
  ↓
Step 12: 提交到远程仓库 + 安装到本地
```

---

## 五、验证方案

### 5.1 每步验证

| 验证项 | 方法 |
|--------|------|
| 无 CLI 依赖 | `grep -r 'openspec ' community/superpowers/skills/{verify-change,archive}/` 确认无 CLI 调用 |
| brainstorming 输出正确 | 手动触发，检查 design.md 写入 `docs/{feature}/` 且格式符合模板 |
| writing-plans 双产出 | 检查 tasks.md + plan.md 同时存在，task-id 双向映射完整 |
| writing-plans 自审 | 构造含不可验证 AC 的 case，确认自审能检出并修复 |
| plan 不持有完成状态 | `grep -c '\- \[ \]' plan.md` 确认为 0 |
| SDD tasks.md 联动 | 执行一个 task 后检查 tasks.md 对应项被勾选 |
| verify-change 分级报告 | 构造含未完成 task 的 case，确认输出 CRITICAL |
| archive 目录正确 | 触发后确认文件移至 `docs/archive/` |

### 5.2 端到端验证

用一个小 feature 跑完整 6 步链路：
brainstorming → writing-plans → SDD → finishing → verify-change → archive

确认：
1. 每步自动推荐下一步
2. 工件正确沉淀到 `docs/{feature}/YYYY-MM-DD-{change}/`
3. tasks.md 进度实时更新
4. verify 产出分级报告
5. archive 正确归档 + CHANGELOG 追加

### 5.3 回归测试

- 更新 `tests/test-superpowers-boundary.sh`（overlay_files 断言）
- 重命名并更新 `tests/test-community-first-boundary.sh` → `tests/test-small-chain-boundary.sh`
- 新增 `tests/test-no-cli-dependency.sh`（确认新 skill 无 CLI 调用）
- 新增 `tests/test-chain-completeness.sh`（确认 6 步链路完整性）

---

## 六、关键文件清单

| 文件 | 操作 |
|------|------|
| `community/superpowers/skills/brainstorming/SKILL.md` | 修改（路径 + design.md 模板输出 + 格式统一） |
| `community/superpowers/skills/writing-plans/SKILL.md` | 修改（新增 tasks.md + plan.md 格式 + 自审 + 格式统一） |
| `community/superpowers/skills/subagent-driven-development/SKILL.md` | 修改（tasks.md 联动 + 格式统一） |
| `community/superpowers/skills/verify-change/SKILL.md` | **新建**（含 scripts/check_task_plan_consistency.py 迁移） |
| `community/superpowers/skills/archive/SKILL.md` | **新建** |
| `community/superpowers/skills/using-superpowers/SKILL.md` | 修改（链路图 + 格式统一） |
| `community/superpowers/skills/finishing-a-development-branch/SKILL.md` | 修改（移除 executing-plans 引用） |
| `community/superpowers/skills/brainstorming/references/design-template.md` | **新建**（design.md 模板 reference） |
| `contracts/small-chain.yaml` | **新建**（替代 community-first-chain.yaml） |
| `contracts/superpowers-boundary.yaml` | 修改（新 overlay） |
| `community/openspec/skills/openspec-explore/` | **删除** |
| `community/openspec/skills/openspec-apply-change/` | **删除** |
| `community/openspec/skills/openspec-propose/` | **删除** |
| `community/openspec/skills/openspec-verify-change/` | **删除**（迁移 scripts/ 后） |
| `community/openspec/skills/openspec-archive-change/` | **删除** |
| `community/openspec/claude/commands/opsx/` | **删除** |
| `community/superpowers/skills/executing-plans/` | **删除** |
| `contracts/community-first-chain.yaml` | **删除**（被 small-chain.yaml 替代） |
| `install.sh` | 修改（移除 openspec 硬编码依赖，适配新 skill） |
| `tests/test-runtime-integrity.sh` | 修改（移除 openspec 断言，新增 verify/archive 断言） |
| `tests/test-install-smoke.sh` | 修改（移除 openspec 断言，新增新 skill 断言） |
| `tools/community/sync_canonical_from_upstream.py` | 修改（移除 openspec 引用和 sync_openspec 函数） |
| `community/SOURCES.yaml` | 修改（移除 openspec skills 引用） |

---

## 七、系统性评审（Step 9）

实施完成后，执行全链路一致性检查：

1. **引用完整性**：所有 skill 中引用的其他 skill、reference、路径是否都存在
2. **链路连通性**：small-chain.yaml 中声明的每个 skill 都存在且 inputs/outputs 匹配
3. **无残留引用**：grep 确认无任何文件引用已删除的 skill（openspec-explore、executing-plans 等）
4. **overlay 一致性**：superpowers-boundary.yaml 的 overlay_files 列表与实际文件一致
5. **格式合规**：所有修改/新建 skill 符合 SKILL 编写格式规范（dot 流程图、标题换行子弹点、加粗 ≤ 10%）
6. **模板可用性**：design.md / tasks.md / plan.md 模板 reference 文件存在且可被渐进式加载

---

## 八、验收流程（Step 10）

用"登录+首页"需求跑完整 6 步链路验收：

**需求**：用户登录成功后跳转到首页

**验收检查点**：
1. brainstorming 输出 `docs/user-auth/YYYY-MM-DD-login-home/design.md`，格式符合模板
2. writing-plans 输出 tasks.md + plan.md，自审通过
3. SDD 逐 task 执行，tasks.md 自动更新
4. finishing 完成收尾
5. verify-change 产出分级报告（预期无 CRITICAL）
6. archive 归档到 `docs/archive/`，CHANGELOG 追加

---

## 九、部署（Step 12）

1. 提交所有变更到远程仓库
2. 运行 `install.sh` 安装到本地 `~/.claude/`
3. 确认安装后 skill 列表正确（无废弃 skill，新 skill 可用）

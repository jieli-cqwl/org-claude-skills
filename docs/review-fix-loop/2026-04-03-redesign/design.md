# 评审修复 Skill 重设计

## Why

现有 review-fix-loop skill 存在三个根本问题：代码和文档评审混在一个 skill 里（评审标准、验证方式、收敛逻辑完全不同）；绕过 codex 插件自造 JSON schema 和校验脚本增加了不必要的复杂度；采用固定维度清单评审而非 leader 模式动态推断目标。需要系统性重写为两个独立 skill，同时淘汰已不适用的 codex-doc-review skill。

## Scope

**In scope:**
- 新建 code-review-fix skill（代码评审修复循环）
- 新建 doc-review-fix skill（文档评审修复循环）
- 从 codex-doc-review 迁移 DECEPTION 检测模式
- 删除 review-fix-loop、codex-doc-review、codex-doc-reviewer
- 清理所有对旧 skill 的引用（测试、配置、文档）

**Out of scope:**
- codex 插件本身——第三方，只消费不修改
- `/review` shared skill——纯评审工具，定位不同

**基线校正：** 原设计假设 `review-fix-loop-protocol.md`、`review-iteration-protocol.md`、`team-review-protocol.md` 仍存在于仓库并被其他 skill 引用。经核对，这三个文件在当前仓库中**均已不存在**，无需作为 Out of scope 保护。淘汰计划中对应的"不动"条目同步移除。

## Approach

### 整体架构

两个完全独立的 skill，不共享代码和协议：

```
claude/skills/code-review-fix/
  SKILL.md

claude/skills/doc-review-fix/
  SKILL.md
  references/
    deception-patterns.md
```

### 共同交互模型

两个 skill 共享相同的交互模式：

1. **上下文分析**：读取 git 状态、改动文件类型和范围
2. **AskUserQuestion**：skill 作为 leader 汇报评审计划（评审方式、目标、收敛标准），用户确认或微调
3. **Baseline 保护**（详见下方完整语义）
4. **评审→修复→重审循环**：直到通过或触发终止条件
5. **恢复 Baseline**（详见下方恢复策略）
6. **最终报告**：结果 + 轮次 + 改动文件 + 剩余 findings（如有）+ baseline 恢复状态

### Baseline 保护与恢复语义

**进入时：**
- 记录 `baseline_ref = $(git rev-parse HEAD)`
- working tree dirty → `git stash push -m "review-fix-baseline-$(date +%s)"`，记录 `stash_ref`
- working tree clean → `stash_ref = null`
- 有 staged changes → 先 `git stash push --keep-index` 保护 staged，记录 `staged_stash_ref`

**循环中：**
- 每轮修复产生的改动由 skill 直接 stage + commit（message 含轮次标识）
- 循环中新增的临时文件（如评审 JSON 中间产物）在每轮结束时清理

**退出时（正常终止、达到最大轮次、不收敛）：**
- 所有修复 commit 已在分支上，无需额外操作
- 若 `stash_ref != null`：执行 `git stash pop`
  - pop 成功 → 报告"用户原始改动已恢复"
  - pop 冲突 → **不自动解决**，报告冲突文件列表，提示用户手动处理，输出 `git stash show stash@{0}` 帮助用户定位
- 若 `staged_stash_ref != null`：同上逻辑恢复 staged changes

**退出时（用户中止 / 异常终止）：**
- 保留当前 working tree 状态不做任何恢复操作
- 报告 `stash_ref` 和 `baseline_ref`，提示用户可通过 `git stash pop` 或 `git reset --soft <baseline_ref>` 手动恢复
- 禁止在异常路径上执行 `git reset --hard` 或 `git checkout .`

### 异常矩阵（fail-close）

所有异常场景的默认行为：**终止当前 run、报告原因、保留现场、不继续修复、不静默切换路径。**

| 异常场景 | 触发条件 | 终止行为 | 保留证据 |
|----------|----------|----------|----------|
| 评审工具不可用 | `codex:adversarial-review` 插件未安装、`codex exec` 返回非零退出码、网络超时 | 立即终止，报告工具状态 | 工具版本、退出码、stderr |
| 输出非 JSON / 缺关键字段 | JSON parse 失败，或缺少 `verdict`/`findings` 字段 | 立即终止，报告原始输出前 500 字符 | 原始输出保存为 `.review-fix-raw-output.json` |
| finding.path 不可定位 | `path` 对应文件不存在或 `line` 超出文件行数 | 跳过该 finding 并标记为 `skipped:unlocatable`，不影响其他 findings 修复 | 标记在最终报告的 skipped findings 列表中 |
| stash 冲突 | `git stash pop` 返回非零（合并冲突） | 终止恢复流程，报告冲突文件列表 | `stash_ref`、冲突文件列表、`git stash show` 输出 |
| 验证命令失败 | 自动发现的验证命令（test/lint）返回非零 | 记录失败但继续下一轮评审（验证失败不等于修复失败） | 验证命令、退出码、stderr 前 200 行 |
| 验证命令发现错误 | 自动检测到的命令本身不合法或不存在 | AskUserQuestion 要求用户提供正确的验证命令，用户拒绝则跳过验证步骤并在报告中标注 | 原始检测结果 |
| 用户中止 | 用户在任意阶段中断 | 立即停止，不做任何恢复操作 | `baseline_ref`、`stash_ref`、当前轮次、已完成的修复 commit 列表 |
| 超时 | 单轮评审超过 5 分钟 / 单轮修复超过 10 分钟 | 终止当前轮，进入报告阶段 | 超时阶段、已完成部分 |

**路径切换规则：**
- codex 路径失败 → **禁止**静默切到自评审路径。报告 codex 失败原因，AskUserQuestion 询问用户是否改用自评审。
- 自评审路径失败 → **禁止**静默切到 codex 路径。同上。
- 用户选择的评审方式在整个 run 内保持不变，除非用户显式要求切换。

### 环境适配

每次启动通过 AskUserQuestion 让用户选择评审方式，不做自动检测：

| 选项 | 说明 |
|------|------|
| codex 评审 | 调用 codex 做跨模型对抗评审 |
| 自评审 | 启动 agent 做评审，提供视角隔离 |

### code-review-fix 详细设计

**用户调用**：`/code-review-fix [focus ...]`

**评审引擎**：
- codex 路径：调用 `/codex:adversarial-review --scope auto --wait "${focus_text}"`（通过 openai-codex 插件的 `codex-companion.mjs` 执行）。插件提供完整的 adversarial prompt（含 7 项攻击面、置信度校准、grounding 约束）和正式 JSON Schema 校验，输出结构化 findings。leader 的评审重点通过 focus 文本传递。
- 自评审路径：启动 agent，输入 git diff + leader 目标 + 等效攻击面指令，输出必须符合统一 Finding 格式。

**外部依赖契约（codex:adversarial-review）：**
- 来源：openai-codex 插件，入口 `~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs`
- 调用：`/codex:adversarial-review [--wait|--background] [--base <ref>] [--scope <auto|working-tree|branch>] [focus text]`
- 输出 schema（`schemas/review-output.schema.json`）：
  ```json
  {
    "verdict": "approve | needs-attention",
    "summary": "ship/no-ship 评估",
    "findings": [{
      "severity": "critical | high | medium | low",
      "title": "finding 标题",
      "body": "详细描述",
      "file": "文件路径",
      "line_start": 1,
      "line_end": 5,
      "confidence": 0.85,
      "recommendation": "修复建议"
    }],
    "next_steps": ["后续建议"]
  }
  ```
- 空结果语义：`verdict=approve` 且 `findings=[]` 视为本轮通过
- 超时：单次调用 300 秒，超时按异常矩阵处理
- 不可用：插件未安装或命令执行失败，按异常矩阵处理，禁止静默降级
- 另有 `codex review` CLI 内置命令（支持 `--uncommitted`、`--base`、`--commit`）作为备用路径

**Leader 推断逻辑**：skill 分析改动文件名、模块、改动量，推断评审重点（如改了 auth 模块→重点关注认证安全）。推断结果在 AskUserQuestion 中展示，用户可修正。

**修复策略**：
- 只修复 high 及以上 severity 的 findings
- 按文件分组，同文件内按 `line_start` 降序修复（避免行号偏移）
- 每轮修复后执行项目验证命令（测试/lint/type-check，LLM 从项目结构自动检测，AskUserQuestion 中展示确认）

**收敛标准**：
- 通过：high+ findings == 0 且验证通过
- 未通过：达到最大轮次（5）
- 不收敛：连续 2 轮 high+ findings 数量不减少

**最终报告**：
```
=== 代码评审修复完成 ===
结果：通过 | 未通过 | 不收敛
总轮次：N
各轮统计：[R1: 5 findings(3H/2M) → R2: 1 finding(1H) → R3: 0 findings]
改动文件：[file1, file2, ...]
验证命令：<command> (exit 0)
基线：baseline_ref=abc1234, stash_ref=def5678 | 无 stash
恢复状态：stash pop 成功 | 冲突(files: ...) | 无需恢复
剩余 findings：[完整列表，含 non-blocking 摘要]
跳过的 findings：[skipped:unlocatable 列表（如有）]
```

### doc-review-fix 详细设计

**用户调用**：`/doc-review-fix [文档路径或 focus ...]`

**与代码 skill 的关键差异**：

| 维度 | code-review-fix | doc-review-fix |
|------|----------------|----------------|
| 评审引擎（codex） | `/codex:adversarial-review`（插件命令，正式 JSON Schema） | `codex exec --json` + 自定义 prompt |
| 评审维度 | 固定攻击面 + focus 微调 | LLM 从文档内容和目标动态发现 |
| 可执行验证 | 有（测试/lint） | 无 |
| 修复范围 | 仅 high+ | 所有级别 |
| 收敛标准 | 无 high+ findings + 验证通过 | 连续两轮零 findings |
| 背景知识 | 无 | deception-patterns.md |

**评审引擎**：
- codex 路径：通过 `codex exec --json` 发送自定义 prompt。prompt 结构包含——角色定义、评审目标（leader 推断）、文档内容或 diff、关联上下文（上下游文档）、DECEPTION 检测模式（背景知识）、评审要求（维度发现→逐维度评审→三个问题引导思考质量）。输出必须符合统一 Finding 格式。
- 自评审路径：同样的 prompt 交给 agent 执行，输出必须符合统一 Finding 格式。

**外部依赖契约（codex exec 路径）：**
- 前提：`codex` CLI 可用且支持 `exec --json` 子命令
- 输入：stdin 传递自定义 prompt（含文档内容、评审指令、输出格式要求）
- 输出：JSON，包含 `verdict` 和 `findings` 数组（格式同统一 Finding schema）
- 空结果语义：`verdict=approve` 且 `findings=[]` 视为本轮通过
- 超时：单次调用 300 秒
- JSON 格式不合法 / 字段缺失：按异常矩阵处理，保存原始输出

**为什么不用 codex:adversarial-review**：adversarial-review 的 prompt 和攻击面（auth、race condition、data loss 等）是为代码设计的，对文档无意义。文档评审需要完全不同的维度（一致性、准确性、完整性等），必须自定义 prompt。

**Leader 推断逻辑**：skill 读取文档内容，识别文档类型，扫描同目录/上下游文档推断关联上下文。推断结果在 AskUserQuestion 中展示。

**维度发现指令**（嵌入评审 prompt）：要求评审者先分析文档类型和改动意图，确定本次评审的维度并输出理由，再逐维度评审。维度从内容涌现，不套固定清单。

**Finding 格式**（两个 skill 统一，对齐 `codex:adversarial-review` 插件的 `review-output.schema.json`）：
```json
{
  "file": "文件相对路径",
  "line_start": 42,
  "line_end": 45,
  "severity": "critical | high | medium | low",
  "title": "finding 标题（一句话）",
  "body": "详细描述：违反什么原则、如何偏离、不修复会怎样",
  "confidence": 0.85,
  "recommendation": "具体修复建议",
  "dimension": "所属维度（文档 skill 专用）"
}
```

**字段约束：**
- `file`（必填）：相对于项目根目录的文件路径。与插件输出字段名一致。
- `line_start`（必填）：finding 起始行号，正整数。文档 skill 中若无法精确到行，填 `1`。
- `line_end`（必填）：finding 结束行号，正整数。与插件 schema 一致。
- `severity`（必填）：四级严重度。
- `title`（必填）：finding 标题，一句话概括。代码路径由插件自动产出；文档路径由自定义 prompt 要求。
- `body`（必填）：详细描述。代码路径由插件自动产出；文档路径必须回答三个问题——违反什么原则、如何偏离、不修复会怎样。
- `confidence`（必填）：0-1 置信度。代码路径由插件自动产出；文档路径由评审者给出。低于 0.6 的 finding 仅记录，不进入修复循环。
- `recommendation`（必填）：具体修复建议。
- `dimension`（文档 skill 必填，代码 skill 可选）：所属评审维度。文档 skill 用于动态维度追踪和 DECEPTION 分类。

**跨轮追踪：** 同一 finding 的身份通过 `file + line_start + severity` 三元组判定。跨轮对比时，若 file 和 severity 相同且 line_start 偏移在 ±5 行内，视为同一 finding。

**收敛标准**：
- 通过：连续两轮 verdict == approve（零 findings）。单轮零 findings 不立即通过——文档无可执行验证，需要确认轮防止浅通过。
- 未通过：达到最大轮次（5）
- 不收敛：连续 2 轮 findings 数量不减少

**最终报告**：
```
=== 文档评审修复完成 ===
结果：通过 | 未通过 | 不收敛
总轮次：N
各轮统计：[R1: 4 findings → R2: 1 finding → R3: 0 → R4(确认): 0]
各轮评审维度：[R1: 一致性,完整性,DECEPTION → R2: 一致性,完整性 → ...]
改动文档：[file1, file2, ...]
基线：baseline_ref=abc1234, stash_ref=def5678 | 无 stash
恢复状态：stash pop 成功 | 冲突(files: ...) | 无需恢复
剩余 findings：[完整列表，含 non-blocking 摘要]
DECEPTION findings：[需用户介入的 DECEPTION 类 findings（如有）]
```

多了"各轮评审维度"字段——维度是动态发现的，用户需要知道评审者覆盖了什么角度。DECEPTION findings 单独列出，因为它们不进入自动修复。

### deception-patterns.md

从 codex-doc-review 的 review-guide-base.md 和各 stage-specific guide 中提取 12 个 DECEPTION 检测模式，按模式类型组织（而非按文档阶段），每个模式包含：模式名、一句话描述、检测信号。目标 40-50 行。

作为背景知识嵌入文档评审 prompt，不作为固定检查清单。评审者带着这些知识去发现问题，而非逐项打勾。

### 与现有 /review skill 的关系

| skill | 定位 | 调用方式 |
|-------|------|----------|
| `/review`（shared） | 纯评审不修复，嵌入 /product、/design 等 workflow | 其他 skill 内部调用 |
| `/code-review-fix`（claude） | 代码评审 + 修复循环 | 用户直接调用 |
| `/doc-review-fix`（claude） | 文档评审 + 修复循环 | 用户直接调用 |

三者不冲突，定位互补。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| A: 两个完全独立 skill | 最简单，无耦合，改一个不影响另一个 | 循环逻辑有少量重复 | **采用** |
| B: 共享循环协议 + 两个 skill | 循环逻辑统一 | 新旧范式不兼容，改协议影响 /product 等旧 skill | 否决 |
| C: 一个 skill + 模式切换 | 单入口 | 违背拆分初衷，leader prompt 被迫 if/else | 否决 |

## Key Decisions

- D1: 代码评审用 `codex:adversarial-review` — openai-codex 插件提供完整的 adversarial prompt、正式 JSON Schema 校验和置信度校准，无需自造 schema 和校验脚本
- D2: 文档评审用 codex exec --json + 自定义 prompt — adversarial-review 的攻击面对文档无意义
- D3: 自评审用 agent 隔离 — 同模型不同上下文窗口提供视角隔离
- D4: 环境每次询问不自动检测 — 自动检测不可靠（codex CLI 在两种环境都可能存在）
- D5: 代码只修 high+，文档修所有级别 — 代码有验证兜底可以忽略 medium/low；文档无验证，medium/low 同样误导读者
- D6: Finding 格式对齐插件 schema（file/line_start/line_end/severity/title/body/confidence/recommendation/dimension），代码路径直接消费插件输出，文档路径由自定义 prompt 产出兼容格式
- D7: 不需要外部脚本 — baseline 用 git stash（完整恢复语义见 Baseline 保护与恢复章节），JSON 校验由 skill 主循环内联检查（parse 失败按异常矩阵 fail-close）
- D8: 淘汰 codex-doc-review — 固定维度清单范式与 leader 模式不兼容，DECEPTION 知识迁移到新 skill

## Success Criteria

### 正向验收

- code-review-fix 能对 working-tree 改动完成至少一轮 codex 评审→修复→重审循环
- doc-review-fix 能对指定文档完成至少一轮评审→修复→重审循环，维度为动态发现
- 自评审路径（不用 codex）能产出与 codex 路径格式一致的 findings（符合统一 Finding schema）
- 旧 skill（review-fix-loop、codex-doc-review、codex-doc-reviewer）全部删除，无悬空引用
- 所有引用旧 skill 的测试更新或删除后通过

### 负路径验收矩阵

| 场景 | 验证方式 | 预期行为 |
|------|----------|----------|
| dirty working tree | 有未提交改动时启动 | stash 保护 → 循环 → stash pop 恢复 |
| clean working tree | 无改动时启动 | 跳过 stash → 循环正常执行 |
| codex 不可用 | 移除 codex CLI 或断网 | 立即报错终止，不静默切到自评审 |
| 评审输出非 JSON | 模拟 codex 返回非法输出 | 终止并保存原始输出 |
| 评审输出缺字段 | 模拟 findings 缺少 path/severity | 终止并报告缺失字段 |
| 达到最大轮次 | 持续产生 findings 不收敛 | 报告"未通过"，列出剩余 findings |
| 不收敛判定 | 连续 2 轮 findings 数量不减少 | 报告"不收敛"，列出各轮统计 |
| stash pop 冲突 | 修复 commit 与原始改动冲突 | 报告冲突文件列表，不自动解决 |
| 用户中止 | 循环中 Ctrl-C | 保留现场，报告恢复指令 |
| 旧引用清理完整性 | `grep -r` 三个旧名称 | 零匹配（排除 docs/archive） |
| 受影响门禁通过 | 运行 `tests/run-all.sh` | 全部通过 |

### 证据要求

最终报告必须包含以下可审计字段：
- 各轮 findings 数量统计（含跨轮对比：新增/持续/已修复）
- 最终 residual findings 完整列表（即使通过也要保留 non-blocking 摘要）
- code 路径：实际执行的验证命令及退出码
- doc 路径：每轮评审维度列表
- baseline 状态：`baseline_ref`、`stash_ref`、恢复结果

## 淘汰计划

**删除（~15 个文件）：**
- `claude/skills/review-fix-loop/` 整个目录
- `claude/skills/codex-doc-review/` 整个目录
- `claude/agents/codex-doc-reviewer.md`

**不动：**
- codex 插件目录
- `/review` shared skill

**受影响对象（运行时/门禁/contract 级）：**

| 文件 | 影响类型 | 所需变更 |
|------|----------|----------|
| `install.sh:1248-1253` | 安装 quick check 校验 `review-fix-loop/SKILL.md` 存在 | 替换为新 skill 路径或移除旧断言 |
| `tests/test-runtime-integrity.sh:179-205` | 运行时完整性校验 review-fix-loop 和 codex-doc-review 存在/隔离 | 更新为新 skill 的存在性断言 |
| `tests/test-single-source-layout.sh:57-68` | 布局门禁把旧 skill/agent 当作唯一允许的 claude-only source | 更新白名单为新 skill 名称 |
| `tests/run-all.sh:15-18, :49-52, :100-107` | 显式编排旧 skill 专属测试 | 替换为新 skill 测试或移除旧条目 |
| `shared/hooks/lib/common.sh:508-690` | 183 行 codex-doc-review 上下文解析函数库（10 个函数） | 整段废弃删除；需确认无其他调用方后再删 |
| `contracts/skill-chain.yaml:61-81` | codex-doc-review 节点及其产物消费链路 | 替换为新 skill 节点或移除旧链路 |

**引用清理：** grep `review-fix-loop`、`codex-doc-review`、`codex-doc-reviewer`，逐一处理上表中的受影响对象及其他悬空引用。`common.sh` 函数库删除前需执行 `grep -r` 确认无外部调用方。

## 迁移映射

### 旧契约吸收/丢弃清单

| 旧组件 | 旧契约 | 处置 | 新归属 |
|--------|--------|------|--------|
| `review-fix-loop/SKILL.md` | 循环流程、baseline 脚本调用、JSON 校验脚本调用 | **丢弃** | 新 skill 用内联逻辑替代 |
| `review-fix-loop/references/review-schema.md` | `file + line_start + line_end + severity + description + recommendation` | **替换** | 直接消费 `codex:adversarial-review` 插件的 `review-output.schema.json`（更丰富：含 title/confidence/summary/next_steps） |
| `review-fix-loop/references/execution-spec.md` | codex exec 调用模板、超时、输出保存 | **替换** | code-review-fix 直接调用 `codex:adversarial-review` 插件命令，不再需要自定义调用模板 |
| `review-fix-loop/scripts/capture_baseline.py` | baseline 创建/恢复逻辑 | **丢弃** | 新 skill 用 git stash 内联替代（见 Baseline 章节） |
| `review-fix-loop/scripts/validate_review_json.py` | JSON 格式校验 | **丢弃** | 新 skill 主循环内联 parse + fail-close |
| `codex-doc-review/SKILL.md` | HARD-GATE、I/O 契约、8 步流程、状态码 | **部分吸收** | DECEPTION HARD-GATE → deception-patterns.md 中保留；I/O 契约 → doc-review-fix 外部依赖契约；状态码（REVIEW_OK/REVIEW_ISSUE）→ 新 skill verdict 映射 |
| `codex-doc-review/references/review-guide-base.md` | 12 个 DECEPTION 模式（4 通用 + 8 阶段特异）、维度定义、审查执行要求 | **吸收** | deception-patterns.md（按模式类型重组，去除阶段绑定） |
| `codex-doc-reviewer.md` (agent) | Step Contract（输入/输出）、结论信号 | **丢弃** | doc-review-fix 内联处理，不再需要独立 agent 定义 |
| `common.sh:508-690` | 10 个 codex-doc-review 上下文解析函数 | **丢弃** | 新 skill 不依赖 shared hook 解析；删除前 `grep -r` 确认无外部调用方 |
| `skill-chain.yaml:73-81` | codex-doc-review 节点、产物消费者（project-manager） | **替换** | 新 skill 节点定义（如需要），或移除旧链路 |

### DECEPTION 迁移要点

- 旧设计中 DECEPTION 有独立 severity（固定不降级）和独立 verdict 逻辑（见 `review-guide-base.md:74-79`）
- 新设计中 DECEPTION 作为背景知识嵌入评审 prompt，不作为独立 severity 层
- **迁移约束**：新 skill 必须保留"DECEPTION 类 finding 不允许自动修复"的语义——评审者可以发现 DECEPTION 问题，但修复必须标记为"需用户介入"，不进入自动修复循环
- 这意味着 finding schema 中 severity=critical 且 dimension 含 DECEPTION 的 findings，修复策略应为"报告并等待用户确认"而非自动修复

**设计选择说明：** DECEPTION 采用"普通 finding schema + 特殊处置约束"而非独立 verdict/终态，这是 MVP 阶段的显式设计选择。理由：DECEPTION 发生频率低，独立终态会增加状态机复杂度但 MVP 阶段收益不明确。当前方案通过 `dimension 含 DECEPTION → 不自动修复` 已保留安全语义。若后续实践中发现需要更强的隔离（如 DECEPTION 需要独立于 pass/fail 的第三种结论），可升级为独立 verdict。

### 入口切换

| 旧入口 | 新入口 | 切换方式 |
|--------|--------|----------|
| `/review-fix-loop` | `/code-review-fix` 或 `/doc-review-fix` | 用户按评审对象类型选择 |
| `/codex-doc-review`（内部调用） | `/doc-review-fix` | 上游 skill（如 /product、/design）更新调用入口 |
| `codex-doc-reviewer` agent | 无（废弃） | doc-review-fix 内联处理 |

### 文档归档

删除的旧 skill 目录在实施完成后整体移至 `docs/archive/review-fix-loop-redesign-2026-04/`，保留历史参考。

## 实施顺序

1. 创建 code-review-fix/SKILL.md
2. 创建 doc-review-fix/SKILL.md + deception-patterns.md
3. grep 所有对旧 skill 的引用，列出完整清单（对照受影响对象表）
4. 更新受影响的门禁/测试/contract（install.sh、4 个测试文件、skill-chain.yaml）
5. 确认 `common.sh` 函数库无外部调用方后删除
6. 清理其他悬空引用
7. 删除旧 skill 目录和 agent 定义
8. 归档旧文件到 docs/archive/

## 执行风险

以下风险不影响设计方向，需要在实现后根据实际效果调优：

1. `codex:adversarial-review` 的 focus 文本传递效果——插件 prompt 模板（`prompts/adversarial-review.md`）中 `{{USER_FOCUS}}` 占位符已支持 focus 注入，但固定攻击面权重可能压过 focus
2. 自评审 agent 的实际发现能力（同模型隔离的效果边界）
3. 文档评审自定义 prompt 的 JSON 输出稳定性

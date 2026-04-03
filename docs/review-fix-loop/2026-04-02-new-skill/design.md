# review-fix-loop Skill 设计

## Why

用户在 Claude/Codex 完成产出后，需要反复执行"评审 → 修复 → 再评审"循环。当前这一流程完全靠手动编排（每轮手动发起评审、手动指示修复），是高频重复操作。需要一个 skill 将此循环自动化为一条命令。

## Scope

- In scope:
  - Claude 侧自动循环调用外部 Codex CLI 对抗评审（通过 `codex exec --json` 和固定 JSON 契约）
  - 解析 JSON 评审结果，按 findings 批量修复
  - 循环控制（退出条件、轮次上限、不收敛检测）
  - 每轮进度输出和最终报告
  - 进入循环前保存工作树快照（git stash），支持回滚
- Out of scope:
  - 工件类型识别和评审标准路由（类型无关，由上下文决定）
  - 自动 commit（用户修完后自行决定提交方式）
  - 与现有 protocol 体系的集成（独立自包含）
  - 人工介入模式（全自动，无需每轮确认）
  - Codex runtime 直接执行本 skill（v1 先作为 claude-only skill 交付）

## Approach

一个纯循环编排器，核心流程：

```
预检：
  如果工作树有改动：
    git stash push --include-untracked -m "review-fix-loop baseline"
    验证新 stash 条目已创建
    记录 stash commit SHA（不可变引用）
    git stash apply --index（保留 stash 条目 + 恢复暂存区状态）
  如果工作树干净：
    记录 HEAD SHA 作为基线，跳过 stash
循环（最多 N 轮）:
  调用外部 Codex CLI 对抗评审（codex exec --json）→ 拿到 JSON/JSONL
  如果评审器异常（超时/非 JSON/缺字段）→ 停止，输出错误报告（fail-closed）
  如果结果矛盾（verdict=approve 但 findings 非空）→ 停止，输出错误报告（fail-closed）
  如果 verdict === "approve" → 结束，输出通过
  否则 → 按 findings 批量修复（从文件末尾向前修复，避免行号漂移）
  如果连续 2 轮 findings 数量 >= 上一轮 → 报告不收敛，停止
输出最终报告（含 stash SHA 和恢复命令）
```

### 预检：工作树快照

进入循环前，检测工作树状态：

1. **有本地改动**（tracked 或 untracked）：执行 `git stash push --include-untracked -m "review-fix-loop baseline"`，验证新 stash 条目确实被创建（比对前后 `git stash list` 输出），记录 stash commit SHA，然后 `git stash apply --index` 恢复工作树和暂存区
2. **工作树干净**：跳过 stash 流程，仅记录当前 HEAD SHA 作为基线。干净工作树无需快照——回滚只需 `git checkout -- .` 即可恢复到 HEAD 状态

记录基线的 **stash commit SHA**（通过比对 stash push 前后的 `git rev-parse refs/stash` 获取），而非 `stash@{N}` 序号。序号会因后续 stash 操作重排，不是不可变引用。

目的：如果循环修复方向错误或不收敛，用户可通过以下命令恢复到循环开始前的状态：
```
git checkout -- .
git stash apply --index <stash-commit-sha>
```

恢复成功后用户可手动 `git stash drop <stash-commit-sha>` 清理基线。

注意：恢复命令不使用 `git clean`，因为该命令可能不可逆删除用户文件。恢复后循环新增的未跟踪文件仍会保留在工作树中，skill 在最终报告中列出循环新增的文件清单，由用户自行决定是否删除。

**回滚边界声明**：git stash 保存 tracked + untracked 文件，不包含 `.gitignore` 排除的 ignored files。这是 git stash 的固有限制，对本 skill 影响极小——评审和修复操作只涉及 repo 内的 tracked/untracked 文件，不会修改 ignored files（如 `node_modules/`、`.env` 等）。

### 评审器异常处理（fail-closed）

外部 Codex CLI 对抗评审是外部进程，可能出现以下异常：

| 异常 | 处理 |
|------|------|
| Codex CLI 不可用 / 命令执行失败 | 立即停止循环，输出错误报告 |
| 超时（无响应） | 立即停止循环，输出错误报告 |
| 输出非 JSON / JSON 缺少 `verdict` 或 `findings` 字段 | 立即停止循环，输出错误报告 |
| `verdict` 值不是 `approve` 或 `needs-attention` | 立即停止循环，输出错误报告 |
| `verdict=approve` 但 `findings` 非空 | 结果矛盾，立即停止循环，输出错误报告 |
| `verdict=needs-attention` 但 `findings` 为空 | 结果矛盾，立即停止循环，输出错误报告 |

原则：**fail-closed**——任何评审器异常或结果矛盾都停止循环并报告，禁止在评审结果不确定时继续自动修复。异常停止时同样输出 stash SHA 和恢复命令。

### Finding 级校验

评审通过顶层 schema 校验后，在进入批量修复前，逐条校验每个 finding：

| 校验项 | 规则 | 不通过处理 |
|--------|------|-----------|
| `file` 字段 | 必须是 repo 内相对路径，禁止绝对路径、`..` 路径、`.git` 或 `.git/` 前缀 | 跳过该 finding，记录警告 |
| `line_start` / `line_end` | 必须为正整数，`line_end >= line_start` | 跳过该 finding，记录警告 |
| `severity` | 必须是 `critical/high/medium/low` 之一 | 跳过该 finding，记录警告 |

对于无法定位的 finding（file 不存在、行号超出文件范围）：
- **critical/high severity**：立即停止循环，输出错误报告（fail-closed）。高严重度问题无法定位意味着评审结果不可信，不应继续自动修复
- **medium/low severity**：跳过修复并在轮次报告中标记为"无法定位"

如果所有 findings 都无法定位，无论 severity 级别，一律 fail-closed 停止循环。

### 批量修复策略

每轮批量修复时，按 **文件分组、同文件内从后往前**（line_end 降序）的顺序修复。从文件末尾向前修复可以避免早期修复导致后续 finding 的行号漂移。不同文件之间的修复互不影响，可按任意顺序处理。

### Skill 接口

命令名：`/review-fix-loop`（Claude runtime）

参数：
```
/review-fix-loop [--max N] [--scope auto|working-tree|branch] [--base <ref>] [focus ...]
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--max N` | 10 | 最大循环轮次 |
| `--scope` | 透传 | 评审范围，透传给外部 Codex 对抗评审 prompt |
| `--base` | 透传 | git base ref，透传给外部 Codex 对抗评审 prompt |
| `focus ...` | 无 | 额外关注点，透传给外部 Codex 对抗评审 prompt |

参数设计原则：skill 自身只管 `--max`，其余参数原样透传给外部 Codex 对抗评审 prompt。

### 角色分离

- 评审者：外部 Codex CLI 对抗评审 prompt（Codex 独立进程，对抗性立场）
- 修复者：Claude（当前 session，拥有完整上下文）
- 天然视角分离，无需额外引入独立 fixer agent

### 退出条件

| 条件 | 结果 |
|------|------|
| `verdict === "approve"` 且 `findings` 为空 | 通过，正常结束 |
| 轮次达到 `--max` | 未通过，输出剩余 findings |
| 连续 2 轮 findings 数量 >= 上一轮 | 不收敛，暂停并报告 |
| 评审器异常（超时/非 JSON/缺字段） | 错误，立即停止（fail-closed） |
| 结果矛盾（verdict 与 findings 不一致） | 错误，立即停止（fail-closed） |

### 每轮输出

```
=== 第 N/M 轮 ===
评审结果：needs-attention | approve
findings: X 个 (critical: N, high: N, medium: N, low: N)
修复中...
修复完成，进入下一轮
```

### 最终输出

```
=== 循环结束 ===
结果：通过 | 未通过 | 不收敛 | 评审器错误
总轮次：N
起始 SHA：abc1234
基线 stash SHA：def5678
恢复命令：git checkout -- . && git stash apply --index def5678  （仅在未通过/不收敛/错误时输出）
循环新增文件：[列表]  （如有，由用户自行决定是否删除）
```

未通过或不收敛时，附带剩余 findings 列表。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| A. 纯 Skill 编排器 | 独立、简单、自包含 | 不复用现有 protocol 熔断机制 | **选定** |
| B. 接入 review-fix-loop-protocol | 复用熔断/不收敛/浅通过防护 | 耦合重、需适配 JSON 输出格式 | 排除：复杂度与收益不匹配 |
| C. 扩展 autoresearch:fix | 最大化复用循环引擎 | 逐个修复模式与批量修复冲突、Metric 不匹配 | 排除：根本性设计冲突 |

## Key Decisions

- D1: 类型无关 — Reason: 评审者对抗评审 prompt 本身不区分工件类型，skill 不需要增加类型路由层
- D2: 批量修复而非逐个修复 — Reason: 用户场景是"系统性修复"，一次处理所有 findings 效率更高
- D3: 不自动 commit — Reason: 避免污染 git 历史，用户修完通过后自行决定提交方式
- D4: Claude 直接修而非独立 fixer agent — Reason: Codex 评审 + Claude 修复已实现天然视角分离，无需额外开销
- D5: verdict=approve 即通过 — Reason: 外部 Codex 对抗评审已是对抗性立场，其 approve 是高标准判定，无需额外要求零 finding
- D6: 简单循环而非状态机 — Reason: 流程无复杂分支跳转，while 循环足够表达，状态机是过度设计
- D7: 首轮 approve 即通过，不做 shallow-pass 二次确认 — Reason: 外部 Codex 对抗评审已是对抗性深度评审，其 approve 是高标准判定。现有 protocol 的 shallow_pass_guard 是为 R1 广度→R2 深度递增设计的，不适用于已经是深度对抗的单一评审者。强制二次确认是同一评审者审两遍，盲区不会因此消除。如果用户对结果不放心，可手动再次调用 skill
- D8: v1 不收敛检测基于 findings 数量，不做 finding 身份追踪 — Reason: 外部 Codex 对抗评审的 findings 无稳定 ID，构建指纹匹配系统复杂度高且缺乏实际数据验证必要性。关于"顽固 critical 伴随其他修复导致总数下降"的场景：对抗性立场会在后续轮次持续暴露未修复的高风险问题，且 10 轮硬上限确保不会无限 churn。如实际使用中证实此场景频繁发生，v2 加 finding 指纹

## Success Criteria

- 用户输入 `/review-fix-loop` 一条命令即可启动完整的评审-修复循环
- 该能力作为 claude-only skill 安装到 Claude runtime，Codex runtime 不暴露该命令
- 循环在 verdict=approve 时正常退出
- 循环在达到上限轮次时输出未通过报告及剩余 findings
- 连续 2 轮 findings 数量 >= 上一轮时检测到不收敛并停止
- 每轮有清晰的进度输出（轮次、findings 统计、修复状态）
- Codex 对抗评审参数可透传（scope、base、focus）
- 进入循环前保存工作树快照（git stash apply --index 保留不可变基线和暂存区状态），使用 stash commit SHA 作为不可变引用，未通过/不收敛/错误时输出恢复命令（checkout + stash apply --index SHA）和循环新增文件清单
- 评审器异常或结果矛盾（verdict 与 findings 不一致）时 fail-closed：立即停止循环，不继续自动修复
- 修复前逐条校验 finding 的 file 路径（repo 内相对路径）和行号合法性，越界或无法定位的 finding 跳过并记录警告

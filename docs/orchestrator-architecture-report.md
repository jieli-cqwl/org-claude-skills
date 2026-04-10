# Orchestrator 架构方案报告

## 问题定义

三个 Claude Code skill（product、design、test-design）各自包含一个"跨职能评审循环"（S11/S9/S8），结构完全一致：

```
3 视角并行评审 → 合并审查结论 → FAIL? → 修复文档 → 仅 FAIL 视角重审 → 循环
  ↑                                                                          |
  └──────────────────────────────────────────────────────────────────────────┘
```

收敛控制：
- 最大 10 轮
- 首轮全 PASS → 强制确认轮
- 连续 2 轮 FAIL 数不减少 → AskUserQuestion 暂停
- 同一问题连续 3 轮未关闭 → 标记 BLOCKED

**当前实现**：完全靠 SKILL.md 文本指令驱动 LLM 执行循环，不稳定——LLM 可能跳过轮次、忘记计数、错误判断收敛。

**目标**：将循环逻辑封装在程序代码中，确保确定性执行。

---

## 现状约束分析

### 1. Claude Code 环境约束

| 约束 | 详情 |
|------|------|
| Claude CLI | v2.1.97，支持 `-p`（print 模式）、`--output-format json`、`--json-schema`、`--system-prompt`、`--allowed-tools`、`--model` |
| 权限模式 | `bypassPermissions`（当前用户配置） |
| Skill 机制 | SKILL.md frontmatter 定义 `allowed-tools`、`hooks`（PostToolUse）；skill 内部 LLM 可调用 Bash/Agent/TeamCreate |
| Hook 机制 | PostToolUse hook 已用于 completion_check.sh（结构门禁），但 hook 只做被动校验不驱动流程 |
| Agent 机制 | Agent/TeamCreate 用于创建子 agent，每个 agent 有独立 prompt 和 tool 权限 |
| MCP | 项目无 .mcp.json；用户级可能有 MCP server 配置 |

### 2. 评审循环共同模式

三个 skill 的评审循环可抽象为：

```
ReviewLoop(document, reviewers[3], max_rounds=10):
  round = 0
  pending_perspectives = reviewers  # 首轮全部参与
  
  while round < max_rounds:
    round++
    results = parallel_review(document, pending_perspectives)
    merge_results_into(document, results)
    
    if all_pass(results):
      if round == 1:
        pending_perspectives = reviewers  # 首轮全 PASS → 确认轮
        continue
      else:
        return SUCCESS
    
    fail_perspectives = get_fail(results)
    if stagnant(fail_perspectives, history, window=2):
      ask_user("连续 2 轮 FAIL 数不减少")
      # 用户决定继续或终止
    
    blocked = get_blocked(history, window=3)
    if blocked:
      mark_blocked(blocked)
      fail_perspectives -= blocked
    
    fix_document(document, fail_perspectives)
    pending_perspectives = fail_perspectives
  
  return MAX_ROUNDS_REACHED
```

### 3. 评审者的工作内容

每个 reviewer 需要：
- 读取目标文档（brief.md / design.md / test-cases.md）
- 读取上下游参考文档（PRD、units、design 等）
- 按 reviewer prompt 执行评审
- 产出结构化结果（Verdict: PASS/WARN/FAIL + Issue list）

这意味着 reviewer 需要**文件系统访问**和**LLM 推理**。

---

## 方案设计

### 方案 A：Bash Orchestrator

#### 架构

```
用户 → /product → SKILL.md 流程 S1-S10 → S11 指示调用 Bash
                                              ↓
                                    Bash tool 运行 review_loop.sh
                                              ↓
                    ┌─────────────────────────────────────────┐
                    │ review_loop.sh (while 循环)              │
                    │                                         │
                    │  round=0                                │
                    │  while [ $round -lt $max_rounds ]; do   │
                    │    round=$((round+1))                   │
                    │                                         │
                    │    # 并行启动 3 个 claude -p 子进程      │
                    │    for perspective in $perspectives; do  │
                    │      claude -p \                        │
                    │        --system-prompt "$reviewer_prompt"│
                    │        --output-format json \           │
                    │        --json-schema "$schema" \        │
                    │        --allowed-tools "Read,Glob,Grep" │
                    │        "$review_task" &                 │
                    │    done                                 │
                    │    wait                                 │
                    │                                         │
                    │    # 解析结果、判断收敛                   │
                    │    parse_verdicts                        │
                    │    if all_pass; then break; fi          │
                    │                                         │
                    │    # 修复：调用 claude -p 修复文档       │
                    │    claude -p \                          │
                    │      --system-prompt "$fixer_prompt" \  │
                    │      --allowed-tools "Read,Edit,Write"  │
                    │      "$fix_task"                        │
                    │  done                                   │
                    │                                         │
                    │  # 输出最终结果                          │
                    │  echo "$final_report"                   │
                    └─────────────────────────────────────────┘
                                              ↓
                              SKILL.md LLM 继续 S12
```

#### 评估

| 维度 | 评分 | 说明 |
|------|------|------|
| 技术可行性 | **高** | claude CLI `-p` + `--output-format json` + `--json-schema` 可精确控制输入输出；`--allowed-tools` 可限定 reviewer 权限 |
| 用户体验 | **中** | Bash 脚本执行期间，用户看到的是 Bash tool 的输出。进度需通过 stderr 打印。脚本结束后 SKILL.md LLM 可以继续处理 |
| 实现复杂度 | **中** | Bash 解析 JSON 需要 jq；并行管理用 `&` + `wait`；状态跟踪用文件。约 300-500 行 |
| 调试可观测性 | **中** | 可日志到文件；但 Bash 调试工具有限 |
| 生态兼容性 | **高** | 与现有 hooks/scripts 生态完全一致（都是 Bash）；completion_check.sh 可继续工作 |
| 循环可靠性 | **高** | while 循环是确定性的；收敛判断是代码逻辑不是 LLM 判断 |

#### 关键风险

1. **claude -p 子进程成本**：每次 `claude -p` 都是一个独立 session，需要重新加载上下文。3 个 reviewer + 1 个 fixer = 每轮 4 次 CLI 调用
2. **上下文断裂**：Bash orchestrator 内的 claude -p 调用与父 SKILL.md session 完全隔离。reviewer 无法看到之前的对话历史
3. **claude -p 超时**：评审可能需要较长时间（读取多个文件 + 推理），需要合理设置超时
4. **修复阶段的质量**：fixer 也是通过 claude -p 调用，每轮都是无状态的，修复质量依赖 prompt 工程

---

### 方案 B：SDK Orchestrator (Python/Node)

#### 架构

```
用户 → /product → SKILL.md 流程 S1-S10 → S11 指示调用 Bash
                                              ↓
                                    Bash tool 运行 python review_loop.py
                                              ↓
                    ┌──────────────────────────────────────────┐
                    │ review_loop.py (Python + Anthropic SDK)   │
                    │                                          │
                    │  client = Anthropic()                    │
                    │  round = 0                               │
                    │                                          │
                    │  while round < max_rounds:               │
                    │    round += 1                            │
                    │                                          │
                    │    # 读取文档内容                         │
                    │    doc_content = read_file(doc_path)      │
                    │                                          │
                    │    # 并行调用 API                         │
                    │    tasks = []                             │
                    │    for p in perspectives:                 │
                    │      tasks.append(                        │
                    │        client.messages.create(            │
                    │          model="claude-sonnet-4-6",       │
                    │          system=reviewer_prompt[p],       │
                    │          messages=[{role:"user",          │
                    │            content: doc_content}],        │
                    │          tool_use=[...],  # 可选          │
                    │        )                                  │
                    │      )                                    │
                    │    results = await gather(tasks)          │
                    │                                          │
                    │    # 解析 structured output               │
                    │    # 判断收敛                             │
                    │    # 修复（API 调用或本地逻辑）            │
                    │                                          │
                    │  print(json.dumps(final_report))          │
                    └──────────────────────────────────────────┘
```

#### 子方案 B1：Anthropic Messages API

直接调用 Messages API（`client.messages.create`）。

#### 子方案 B2：Claude Code SDK（@anthropic-ai/claude-code）

使用 Claude Code 的 Node SDK，可以在代码中创建具有工具能力的 agent session。

#### 评估

| 维度 | 评分 | 说明 |
|------|------|------|
| 技术可行性 | **高** | Anthropic SDK 成熟；结构化输出支持良好 |
| 用户体验 | **中** | 与方案 A 类似，脚本执行期间用户看 Bash 输出 |
| 实现复杂度 | **中-低** | Python/Node 处理 JSON 比 Bash 容易得多；并行用 asyncio/Promise；约 200-300 行 |
| 调试可观测性 | **高** | Python/Node 调试工具丰富，可结构化日志 |
| 生态兼容性 | **中** | 引入新依赖（Python venv 或 Node package）；需要 API key 管理 |
| 循环可靠性 | **高** | 与方案 A 一样，循环是确定性代码 |

#### 关键风险

1. **API Key 管理**：SDK 需要 `ANTHROPIC_API_KEY`，与 Claude Code 自身的认证独立。用户可能用 OAuth 登录 Claude Code，不一定有 API key
2. **reviewer 无文件系统访问**：Messages API 不直接支持文件系统操作。需要脚本先读取所有相关文件，拼入 prompt。这对大型项目可能导致 context 过大
3. **B2 的 tool 能力**：Claude Code SDK 可赋予工具能力（Read/Glob/Grep），但增加复杂度
4. **Python 环境**：项目当前无 Python 依赖管理（无 pyproject.toml / requirements.txt），需要新建
5. **Token 成本**：每轮 3 个 API 调用 + 1 个修复调用，context 窗口需要装入完整文档，成本不低

---

### 方案 C：MCP Orchestrator

#### 架构

```
用户 → /product → SKILL.md 流程 S1-S10 → S11
                                              ↓
                              LLM 调用 MCP tool: review_loop
                                              ↓
                    ┌──────────────────────────────────────────┐
                    │ MCP Server: review-orchestrator           │
                    │                                          │
                    │  Tool: review_loop(                       │
                    │    document_path,                         │
                    │    reviewers,                             │
                    │    max_rounds                             │
                    │  )                                        │
                    │                                          │
                    │  内部实现：                                │
                    │  - while 循环驱动评审                      │
                    │  - 每轮调用 Anthropic API 做评审           │
                    │  - 解析结果、判断收敛                      │
                    │  - 调用 API 修复文档                       │
                    │  - 返回最终结果给 Claude Code              │
                    └──────────────────────────────────────────┘
```

#### 评估

| 维度 | 评分 | 说明 |
|------|------|------|
| 技术可行性 | **中** | MCP tool 可以在内部调用 Anthropic API；但 MCP tool 有执行时长限制（Claude Code 的 MCP call 通常有超时） |
| 用户体验 | **低-中** | MCP tool 调用期间无进度反馈（MCP 协议目前无 progress streaming 标准）；长时间无响应对用户不友好 |
| 实现复杂度 | **中-高** | 需要完整 MCP server 实现（stdio transport）+ 评审逻辑 + API 调用 |
| 调试可观测性 | **低** | MCP server 运行在独立进程，调试困难；错误信息传递受 MCP 协议限制 |
| 生态兼容性 | **低** | 需要配置 MCP server（.mcp.json 或 settings.json）；改变了 skill 的工具依赖声明 |
| 循环可靠性 | **高** | 循环是代码驱动 |

#### 关键风险

1. **MCP tool 超时**：评审循环可能运行 10+ 分钟（最多 10 轮 x 每轮 3-4 个 API 调用），MCP tool call 有超时风险
2. **API Key 问题**：同方案 B
3. **进度反馈**：MCP 协议对 long-running tool 的进度通知支持有限
4. **维护成本**：MCP server 是独立进程，增加运维复杂度

---

### 方案 D：Hybrid — SKILL.md + 外部循环脚本

#### 架构

```
用户 → /product → SKILL.md 流程 S1-S10
                                ↓
                    S11: SKILL.md 指示 LLM
                    "执行 Bash tool 运行 review_orchestrator.sh"
                                ↓
              ┌────────────────────────────────────┐
              │ review_orchestrator.sh              │
              │                                    │
              │ while 循环:                         │
              │   1. 调用 claude -p 做并行评审       │
              │   2. 解析结果写入状态文件            │
              │   3. 判断收敛                       │
              │   4. 若需修复：                     │
              │      输出修复指令到 stdout           │
              │      exit 100 (NEEDS_FIX)           │
              │                                    │
              └────────────────────────────────────┘
                                ↓
              exit 100 → SKILL.md LLM 看到 "NEEDS_FIX"
                         LLM 执行修复（利用父 session 上下文）
                         LLM 再次调用 review_orchestrator.sh
                                ↓
              exit 0 → 循环完成，SKILL.md 继续 S12
```

#### 评估

| 维度 | 评分 | 说明 |
|------|------|------|
| 技术可行性 | **中** | 核心问题：需要 SKILL.md LLM 正确解读脚本的 exit code 并执行回调。这本质上是半 LLM 驱动 |
| 用户体验 | **中-高** | 修复阶段利用父 session，用户可以看到修复过程 |
| 实现复杂度 | **中** | 脚本较简单（只做评审和判断），但"回调"机制需要 SKILL.md 配合 |
| 调试可观测性 | **中-高** | 评审在脚本中有日志；修复在主 session 中可见 |
| 生态兼容性 | **高** | 最接近现有模式——脚本 + SKILL.md 配合 |
| 循环可靠性 | **中** | 循环的控制权分散在脚本和 LLM 之间。评审/判断是确定性的，但修复和"重新调用脚本"依赖 LLM |

#### 关键风险

1. **回调可靠性**：LLM 需要正确理解 exit code 含义并执行回调，这正是当前问题的根源（虽然简化了）
2. **状态同步**：脚本通过文件传递状态（哪些视角 FAIL、当前轮次等），LLM 需要正确读取并在修复后传递给下一次调用

---

### 方案 E：Claude Code 原生 Agent Loop

#### 架构

```
用户 → /product → SKILL.md 流程 S1-S10
                                ↓
                    S11: SKILL.md 使用 TeamCreate 创建 review-controller agent
                                ↓
              ┌────────────────────────────────────────────────┐
              │ review-controller agent                         │
              │ (prompt 包含精确的循环协议)                      │
              │                                                │
              │ Agent prompt:                                   │
              │ "你是评审循环控制器。严格执行以下协议：            │
              │  1. 调用 TeamCreate 创建 3 个 reviewer agent     │
              │  2. 收集评审结果                                 │
              │  3. 判断收敛（严格按规则）                        │
              │  4. 修复文档                                     │
              │  5. 回到步骤 1，直到收敛                         │
              │  ..."                                           │
              └────────────────────────────────────────────────┘
```

#### 评估

| 维度 | 评分 | 说明 |
|------|------|------|
| 技术可行性 | **高** | Agent/TeamCreate 是 Claude Code 原生能力 |
| 用户体验 | **高** | agent 在主 session 内运行，用户可以看到过程 |
| 实现复杂度 | **低** | 无需外部脚本，只需设计好 prompt |
| 调试可观测性 | **中** | agent 的思考过程可见，但如果嵌套 agent 层级深则难追踪 |
| 生态兼容性 | **高** | 完全在 Claude Code 生态内 |
| 循环可靠性 | **低** | **这正是当前问题**——LLM 驱动循环。虽然可以通过更精确的 prompt 和 sub-agent 分工改善，但本质不变 |

#### 关键风险

1. **核心矛盾**：方案 E 本质上没有解决问题——循环仍然由 LLM 驱动
2. **可能的改进方向**：如果 review-controller 的 prompt 足够精确，且配合 completion_check.sh hook 做门禁，可能比当前直接嵌入 SKILL.md 更可靠——因为 controller 的 prompt 只需专注于循环逻辑

---

## 方案对比矩阵

| 维度 | A: Bash Orchestrator | B: SDK Orchestrator | C: MCP Orchestrator | D: Hybrid | E: Agent Loop |
|------|---------------------|--------------------|--------------------|-----------|--------------|
| **循环可靠性** | ★★★★★ | ★★★★★ | ★★★★★ | ★★★ | ★★ |
| **技术可行性** | ★★★★★ | ★★★★ | ★★★ | ★★★ | ★★★★★ |
| **用户体验** | ★★★ | ★★★ | ★★ | ★★★★ | ★★★★★ |
| **实现复杂度（低=好）** | ★★★ | ★★★★ | ★★ | ★★★ | ★★★★★ |
| **调试可观测性** | ★★★ | ★★★★ | ★★ | ★★★★ | ★★★ |
| **生态兼容性** | ★★★★★ | ★★★ | ★★ | ★★★★ | ★★★★★ |
| **Token 成本** | ★★★ | ★★★ | ★★★ | ★★★★ | ★★★★★ |
| **API Key 需求** | 无（用 claude CLI 认证） | 需要 | 需要 | 无 | 无 |
| **新依赖** | 无 | Python/Node SDK | MCP Server | 无 | 无 |
| **文件系统访问** | 通过 claude -p --allowed-tools | 需要预读或 SDK tool | 需要预读或嵌入 | 原生 | 原生 |

---

## 推荐方案

### 首选：方案 A（Bash Orchestrator）

**理由**：

1. **循环可靠性最高**：while 循环、收敛判断、轮次计数全部是确定性 Bash 代码，不依赖 LLM 遵守指令
2. **无新依赖**：不需要 API key（利用 claude CLI 的现有认证）、不需要 Python/Node 环境、不需要 MCP 配置
3. **生态一致**：与现有 hooks/scripts 生态完全一致——hooks/lib/common.sh 已有丰富的 Markdown 解析、状态管理工具函数
4. **claude CLI 功能完备**：`-p` + `--output-format json` + `--json-schema` + `--allowed-tools` + `--system-prompt` 足够支持程序化调用
5. **渐进式采用**：可以逐个 skill 迁移，不影响其他 skill

**对方案 A 的主要顾虑与缓解**：

| 顾虑 | 缓解策略 |
|------|---------|
| claude -p 子进程上下文断裂 | 脚本预读所有相关文件，拼入 reviewer prompt 的 user message。文档内容是自包含的 |
| Bash 解析 JSON 复杂 | 已有 jq 依赖（hooks/lib/common.sh 使用 jq）；reviewer 输出由 `--json-schema` 约束结构 |
| 每轮 4 次 CLI 调用的成本 | 1) 可用 sonnet 而非 opus 做评审（`--model sonnet`）降低成本；2) 收敛快的话只需 2-3 轮 |
| 用户体验（脚本运行时无交互） | 1) stderr 输出进度信息；2) 修复阶段可选"脚本修复"或"回到主 session 让用户看修复过程"（方案 A+D 混合） |

### 次选：方案 A+D 混合（Bash 评审 + 主 Session 修复）

如果修复阶段的质量很重要（修复需要理解完整上下文），可以采用混合策略：

- **评审阶段**：Bash 脚本调用 claude -p 做并行评审（确定性控制）
- **修复阶段**：脚本输出修复指令后退出，由主 session LLM 执行修复（利用完整上下文）
- **再评审**：主 session LLM 再次调用脚本

这牺牲了一部分循环可靠性（修复→再调用脚本的环节依赖 LLM），但换来了更好的修复质量和用户体验。

### 不推荐

- **方案 C（MCP）**：超时风险 + 无进度反馈 + 维护复杂度，收益不足以抵消
- **方案 E（Agent Loop）**：没有解决核心问题

---

## 推荐方案（A）实现骨架

### 文件结构

```
shared/skills/lib/
  review_loop.sh        # 通用评审循环编排器
  review_schema.json    # reviewer 输出 JSON Schema

shared/skills/product/
  scripts/
    completion_check.sh # 现有，不变
  references/
    prd-reviewer-prompt.md      # 已有
    architect-reviewer-prompt.md # 已有
    tester-reviewer-prompt.md    # 已有

# design、test-design 同理
```

### review_loop.sh 核心逻辑（伪代码）

```bash
#!/bin/bash
# review_loop.sh — 通用跨职能评审循环编排器
# 用法: review_loop.sh <config.json>
# config.json 包含: document_path, reviewer_configs[], max_rounds, ...

set -euo pipefail
source "$(dirname "$0")/../../hooks/lib/common.sh"

CONFIG="$1"
DOC_PATH=$(jq -r '.document_path' "$CONFIG")
MAX_ROUNDS=$(jq -r '.max_rounds // 10' "$CONFIG")
REVIEWER_CONFIGS=$(jq -c '.reviewers[]' "$CONFIG")

round=0
pending_perspectives=("all")
history_file=$(mktemp)

while [ "$round" -lt "$MAX_ROUNDS" ]; do
    round=$((round + 1))
    echo "[Round $round/$MAX_ROUNDS] 启动评审..." >&2
    
    # 1. 并行评审
    pids=()
    result_files=()
    for reviewer in $REVIEWER_CONFIGS; do
        perspective=$(echo "$reviewer" | jq -r '.perspective')
        prompt_file=$(echo "$reviewer" | jq -r '.prompt_file')
        result_file=$(mktemp)
        result_files+=("$result_file")
        
        # 预读文档内容
        doc_content=$(cat "$DOC_PATH")
        
        claude -p \
            --system-prompt "$(cat "$prompt_file")" \
            --output-format json \
            --json-schema "$(cat review_schema.json)" \
            --allowed-tools "Read,Glob,Grep" \
            --model sonnet \
            "评审以下文档:\n$doc_content" \
            > "$result_file" 2>/dev/null &
        pids+=($!)
    done
    
    # 等待所有评审完成
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
    
    # 2. 解析结果
    all_pass=true
    fail_count=0
    for result_file in "${result_files[@]}"; do
        verdict=$(jq -r '.verdict' "$result_file")
        if [ "$verdict" = "FAIL" ]; then
            all_pass=false
            fail_count=$((fail_count + 1))
        fi
    done
    
    # 3. 收敛判断
    echo "$round $fail_count" >> "$history_file"
    
    if $all_pass; then
        if [ "$round" -eq 1 ]; then
            echo "[Round $round] 首轮全 PASS，执行确认轮..." >&2
            continue
        fi
        echo "[Complete] 评审通过 (Round $round)" >&2
        break
    fi
    
    # 连续 2 轮不减少
    if [ "$round" -ge 2 ]; then
        prev_fail=$(sed -n "$((round-1))p" "$history_file" | awk '{print $2}')
        if [ "$fail_count" -ge "$prev_fail" ]; then
            echo "STAGNANT" # 信号给主 session
            exit 2
        fi
    fi
    
    # 4. 修复（调用 claude -p）
    # ... 修复逻辑 ...
done

# 输出最终报告
jq -n --arg rounds "$round" --arg result "..." \
    '{rounds: $rounds, result: $result}'
```

### SKILL.md 集成方式

在 SKILL.md 的评审步骤中，原来的文本指令改为：

```markdown
8. 跨职能评审
   - 准备评审配置文件 `review-config.json`（包含文档路径、reviewer prompt 路径、最大轮次）
   - 执行 Bash tool: `bash {{RUNTIME_HOME}}/skills/lib/review_loop.sh review-config.json`
   - 解析脚本输出的 JSON 结果
   - 将审查结论写入目标文档
```

---

## 待验证项

1. **claude -p 在 Bash tool 内调用是否受限**：需要验证 Claude Code 的 Bash tool sandbox 是否允许启动 claude CLI 子进程
2. **claude -p 的并发上限**：3 个并行 claude -p 进程是否正常工作
3. **--json-schema 的可靠性**：reviewer 输出是否严格遵守 schema
4. **修复阶段策略**：纯脚本修复（方案 A）vs 回到主 session 修复（方案 A+D）哪个更适合
5. **Token 成本实测**：一个完整评审循环的实际 API 消耗

---

## 附录：与 Task #1 和 Task #2 的关系

本报告基于已有知识和项目代码分析完成。待 Task #1（Claude Code CLI 程序化调用能力调研）和 Task #2（开源 Agent 框架调研）完成后，需要补充：

- Task #1 结果可能影响方案 A 的 claude -p 能力边界判断（如 sandbox 限制、并发行为）
- Task #2 结果可能提供方案 B 的参考实现模式（如 OpenHands 的 while 循环 + API 调用模式）

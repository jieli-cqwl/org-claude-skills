# 开源 Agent 框架代码级循环实现对比报告

## 调研范围

本报告对 5 个 Agent 框架的代码级循环实现进行系统调研：OpenHands、Claude Code、Aider、SWE-agent（含 mini-swe-agent）、LangGraph。重点提炼循环代码结构、状态持有者、终止判断者、LLM 角色、LLM 调用方式。

---

## 1. OpenHands（原 OpenDevin）

**源码位置**: `openhands/controller/agent_controller.py`

### 循环代码结构

OpenHands 采用 **事件驱动循环**（非传统 while 循环）。核心是 EventStream pub/sub 机制驱动 step 执行：

```python
# 伪代码 — 事件驱动的 step 循环
class AgentController:
    def __init__(self, agent, event_stream, ...):
        event_stream.subscribe(AGENT_CONTROLLER, self.on_event)
        self.state = State()

    async def on_event(self, event):
        if self.should_step(event):
            await self._step_with_exception_handling()

    async def _step(self):
        # 1. 状态守卫：非 RUNNING 则跳过
        if self.get_agent_state() != AgentState.RUNNING:
            return
        if self._pending_action:
            return

        # 2. 死循环检测
        if self.agent.config.enable_stuck_detection and self._is_stuck():
            await self._react_to_exception(AgentStuckInLoopError(...))
            return

        # 3. 控制标志检查（iteration/cost 上限）
        self.state_tracker.run_control_flags()

        # 4. Agent 推理：调用 LLM 产生 action
        action = self.agent.step(self.state)  # 内部调用 self.llm.completion()

        # 5. 发布 action → EventStream → Runtime 执行 → 产生 Observation
        event_stream.add_event(action, EventSource.AGENT)
        # Observation 回到 EventStream，触发下一次 on_event → _step
```

### 状态机

```
AgentState 枚举:
  RUNNING → FINISHED | REJECTED | ERROR | STOPPED
  RUNNING → AWAITING_USER_INPUT | AWAITING_USER_CONFIRMATION
  AWAITING_USER_CONFIRMATION → USER_CONFIRMED | USER_REJECTED → RUNNING
  RATE_LIMITED → RUNNING (retry 后)
  ERROR → RUNNING (用户干预后)
```

### 终止条件

| 触发器 | 结果状态 |
|--------|---------|
| Agent 返回 `AgentFinishAction` | FINISHED |
| Agent 返回 `AgentRejectAction` | REJECTED |
| 死循环检测 (`_is_stuck()`) | ERROR |
| 控制标志上限（iteration/cost） | ERROR |
| RateLimitError 重试耗尽 | ERROR |
| 用户手动停止 | STOPPED |

### 提炼维度

| 维度 | 答案 |
|------|------|
| 循环结构 | 事件驱动：EventStream → on_event → should_step → _step |
| 状态持有者 | **代码**（StateTracker + AgentState 枚举） |
| 终止判断者 | **代码 + LLM**（代码检查上限/死循环；LLM 发出 FinishAction） |
| LLM 角色 | 完整 Agent（接收全部 state，自主决策 action） |
| LLM 调用方式 | SDK API call（`self.llm.completion()`，支持多种 LLM provider） |

---

## 2. Claude Code

**公开信息来源**: 官方文档 + 架构分析

### 循环代码结构

Claude Code 采用 **单线程 while 循环**（内部代号 "nO"）。循环在模型返回无 tool_calls 的纯文本响应时自然终止：

```python
# 伪代码 — Claude Code 的 agentic loop
def agentic_loop(user_message):
    messages = [system_prompt, user_message]

    while True:
        # 1. 流式调用 Claude API
        response = claude_api.stream_completion(messages)

        # 2. 中途检测 tool_calls，流式触发执行
        if response.has_tool_calls():
            for tool_call in response.tool_calls:
                # 权限检查
                if not permission_check(tool_call):
                    result = ask_user_permission(tool_call)
                else:
                    result = execute_tool(tool_call)
                messages.append(tool_call)
                messages.append(tool_result(result))
            # 继续循环，让 Claude 看到 tool 结果后再决策
        else:
            # 3. 纯文本响应，无 tool_calls → 循环终止
            return response.text
```

### 关键设计特点

1. **Streaming-first**: API 响应是 SSE，tool_calls 在完整响应返回前就被检测和执行
2. **单线程 + flat history**: 一条消息历史，无线程/多 persona
3. **三阶段任务执行**: gather context → take action → verify results（自然融合）
4. **Sub-agent 并行**: 通过 Task Agent 系统派生子 agent，有深度限制防止递归失控
5. **实时转向**: "h2A" 双缓冲队列允许用户在 agent 执行中途注入新指令
6. **TodoWrite 规划**: 结构化 JSON 任务列表，tool_use 后注入系统消息提醒当前 TODO 状态

### 终止条件

| 条件 | 行为 |
|------|------|
| Claude 返回纯文本（无 tool_calls） | 循环自然终止 |
| 用户中断（Ctrl+C / 输入新指令） | 中断当前执行，切换方向 |
| Context window 耗尽 | 自动 compaction 或报错 |

### 提炼维度

| 维度 | 答案 |
|------|------|
| 循环结构 | `while True` + tool_calls 检测，无 tool_calls 时 break |
| 状态持有者 | **LLM**（flat message history 是唯一状态；代码只管权限和执行） |
| 终止判断者 | **LLM**（选择不调用 tool 即终止；代码仅处理异常退出） |
| LLM 角色 | 完整 Agent（完全自主决策：选工具、读结果、决定下一步） |
| LLM 调用方式 | Anthropic API（流式 SSE，支持多 tool 并行调用） |

---

## 3. Aider

**源码位置**: `aider/coders/base_coder.py`

### 循环代码结构

Aider 采用 **反射循环（reflection loop）**，基于 `reflected_message` 信号驱动重试：

```python
# 伪代码 — Aider 的 edit-test-fix 反射循环
class Coder:
    max_reflections = 3

    def run_one(self, user_message):
        message = user_message
        self.num_reflections = 0

        while message:
            self.reflected_message = None

            # 1. 发送消息给 LLM，获取代码编辑
            self.send_message(message)
            # send_message 内部：
            #   response = llm.completion(messages)
            #   edits = parse_edits(response)
            #   apply_edits(edits)
            #   git_commit(edits)

            # 2. 检查是否需要反射（lint/test 失败）
            if not self.reflected_message:
                break  # 无问题，终止

            # 3. 反射上限检查
            if self.num_reflections >= self.max_reflections:
                warn("Only N reflections allowed, stopping.")
                return

            self.num_reflections += 1
            message = self.reflected_message  # 用错误信息作为下一轮输入

    def send_message(self, message):
        # ... LLM 调用、编辑应用、git commit ...

        # Auto-lint 阶段
        if edited and self.auto_lint:
            lint_errors = self.lint_edited(edited)
            if lint_errors:
                if user_confirms("Attempt to fix lint errors?"):
                    self.reflected_message = lint_errors
                    return

        # Auto-test 阶段
        if edited and self.auto_test:
            test_errors = self.cmd_test(self.test_cmd)
            if test_errors:
                if user_confirms("Attempt to fix test errors?"):
                    self.reflected_message = test_errors
                    return
```

### 关键设计特点

1. **反射信号**: `reflected_message` 非 None 时触发下一轮循环
2. **三种反射源**: 文件引用（LLM 提到未加载文件）、lint 错误、test 错误
3. **用户确认门控**: lint/test 失败后需用户确认才进入修复循环
4. **硬上限**: `max_reflections = 3` 防止无限消耗 token

### 终止条件

| 条件 | 行为 |
|------|------|
| `reflected_message` 为 None | 循环自然终止（无错误） |
| `num_reflections >= max_reflections` | 强制停止，发出警告 |
| 用户拒绝修复提示 | `reflected_message` 保持 None |
| 用户中断 | 设置 `interrupted` 标志 |
| Context window 耗尽 | `show_exhausted_error()` 并返回 |

### 提炼维度

| 维度 | 答案 |
|------|------|
| 循环结构 | `while message` + `reflected_message` 信号驱动 |
| 状态持有者 | **代码**（`reflected_message`、`num_reflections` 由代码管理） |
| 终止判断者 | **代码**（lint/test 通过 → 无反射 → 终止；上限检查） |
| LLM 角色 | 单步 Worker（每轮只做"给定错误信息 → 产出修复编辑"） |
| LLM 调用方式 | SDK API call（通过 litellm 统一接口，支持多 provider） |

---

## 4. SWE-agent / mini-swe-agent

**源码位置**: 
- SWE-agent: `sweagent/agent/agents.py`
- mini-swe-agent: `src/minisweagent/agents/default.py`

### 循环代码结构（mini-swe-agent — 当前主力）

mini-swe-agent 采用 **经典 while True 循环**，极简约 100 行：

```python
# 伪代码 — mini-swe-agent 的 DefaultAgent
class DefaultAgent:
    def __init__(self, model, environment, config):
        self.model = model
        self.env = environment
        self.messages = []
        self.n_calls = 0
        self.cost = 0.0

    def run(self, task):
        # 初始化 system + instance prompt
        self.messages = [system_msg, instance_msg(task)]

        while True:
            try:
                self.step()
            except InterruptAgentFlow as e:
                self.add_messages(*e.messages)
            except Exception as e:
                self.handle_uncaught_exception(e)
                raise
            finally:
                self.save(self.config.output_path)

            # 终止判断：最后一条消息 role == "exit"
            if self.messages[-1].get("role") == "exit":
                break

        return self.messages[-1].get("extra", {})

    def step(self):
        return self.execute_actions(self.query())

    def query(self):
        # 限制检查
        if (0 < self.config.step_limit <= self.n_calls or
            0 < self.config.cost_limit <= self.cost):
            raise LimitsExceeded()

        self.n_calls += 1
        response = self.model.query(self.messages)
        self.cost += response.extra.cost
        self.messages.append(response)
        return response

    def execute_actions(self, message):
        actions = message.get("extra", {}).get("actions", [])
        outputs = [self.env.execute(action) for action in actions]
        obs_messages = self.model.format_observation_messages(outputs)
        self.messages.extend(obs_messages)
        return obs_messages
```

### SWE-agent（原版）循环结构

```python
# 伪代码 — SWE-agent DefaultAgent
class DefaultAgent:
    def run(self, env, problem_statement, output_dir):
        self.setup(env, problem_statement, output_dir)
        step_output = StepOutput()  # done=False

        while not step_output.done:
            step_output = self.step()
            self.save_trajectory()

        return AgentRunResult(info=self.info, trajectory=self.traj_path)

    def step(self):
        output = self.forward_with_handling(self.messages)
        self.add_step_to_history()
        self.add_step_to_trajectory()
        return output  # StepOutput(done=True/False)
```

### 关键设计差异

| 特性 | SWE-agent | mini-swe-agent |
|------|-----------|----------------|
| 工具调用 | 自定义 ACI 工具集 | 只有 bash（不用 tool-calling 接口） |
| 执行方式 | Docker 内有状态 shell | `subprocess.run`（无状态，独立执行） |
| 消息历史 | 经 history processor 处理 | 完全线性（messages == trajectory） |
| 状态管理 | StepOutput + AgentInfo | 简单 role=="exit" 检查 |
| 重试 | RetryAgent 包装多次尝试 | 无内置重试 |

### 终止条件（SWE-agent）

| 条件 | exit_status |
|------|-------------|
| 提交 patch | `submitted` |
| 发出 exit 命令 | `exit_command` |
| 费用超限 | `exit_cost` |
| Context 超限 | `exit_context` |
| 放弃 token | `exit_forfeit` |
| 格式错误过多 | `exit_format` |
| 命令超时 | `exit_command_timeout` |
| 执行时间超限 | `exit_total_execution_time` |
| 运行时错误 | `exit_error` |

### 提炼维度

| 维度 | 答案 |
|------|------|
| 循环结构 | `while True` + step() + exit 条件检查 |
| 状态持有者 | **代码**（step_limit、cost_limit、exit 条件由代码追踪） |
| 终止判断者 | **代码 + LLM**（代码检查资源上限；LLM 可发 submit/exit 命令） |
| LLM 角色 | 完整 Agent（自主选择 bash 命令，自由探索） |
| LLM 调用方式 | SDK API call（通过 litellm 统一接口） |

---

## 5. LangGraph

**源码位置**: `libs/langgraph/langgraph/graph/graph.py`, `libs/langgraph/langgraph/graph/state.py`

### 循环代码结构

LangGraph 提供两种等价实现方式：

#### 方式 A：Graph API（声明式 — 推荐生产用法）

```python
# 伪代码 — LangGraph StateGraph 循环模式
from langgraph.graph import StateGraph, END

# 1. 定义状态
class AgentState(TypedDict):
    messages: list

# 2. 定义节点
def call_model(state: AgentState):
    response = model.invoke(state["messages"])
    return {"messages": [response]}

def call_tools(state: AgentState):
    last_msg = state["messages"][-1]
    results = [execute_tool(tc) for tc in last_msg.tool_calls]
    return {"messages": results}

# 3. 定义路由（条件边）
def should_continue(state: AgentState) -> str:
    last_msg = state["messages"][-1]
    if last_msg.tool_calls:
        return "tools"       # → 继续循环
    return END               # → 终止

# 4. 组装图（循环在此形成）
graph = StateGraph(AgentState)
graph.add_node("model", call_model)
graph.add_node("tools", call_tools)
graph.set_entry_point("model")
graph.add_conditional_edges("model", should_continue, {"tools": "tools", END: END})
graph.add_edge("tools", "model")  # ← 关键：tools → model 形成循环
app = graph.compile()
```

#### 方式 B：Functional API（命令式 — 更直观）

```python
# 伪代码 — LangGraph Functional API 循环
@entrypoint(checkpointer=checkpointer)
def agent(messages, previous):
    if previous is not None:
        messages = add_messages(previous, messages)

    response = call_model(messages).result()

    while True:
        if not response.tool_calls:
            break  # 无 tool_calls → 终止
        # 并行执行 tools
        tool_results = [call_tool(tc).result() for tc in response.tool_calls]
        messages = add_messages(messages, [response, *tool_results])
        response = call_model(messages).result()

    return entrypoint.final(value=response, save=messages)
```

### 关键设计特点

1. **状态图 + 条件边**: 循环由 `add_edge("tools", "model")` + `add_conditional_edges("model", should_continue)` 形成
2. **声明式 vs 命令式**: Graph API 声明循环拓扑；Functional API 用 while 循环
3. **内置安全**: `_are_more_steps_needed()` 防止无限循环
4. **中间件/钩子**: Graph 编译后可注入 middleware，支持 human-in-the-loop
5. **Checkpointing**: 每个节点执行后可持久化状态，支持中断恢复

### 终止条件

| 条件 | 行为 |
|------|------|
| `should_continue` 返回 END | 图执行到 END 节点 |
| 步数超限 | `_are_more_steps_needed()` 返回终止消息 |
| 异常 | 图执行中断 |

### 提炼维度

| 维度 | 答案 |
|------|------|
| 循环结构 | 有向图的环：`model → (conditional) → tools → model`；或 `while True` |
| 状态持有者 | **代码**（TypedDict 状态对象，节点间通过状态传递数据） |
| 终止判断者 | **代码**（路由函数检查 tool_calls；步数上限） |
| LLM 角色 | 单步 Worker（每次只做"给定 messages → 返回 response"） |
| LLM 调用方式 | SDK API call（通过 LangChain model 抽象层） |

---

## 共同模式提炼

### 模式 1：核心循环骨架

所有框架的 Agent 循环归结为同一个基本模式：

```
while not done:
    response = LLM(state)
    actions = extract_actions(response)
    if no_actions(actions):
        done = True
    else:
        for action in actions:
            observation = execute(action)
            state = update(state, action, observation)
```

差异在于"谁驱动这个 while"和"state 住在哪里"。

### 模式 2：循环驱动方式分类

| 驱动方式 | 框架 | 特点 |
|----------|------|------|
| **事件驱动** | OpenHands | EventStream pub/sub，step 由事件触发 |
| **While 循环** | Claude Code, mini-swe-agent, LangGraph(Functional) | 显式 while True，tool_calls 空时 break |
| **反射循环** | Aider | while message + reflected_message 信号驱动 |
| **图执行** | LangGraph(Graph API) | 条件边 + 普通边形成有向环 |

### 模式 3：状态持有者谱系

```
LLM 持有状态 ←————————————————————→ 代码持有状态
    Claude Code    SWE-agent    OpenHands    Aider    LangGraph
    (flat history  (messages    (StateTracker (reflected (TypedDict
     是唯一状态)    + 代码上限)  + AgentState)  _message)   state)
```

- **Claude Code**: 状态几乎完全在 LLM 的 message history 中，代码只管权限和工具执行
- **LangGraph**: 状态完全由代码管理的 TypedDict，LLM 只是一个纯函数节点

### 模式 4：终止判断谱系

```
LLM 判断终止 ←————————————————————→ 代码判断终止
    Claude Code    SWE-agent    OpenHands    Aider    LangGraph
    (不调 tool     (submit/     (FinishAction (lint/test  (路由函数
     即终止)        exit 命令)   + 代码守卫)   通过即止)   检查 tool_calls)
```

- **Claude Code**: LLM 选择不调用工具 = 终止（最纯粹的 LLM 驱动终止）
- **Aider**: 代码运行 lint/test，通过就终止（最纯粹的代码驱动终止）

### 模式 5：LLM 角色谱系

| 角色 | 框架 | 含义 |
|------|------|------|
| **完整 Agent** | Claude Code, OpenHands, SWE-agent | LLM 接收全部上下文，自主决策下一步行动 |
| **单步 Worker** | Aider, LangGraph | LLM 只做"给定输入 → 产出输出"，循环逻辑由代码控制 |

### 模式 6：安全防护层

所有框架都实现了至少一种防无限循环机制：

| 框架 | 防护机制 |
|------|---------|
| OpenHands | `_is_stuck()` 死循环检测 + control_flags 上限 |
| Claude Code | Context window 耗尽时自动 compaction 或停止 |
| Aider | `max_reflections = 3` 硬上限 |
| SWE-agent | step_limit + cost_limit + 多种 exit_status |
| LangGraph | `_are_more_steps_needed()` 步数检查 |

---

## 对 skill-as-program 的启示

### 与 Claude Code Skill 评审循环的映射

当前 skill 评审循环本质上是 Aider 模式的变体：
- **循环驱动**: 代码检查评审结果 → 有问题则反射 → 再次调用 LLM 修复
- **终止判断**: 代码侧（评审通过 or 达到最大轮次）
- **LLM 角色**: 单步 Worker（每轮做"给定评审意见 → 产出修复"）

### 推荐的代码驱动循环模型

基于调研结果，推荐采用 **mini-swe-agent 的 while True + step() 模式** 作为基础骨架，原因：

1. **极简**: 核心循环约 30 行代码
2. **线性历史**: messages 即 trajectory，便于调试
3. **代码控制终止**: step_limit + cost_limit + 条件检查
4. **LLM 做 Worker**: 每步只需"给定上下文 → 产出操作"
5. **已验证**: SWE-bench >74% 性能

映射到 skill 评审循环：

```python
# skill 评审循环骨架（借鉴 mini-swe-agent + Aider 反射）
def review_fix_loop(code, max_rounds=3):
    messages = [system_prompt, code_context]
    round = 0

    while round < max_rounds:
        # Step 1: 评审
        review = llm.query(messages + [review_prompt])
        messages.append(review)

        # Step 2: 代码判断终止
        issues = parse_issues(review)
        if not issues:
            return ReviewResult(status="passed", round=round)

        # Step 3: 修复
        fix = llm.query(messages + [fix_prompt(issues)])
        messages.append(fix)
        apply_fix(fix)

        # Step 4: 验证
        verify_result = run_verification()
        messages.append(verify_result)
        round += 1

    return ReviewResult(status="max_rounds_reached", round=round)
```

---

## 信息来源

- OpenHands: https://github.com/OpenHands/OpenHands — `openhands/controller/agent_controller.py`
- Claude Code: https://code.claude.com/docs/en/how-claude-code-works
- Aider: https://github.com/Aider-AI/aider — `aider/coders/base_coder.py`
- SWE-agent: https://github.com/SWE-agent/SWE-agent — `sweagent/agent/agents.py`
- mini-swe-agent: https://github.com/SWE-agent/mini-swe-agent — `src/minisweagent/agents/default.py`
- LangGraph: https://github.com/langchain-ai/langgraph — Graph API + Functional API docs

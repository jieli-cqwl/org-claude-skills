# Dispatch Packet

## 目标

给定一个 gap，构造出让执行者能独立闭环的派发。执行者拿到 packet 后，能清楚知道：处理什么问题、在哪里操作、读什么输入、交付什么证据、何时停止、什么不能做。

## 判断框架

### 路由判断

先判断 gap 属于谁的职责域：

| Gap | 逻辑角色 | Packet `role` |
| --- | --- | --- |
| AC 未实现 | developer agent | `developer` |
| 实现后验 AC/scope | verifier agent | `verifier` |
| 已验证批次提测前整体 review | code-reviewer agent | `code-reviewer` |
| QA FAIL 或已知 bug | fixer agent | `fixer` |
| 用户路径或端到端验收 | qa agent | `qa` |
| 介入前冻结工件 baseline 一致性审计 | consistency-auditor agent | `consistency-auditor` |
| 提交准备前跨工件一致性审计 | consistency-auditor agent | `consistency-auditor` |
| QA PASS 后提交 | /commit handoff | n/a |
| scope/AC/风险/授权不清 | user decision | n/a |

executor 从当前运行时的 agent catalog、tooling 或命令入口解析；packet 只写逻辑 `role`，不写 runtime 专属文件路径。没有可用 executor 时，暂停并输出 `NEEDS_RESOURCE`。

### Scope 模型

Scope 只定义**不能做什么**，不预设应该改哪些文件：

**`forbidden_scope`（硬约束）** — 绝对不能碰的文件/目录。包括：
- 明确禁止的 baseline 文件（tasks.json 等冻结文件）。
- delivery-owner 根据风险评估额外标记的文件。
- 并行任务间存在文件/模块冲突风险时，优先串行化而非枚举禁止文件。

**实际变更范围由 developer 自主分析** — developer 拿到 goal 后，结合 `影响范围分析.md` 的三步识别法（列变更点 → 追依赖链 → 评估影响面）自行确定需要修改的文件。实际 scope 在 developer-report 的 `impact_files` 中报告。verifier 基于 AC 和 impact_files 验收。

为什么这样设计：影响文件只有实际开发者在分析代码后才最清楚。预设文件范围是 tech-lead 的规划估计，在执行阶段反而会误导——要么限制 LLM 的跨切洞察能力，要么被当作"正确答案"阻碍独立分析。`forbidden_scope` 防止真正的冲突和风险，其余交给 developer 的专业判断。

### Packet 构造

```text
task_ref:
role:
goal:
forbidden_scope:
input_refs:
expected_evidence:
stop_condition:
forbidden_actions:
```

**字段判断指导：**

- **`goal`** — 只写一个可验收目标，带 task/gap/AC 标识。不写"完成 AC-3"这样的泛目标；写"实现 AC-3 的头像上传功能并通过对应测试"。
- **`forbidden_scope`** — 列出绝对不能碰的文件/目录。至少包含冻结 baseline 文件和 delivery-owner 额外标记的风险文件。
- **`input_refs`** — 指向冻结 tasks、当前 gap、最新角色报告和失败证据。不能只写口头摘要。现场事实只提供报告名、缺少真实路径时，先用逻辑引用写清输入（例如 `developer-report:T2`、`verify-result:AC-2-missing`），并标注 `path=unavailable`。
- **`expected_evidence`** — 使用对应角色的证据合同；不能写"完成即可"。
- **`stop_condition`** — 写 PASS 条件或精确阻塞条件；不能写 "done"。
- **`forbidden_actions`** — 必须覆盖四类边界：
  - **scope 边界** — 禁止修改 `forbidden_scope` 中的文件（例：`禁止修改 src/config/ 下任何文件`）。
  - **baseline/AC 边界** — 禁止修改 AC 定义、测试基线或验收标准（例：`禁止修改 tasks.json 或 test-cases.json`）。
  - **commit/release 边界** — 禁止提交、发布或合并（例：`禁止执行 git commit/push 或调用 /commit`）。
  - **角色结论边界** — 禁止替代其他角色下结论（例：`禁止判定 QA 是否通过`）。

模糊词的标点或嵌入短语变体不合格，例如"按需处理。"和"done when ready"。

### Packet 精度校准

Packet 的详细程度应该匹配任务的不确定性：

- **高不确定性任务**（首次实现、技术验证、复杂修复）— goal 写清可验收目标，input_refs 尽量完整，expected_evidence 写明每一项需要的输出。详细的 packet 降低执行者猜测空间。
- **低不确定性任务**（明确的 bug fix、简单补充、已验证模式的复用）— goal 和 stop_condition 精确，其余字段简洁即可。过度详细的 packet 对简单任务是噪音。
- **回派任务** — 必须比上一轮更收窄。goal 写入上一轮的具体 missing gap，input_refs 指向上一轮的失败证据，expected_evidence 写明这一轮必须新增什么。复制上一轮 packet 原样重派不会产生新进展。

当任务存在已知的实现陷阱、环境注意事项或容易踩的坑时，写入 `input_refs` 中作为上下文。

## 角色 Packet 契约

| Packet | Use when | Key input refs | Expected evidence | Stop condition |
| --- | --- | --- | --- | --- |
| developer | AC 未实现、verifier missing gap 或证据缺口 | tasks、AC/test refs、最新 verify-result | developer preflight、RED/GREEN/REFACTOR、developer-report.json（含 impact_files） | AC green，或 scope/AC/环境阻塞 |
| verifier | developer/fixer 返回后需要独立验 AC/scope | AC、developer-report（含 impact_files）或 fix-result | AC/scope 独立核验、verify-result.json | PASS，或明确 missing gap |
| code-reviewer | 已验证批次提测前整体 review | 计划/需求、developer-report、verify-result、git diff 范围 | Strengths、Issues、Recommendations、Assessment、code-review-result.json 或等价审查报告 | Assessment Yes 且无阻断问题，或明确需回派问题 |
| qa | 已验证批次需要用户路径/端到端验收 | qa_handoff_contract、verify-result、用户路径、环境入口 | 用户路径证据、qa-result.json | 全部必测路径 PASS，或可复现缺陷 |
| fixer | qa-result/verify-result 给出可复现失败 | failing result、scope、相关报告 | root cause、minimal fix、影响面声明、fix-result.json | failure fixed，或精确 blocker |
| consistency-auditor | 介入前 baseline 一致性审计，或提交准备前 full 一致性审计 | baseline: brief、phase-prd、artifact-registry、plan、tasks、design、test-cases、qa_handoff_contract、cross_unit_obligations；final: baseline 输入加 developer-report、verify-result、code-review-result、qa-result、qa-result.obligation_results | advisory_only、findings、required_owner_action、consistency-audit-result.json | 无 blocked owner action，或明确回流 owner |

回派时必须收窄 packet：把上一轮 `missing gap / failing result / stale evidence` 写入 `goal` 或 `input_refs`，把下一轮必须新增的证据写入 `expected_evidence`，把停止条件写成"gap closed 或 exact blocker reported"。

## Packet 校验

`task_packet_check.sh --packet` 只接收 packet JSON 文件路径；不要把 JSON 字符串直接传给 `--packet`。临时文件命名使用当前运行环境的安全临时目录，校验后按环境约定清理。

校验前把 Task Packet 写入临时 JSON 文件：`bash shared/skills/delivery-owner/scripts/task_packet_check.sh --packet "$TASK_PACKET_JSON_PATH"`。

packet 失败先修派发包；基线或资源问题暂停给用户。

## /commit Handoff

`/commit` 是 handoff，不走 `task_packet_check.sh`；提交前仍要确认 QA PASS、风险状态、授权和提交摘要。

受限环境无法实际调用 `/commit` 时，仍输出 handoff：

```text
handoff: /commit
dispatch_ready: true
change_scope:
evidence_refs:
risk_status:
authorization:
commit_summary:
stop_condition:
```

如果输入已明确 developer/verifier/code-reviewer/qa/consistency-auditor 证据闭合、无未决风险且用户授权，`evidence_refs` 可以使用逻辑引用；不要因为路径不可用而把已满足的提交门禁改判为 DO-S1 阻断。

## 质量标准

有效的 packet 让执行者不需要回来问你任何问题就能闭环：
- goal 是一个可验收的目标，不是模糊描述。
- forbidden_scope 让执行者清楚什么不能碰；实际变更范围由执行者自主分析。
- input_refs 覆盖了执行者需要的全部上下文。
- expected_evidence 让执行者知道要交付什么。
- stop_condition 让执行者知道何时停止。

## 常见模式

| 场景 | 处理 |
| --- | --- |
| 执行者不确定自己能改什么 | 确保 forbidden_scope 清晰，明确"除了 forbidden_scope 外的文件都可以根据分析结果修改" |
| 执行者改动范围很大 | 正常——如果影响分析结论合理，大范围变更是正确的；检查 goal 是否过于宽泛 |
| 同一个 gap 回派三次仍未关闭 | 不是 packet 格式问题——参考 `references/followup-loops.md` 做根因诊断 |
| 输入只有报告名没有路径 | 用逻辑引用内联 packet，标注 `path=unavailable`；路径缺失不能替代内联 packet |

## 边界

- Packet 格式有效不等于派发有效——有效的格式加上错误的 goal 或遗漏的 input_refs 仍然会导致失败。
- 派发或回派时在回复中内联完整 Task Packet；文件链接或校验结果不能替代 packet 字段。
- `scope_item_refs`（来自 product-director 的需求追踪）只能放入 `input_refs` 解释范围来源，不能作为 scope 授权。

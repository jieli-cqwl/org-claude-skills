# TD-002 Decision

日期：2026-05-14

## 决策

`TD-002` 判定为 `warn`，但允许继续进入 `tech-lead`。

状态：

- `judgment`: `warn`
- `chain_status`: `continue`
- `grade`: `P2`

## 为什么通过

Test-design 输出满足 `TD-002` 的核心能力标准：

- 明确输入是 synthetic frozen fixture，不是真实 `qft-pai` 证据。
- 建立了 `TDO-01` 到 `TDO-13` 的追溯矩阵。
- 每个 TDO 绑定 UNIT / AC / design interface / 断言目标。
- 覆盖正向、范围外、阻断、失败、回滚/补偿和证据完整性。
- 证据期望具体到 `chain_id`、阶段状态、原因、证据摘要、`chain_record`、未执行阶段和重试记录。
- typed gap 含 type、blocking、owner、evidence refs、next action，且均为非阻断。
- QA handoff 和 Tech-lead 消费提示可被下游继续使用。
- 没有执行 QA、批准发布、拆任务、补产品/设计结论或声明真实交付。

## 为什么是 warn / P2

存在两个真实执行前必须承接的非阻断 followup：

- `GAP-TD002-01`：缺真实执行数据值，例如选定 `channel_id`、`bot_id`、样板触发语、关键上下文 keys。
- `GAP-TD002-02`：缺 `chain_record` 的真实落点和查询证据入口。

这些缺口不阻断 Stage 1 synthetic 能力验证，也不污染 Tech-lead；但进入真实样板前必须被承接。

## 工程化边界

evaluator 给出的 owner action 是 `script`：

> 把本次可枚举检查外置为 TD-002 grader：校验 synthetic 标注、禁止范围、TDO->UNIT/AC/IF 追溯、typed gap 字段、QA handoff、Tech-Lead 绑定提示。

这对应当前团队建设原则：LLM 负责语义判断、测试建模和专业产物；可枚举检查应逐步外置到 script、test 或 hook，避免 skill 变成大杂烩。

该 action 已落地：

- `tools/eval/scripts/grade_td002_dry_run.py`
- `tests/test-td002-dry-run-grader.sh`

验证命令：

```bash
bash tests/test-td002-dry-run-grader.sh
```

## 下游约束

允许：

- `tech-lead` 在 Stage 1 synthetic 语境下继续消费 `TDO-*`、`IF-*`、状态枚举、原因字段、证据摘要和停止规则。
- 将 `GAP-TD002-01/02` 作为非阻断 followup 带入 task readiness。

禁止：

- 把本输出当真实 `test-cases.json`。
- 宣称 Stage 1 全局通过。
- 进入真实 `/Users/lijieli/project/qft-pai`。
- 基于本输出做真实任务拆解、语言选型、代码重写或上线交付。

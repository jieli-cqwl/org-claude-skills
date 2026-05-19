# DES-002 Decision

日期：2026-05-14

## 决策

`DES-002` 通过，但必须暂停正式链路。

状态：

- `judgment`: `pass`
- `chain_status`: `pass_to_pause`
- `grade`: `none`

## 为什么通过

Design 输出满足 `DES-002` 的核心能力标准：

- 明确输入是 synthetic，且不把 PM-002 当真实 `qft-pai` 证据。
- 给出两种本质不同方案：
  - 方案 A：阶段门控闭环。
  - 方案 B：状态证据驱动闭环。
- 写清每种方案的适用场景、取舍和风险。
- 给出取舍矩阵、推荐方案、推荐理由和失效条件。
- 暴露 6 个待 human 裁决点，并写出 resume condition。
- 给 test-design 明确了正向、范围外、阻断、失败、证据、回滚和方案差异测试义务。
- 没有选择语言、框架、数据库、云产品。
- 没有进入任务拆解、开发计划、代码重写或真实项目交付。

## 为什么暂停

暂停原因是 design freeze 所需的人类裁决未闭合，而不是 Design 岗位能力失败。

必须由 human 裁决：

- 样板场景精确定义。
- 质量优先级：两周交付、审计可追溯、未来扩展的排序。
- 响应是否自动对外返回。
- 上下文不足的阻断阈值。
- 系统失败处理策略。
- 采用方案 A、方案 B，还是 A 加状态证据底线。

裁决前不能冻结 `design.json`，不能把本输出当正式下游输入交给 test-design、tech-lead 或 delivery-owner。

## 后续允许路径

允许：

- 记录为 Design 正向专业能力通过样例。
- 后续用明确标注的 synthetic frozen design fixture 单独测试 `TD-002`。
- human 补齐裁决后，恢复同一链路并让 Design 冻结接口边界、状态语义、风险回应和验证映射。

禁止：

- 把本输出伪装成已冻结 design。
- 直接进入真实 `/Users/lijieli/project/qft-pai`。
- 基于本输出做语言选型、架构定版、任务拆解或代码重写。

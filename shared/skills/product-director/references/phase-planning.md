# Phase 规划

## 目标

把已闭合的目标、范围、本期不做范围、约束和风险，切成可交付的 Phase 级价值闭环。

Phase 基于业务价值边界切分，不基于实现步骤、组件分层、页面顺序或 UNIT 数量切分。

## 工作原则

每个 Phase 必须说明本阶段独立交付什么业务结果，以及哪些相邻价值不在本阶段内。

每个 Phase 必须有入口条件、出口条件和 `iteration_timebox_days`。

`iteration_timebox_days` 必须是 1-14 的整数；超过 14 天时，先缩小本 Phase 范围，仍无法闭合时拆出后续 Phase。

单 Phase 能在 14 天内闭合核心价值时，保持 `phase-1`，不为形式拆分。

后续 Phase 只能扩展已闭合价值，不得依赖前一 Phase 的未完成部分才能成立。

风险或未知项会改变 Phase 边界、顺序、入口条件、出口条件或 timebox 时，先回到风险与范围事实验证。

## 执行步骤

1. 读取已闭合的根问题、用户画像、成功标准、投入边界、范围、本期不做范围、可行性约束、风险与未知项。
2. 从核心范围中提取业务价值片段：用户或业务在本阶段结束后能观察到什么改变。
3. 为每个候选 Phase 写价值边界：阶段内交付的业务结果、阶段外排除的相邻价值。
4. 按价值闭环排序：核心闭环先交付，增强价值后置。
5. 写入口条件：开始本 Phase 前必须已确认的业务事实、约束事实、依赖可用性或前序 Phase 出口。
6. 写出口条件：本 Phase 完成后可观察的业务状态，不写任务完成清单。
7. 估算 `iteration_timebox_days`；任一 Phase 超过 14 天时，先裁剪增强价值，再按独立业务结果拆 Phase。
8. 单列 `推荐理由`：为什么当前 Phase 能直接支撑成功标准，为什么相邻价值不进入本期。
9. 检查风险与未知项；只要它会改变 Phase 判断，停回风险与范围事实验证。
10. 检查是否写入 UNIT、AC、`scope_item_id`、字段、状态流转、设计或实现方案；发现后删除或退回产品经理同事后续细化。

## 检查点

- Phase 列表：
  - Phase：
  - 价值边界：
  - 阶段内业务结果：
  - 阶段外相邻价值：
  - 入口条件：
  - 出口条件：
  - `iteration_timebox_days`：
  - 拆分理由：
- 推荐理由：
- 单 Phase / 多 Phase 判断：
- 影响 Phase 的风险与未知项：
- 待验证关键事实：

## 最终 JSON 映射

- Phase 顺序对应 `brief.json.delivery_plan[].phase_id`。
- Phase 级业务结果对应 `brief.json.delivery_plan[].goal` 和 `phase-prd.json.phase_goal`。
- `iteration_timebox_days` 对应 `brief.json.delivery_plan[].iteration_timebox_days`。
- 入口条件对应 `phase-prd.json.entry_conditions`。
- 出口条件对应 `phase-prd.json.exit_conditions`。

价值边界、拆分理由、阶段外相邻价值先保留在 Director 台账检查点；只有能落入模板既有字段时才写入最终 JSON，不新增模板外字段。

`phase-prd.json.unit_index` 保持空索引，等待产品经理同事分解。

## 停止条件

无法写清 Phase 的独立业务结果时，停在 Phase 边界收口。

入口条件或出口条件写成任务、方案、AC 或实现完成项时，改写为业务事实或可观察业务状态。

任一 Phase 的 `iteration_timebox_days` 超过 14 天时，不得冻结；先缩范围或拆 Phase。

风险、未知项或可行性约束可能推翻 Phase 拆法时，回到风险与范围事实验证。

多 Phase 之间存在硬依赖，导致前一 Phase 不能独立交付价值时，重新合并或调整边界。

Phase 只是按实现层、页面、接口、数据表或 UNIT 数量分组时，重新按业务价值切分。

## 反模式

- 按前端、后端、接口、数据迁移或页面顺序拆 Phase。
- 用 UNIT 数量凑 Phase。
- 把“完成设计”“完成开发”“通过验收”写成出口条件。
- 明知超过 14 天仍冻结，把范围压力留给产品经理同事。
- 为没有独立业务结果的增强项创建独立 Phase。
- 记录会改变 Phase 的风险后仍继续冻结。

## 输出边界

Phase 规划步骤只形成可闭合的 Phase 规划和 Director 台账检查点。

物理 `phase-{N}/` 目录、`brief.json` 和 `phase-{N}/phase-prd.json` 只能在收到明确 `产品总监确认` 且台账验证通过后写入。

Director 只写 Phase 级价值边界、入口条件、出口条件和 timebox。

Director 不写 UNIT、AC、`scope_item_id`、字段、状态流转、设计方案或实现方案。

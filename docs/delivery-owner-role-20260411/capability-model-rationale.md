# Delivery Owner 能力模型为什么要先定义

## 目的

说明为什么在继续改造 `delivery-owner` 之前，必须先定义一份明确的能力模型。

这份文档不讨论具体实现细节，只回答一件事：

`为什么要先定义 Delivery Owner 真正应该具备的能力`

## 要解决的问题

如果不先定义能力模型，后续改造会持续遇到 3 个问题：

1. 改造对象不清楚
   - 我们会不断改 `SKILL.md`、template、script、tests`
   - 但无法判断这些改动是不是在补 `delivery-owner` 的核心能力

2. 讨论会反复打转
   - 每次都会回到“这个该不该归 `delivery-owner`”
   - 但没有统一判断尺子

3. 落地会失真
   - 文档里写了很多职责
   - 真正被脚本、模板、测试托住的，可能只是其中一部分

因此，当前最先缺的不是“多一个 gate”或“多一条规则”，而是：

`一份可以稳定裁决边界、评估现状、指导落地的能力真源`

## 为什么要从整条链路反推

`delivery-owner` 不是独立存在的角色，它处在整条标准链路中：

`product → design → test-design → tech-lead → delivery-owner → qa → user sign-off`

所以能力定义不能只看当前 skill 写了什么，而要看：

- 上游已经提供了什么
- 下游必须消费什么
- 执行期到底需要谁来判断、谁来推进、谁来收口

也就是说，能力模型不是从“当前文案”推出的，而是从“链路责任”反推出的。

## 能力模型是用来做什么的

能力模型至少承担 4 个作用：

1. 定义边界
   - 明确哪些能力是 `delivery-owner` 必须具备的
   - 哪些能力不该塞进这个角色

2. 审计现状
   - 判断每项能力现在是 `真实具备 / 部分具备 / 只有文案`

3. 指导落地
   - 把每项能力映射到 `SKILL.md / templates / scripts / tests / replay`

4. 约束后续讨论
   - 以后新增机制时，先问它服务哪项能力
   - 不能映射到核心能力的内容，不进入真源

## 能力矩阵会长什么样

后续要产出的 `Delivery Owner 能力矩阵`，不是职责口号表，而是一张可执行的能力表。

每项能力至少要包含：

- 能力名称
- 要达成的结果
- 关键决策点
- 关键输入
- 关键输出
- 触发器
- 升级动作
- 明确边界
- 当前具备状态
- 落地载体（skill / template / script / test）

这样它才能真正成为“能力真源”，而不是又一份描述性文档。

## 为什么这一步排在最前

因为后面的所有工作都依赖它：

- 要评估当前 `delivery-owner` 是否做到位，需要能力模型
- 要判断哪些能力必须做实，需要能力模型
- 要把能力落到脚本和测试，需要能力模型
- 要验收这次改造有没有完成，需要能力模型

一句话说：

`能力模型是 delivery-owner 后续所有改造的判断基线`

## 下一步产出

在这份说明之后，下一步应直接产出 3 份工件：

1. [delivery-owner-capability-matrix.md](/Users/lijieli/org-claude-skills/docs/delivery-owner-role-20260411/delivery-owner-capability-matrix.md)
   - 定义 Delivery Owner 真正必须具备的能力

2. `delivery-owner-capability-audit.md`
   - 逐项判断当前是否真实具备

3. `delivery-owner-capability-rollout.md`
   - 把能力映射到 skill、template、script、tests 的落地矩阵

## 一句话结论

先定义 `Delivery Owner` 的能力模型，不是为了多写一份文档，而是为了让后续改造有统一边界、统一评估标准和统一落地目标。

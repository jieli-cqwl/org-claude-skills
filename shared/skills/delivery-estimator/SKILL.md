---
name: delivery-estimator
user-invocable: true
disable-model-invocation: true
description: Use when 需要评估需求排期、交付日期、项目计划、WBS、甘特图、关键路径、里程碑、投入时长、AI agent 并行计划、风险缓冲或老板/业务可验收的交付排期计划。
eval-type: encoded_preference
argument-hint: "[需求描述、phase-dir 或 tasks refs]"
allowed-tools: Read, Write, Bash, Glob, Grep
---

# /delivery-estimator -- 项目排期计划与交付投入评估

## HARD-GATE

1. NO schedule plan without explicit assumptions, baseline and data date.
   - Why: 排期是承诺工具，不是许愿。缺数据可以估，但必须把假设、版本和状态基准摊开。
2. NO delivery commitment without WBS, calendar dates, Gantt timeline, milestones, dependencies, critical path and risk buffer.
   - Why: 业务要日期，老板要投入和风险；没有结构的日期无法管理。
3. NO model-only arithmetic for P50, P80, P95, float/slack or calendar finish dates.
   - Why: PERT、关键路径、日历化日期、并行批次和缓冲是可复验计算，必须用 `scripts/estimate_schedule.py` 计算或复核。
4. NO changing product scope, architecture, AC, test obligations or frozen task contracts.
   - Why: 本 skill 只评估排期和投入；范围变化必须回到对应 owner。
5. NO final report that hides unknowns.
   - Why: 未知项必须转成风险、readiness 任务、缓冲或重估触发条件。

## 角色

你是项目排期负责人，服务新的生产模型：`1 人 + AI agents`，可按需使用 Codex、Claude Code 和多个 agent，token 不是主要瓶颈。

判断重心：
- 业务关心：什么时候能交付、交付范围是什么、哪些风险会影响承诺。
- 老板关心：人类投入多少、每个环节周期/产出是什么、瓶颈和风险在哪里。
- 交付负责人关心：WBS、甘特图、关键路径、里程碑、并行批次、资源约束、风险缓冲和 rebaseline 规则。

## 状态表

| 状态 | 进入条件 | 允许动作 | 退出条件 |
| --- | --- | --- | --- |
| Scope Intake | 需求、phase-dir 或 tasks refs 已提供 | 明确范围、交付口径、起始日期、日历、baseline 和假设 | 范围与假设可写入 `estimate-input.json` |
| Schedule Modeling | WBS、依赖和三点估算已具备 | 运行 `estimate_schedule.py`，生成 JSON 和 Markdown | 输出包含日期、甘特图、WBS、里程碑、关键路径和风险 |
| Review | 排期计划包已生成 | 检查范围漂移、计算证据、可读性、风险承接和重估条件 | 目标内缺口清零 |
| Re-estimate | AC 变化、readiness 失败、关键路径验证失败或 QA 主路径 FAIL | 更新输入、重新运行脚本，不保留旧结论当新事实 | 新计划版本和 data date 已生成 |
| Rebaseline | scope/AC 被正式变更并接受 | 提升 baseline version，保留旧计划为历史证据 | 新 baseline 被业务/老板接受 |

## 流程

1. 对齐排期对象
   - 明确需求名称、范围、目标用户、交付口径、计划起始日期、工作日历和是否已有 `brief / phase-prd / design / test-cases / tasks`。
   - 如果输入是原始需求，先输出估算假设与缺口，不替用户补产品结论。
   - 如果输入是 `phase-dir` 或 `tasks.json`，优先消费冻结产物，不用对话摘要覆盖 canonical JSON。

2. 建立 WBS 字典
   - 拆成项目管理 work package：产品/澄清、设计、测试义务、开发、验证、QA、发布/交接。
   - 每个 work package 写清 `wbs_id / owner / resource / inputs / outputs / acceptance / status / percent_complete`。
   - 外部依赖、权限、数据、第三方 SDK 或环境条件要建 readiness/spike 项，不塞进正常开发估算里糊弄过去。

3. 标注依赖、并行批次、关键路径和里程碑
   - 识别哪些任务能交给多个 AI agents 并行，哪些因共享文件、共享数据、同一路径或验收依赖必须串行。
   - 标出 critical path 与 float/slack；critical path 决定交付日期，非关键路径决定资源峰值和管理复杂度。
   - 定义 milestone：计划确认、开发完成、验证通过、QA/signoff、release/handoff；每个 milestone 需要 owner、退出条件和证据。

4. 三点估算并运行计算器
   - 为每个任务给出 `optimistic / most_likely / pessimistic` 的 `human_hours` 与 `elapsed_hours`。
   - 用 `templates/estimate-input.template.json` 组织输入，必须包含 `project_start_date / calendar / baseline / assumptions / tasks`。
   - 运行：
     ```bash
     python3 shared/skills/delivery-estimator/scripts/estimate_schedule.py --input <estimate-input.json> --output <schedule-plan.json> --markdown <schedule-plan.md>
     ```
   - 计算器负责 PERT、P50/P80/P95、日历化交付日期、甘特图、关键路径、float/slack、并行 wave、里程碑、风险清单、stage rollup 和 Markdown 排期计划包。

5. 形成排期计划包
   - 使用 `projections/delivery-estimate-template.md` 的结构汇报。
   - 先给一页结论：推荐承诺日期、P50/P80/P95 日期与小时、人类投入、最大 AI agents 并发、关键路径、最大风险和是否建议承诺。
   - 再给证据：Mermaid Gantt、WBS 字典、里程碑、依赖/关键路径、资源与 AI-agent 计划、环节投入产出、风险缓冲、重估规则。

6. 复检与重估条件
   - 检查范围是否被暗中扩大，风险是否被任务承接，估算是否混淆人类投入和 wall-clock。
   - 任一高风险 readiness 失败、AC 变更、第三方依赖不可用、验证轮次超过预期或 QA 主路径 FAIL 时，必须重估。
   - scope/AC 变化才允许 rebaseline；普通延迟先更新 actual/status，不得伪装成新基线。

## 输出

- `estimate-input.json`
  - format: JSON
  - template: `templates/estimate-input.template.json`
  - consumer: `scripts/estimate_schedule.py`
- `schedule-plan.json`
  - format: JSON from `scripts/estimate_schedule.py`
  - consumer: 用户、老板、delivery-owner、tech-lead 回流决策
- `schedule-plan.md`
  - format: Markdown from `scripts/estimate_schedule.py --markdown`
  - template reference: `projections/delivery-estimate-template.md`
  - consumer: 业务交付承诺、资源投入评审、风险接受讨论

## 完成校验

- [ ] 已复述目标、操作对象、预期结果和成功标准。
- [ ] 已输出计划起始日期、工作日历、baseline version、data date 和 status。
- [ ] 已区分人类投入时长与交付 wall-clock。
- [ ] 已列 WBS 字典、甘特图、里程碑、依赖、关键路径、float/slack、并行批次和集成收口点。
- [ ] 已输出 P50、P80、P95 的小时、工作日和日历日期。
- [ ] 已列每个环节的投入、周期、产出、owner、resource、status 和完成信号。
- [ ] 已写明假设、未知项、风险触发、缓冲、mitigation、owner、重估触发和 rebaseline 条件。
- [ ] PERT / P50 / P80 / P95 / float / 日期由 `scripts/estimate_schedule.py` 计算或复核。
- [ ] 未改写产品范围、架构决策、AC、测试义务或冻结 Task 合同。

Proof commands for this skill package:

```bash
bash tests/test-delivery-estimator-contract.sh
python3 tests/test-delivery-estimator-calculator.py
python3 tools/skill_quality/check_skill_package_quality.py shared/skills/delivery-estimator
```

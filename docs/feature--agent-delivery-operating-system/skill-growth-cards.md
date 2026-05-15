# Stage 1 Skill Growth Cards

日期：2026-05-14

## 结论

本文件记录 Stage 1 首轮 dry-run 后，各关键 skill 的成长方向。

成长卡不是“模型发挥好不好”的评价，而是团队负责人对每位角色同事的培养计划：哪些能力要保留，哪些退化风险要防，哪些确定性检查要交给工程化。

## Product Director Skill

强项：

- 能把方案诉求拉回业务根问题。
- 能识别目标冲突和 Phase 价值切分。
- 能正确停在 human 事实确认点。

退化风险：

- 容易因为用户强烈表达“重写/平台化”而过早进入方案。
- 过多 `pass_to_pause` 会导致链路缺少可恢复输入，需要更明确的 resume package。

成长动作：

- 已验证 `PD-003`：主观满意指标可观察化。
- 已验证 `E2E-RESUME-001`：human resume package 能恢复 Director 暂停点，并让 PM 不脑补接续。
- 将禁止语言选型、禁止直接接受重写的检查外置为轻量 script 或 evaluator assertion。

已外置：

- `tools/eval/scripts/grade_pd003_dry_run.py`
- `tools/eval/scripts/grade_e2e_resume001_chain.py`
- `tests/test-stage1-003-dry-run-graders.sh`
- `tests/test-e2e-resume001-chain-grader.sh`
- `tools/eval/scripts/run_stage1_dry_run_graders.py`
- `tools/eval/scripts/run_stage1_eval_checks.py`

## Product Manager Skill

强项：

- 能守住 Director 基线准入。
- 能把 Phase 目标转成业务流程、用户路径、规则映射、UNIT 和 AC。
- 能给 Design / Test-design 提供可追溯输入。

退化风险：

- 术语冲突、同名不同义、UNIT 边界漂移尚未被压力测试。
- synthetic confirmed 输入下表现好，不等于真实用户输入下不会脑补。

成长动作：

- 已验证 `PM-003`：术语漂移与冲突 UNIT 回流。
- 增加 UNIT / AC 术语表和冲突检测 reference。
- 将 `WHY` 改写、技术方案越权、缺 Director 基线却拆 UNIT 的检查外置。

已外置：

- `tools/eval/scripts/grade_pm003_dry_run.py`
- `tests/test-stage1-003-dry-run-graders.sh`
- `tools/eval/scripts/run_stage1_dry_run_graders.py`

## Design Skill

强项：

- 能守住 canonical PRD/UNIT 准入。
- 能输出多方案、取舍、风险和待裁决点。
- 能在裁决未闭合时保护下游，不伪冻结设计。

退化风险：

- 方案表达可能停留在 high-level，接口 error、观测、回滚、失败语义还未被专项压测。
- `DES-002` 正确暂停依赖 human 裁决，恢复后的 frozen design 仍需专门验证。

成长动作：

- 已验证 `DES-003`：接口 input/output/error、观测、幂等、重试、降级、回滚。
- 已验证 Stage 2 design package gate：canonical `design.json`、review digest、reference integrity、design ledger、final confirmation 和实现禁区已可确定性检查。
- 为 frozen design 增加结构化接口契约模板。
- 将“单方案拍板”“选语言框架”“缺回滚还继续”的检查外置。

已外置：

- `tools/eval/scripts/grade_des003_dry_run.py`
- `tools/eval/scripts/validate_stage2_design_package.py`
- `tools/eval/scripts/validate_stage2_design_materials.py`
- `tests/test-stage1-003-dry-run-graders.sh`
- `tests/test-stage2-design-package.sh`
- `tools/eval/scripts/run_stage1_dry_run_graders.py`
- `tools/eval/scripts/run_stage1_eval_checks.py`

## Test Design Skill

强项：

- 能从 AC 和 design interface 推导 TDO traceability。
- 能覆盖正向、边界、失败、回滚/补偿和证据完整性。
- 能输出 typed gap、QA handoff 和 Tech-lead 消费提示。

退化风险：

- 测试清单可能退化为通用项，丢失 TDO 到 UNIT/AC/IF 的强追溯。
- 非阻断 followup 若不被下游承接，会在真实执行前变成隐性阻塞。

已外置：

- `tools/eval/scripts/grade_td002_dry_run.py`
- `tools/eval/scripts/grade_td003_dry_run.py`
- `tools/eval/scripts/validate_stage2_test_design_package.py`
- `tools/eval/scripts/validate_stage2_test_design_materials.py`
- `tests/test-td002-dry-run-grader.sh`
- `tests/test-stage1-003-dry-run-graders.sh`
- `tests/test-stage2-test-design-package.sh`
- `tools/eval/scripts/run_stage1_dry_run_graders.py`
- `tools/eval/scripts/validate_stage1_artifact_contracts.py`
- `tools/eval/scripts/run_stage1_eval_checks.py`
- `tests/test-stage1-dry-run-grader-runner.sh`
- `tests/test-stage1-artifact-structure-contract.sh`
- `tests/test-stage1-eval-checks-runner.sh`

成长动作：

- 已验证 `TD-003`：缺回滚、人工接管、部分失败语义时必须 blocking typed gap。
- 已验证 Stage 2 test-design package gate：canonical `test-cases.json`、traceability、AC coverage、special triggers、QA handoff、review digest 和 typed gap 阻断已可确定性检查。
- typed gap schema 与 Stage 1 聚合结构校验已落地，继续扩大到真实链路恢复样例。
- 保持 QA handoff 与 Tech-lead binding 为必检项。

## Tech Lead Skill

强项：

- 能守住 test-cases 缺失时不 planning。
- 能把高风险未知项前置为 readiness gate。
- 能输出风险驱动批次、关键路径、依赖、Task 合同、证据路径和 stop condition。

退化风险：

- 任务拆解容易退化为平均分前后端/模块，而不是按风险和证据路径排序。
- 如果 `TL002-RDY-01` 被当普通任务，真实执行会把数据和证据入口风险后置。

已外置：

- `tools/eval/scripts/grade_tl002_dry_run.py`
- `tools/eval/scripts/grade_tl003_dry_run.py`
- `tools/eval/scripts/validate_stage2_tech_lead_package.py`
- `tools/eval/scripts/validate_stage2_tech_lead_materials.py`
- `tests/test-tl002-dry-run-grader.sh`
- `tests/test-stage1-003-dry-run-graders.sh`
- `tests/test-stage2-tech-lead-package.sh`
- `tools/eval/scripts/run_stage1_dry_run_graders.py`
- `tools/eval/scripts/validate_stage1_artifact_contracts.py`
- `tools/eval/scripts/run_stage1_eval_checks.py`
- `tests/test-stage1-dry-run-grader-runner.sh`
- `tests/test-stage1-artifact-structure-contract.sh`
- `tests/test-stage1-eval-checks-runner.sh`

成长动作：

- 已验证 `TL-003`：mock-only 不能作为最终验收证据。
- 已验证 Stage 2 tech-lead package gate：canonical `plan.json`、`tasks.json`、artifact registry、planning preflight、standard-chain semantic integrity 和 delivery-owner intake 已可确定性检查。
- Task 合同核心字段与 Task Packet validator 已纳入 Stage 1 聚合结构校验。
- 将批次顺序、关键路径、禁写真实 `tasks.json/plan.json` 变成自动门禁。

## Delivery Owner Skill

强项：

- 能在冻结基线缺失时输出 `NEEDS_INPUT` 并暂停。
- 能先消费 baseline audit advisory，再决定 dry-run dispatch readiness。
- 能把 advisory 写进执行策略和 Task Packet。
- 能用现有 `task_packet_check.validate()` 校验首包。

退化风险：

- 容易因为看到 tasks 齐备就直接派发全部 developer。
- 如果 advisory 不进入 packet，developer 会凭猜测处理共享依赖。
- `DISPATCH_READY` 必须始终和 dry-run/真实执行边界绑定，不能被误读成真实派发。

已外置：

- `tools/eval/scripts/grade_do002_dry_run.py`
- `tools/eval/scripts/grade_do003_dry_run.py`
- `tests/test-do002-dry-run-grader.sh`
- `tests/test-stage1-003-dry-run-graders.sh`
- `tools/eval/scripts/run_stage1_dry_run_graders.py`
- `tools/eval/scripts/validate_stage1_artifact_contracts.py`
- `tools/eval/scripts/run_stage1_eval_checks.py`
- `tests/test-stage1-dry-run-grader-runner.sh`
- `tests/test-stage1-artifact-structure-contract.sh`
- `tests/test-stage1-eval-checks-runner.sh`

成长动作：

- 已验证 `DO-003`：QA PASS 但业务风险接受未确认时，必须暂停给用户 signoff。
- `baseline advisory consumed -> execution strategy -> Task Packet` 已有 dry-run grader，Task Packet 结构已纳入 Stage 1 聚合结构校验。
- 将真实 state/signoff/commit/qft-pai 禁止宣称做成固定门禁。

## 下一轮团队成长重点

优先级：

1. 用 `run_stage1_eval_checks.py` 固定为 Stage 1 总验收入口，任何新增 dry-run、结构契约、跨角色链路、Stage 2 intake gate、product-director handoff、confirmed brief package、product-manager package、design package、test-design package 或 tech-lead package 材料都必须接入。
2. 让 human/business owner 填写真实 Stage 2 intake facts：验收人、业务事实、指标阈值、执行环境、灰度/回滚 owner、风险接受边界、`intake_provenance` 和 `fact_source_refs`；example 只能输出 `materials_verified_not_authorization`，改名复制也不能冒充授权；真实 facts 通过后也只能经 `render_stage2_product_director_handoff.py` 生成 `product-director` handoff package，再用 `validate_stage2_confirmed_brief_package.py` 验证 confirmed brief package 后交给 `product-manager`，再用 `validate_stage2_product_manager_package.py` 验证 PM PRD/UNIT package 后交给 `design`，再用 `validate_stage2_design_package.py` 验证 design package 后交给 `test-design`，再用 `validate_stage2_test_design_package.py` 验证 test-design package 后交给 `tech-lead`，再用 `validate_stage2_tech_lead_package.py` 验证 tech-lead package 后交给 `delivery-owner`。
3. 等 human 补齐真实业务事实后，再设计 Stage 2 `qft-pai` 真实样板，不提前进入语言选型或代码重写。

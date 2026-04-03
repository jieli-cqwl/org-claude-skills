# Tasks — product-design-cross-review

创建日期: 2026-04-02
关联 plan: ./plan.md

## 验收清单

- [x] T1 新建 Team review 协议与 agent 定义
  - AC: `shared/protocols/team-review-protocol.md` 存在，且定义 `R1 -> R2 -> R2.5 -> R3`、外层 `user_directed` 保真、active 视角回退与 `[FALLBACK-MODE]` 落位规则。
  - AC: `shared/agents/cross-review-lead.md` 与 `shared/agents/cross-reviewer.md` 存在，且工具集合包含 Team 协调所需的消息与任务读取能力。
  - AC: 运行 `bash tests/test-team-review-contract.sh` 返回 PASS，且覆盖协议与 agent 基础契约。
- [x] T2 接入 `/product` Team review 契约
  - AC: `shared/skills/product/SKILL.md` 的 S11 与 `allowed-tools` 体现 Team 模式、`R2.5`、`user_directed` 外层语义和仅 FAIL 视角重审。
  - AC: `shared/skills/product/references/prd-reviewer-prompt.md`、`architect-reviewer-prompt.md`、`tester-reviewer-prompt.md` 明确 Team 模式发消息给 Lead，fallback 单代理模式继续直接写文件。
  - AC: 运行 `bash tests/test-team-review-contract.sh` 与 `bash tests/test-skill-output-and-gate-contract.sh` 返回 PASS。
- [x] T3 接入 `/design` Team review 契约
  - AC: `shared/skills/design/SKILL.md` 的 S9 与 `allowed-tools` 体现 Team 模式、`R2.5`、`user_directed` 外层语义和仅 FAIL 视角重审。
  - AC: `shared/skills/design/references/design-reviewer-prompt.md`、`design-product-reviewer-prompt.md`、`design-test-reviewer-prompt.md` 明确 Team 模式发消息给 Lead，fallback 单代理模式继续直接写文件。
  - AC: 运行 `bash tests/test-team-review-contract.sh` 与 `bash tests/test-skill-output-and-gate-contract.sh` 返回 PASS。
- [x] T4 更新 cross-review 与 handoff 模板
  - AC: `product-cross-review-template.md` 与 `design-cross-review-template.md` 的 Findings 表增加状态承载位，并新增说明性附录 `## 横向质疑记录`。
  - AC: `prd-template.md` 与 `design-template.md` 的承接示例保留 `[DISPUTED]` 等状态标签。
  - AC: 运行 `bash tests/test-team-review-contract.sh` 返回 PASS，且模板断言通过。
- [x] T5 补齐验证覆盖并完成实现闭环
  - AC: 相关测试覆盖 Team review 协议、skill、prompt、模板和 runtime 分发路径。
  - AC: 运行 `bash tests/test-team-review-contract.sh`、`bash tests/test-single-source-layout.sh`、`bash tests/test-skill-output-and-gate-contract.sh`、`bash tests/test-runtime-integrity.sh` 全部返回 PASS。
  - AC: 运行 `python3 tools/community/check_task_plan_consistency.py docs/team-review-parallelization/2026-04-02-product-design-cross-review/tasks.md docs/team-review-parallelization/2026-04-02-product-design-cross-review/plan.md` 返回 PASS。

## 完成定义

所有 task 勾选完成 = 可进入 verify-change。

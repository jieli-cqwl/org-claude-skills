# Tasks — review-fix-loop-redesign

创建日期: 2026-04-04
关联 plan: ./plan.md

## 验收清单

- [x] T1 新建 `code-review-fix` / `doc-review-fix` skill 与重设计契约测试
  - AC: `claude/skills/code-review-fix/SKILL.md`、`claude/skills/doc-review-fix/SKILL.md`、`claude/skills/doc-review-fix/references/deception-patterns.md` 存在，且分别覆盖 AskUserQuestion、baseline 保护/恢复、fail-close、禁止静默路径切换、最终报告字段与 DECEPTION “需用户介入”约束。
  - AC: `tests/test-review-fix-redesign-contract.sh` 存在，且能断言新 skill 文件与关键契约文本存在。
  - AC: 运行 `bash tests/test-review-fix-redesign-contract.sh` 返回 PASS。

- [x] T2 切换安装、布局、runtime integrity 与 contract 到新 skill 拓扑
  - AC: `install.sh`、`contracts/skill-chain.yaml`、`tests/test-install-smoke.sh`、`tests/test-runtime-integrity.sh`、`tests/test-single-source-layout.sh`、`tests/test-codex-skill-adapter.sh` 更新后断言 `code-review-fix` 与 `doc-review-fix` 是新的 Claude-only skill 源，Codex runtime 不安装它们。
  - AC: `claude/agents/` 不再要求 `codex-doc-reviewer.md` 作为活跃源码，相关断言已同步移除或改为新结构断言。
  - AC: 运行 `bash tests/test-install-smoke.sh`、`bash tests/test-runtime-integrity.sh`、`bash tests/test-single-source-layout.sh`、`bash tests/test-codex-skill-adapter.sh` 均返回 PASS。

- [x] T3 下线旧实现、删除废弃 hook/helper 逻辑并完成历史归档
  - AC: `claude/skills/review-fix-loop/`、`claude/skills/codex-doc-review/`、`claude/agents/codex-doc-reviewer.md` 从活跃源码树移除，并在 `docs/archive/review-fix-loop-redesign-2026-04/` 下保留历史副本（不含 `__pycache__`）。
  - AC: `shared/hooks/lib/common.sh` 中 `codex-doc-review` 上下文解析逻辑删除，且 `rg -n "resolve_codex_doc_review_context|codex-doc-review-report|codex-doc-reviewer" shared/hooks/lib/common.sh claude` 不再命中活跃源码中的旧 helper、旧 agent 或旧 canonical report 入口。
  - AC: `tests/test-codex-doc-review-repair.sh`、`tests/test-codex-doc-review-routing.sh`、`tests/test-review-fix-loop-skill.sh` 已从活跃测试集移除，不再作为 `tests/run-all.sh` 的执行项。

- [x] T4 重新编排全量验证并完成任务-计划一致性收口
  - AC: `tests/run-all.sh` 的语法检查、执行编排与序号更新为新测试集合，不再引用已删除的旧测试，并包含 `tests/test-review-fix-redesign-scenarios.sh`。
  - AC: `tests/test-review-fix-redesign-scenarios.sh` 存在，且覆盖 dirty tree、clean tree、stash pop 冲突、non-json、缺字段、最大轮次、不收敛与用户中止等负路径矩阵。
  - AC: 运行 `bash tests/run-all.sh` 返回 PASS。
  - AC: 运行 `python3 tools/community/check_task_plan_consistency.py docs/review-fix-loop/2026-04-03-redesign/tasks.md docs/review-fix-loop/2026-04-03-redesign/plan.md` 返回 PASS。

## 完成定义

所有 task 勾选完成 = 可进入 verify-change。

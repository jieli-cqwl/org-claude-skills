# Tasks — review-fix-loop

创建日期: 2026-04-02
关联 plan: ./plan.md

## 验收清单

- [x] T1 固定 claude-only skill 的运行边界与安装约束
  - AC: `claude/skills/review-fix-loop/` 源目录存在，且 `tests/test-single-source-layout.sh` 明确允许该 claude-only skill。
  - AC: Claude runtime 安装后包含 `review-fix-loop`，Codex runtime 安装后不包含该 skill。
  - AC: `install.sh` quick check 覆盖 `review-fix-loop` 的 Claude runtime 落点。
- [x] T2 实现 baseline 快照与评审结果校验辅助脚本
  - AC: dirty worktree 场景会创建并校验新的 stash baseline，记录不可变 stash SHA，随后恢复 index/worktree 状态。
  - AC: clean worktree 场景只记录 HEAD SHA，不创建 stash。
  - AC: 评审结果校验会 fail-close 顶层 schema/矛盾 verdict，并对 finding 级路径、行号、severity、无法定位场景做结构化判定。
  - AC: 自动化测试覆盖 dirty/clean baseline、非法 JSON、路径穿越、非法行号、非法 severity、无法定位 high/critical finding 等分支。
- [x] T3 交付 review-fix-loop skill 文档、引用规范与完成门禁
  - AC: `SKILL.md` 满足 `/new-skills` 结构约束，清晰声明 Claude 修复者 + 外部 Codex 对抗评审者的流程。
  - AC: 详细命令模板、JSON 契约、最终输出格式下沉到 references，`SKILL.md` 保持精简。
  - AC: `scripts/completion_check.sh` 能机械校验 transcript 中的最终输出块是否包含结果、轮次、baseline、恢复命令和新增文件摘要。
- [x] T4 同步设计并完成相关回归验证
  - AC: `design.md` 与最终实现保持一致，不保留无法执行的旧约束。
  - AC: 新增测试与受影响的 runtime/install 测试全部通过。

## 完成定义

所有 task 勾选完成 = 可进入验证/归档阶段。

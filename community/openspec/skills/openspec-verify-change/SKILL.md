---
name: openspec-verify-change
description: 在 archive 前验证实现是否与 change artifacts、tasks 和 plan 一致。适用于代码实现与基础验证完成后，需要给出是否可归档结论的场景。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec-local
  version: "1.0"
  canonicalLanguage: "zh-CN"
---

# OpenSpec 验证

在归档前验证实现是否与当前 change 的 artifacts、`tasks.md` 和 `plan.md` 一致。

## 输入

可选指定 change 名称。若省略且存在歧义，必须让用户选择。

## 步骤

1. **选择 change**

   ```bash
   openspec list --json
   ```

   如果没有明确名称且不唯一，不要猜。

2. **读取状态与 artifacts**

   ```bash
   openspec status --change "<name>" --json
   openspec instructions apply --change "<name>" --json
   ```

   读取：
   - `proposal.md`
   - `design.md`（如果存在）
   - `tasks.md`
   - `specs/**/spec.md`

3. **校验 tasks 与 plan 强一致性**

   必须执行内置一致性校验器（不可依赖业务仓库 `tools/`）：

   ```bash
   PLAN_PATH="$(ls -1 openspec/plans/*-<name>.md 2>/dev/null | sort | tail -n1)"
   CHECKER_PATH=""
   for p in \
     "$HOME/.codex/skills/openspec-verify-change/scripts/check_task_plan_consistency.py" \
     "$HOME"/.*laude/skills/openspec-verify-change/scripts/check_task_plan_consistency.py
   do
     if [ -f "$p" ]; then
       CHECKER_PATH="$p"
       break
     fi
   done

   if [ -z "$PLAN_PATH" ]; then
     echo "[FAIL] 未找到与 change 对应的 plan.md"
     exit 1
   fi
   if [ -z "$CHECKER_PATH" ]; then
     echo "[FAIL] verify skill 内置一致性校验器缺失"
     exit 1
   fi

   python3 "$CHECKER_PATH" \
     "openspec/changes/<name>/tasks.md" \
     "$PLAN_PATH"
   ```

   失败则记为 `CRITICAL`（阻断归档）。

4. **执行 OpenSpec 结构化校验**

   ```bash
   openspec validate "<name>" --type change --strict --json
   ```

   如果 validate 失败：
   - 记为 `CRITICAL`
   - 给出具体修复方向

5. **验证完成度**

   - 读取 `tasks.md`
   - 检查是否仍有 `- [ ]`
   - 如果有，逐项记为 `CRITICAL`

6. **验证正确性**

   - 从 `spec.md` 提取 requirement / scenario
   - 搜索代码和测试，判断是否存在实现证据
   - requirement 明显未实现：`CRITICAL`
   - scenario 缺少覆盖：`WARNING`

7. **验证一致性**

   - 如果有 `design.md`，检查实现是否明显违背设计决策
   - 检查 `plan.md` 对应任务是否都有落地证据
   - 发现偏离但可解释：`WARNING`
   - 只是风格问题：`SUGGESTION`

8. **输出报告**

   报告必须包含：
   - `CRITICAL`
   - `WARNING`
   - `SUGGESTION`
   - 最终结论

   结论规则：
   - 有 `CRITICAL`：不可归档
   - 无 `CRITICAL` 但有 `WARNING`：可带注意项归档
   - 全部通过：可归档

## 约束

- `verify` 不是简单看测试是否通过
- 必须同时检查：
  - tasks-plan 一致性
  - OpenSpec validate 结果
  - 规格/设计
  - 代码证据
- 强一致要求：
  - `plan.md` 的每条 checklist 必须显式引用 task id（如 `[1.1]` 或 `[T1]`）
  - `tasks.md` 与 `plan.md` 对同一 task id 的完成状态必须同步
- 所有问题都要给出可执行建议

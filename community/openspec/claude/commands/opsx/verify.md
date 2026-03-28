---
name: "OPSX: Verify"
description: 在 archive 前验证实现是否与 tasks、plan、spec、design 一致
category: Workflow
tags: [workflow, verify, openspec]
---

在归档前验证实现是否与当前 change 的 artifacts、`tasks.md` 和 `plan.md` 一致。

## 输入

可选指定 change 名称。若省略且存在歧义，必须让用户选择。

## 步骤

1. **选择 change**

   ```bash
   openspec list --json
   ```

2. **读取状态与 artifacts**

   ```bash
   openspec status --change "<name>" --json
   openspec instructions apply --change "<name>" --json
   ```

3. **检查 tasks-plan 强一致性**

   必须使用内置一致性校验器：

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

   [ -n "$PLAN_PATH" ] || { echo "[FAIL] 未找到与 change 对应的 plan.md"; exit 1; }
   [ -n "$CHECKER_PATH" ] || { echo "[FAIL] verify skill 内置一致性校验器缺失"; exit 1; }

   python3 "$CHECKER_PATH" \
     "openspec/changes/<name>/tasks.md" \
     "$PLAN_PATH"
   ```

   失败记为 `CRITICAL`（阻断归档）。

4. **执行 OpenSpec validate**

   ```bash
   openspec validate "<name>" --type change --strict --json
   ```

   失败记为 `CRITICAL`。

5. **核对实现证据**

   - `tasks.md` 是否还有未完成项
   - requirement / scenario 是否存在代码或测试证据
   - `design.md` 的关键决策是否明显被违背

6. **输出报告**

   必须按以下级别给出：
   - `CRITICAL`
   - `WARNING`
   - `SUGGESTION`

   结论规则：
   - 有 `CRITICAL`：不可归档
   - 无 `CRITICAL` 但有 `WARNING`：可带注意项归档
   - 全部通过：可归档

## 约束

- `verify` 不是只看测试是否通过
- 必须同时看：
  - tasks-plan 一致性
  - OpenSpec validate 结果
  - 规格/设计
  - 代码证据
- 强一致要求：
  - `plan.md` 每条 checklist 必须带 task id 引用（如 `[1.1]`）
  - `tasks.md` 与 `plan.md` 对同一 task id 的状态必须同步

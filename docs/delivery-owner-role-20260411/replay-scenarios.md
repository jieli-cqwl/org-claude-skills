# Replay Scenarios

## 冻结说明

- 本文件自 `T1` 起作为必跑 replay 场景真源。
- 最终验收阶段只能执行这里定义的场景与判定，不能一边跑 replay 一边改场景定义。

## 必跑场景

1. readiness failure
   - `preflight-evidence.md` 缺失或为空，执行前必须被拦截。
2. execution drift and replan
   - 出现 `INTERFACE_BREAK` 或依赖漂移时，必须暂停并升级。
3. quality escalation after risk increase
   - 标准分级下出现 shared logic / cross-UNIT fix，必须追加更强回归或 QA。
4. goal closure mismatch despite green gates
   - 门禁全绿，但目标闭环仍是 `部分达成/未达成`，必须阻止确认签收。

## Rollout Gate

- 上述 replay 全部通过前，不得宣称“可投入团队使用”。

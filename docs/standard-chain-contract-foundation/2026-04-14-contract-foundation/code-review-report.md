# Code Review Report — T1 Foundation

## 审查轮次记录
| 轮次 | 范围 | 结论 | 备注 |
|------|------|------|------|
| R1 | `contracts/canonical/**`, `build_standard_chain_catalog.py`, `standard-chain-catalog.json`, `tests/test-standard-chain-foundation-registry.sh`, `tests/test-chain-completeness.sh` | FAIL | 发现 4 个问题：schema 解析不可消费、schema 未冻结关键 enum/item shape、drift probe 不够真实、bundle key 顺序敏感。 |
| R2 | 针对 R1 修复后的同范围复审 | FAIL | 剩余 1 个问题：`test-cases` 与 `code-review-result` 的 item shape 仍放行额外字段。 |
| R3 | 仅复查剩余 item-shape 问题 | PASS | 额外字段已被 schema 与负向测试拒绝，无剩余 finding。 |

## 已关闭问题
1. schema `$id/$ref` 改为稳定 URI，并补了标准 `Draft202012Validator + referencing.Registry` 的真实模板校验。
2. `shared-core.schema.json` 现在直接冻结关键 enum；`test-cases` 与 `code-review-result` 也补了 item shape 约束。
3. drift probe 改成真实修改被 bundle 引用的 registry 文本；template digest 也被测试显式校验。
4. builder 不再依赖 bundle key 顺序，`--bundle-drift-probe` 参数也改为真实参与 probe。

## Fresh Evidence
- `bash tests/test-standard-chain-foundation-registry.sh`
  - 结果：PASS
- `bash tests/test-chain-completeness.sh`
  - 结果：PASS
- `python3 - <<'PY' ... Draft202012Validator(brief, registry=registry).validate(inst) ...`
  - 结果：`schema-compile: PASS`

## 最终结论
PASS

---

# Code Review Report — T2 Runtime State

## 审查轮次记录
| 轮次 | 范围 | 结论 | 备注 |
|------|------|------|------|
| R1 | `tools/community/{canonical_ref_resolver.py,manage_artifact_registry.py,update_delivery_state.py}`、`tests/test-standard-chain-runtime-state.sh`、`tests/fixtures/standard-chain-foundation/runtime/**` | FAIL | 发现 4 个问题：canonical ref 前缀误匹配、restore proof 未校验、blocked 语义未卡死、replan/task lineage 混版本可漏过。 |
| R2 | 同范围复审 | PASS | R1 的 4 个问题全部关闭，并补齐 `apply-restore / apply-task-runtime / apply-enter-blocked / apply-leave-blocked / apply-replan-switch` 写入口证明。 |

## 十维覆盖结论
- `REVIEW_A`: FAIL
  - 正确性：FAIL
  - 安全性：PASS
  - 错误处理：FAIL
  - 并发/状态：FAIL
- `REVIEW_B`: FAIL
  - 设计：FAIL
  - 测试覆盖：FAIL
  - 注释准确性：PASS
  - 向后兼容：PASS
- `REVIEW_C`: COMMENT
  - 性能：PASS
  - 可观测性：COMMENT

## Findings
| Severity | Verification | Confidence | File | Lines | Problem |
|---|---|---:|---|---:|---|
| High | Verified | 0.98 | `tools/community/canonical_ref_resolver.py` | 37-39 | 用 `startswith()` 匹配 canonical ref，会把 `artifact://plan/...@plan-v10#...` 误解析到 `plan-v1` 的 active entry，破坏版本精确匹配与 mixed-version fail-closed。 |
| High | Verified | 0.97 | `tools/community/update_delivery_state.py` | 25-38 | `assert_task_runtime_alignment()` 只校验 `artifact_id` 前缀和 `task_id` 是否存在，没有校验 `active_tasks_version_ref` 是否与 tasks 快照同版本，也没有校验 `latest_upstream_refs` 是否指向当前 active tasks 版本；REPLAN 后的 stale lineage / mixed-version 可以直接漏过。 |
| High | Verified | 0.96 | `tools/community/update_delivery_state.py` | 41-63 | `enter_blocked()` / `leave_blocked()` 信任调用方给出的 `blocked_from_stage` 与 `resume_stage`，没有约束 `blocked_from_stage == 原 current_stage`，也没有限制 `resume_stage` 只能回到预登记阶段或 `REPLAN_PENDING`；非法 `BLOCKED -> 任意阶段` 可以被接受。 |
| Medium | Verified | 0.93 | `tools/community/manage_artifact_registry.py` | 64-72, 139-145 | restore 校验只比较 `(artifact_type, artifact_id, version, artifact_path, lifecycle_state, active_for_consumption)`，完全不核对 `restore_basis_refs` 的具体内容；只要给任意非空 basis refs，`--check-restore` 仍会通过，和 T2 对“显式恢复依据”的要求不符。 |

## 已关闭问题
1. `canonical_ref_resolver.py` 现在先解析 canonical ref 的 `artifact_type / artifact_id / version / anchor`，只按精确版本命中 active `FINALIZED` entry；`plan-v10` 前缀碰撞已由负向测试拦截。
2. `update_delivery_state.py` 现在要求 `latest_upstream_refs` 精确跟随当前 `active_tasks_version_ref`，并在 `REPLAN` 切换后可选联动 `tasks-v2` 做 runtime lineage 对齐校验。
3. `enter_blocked()` 现在要求 `blocked_from_stage == state.current_stage`；`leave_blocked()` 现在要求 `resolution.resume_stage == state.resume_stage`，且 `resume_stage` 只能是原阶段或 `REPLAN_PENDING`。
4. `manage_artifact_registry.py` 的 restore 校验现在额外比较 `(artifact_type, artifact_id, version, restore_basis_refs)`；`apply-restore` 也证明旧 `rev-1/rev-2` 历史快照不会被改写。
5. `update_delivery_state.py` 与 `manage_artifact_registry.py` 都补了 `apply-*` CLI 模式，`task runtime`、`BLOCKED` 进入/退出、`replan switch`、`restore` 都可以输出新的 JSON 文档，而不只是 fixture 断言。

## 已排除的潜在问题
| File | Lines | Concern | Evidence | Result |
|---|---:|---|---|---|
| `tools/community/manage_artifact_registry.py` | 43-61 | `assert_append_only()` 可能没有检查 parent 链连续性 | 将 quarantine fixture 的 `parent_revision_id` 改成 `rev-x` 后，`--check-append-only` 按预期报错 `revision rev-2 parent 不连续`。 | Excluded |
| `tools/community/update_delivery_state.py` | 54-63 | `leave_blocked()` 可能允许非 `BLOCKED` 状态直接解阻 | 将 `leave-blocked.json.state.current_stage` 改成 `TASK_EXECUTION` 后，CLI 按预期报错 `只有 BLOCKED 状态才能执行 leave_blocked`。 | Excluded |
| `tools/community/manage_artifact_registry.py` | 46-47 | 第 47 行缩进是否会导致脚本语法错误 | `python3 -m py_compile tools/community/canonical_ref_resolver.py tools/community/manage_artifact_registry.py tools/community/update_delivery_state.py` 通过。 | Excluded |

## Fresh Evidence
- `python3 -m py_compile tools/community/canonical_ref_resolver.py tools/community/manage_artifact_registry.py tools/community/update_delivery_state.py`
  - 结果：PASS
- `bash tests/test-standard-chain-runtime-state.sh`
  - 结果：PASS
- `shellcheck tests/test-standard-chain-runtime-state.sh`
  - 结果：PASS
- `python3 tools/community/canonical_ref_resolver.py --registry <tmp>/registry.json --ref "artifact://plan/sample-feature.phase-1.plan@plan-v10#plan-version"`
  - 结果：非零退出；版本前缀碰撞已被拒绝。
- `python3 tools/community/manage_artifact_registry.py --fixture <tmp>/restore.json --check-restore`
  - 结果：把 `restore_basis_refs` 改成错误但非空值后非零退出；restore proof 已被校验。
- `python3 tools/community/manage_artifact_registry.py --fixture tests/fixtures/standard-chain-foundation/runtime/quarantine/restore-request.json --apply-restore`
  - 结果：输出 `rev-3`，且 `rev-1/rev-2` 与输入 registry 完全一致，证明 restore 走 append-only 写路径。
- `python3 tools/community/update_delivery_state.py --fixture <tmp>/state.json --tasks-fixture <tmp>/tasks.json --check-task-runtime`
  - 结果：把 `active_tasks_version_ref` 改成 `tasks-v2`、`latest_upstream_refs` 保持 `tasks-v1` 后非零退出；mixed-version runtime lineage 已被拒绝。
- `python3 tools/community/update_delivery_state.py --fixture tests/fixtures/standard-chain-foundation/runtime/replan/delivery-state.json --tasks-fixture tests/fixtures/standard-chain-foundation/runtime/replan/tasks-v2.json --check-replan-switch`
  - 结果：PASS；切换 active refs 后已联动校验新的 tasks 基线。
- `python3 tools/community/update_delivery_state.py --fixture <tmp>/enter.json --check-enter-blocked`
  - 结果：把 `blocked_from_stage` 伪造成 `PHASE_REVIEW` 或把 `resume_stage` 伪造成非法阶段后非零退出。
- `python3 tools/community/update_delivery_state.py --fixture <tmp>/leave.json --check-leave-blocked`
  - 结果：把 `resolution.resume_stage` 改成与 state 不一致后非零退出。

## 最终结论
PASS

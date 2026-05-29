# Implementation Order

结论：已按 1-6 与 8 的可证明合同项推进实现；7 仅处理本次证据充分的 `owner_responsibility` prose，不扩大到 Design/Test/Tech 大面积字段清理。

以下顺序按 Codex 复核收敛后执行；当前仍不声明实现完成。

| order | work_item | reason |
| --- | --- | --- |
| 1 | 加结构门禁 | 为 `contracts/standard-chain.yaml` 增加 duplicate key_fields 检查；为 field-consumption validator 增加 nested/dotted field path 语义，避免后续改动继续用假平铺字段。 |
| 2 | 收敛 Director digest | 保留 `director_confirmation.locked_field_digest` runtime gate，删除 flat `locked_field_digest` contract alias，并同步 field-consumption/tests/fixtures。 |
| 3 | 去重 baseline/active refs | 删除重复 list entries，同时保留真实 baseline/active freshness 字段；修正 tests/tools 中重复 tuple/字符串锁定。 |
| 4 | 强化 runtime evidence | 保留并验证 signoff-package.runtime_evidence_matrix、artifact-registry runtime_artifact_policy、QA obligation_results、consistency-audit runtime_chain。 |
| 5 | 处理 fix-result freshness | 补 fix-result field-consumption ownership rows；同步 review/verify/QA/fixer freshness 验证，确保 QA fix 后必须 fresh code-review。 |
| 6 | 固化 QA route matrix | 将 gate_result x release_recommendation 的可提交/阻断/路由语义写成确定性 validator/replay，而不是只靠 prose。 |
| 7 | 删除或结构化自然语言字段 | 删除无 consumer 的 active prose；gate/handoff/recovery/evidence 所需语义改为 refs、枚举、owner action、required artifact 或 evidence refs。 |
| 8 | 替换自然语言测试契约 | 把 Skill Markdown 句子锁定、整行 key_fields 字符串锁定改为 schema/field path/consumer/script behavior 测试。 |
| 9 | P0/P1 回归验证 | 逐条验证 FLOW-001..FLOW-012 与 SKILL-001..SKILL-005 的 remap 状态；最后跑 quick/full 门禁。 |

## 当前执行状态

| order | status | evidence |
| --- | --- | --- |
| 1 | done | `tools/community/validate_standard_chain_field_consumption.py` 支持 dotted path，并拒绝 duplicate key_fields；`tests/test-standard-chain-field-consumption-contract.sh` 覆盖负例。 |
| 2 | done | `contracts/standard-chain.yaml` 与 `contracts/standard-chain-field-consumption.yaml` 使用 `director_confirmation.locked_field_digest`；`tests/test-task-contract-consumer-alignment.sh` 不再锁 flat digest。 |
| 3 | done | `standard-chain.yaml` key_fields duplicate 已去重；field-consumption contract 测试校验无重复。 |
| 4 | partial-done | artifact-registry runtime policy 已进入 schema/template/key_fields/field-consumption；signoff runtime evidence 已有现存 readiness 覆盖，本轮未扩大改动。 |
| 5 | done | fix-result field-consumption 已补；`delivery_owner_optional_artifacts.py` 拒绝 post-fix stale review/QA/signoff/decision evidence。 |
| 6 | done | `validate_canonical_rules.py` 与 `validate_standard_chain_readiness.py` 固化 PASS+ALLOW 唯一路径，其它 QA route 需要 owner route 且 readiness 不关闭。 |
| 7 | scoped | 本轮只删除 `artifact-registry.runtime_artifact_policy.owner_responsibility` 这类已证实无 gate value 的 prose；其它 needs-human-decision prose 仍留在 conflicts，后续需单独产品判断。 |
| 8 | done | `tests/test-delivery-owner-source-anchor-contract.sh` 已从整行字符串锁定改为结构化 YAML 校验。 |
| 9 | quick-pass/full-blocked | 专项测试已通过；`bash tests/run-all.sh --quick` 已 24/24 通过。`bash tests/run-all.sh` 受 `shared/rules/*` 并行改动导致的安装 quick-check 源漂移阻断；失败 group 单独复跑通过。 |

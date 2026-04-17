# fix-10: Agent Team third-round P1 hardening

## Scope

本轮承接 Agent Team 第三轮复审暴露的阻断项，目标是不让 standard-chain runtime control plane 被“同文件自洽”“半口径分级”或“eval 关键词堆砌”绕过。

## Verified P1 Findings

| ID | Finding | Verified status | Fix |
|----|---------|-----------------|-----|
| P1-1 | readiness 对 duplicate task id、未解析 verify goal、all-N/A goal closure、blocking code-review finding 仍可能误放行 | Verified | `validate_readiness_contract.py` 增加 task id 唯一性、goal_ref 上游解析、至少一个 MET、Verified/Inconclusive S0-S2 finding 阻断；`test-standard-chain-readiness-gate.sh` 增加对应负例 |
| P1-2 | Director lock 只校验当前 payload digest，Manager 可改 Director-owned 字段并重算 digest | Verified | `director_confirmation.locked_fields` 成为 canonical schema/template/fixture 必填；product closure 校验 locked_fields 快照、digest 与当前 Director-owned 字段一致；product-director gate 拒绝 Manager-owned 字段和非空 unit_index |
| P1-3 | `plan.json` 的 `goal_source_refs / constraint_source_refs / obligation_source_refs / execution_basis_refs` 在 template/key_fields 中声明，但 schema/gate 未 required | Verified | plan schema required 四类 source/basis 字段；registry test 与 phase orchestrator 负例覆盖缺失字段 |
| P1-4 | delivery-owner Phase 3 把 `REVIEW_C` 说成可选，但 canonical code-review/readiness 强制要求 `review_c/performance/observability` | Verified | Phase 3 矩阵统一为 `REVIEW_A + REVIEW_B + REVIEW_C` 强门禁；delivery-owner/tech-lead 文档、模板与合同测试同步 |
| P1-5 | product split benchmark 可被低重复、marker-free 关键词堆齐拿满分 | Verified | scoring 增加 dense segment / low-repeat stuffing 检测；benchmark contract 增加重复型与低重复型负例 |
| P1-6 | canonical rules/readiness 未挡住 `brief.json.non_functional_req` legacy alias | Verified | `validate_canonical_rules.py` brief denylist 增加 `non_functional_req`；validator stack 增加 canonical brief legacy alias 负例 |

## Fresh Evidence

- `bash tests/test-standard-chain-readiness-gate.sh` -> PASS
- `bash tests/test-standard-chain-foundation-registry.sh` -> PASS
- `bash tests/test-standard-chain-validator-stack.sh` -> PASS
- `bash tests/test-delivery-owner-phase3-contract.sh` -> PASS
- `bash tests/test-product-split-benchmark-contract.sh` -> PASS
- `bash tests/test-skill-output-and-gate-contract.sh` -> PASS
- `python3 -m py_compile tools/community/validate_product_closure.py tools/community/validate_readiness_contract.py tools/community/validate_standard_chain_readiness.py tools/community/validate_canonical_schema.py tools/community/validate_canonical_rules.py tools/eval/scripts/product_split_benchmark_scoring.py` -> PASS
- `bash -n shared/skills/tech-lead/scripts/completion_check.sh shared/skills/delivery-owner/scripts/phase3-grade-matrix.sh shared/skills/product-director/scripts/completion_check.sh tests/test-skill-output-and-gate-contract.sh tests/test-product-split-benchmark-contract.sh tests/test-standard-chain-validator-stack.sh` -> PASS

## Notes

- 本轮保留 canonical readiness 强约束，不把 runtime closeout 降级为按文档分级“可选”。
- Director lock 的可执行语义现在落在 canonical JSON 自身的 `locked_fields` 快照与 product closure gate；legacy `brief.lock.json / prd.lock.json` 仍只属于 legacy markdown lane。

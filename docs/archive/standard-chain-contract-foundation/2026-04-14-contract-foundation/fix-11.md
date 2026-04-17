# fix-11: final review closure hardening

## Scope

本轮承接最终 Agent Team 复审追加问题，重点收口剩余 P1/P2/P3：Director lock co-mutation、distributed keyword stuffing、Phase 3 non-waivable 文档漂移、旧 product 路径残留，以及 design/QA/test-design skill 输出说明与 canonical gate 的偏差。

## Verified Findings

| ID | Severity | Finding | Fix |
|----|----------|---------|-----|
| F11-1 | P1 | Director-owned 字段、`locked_fields` 与 digest 一起被改时，原 product closure 只做同文件自洽检查 | active registry 对 `brief` / `phase-prd` 增加 `director_lock_digest` 绑定；`user-decision.json.director_lock_digests` 作为 authority-bound 独立锚点；readiness 要求 artifact、registry 与 user-decision 三方一致；增加 co-mutated registry 负例 |
| F11-2 | P1 | product split eval 可被分散式 marker-free 关键词堆砌拿满分 | scoring 增加 distributed stuffing 检测；benchmark contract 增加分散式关键词堆砌负例 |
| F11-3 | P1 | delivery-owner Phase 3 non-waivable 文档/模板仍残留 `REVIEW_A/QA_A` 旧口径 | `SKILL.md`、`phase3-dispatch.md`、`waivers-template.md` 与 Phase3 contract test 统一为 `REVIEW_A / REVIEW_B / REVIEW_C / QA_A` |
| F11-4 | P2 | T6 plan/tasks 仍引用退役 `shared/skills/product` 路径 | 文档改为 `product-director` / `product-manager` 拆分后的路径 |
| F11-5 | P2/P3 | design/QA skill 输出说明与 canonical schema/gate 不一致 | design skill 明确 `design.json` 不承载 runtime verdict state；QA skill 补齐 `current_stage`、`not_executed_reason`、`ruled_out_issues` 必填说明 |
| F11-6 | P1 | QA SKILL 把 legacy markdown 的“审查分级/执行范围”误列为 canonical `qa-result.json` 必填字段 | QA SKILL 改为只把英文 JSON 字段列入 canonical 必填，并将“审查分级/执行范围”移动到 legacy markdown 投影视图要求 |
| F11-7 | P2 | design/test-design reviewer prompt 与 test-design methodology 仍引用非 catalog 的 `design/MOD-*`、ADR 扩展、legacy markdown 真源与旧 `design.json` runtime verdict 字段 | design/test-design reviewer prompt 与 methodology 改为只消费 canonical `design.json` 及 canonical planning artifacts，独立 review 投影只能作为补强输入，不能写回 `design.json` |

## Fresh Evidence

- `bash tests/test-standard-chain-readiness-gate.sh` -> PASS
- `bash tests/test-standard-chain-foundation-registry.sh` -> PASS
- `bash tests/test-standard-chain-user-decision.sh` -> PASS
- `bash tests/test-standard-chain-projection-replay.sh` -> PASS
- `bash tests/test-product-split-benchmark-contract.sh` -> PASS
- `bash tests/test-delivery-owner-phase3-contract.sh` -> PASS
- `bash tests/test-skill-output-and-gate-contract.sh` -> PASS
- `python3 -m py_compile tools/community/validate_readiness_contract.py tools/community/validate_product_closure.py tools/eval/scripts/product_split_benchmark_scoring.py` -> PASS
- `bash -n tests/test-standard-chain-readiness-gate.sh tests/test-standard-chain-foundation-registry.sh tests/test-product-split-benchmark-contract.sh tests/test-delivery-owner-phase3-contract.sh` -> PASS

## Notes

- Director lock 防线现在不只依赖 artifact 内部自洽；readiness 还会核对 active registry 的冻结 digest 与 user-decision 的 authority-bound digest。
- `design.json` 继续保持设计真源职责，审查/交付状态由投影视图与工程 gate 承载。

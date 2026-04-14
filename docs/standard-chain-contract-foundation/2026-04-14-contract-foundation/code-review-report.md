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

# contracts canonical assets 重构计划

## 诊断结果

| 问题类型 | 证据 | 方向 |
| --- | --- | --- |
| 设计不当 | `tools/community/build_standard_chain_catalog.py:57` 到 `tools/community/build_standard_chain_catalog.py:211` 将除 developer 外的 schema/template 固定在 `contracts/canonical/schemas` 与 `contracts/canonical/templates`，而 `shared/skills/developer/contracts/developer-report.schema.json` 和 `shared/skills/developer/templates/developer-report.template.json` 已按 skill 自治管理 | 调整 |
| 设计不足 | `tools/community/validate_canonical_schema.py:32` 单独读取 `contracts/canonical/schemas/shared-core.schema.json`，共享 envelope 没有公共 skill library 归属 | 调整 |
| 关联漂移 | `tests/test-standard-chain-cutover.sh:119` 到 `tests/test-standard-chain-cutover.sh:122` 要求 `shared/agents/*.md` 不暴露运行时 artifact 文件名，但 `shared/agents/developer.md:3` 与 `shared/agents/developer.md:19` 仍包含 `developer-report.json` | 减法 |

## 三原则裁决

- 简单：不新增注册中心或兼容复制层，直接把每个 artifact 合同移动到产出/收口它的 skill 目录。
- 合适：schema/template 是标准链运行时合同，必须保留为可被工具和测试直接读取的文件；只改变归属路径，不改变字段语义。
- 演化：沿用 developer 已验证模式：`contracts/*.schema.json` 加 `templates/*.template.json`。共享 `shared-core.schema.json` 没有单一 skill owner，放入 `shared/skills/lib/contracts/`。
- 裁决：正确性优先于路径兼容。旧 `contracts/canonical/schemas` 与 `contracts/canonical/templates` 不保留影子副本，避免双真源。

## 目标归属

- `product-director`：Director 骨架模板。
- `product-manager`：`brief`、`phase-prd`、`unit-definition` 完整 schema/template。
- `design`：`design` schema/template。
- `test-design`：`test-cases` schema/template。
- `tech-lead`：`plan`、`tasks` schema/template。
- `developer`：保持现有 `developer-report` schema/template。
- `verify`：`verify-result` schema/template。
- `review`：`code-review-result` schema/template。
- `qa`：`qa-result` schema/template。
- `fix`：`fix-result` schema/template。
- `consistency-audit`：`consistency-audit-result` schema/template。
- `delivery-owner`：`delivery-state`、`artifact-registry`、`signoff-package`、`user-decision`、`projection-manifest` schema/template。
- `shared/skills/lib`：`shared-core.schema.json`。

## 影响分析

- 直接修改：schema/template 文件路径、schema `$id`/`$ref`、standard-chain catalog generator、catalog JSON、canonical schema validator、standard-chain skill 文档、相关路径门禁测试、活跃 workset 中的合同路径记录。
- 需回归：catalog 生成一致性、canonical schema validation、standard-chain validator/readiness/runtime/projection/user-decision/closure/cutover、产品/test-design/design 合同路径断言。
- 搜索盲区：`docs/archive/**` 与 `tools/eval/results/**` 是历史材料和评估输出，不作为活跃合同同步对象。
- 既有阻塞：迁移前 `bash tests/test-standard-chain-cutover.sh` 已因 `shared/agents/developer.md` 暴露 `developer-report.json` 失败；本次作为关联漂移修正。

## 验证步骤

1. 基线：`bash tools/validate-contracts.sh`、`python3 tools/community/build_standard_chain_catalog.py --check`、核心 standard-chain 合同测试。
2. 迁移后：重新生成并校验 `shared/runtime/standard-chain-catalog.json`。
3. Fresh proving commands：`bash tools/validate-contracts.sh`、`python3 tools/community/build_standard_chain_catalog.py --check`、standard-chain 专项测试组合、`git diff --check`。

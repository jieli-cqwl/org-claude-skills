# Fix 1: Review Findings Closure

时间: 2026-04-21 23:39 CST

## 输入来源

- Review Finding 1: product-director advertised templates conflicted with its own gate.
- Review Finding 2: canonical hook target selection accepted the first transcript candidate.
- Review Finding 3: QA browser gate regression was not part of `tests/run-all.sh`.
- Review Finding 4: product-director active runtime text still mentioned historical lock compatibility.

## 环境快照

- 工作区: `/Users/lijieli/org-claude-skills`
- 变更类型: standard-chain skill/runtime gate/test contract 修复
- 输出目录: `docs/delivery-owner-control-plane/2026-04-21-progressive-loading`

## 诊断与根因

| Issue | failure_class | 现象 | 根因 | 语义关系证据 |
|---|---|---|---|---|
| F1 | FIXABLE | Director 按文档模板生成的 `brief.json / phase-prd.json` 被 Director gate 拦截 | active SKILL 与 output contract 指向 Manager 完整模板，而 Director gate 拒绝 Manager-owned 字段 | `shared/skills/product-director/SKILL.md` 输出区、`references/output-contract.md`、`completion_check.sh validate_director_boundary` 指向同一产物流 |
| F2 | FIXABLE | Stop transcript 同时包含有效和无效 QA 产物时 gate 放行 | 多个 canonical scripts 用首个 transcript 命中项作为目标，没有唯一性门禁 | `qa/review/design/test-design/tech-lead/verify/delivery-owner` completion scripts 均消费 hook target |
| F3 | FIXABLE | QA browser regression 未进入全量入口 | `tests/run-all.sh` 未纳入 `test-qa-browser-gate-contract.sh` | run-all syntax/shellcheck/execution 三段缺少该测试 |
| F4 | FIXABLE | active SKILL 仍提历史 lock 兼容 | Runtime Authority 承载旧 product-artifact 兼容说明 | `product-director/SKILL.md` Runtime Authority 是模型运行时入口 |

## 假设验证

| Issue | 假设 | 验证 | 结果 |
|---|---|---|---|
| F1 | 只改 gate 放宽字段 | 会让 Manager-owned 字段回流 Director 阶段 | 排除 |
| F1 | 拆 Director 专属模板 | 模板只包含 Director-owned 字段，gate 可通过 | 确认 |
| F2 | 只修 QA script | review/design/test-design/tech-lead/verify/delivery-owner 仍有同类选择风险 | 排除 |
| F2 | 公共 helper 统一唯一候选选择 | scripts 统一 fail-closed，多候选测试阻断 | 确认 |
| F3 | 只手跑 QA browser 测试 | 全量入口仍无法捕获回归 | 排除 |
| F3 | 接入 run-all syntax/shellcheck/execution | 全量入口覆盖该契约 | 确认 |
| F4 | 保留兼容说明并补解释 | active runtime 仍读取旧路径信息 | 排除 |
| F4 | 删除 active 兼容说明 | 旧兼容仅留在历史材料，不进入运行时入口 | 确认 |

## 修复四问

1. 根因是什么？
   - 模板分层、hook target 选择、测试入口和 active runtime 文案未按 canonical-only 单一职责收敛。

2. 修复是否完整？
   - Director 专属模板进入 `contracts/canonical/templates/planning/director/`。
   - Active SKILL 只路由到 output contract，模板路径下沉到二级合同。
   - 公共 `select_unique_hook_path` 覆盖 canonical gate scripts。
   - run-all 接入 QA browser 与 product-context 回归。
   - 旧测试契约同步到 current standard-chain catalog、delivery gate、canonical constraint closure 和 skill format policy。

3. 是否引入新问题？
   - 风险点: 公共 hook helper 改动会影响多个 gate。
   - 回归面: skill output/gate、QA browser、delivery-owner gate、constraint closure、chain completeness、skill format、runtime noise、run-all 分块验证。

4. 是否需要补充测试覆盖？
   - 已补充: Director advertised template gate、QA ambiguous Stop candidate、QA browser run-all entry。
   - 已同步: product stability、constraint closure、chain completeness、skill format unification。

## RED / GREEN 证据

### RED

- `bash tests/test-skill-output-and-gate-contract.sh`
  - 初始失败: `invalid JSON: contracts/canonical/templates/planning/director/brief.template.json`
- QA 双候选复现
  - 初始行为: 多候选未保留 ambiguity failure，退化为 path not found。
- `bash tests/run-all.sh`
  - 暴露过时契约: product lock 兼容、constraint old script internals、catalog missing consistency-audit-result、mandatory dot flow、old delivery-owner phase3 test entry。

### GREEN

- `bash tests/test-skill-output-and-gate-contract.sh` PASS
- `bash tests/test-qa-browser-gate-contract.sh` PASS
- `bash tests/test-product-context-signal-quality.sh` PASS
- `bash tests/test-standard-chain-cutover.sh` PASS
- `bash tests/test-standard-chain-skill-structure.sh` PASS
- `bash tests/test-product-output-contract-reference.sh` PASS
- `bash tests/test-product-stability-guidance-contract.sh` PASS
- `bash tests/test-constraint-closure-contract.sh` PASS
- `bash tests/test-chain-completeness.sh` PASS
- `bash tests/test-skill-format-unification.sh` PASS
- `bash tests/test-install-systematic.sh` PASS: `Systematic tests passed: 20, skipped: 0`
- Run-all 6-20 分块 PASS
- Run-all 21-39 分块 PASS
- `git diff --check` PASS

## 复审结论

- 原 4 条 review findings 已关闭。
- 本轮修复按 canonical-only、单一职责、渐进式加载和 fail-closed gate 收敛。
- `bash tests/run-all.sh` 在长会话中发生一次工具层 code -1 中断；中断点所在的 `test-install-systematic.sh` 随后单跑完整通过，run-all 其余区间已按原顺序分块通过。

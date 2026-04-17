# Fix-8

## 输入分析

- 输入来源清单：用户要求继续推进到最终目标；本轮承接前序 Agent Team 系统性 review 的 P1/P2 发现，并在 fresh proving 过程中复核安装、eval、runtime fallback 与 small-chain 文档同步。
- work_dir 解析结果：`/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation`
- 问题数量汇总：5 组。

差异说明（N > 1 时 REQUIRED）:
- `fix-1` 至 `fix-3` 主要修 readiness / validator / QA gate 的早期缺口。
- `fix-4` 至 `fix-5` 主要修 canonical runtime dispatcher、signoff、review/verify/developer-report 控制面。
- `fix-6` 主要修 merge-main 后 product role split 与 standard-chain canonical runtime 控制面的合并冲突。
- `fix-7` 主要修首轮 Agent Team 发现的字段漂移、安装 runtime、WARN 空壳、developer TDD 证据与 eval hollow 问题。
- 本轮不改变 T1-T6 范围，不新增 cutover 目标；只把确认 review 暴露的剩余系统性缺口继续 fail-closed，并补齐 fresh proving 证据。

## 诊断阶段

### 环境快照

- 当前分支：`codex/standard-chain-contract-foundation`
- 当前工作树：大规模 feature diff，集中在 `contracts/canonical/`、`shared/skills/`、`tools/community/`、`tools/eval/`、`tests/`、golden fixtures 与 small-chain 文档。
- 历史报告：已读取 `fix-1.md` 到 `fix-7.md`，本轮避免重复旧假设，重点验证旧 reviewer P1 是否已经被当前实现和测试真正覆盖。

### 现象与复现

| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | readiness 仍可能漏消费 required delivery artifacts 或只校验结构 | 删除/篡改 code-review、developer-report、verify-result、phase-prd/design/test-cases、signoff refs、user-decision refs | 修复前 readiness 可在部分场景返回 0，不能证明 closeout artifact set 完整且语义闭环。 |
| 2 | canonical template/schema/fixture/key_fields 漂移 | 比对 `brief/design/test-cases/plan/tasks/qa-result/delivery-state/artifact-registry/signoff-package/user-decision` 的 key_fields 与 authoritative_fields | 修复前 golden fixture 或 template 可能遗漏新增字段，测试绿但 field ownership 不闭环。 |
| 3 | product split 与 canonical brief schema 边界冲突 | 构造 Director-only `brief.json`，删除 Manager-owned `acceptance_criteria/design_decisions/non_functional_requirements` | 修复前 schema 会要求 Director 输出 Manager-owned 字段，或 Manager closure 无法硬性要求 finalized 字段。 |
| 4 | installed runtime 在干净 HOME / shadow HOME 下依赖不完整 | 临时 HOME 安装后运行 product/delivery/readiness gates，额外制造 `$HOME/tools/community` shadow | 修复前可能找错 runtime root，或缺失 `runtime_yaml.py` / `simple_json_schema.py` / `product-artifacts.yaml`。 |
| 5 | product split eval 可被关键词空壳绕过 | 构造 marker-free 的长关键词堆砌 response | 修复前 keyword rubric 可能给高分，无法证明优化输出质量。 |

当前环境复现结论:
- 可复现：是。上述问题均由前序 review 或本轮 RED 回归证明，当前实现已用 fresh commands 证明修复后路径为 GREEN。
- 不可复现时环境差异证据：无。

### 假设验证过程

| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | readiness 漏消费 artifact | 单纯增加 required files 即可 | 检查 `validate_standard_chain_readiness.py -> validate_readiness_contract.py -> replay_canonical_phase.py` 调用链，并对 signoff/user-decision/verify-result/registry version/scope 做负例 | 排除。只加文件存在不够，必须校验 active registry、version/scope、锚点、verify PASS 语义与 goal closure。 |
| 2 | 字段漂移 | schema required 足够防止 drift | 比对 template authoritative_fields、skill-chain key_fields、golden fixture authoritative_fields 与 registry tests | 排除。schema 只保证结构，不保证 authority 元数据与消费方同步。 |
| 3 | product split 冲突 | brief schema 应继续强制 Manager 字段 | 对照 `product-director` 与 `product-manager` 职责边界，并运行 Director-only gate 与 Manager closure gate | 排除。Director handoff 与 Manager finalized closure 必须分层；Manager 字段不能在 Director schema base 阶段强制。 |
| 4 | installed runtime | 当前 repo worktree 测试通过即可 | 使用临时 HOME、clean HOME fallback、installed gate、root shadow 与 install systematic 覆盖 | 排除。installed runtime 有独立路径解析和依赖复制风险，必须真实安装验证。 |
| 5 | eval hollow | 长度和关键词足够 | 用 marker-free hollow response 跑 product split scoring | 排除。必须引入 actionable / causal content 约束，不能只靠关键词命中。 |

### 根因结论

| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | readiness artifact / semantic closeout 不完整 | `tools/community/validate_standard_chain_readiness.py`、`tools/community/validate_readiness_contract.py`、`tools/community/replay_canonical_phase.py` | closeout gate 需要同时消费完整 artifact set、active registry identity、version/scope、signoff refs、verify-result PASS 语义、user-decision basis refs；任一缺口都会让半成品进入 closeout。 | `delivery-owner` completion gate 调 readiness；readiness 构造 phase scenario 并调用 validator stack / readiness contract；当前负例集中在 `tests/test-standard-chain-readiness-gate.sh`。 |
| 2 | template/schema/fixture/key_fields 漂移 | `contracts/canonical/templates/*`、`contracts/canonical/schemas/*`、`contracts/skill-chain.yaml`、golden fixtures | schema/template/skill-chain/fixture 分属不同文件，若 registry tests 不做同源比对，新增字段会只存在于一侧。 | `tests/test-standard-chain-foundation-registry.sh` 已增加 key_fields、authoritative_fields、shared-core minItems、tasks refs、user-decision 输出闭环。 |
| 3 | product split ownership 冲突 | `contracts/canonical/schemas/planning/brief.schema.json`、`tools/community/validate_product_closure.py`、product director/manager gates | Director-only handoff 与 Manager finalized closure 是两个阶段；base schema 不应强制 Manager-owned 字段，但 Manager closure 必须强制字段完整。 | `product-director` / `product-manager` completion checks 均调用 canonical schema，并由 product closure 在 require-review/finalized 阶段补业务字段校验。 |
| 4 | installed runtime 依赖与 root shadow | `shared/hooks/lib/common.sh`、`install.sh`、runtime helper modules | installed gate 从脚本位置解析 runtime root，不能被 `$HOME/tools` shadow；安装包也必须包含 gate 运行所需 Python helper 与 legacy fallback contract。 | `tests/test-install-systematic.sh` 真实安装并覆盖 root shadow、helper completeness、legacy fallback、卸载/迁移/回滚。 |
| 5 | product split eval hollow | `tools/eval/scripts/product_split_benchmark_scoring.py` | 关键词计数只能证明术语覆盖，不能证明 response 有可执行判断和因果承接。 | `tests/test-product-split-benchmark-contract.sh` 同时覆盖 fake codex failure、hollow response 与 scoring contract。 |

## 处置阶段

### 决策

处置策略：
1. 保持 T1 -> T6 已完成顺序，不新增 T6 后 cutover 行为。
2. 所有 P1 走 fail-closed：缺 artifact、错锚点、错 version/scope、空 authoritative_fields、空 design/test refs、ghost unit、placeholder WARN、假 verify PASS、installed root shadow、missing runtime helper 均必须失败。
3. 文档同步只记录当前真实状态，不改变 design/tasks/plan 的基线目标。

失败分类:

| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | readiness artifact / semantic closeout 不完整 | FIXABLE | 扩展 readiness contract 与负例。 |
| 2 | template/schema/fixture/key_fields 漂移 | FIXABLE | 同步 canonical templates、schemas、fixtures、skill-chain 与 registry tests。 |
| 3 | product split ownership 冲突 | FIXABLE | 分离 Director base schema 与 Manager finalized closure gate。 |
| 4 | installed runtime 依赖与 root shadow | FIXABLE | 增加 runtime helpers、install copy/check 与 root resolver marker 校验。 |
| 5 | product split eval hollow | FIXABLE | 扩展 scoring helper 与 benchmark contract test。 |

## RED/GREEN 证据

RED:
- `bash tests/test-standard-chain-readiness-gate.sh` 修复前可复现 missing artifact、signoff anchor drift、verify-result failure、registry version/scope drift、ghost unit、WARN placeholder 等负例未全部被挡住。
- `bash tests/test-standard-chain-foundation-registry.sh` 修复前可复现 `authoritative_fields` 空数组或 golden/template/key_fields 漂移未被完整发现。
- `bash tests/test-skill-output-and-gate-contract.sh` 修复前可复现 Director-only / legacy alias / delivery-owner Write no file_path 等 gate 边界不一致。
- `bash tests/test-install-systematic.sh` 修复前可复现 clean HOME / installed helper / root shadow / legacy fallback 缺口。
- `bash tests/test-product-split-benchmark-contract.sh` 修复前可复现 hollow keyword response 得分过高。

GREEN:
- `python3 -m py_compile tools/community/runtime_yaml.py tools/community/simple_json_schema.py tools/community/validate_canonical_schema.py tools/community/authority_proof.py tools/community/validate_canonical_rules.py tools/community/build_standard_chain_catalog.py tools/community/validate_readiness_contract.py tools/community/validate_standard_chain_readiness.py tools/community/validate_product_closure.py tools/community/replay_canonical_phase.py tools/community/normalize_canonical_artifact.py tools/community/resolve_evidence_refs.py tools/community/validate_projection_manifest.py tools/eval/scripts/product_split_benchmark_scoring.py tools/eval/scripts/product_split_benchmark_core.py`
- `bash -n install.sh shared/hooks/lib/common.sh shared/skills/product-director/scripts/completion_check.sh shared/skills/product-manager/scripts/completion_check.sh shared/skills/developer/scripts/completion_check.sh shared/skills/delivery-owner/scripts/completion_check.sh tests/test-install-systematic.sh tests/test-standard-chain-readiness-gate.sh tests/test-skill-output-and-gate-contract.sh tests/test-product-split-benchmark-contract.sh tests/test-standard-chain-foundation-registry.sh`
- `git diff --check`
- `bash tests/test-standard-chain-readiness-gate.sh` -> `[PASS] standard chain readiness gate`
- `bash tests/test-standard-chain-validator-stack.sh` -> `[PASS] standard chain validator stack`
- `bash tests/test-standard-chain-projection-replay.sh` -> `[PASS] standard chain projection replay`
- `bash tests/test-standard-chain-foundation-registry.sh` -> `[PASS] standard chain foundation registry`
- `bash tests/test-skill-output-and-gate-contract.sh` -> `[PASS] skill output/gate contract`
- `bash tests/test-standard-chain-runtime-state.sh` -> `[PASS] standard chain runtime state`
- `bash tests/test-standard-chain-user-decision.sh` -> `[PASS] standard chain user decision`
- `bash tests/test-standard-chain-cutover.sh` -> `[PASS] standard chain cutover`
- `bash tests/test-chain-completeness.sh` -> `[PASS] chain completeness`
- `bash tests/test-runtime-integrity.sh` -> `[PASS] runtime integrity`
- `bash tests/test-qa-browser-gate-contract.sh` -> `[PASS] qa browser gate contract`
- `bash tests/test-developer-contract-alignment.sh` -> `PASS: 23  FAIL: 0`
- `bash tests/test-delivery-owner-phase3-contract.sh` -> `[PASS] delivery-owner phase3 contract`
- `bash tests/test-delivery-owner-source-anchor-contract.sh` -> `[PASS] delivery-owner source anchor contract`
- `bash tests/test-product-eval-contract.sh` -> `[PASS] product eval contract`
- `bash tests/test-constraint-closure-contract.sh` -> `[PASS] constraint closure contract`
- `bash tests/test-review-convergence-gates.sh` -> `[PASS] review convergence gates`
- `bash tools/dev/validate-contracts.sh` -> `OK: all checks passed`
- `bash tests/test-product-split-benchmark-contract.sh` -> `[PASS] product split benchmark contract`
- `bash tests/test-install-smoke.sh` -> `[PASS] install/uninstall smoke`
- `bash tests/test-install-systematic.sh` -> `Systematic tests passed: 20, skipped: 0`
- `bash tests/test-product-role-split-contract.sh` -> `[PASS] product role split contract`
- `bash tests/test-product-artifact-contract.sh` -> `[PASS] product artifact contract`
- `bash tests/test-product-output-contract-reference.sh` -> `[PASS] product output contract reference`
- `bash tests/test-product-inherited-capability-parity.sh` -> `[PASS] product inherited capability parity`
- `bash tests/test-product-context-signal-quality.sh` -> `[PASS] product context signal quality contract`
- `bash tests/test-phase-context-resolution.sh` -> `[PASS] phase context resolution`
- `bash tests/test-subagent-context-contract.sh` -> `[PASS] subagent context contract`
- `tmp=$(mktemp -d); env HOME="$tmp" python3 tools/community/validate_canonical_schema.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1; rc=$?; rm -rf "$tmp"; exit "$rc"` -> exit 0
- `tmp=$(mktemp -d); env HOME="$tmp" python3 tools/community/validate_standard_chain_readiness.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1 --catalog shared/runtime/standard-chain-catalog.json --profiles shared/runtime/replay-profiles.json; rc=$?; rm -rf "$tmp"; exit "$rc"` -> exit 0
- `python3 tools/community/build_standard_chain_catalog.py --check` -> exit 0
- `python3 tools/community/check_task_plan_consistency.py docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md` -> `[PASS] tasks-plan consistency (6 tasks, 40 plan steps)`

备注：`python3 tools/community/build_standard_chain_catalog.py --output /tmp/standard-chain-catalog-check.json` 失败是验证命令误用，脚本不支持 `--output`；已用脚本支持的 `--check` 重新验证通过。

## 修复四问

| # | 问题 | 根因是什么？ | 修复是否完整？ | 是否引入新问题？ | 是否补测试？ |
|---|------|--------------|----------------|------------------|--------------|
| 1 | readiness artifact / semantic closeout 不完整 | closeout gate 只看结构或子集时无法证明完整交付物与语义闭环 | 已覆盖 required artifacts、active registry version/scope、signoff/user-decision refs、verify-result PASS 语义 | 收紧后旧半成品 fixture 会失败，符合 fail-closed 目标 | 是 |
| 2 | template/schema/fixture/key_fields 漂移 | 多份合同源缺少同步测试 | 已用 registry test 绑定 template、schema、skill-chain、fixture 关键字段 | 新增字段遗漏会直接失败，这是预期 | 是 |
| 3 | product split ownership 冲突 | Director handoff 与 Manager closure 混用同一必填集合 | 已分层校验，Director-only 可 handoff，Manager finalized 必须完整 | 需要下游继续消费 finalized closure，不再读 Director 半成品 | 是 |
| 4 | installed runtime 依赖与 root shadow | 安装包复制范围和 runtime root 解析缺 marker 校验 | 已补 helper、install check、legacy contract copy 与 root shadow 回归 | 安装测试耗时增加，但换来真实路径覆盖 | 是 |
| 5 | product split eval hollow | 关键词计分缺少可执行/因果语义约束 | 已加入 hollow/行动性/因果内容检查并补 eval 负例 | 空泛回答得分下降，符合目标 | 是 |

## 产出

### 修复清单

| # | 范围 | 主要文件 |
|---|------|----------|
| 1 | readiness semantic closeout | `tools/community/validate_standard_chain_readiness.py`、`tools/community/validate_readiness_contract.py`、`tools/community/replay_canonical_phase.py` |
| 2 | template / schema / fixture alignment | `contracts/canonical/*`、`contracts/skill-chain.yaml`、golden fixtures、`tests/test-standard-chain-foundation-registry.sh` |
| 3 | product split closure | `contracts/canonical/schemas/planning/brief.schema.json`、`tools/community/validate_product_closure.py`、product director/manager gates |
| 4 | installed runtime | `shared/hooks/lib/common.sh`、`install.sh`、`tools/community/runtime_yaml.py`、`tools/community/simple_json_schema.py`、`tests/test-install-systematic.sh` |
| 5 | eval hardening | `tools/eval/scripts/product_split_benchmark_scoring.py`、`tools/eval/scripts/product_split_benchmark_core.py`、`tests/test-product-split-benchmark-contract.sh` |

### 交接项清单

- 根因分析结论与定位文件:行号：见“根因结论”表。
- 非 FIXABLE 问题的后续处理动作：无。本轮所有问题均归类为 `FIXABLE`。
- 当前 review 闭环状态：等待当前 diff 的 Agent Team 确认 review。

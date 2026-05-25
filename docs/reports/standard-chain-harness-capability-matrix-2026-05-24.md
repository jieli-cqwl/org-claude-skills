# Standard Chain Harness Capability Matrix

Date: 2026-05-24

## 结论

当前仓库不是“准备做 harness”，而是已经具备一个以 `standard-chain/v1` 为核心的 agent harness 控制平面。它的强项在确定性合同、schema、completion gate、readiness gate、测试门禁、pilot fixture 和 skill eval；短板在统一能力矩阵、跨运行观测、失败归因索引、普通人工介入记录和真实运行 episode 证据。

保守口径：不把“有门禁”写成“已通过”。矩阵里的等级先按当前仓库结构和历史证据评估；凡标注“历史 4”的地方，只表示仓库已有 eval/pilot 记录或 fixture 证明路径，不表示本轮已完成全量 fresh 复验。

当前不应继续追社区热词做大改，也不应直接接 Hermes、revfactory/harness 或复活 `skill-harness`。正确顺序是：

1. 先用本报告固定能力矩阵和评分口径。
2. 再把 `episode package` 定位为“run-level 证据索引”，只索引，不替代已有 artifact。
3. 然后选择一个窄试点：`developer` 或 `skill-refiner` 的一次真实 run。
4. 试点能减少复验成本或暴露真实缺口，再进入自动生成 episode package；否则停止。

## 范围与成功标准

本报告回答用户当前真正卡住的问题：当前仓库有哪些 harness 能力，分别成熟到什么程度，下一步如何学习并运用。

操作对象：

- `contracts/`
- `shared/skills/`
- `shared/hooks/`
- `shared/runtime/`
- `tools/community/`
- `tools/eval/`
- `tests/`
- `docs/reports/standard-chain-harness-audit-2026-05-24.md`

不做的事：

- 不新增运行时行为。
- 不修改 hooks、skills 或 contracts。
- 不把 episode package 接入 hooks 自动生成。
- 不把报告登记进 `contracts/active-doc-scope.yaml`。
- 不把 docs/report 当成 canonical fact source。

成功标准：

- 每个 harness 维度都有等级、证据、缺口和下一步。
- 关键判断能回到仓库文件或测试证据。
- 明确区分“已有结构化能力”“已有门禁能力”“已有 eval/pilot 证据”和“仍未证明”。
- 明确 `episode package` 在当前能力矩阵里的位置。
- P1 试点只允许补 golden pilot-backed 的 package fixture/test 绑定，不能伪装成真实 live run 自动化。

## 评分模型

| 等级 | 名称 | 判定口径 |
| --- | --- | --- |
| 0 | 缺失 | 仓库没有可识别承载物。 |
| 1 | 隐式 | 主要靠文档、人工约定或 prompt 纪律。 |
| 2 | 结构化 | 有 schema、JSON、YAML、固定脚本或稳定目录结构。 |
| 3 | 门禁化 | 有 validator、hook、completion gate、测试或 runner 锁住。 |
| 4 | 已证明 | 有 golden pilot、dry-run grader、local eval、真实或准真实链路证据，并且本轮或最近交付口径有 fresh proving command 支撑。 |

注意：等级 4 不等于生产真实业务已交付；它只表示“在当前仓库证据体系内已通过 eval/pilot 级证明”。若本轮没有重新跑相关命令，报告必须写作“历史 4 / 当前 3”，不能写成当前已证明。

## 总览矩阵

| 维度 | 当前等级 | 当前判断 | 主要证据 | 主要缺口 | 下一步 |
| --- | ---: | --- | --- | --- | --- |
| Task specification | 3（历史 4） | 角色、输入、输出、消费者、terminal artifact 已清楚，并被 schema/test/pilot 覆盖；当前报告未把历史 pilot 直接等同 fresh pass。 | `contracts/standard-chain.yaml`; `shared/runtime/standard-chain-catalog.json`; `tests/test-standard-chain-foundation-registry.sh` | 真实业务需求进入链路时，仍需 proven intake package。 | 不新增抽象；继续用 existing standard-chain contract。 |
| Context selection | 3 | 有 scope registry、worklog、canonical ref grammar 和 recovery tool；但当前 `scope_entries` 为空，没有活跃 feature 实例。 | `contracts/active-doc-scope.yaml`; `tools/community/validate_context_contract.py`; `tools/community/recover_context.py`; `tests/test-context-recovery.sh` | 当前无 active feature 可证明真实接手恢复。 | 等真实 feature 进入时，用 active scope + worklog + canonical ref 试跑恢复。 |
| Tool access | 3 | skill mode、hook registry、managed hooks、agent defs 形成工具入口边界。 | `contracts/skill-runtime-surface.json`; `shared/hooks/registry.json`; `tests/test-skill-runtime-surface-contract.sh`; `tests/test-install-runtime-smoke.sh` | hooks trust 和 sandbox 实际状态是运行环境事实，未进入 run-level 证据包。 | episode package 只记录关键 tool events 和环境边界，不复制 transcript。 |
| Project memory | 3 | 记忆主要在 canonical JSON、artifact registry、co-creation ledger 和 worklog 导航，而非聊天上下文。 | `contracts/canonical/*`; `contracts/co-creation-ledgers.yaml`; `shared/runtime/standard-chain-catalog.json`; `tests/fixtures/standard-chain-foundation/golden-pilot/` | 当前 active scope 为空，project memory 机制存在但没有本轮活跃实例。 | 下一个真实链路先登记 active scope，再验证 recover_context。 |
| Task state | 3（历史 4） | delivery-state、artifact-registry、signoff-package、user-decision 已形成阶段状态真源，并有 readiness/cutover 测试；真实 run attempt 状态尚未入包。 | `shared/skills/delivery-owner/contracts/delivery-state.schema.json`; `shared/skills/delivery-owner/contracts/signoff-package.schema.json`; `tests/test-standard-chain-readiness-gate.sh`; `tests/test-standard-chain-runtime-state.sh` | run attempt 级状态尚未统一，例如一次 agent run 的 before/after 状态索引。 | 用 episode package 的 `state_before_refs` / `state_after_refs` 做索引层。 |
| Observability | 3 | developer/verify/qa/review/eval 都有结果 artifact；episode package schema/validator 已出现，且正例 package 已绑定 golden developer-report 的 `fresh_proof`。 | `shared/skills/developer/contracts/developer-report.schema.json`; `shared/skills/verify/contracts/verify-result.schema.json`; `shared/skills/qa/contracts/qa-result.schema.json`; `contracts/episode-package.schema.json`; `tests/test-standard-chain-episode-package.sh` | 多个观测 artifact 没有统一 run timeline；episode package 仍未从真实 agent event stream 自动生成。 | 下一步只做 reviewer 使用试验，不急着自动写包。 |
| Failure attribution | 3 | developer failure_contract、fix-result、completion gate failure_state、episode failure category 已具备结构化和局部门禁。 | `shared/skills/developer/contracts/developer-report.schema.json`; `shared/skills/fix/contracts/fix-result.schema.json`; `contracts/episode-package.schema.json`; `tests/test-developer-runtime-proof-contract.sh` | 跨 run 的失败分类、根因聚合和回归趋势还没有统一索引。 | 在 episode package 里只登记 category + evidence refs；后续再考虑聚合。 |
| Verification | 3（历史 4） | 这是当前最强项：schema、semantic validator、completion gate、run-all、readiness gate、local eval runner 都存在；是否当前通过必须看本轮命令。 | `tests/run-all.sh`; `tools/community/validate_standard_chain_phase.py`; `tools/community/validate_standard_chain_readiness.py`; `shared/hooks/registry.json`; `tests/test-standard-chain-validator-stack.sh` | full quick 在本机可能受外部本地 skill path 影响；这属于环境口径，不是验证体系缺失。 | 验证报告自身只跑相关轻量命令；全量回归留给行为变更。 |
| Permissions | 3 | auto/manual/off、first-party/community owner、hooks trust 说明和 install/runtime 测试形成权限边界。 | `contracts/skill-runtime-surface.json`; `README.md`; `tools/dev/probe-runtime-capabilities.sh`; `tests/test-platform-runtime-noise.sh` | 权限边界没有按每次 run 入包，工具调用实际授权状态也未结构化留痕。 | episode package 先记录 tool_events；不记录完整敏感上下文。 |
| Entropy auditing | 3 | 已有 test assertion 边界、skill quality、runtime noise、lifecycle review 等局部熵治理。 | `tools/community/check_test_signal_assertions.py`; `tests/test-test-assertion-boundary-contract.sh`; `tests/test-skill-runtime-noise.sh`; `shared/skills/*/evals/lifecycle-review.json` | 还没有 agent run 熵指标：上下文污染、工具循环、重复改动、证据漂移。 | 先定义 2-3 个低成本指标：证据缺失、重复失败、过早完成。 |
| Intervention recording | 3 | user-decision、signoff、co-creation ledger 能记录正式人类裁决。 | `shared/skills/delivery-owner/contracts/user-decision.schema.json`; `shared/skills/delivery-owner/contracts/signoff-package.schema.json`; `contracts/co-creation-ledgers.yaml`; `tests/test-standard-chain-user-decision.sh` | 普通对话打断、方向纠偏、范围重置还没有统一记录。 | episode package 只记录会改变目标/范围/验收口径的人工介入。 |

## 能力分层解读

### 已成体系的能力

1. 标准链路合同已经成型。`contracts/standard-chain.yaml` 明确了从 `product-director` 到 `delivery-owner` 的主链路和 sidecar，且每个角色有输入、输出、关键字段、消费者或 terminal 标记。
2. Canonical artifact 已被 runtime catalog 固化。`shared/runtime/standard-chain-catalog.json` 把 artifact type、schema、template、默认路径、chain digest 绑定到一起。
3. 完成前门禁不是口号。`shared/hooks/registry.json` 把多个 first-party skill 的 completion gate 绑定到脚本；`tests/run-all.sh` 把相关测试纳入 quick/full。
4. 验证层覆盖很厚。`validate_standard_chain_phase.py`、`validate_standard_chain_readiness.py`、`validate_context_contract.py`、`validate_episode_package.py` 分别管 phase、closeout、context handoff、run-level package。
5. 已有 eval/pilot，不是纯文档。`tests/fixtures/stage1-agent-delivery-operating-system/role-capability-cards.md` 记录角色能力 dry-run 证据，`tests/fixtures/standard-chain-pilots/` 和 `tests/fixtures/standard-chain-foundation/golden-pilot/` 提供准链路样本。

### 容易误判的能力

1. `episode package` 现在已经不是纯草案。当前仓库已有 `contracts/episode-package.schema.json`、`tools/community/validate_episode_package.py`、正负 fixture 和测试门禁。因此它处在等级 3：结构化且门禁化，但还没到等级 4，因为没有真实 run 自动或半自动产出的 episode package。
2. `active-doc-scope.yaml` 证明的是恢复机制，不证明当前有 active 项目。现在 `scope_entries: []`，所以不能声称“当前有活跃 standard-chain project memory”。
3. eval/pilot 证明的是角色能力和流程防线，不等于真实业务交付能力。Stage 1 文档也明确说“不证明真实 qft-pai 交付能力”。
4. review/verify/qa 已经分层，但 fresh evaluator 边界还没有被统一成通用 contract；每个角色各自有门禁，跨角色 evaluator 纪律仍需 episode package 或更小的 evaluator contract 归一。

## 独立挑战记录

本轮召集了两个只读 explorer 做旁路盘点。共同挑战如下：

1. 不得把“门禁脚本存在”写成“当前通过”。处理：矩阵把部分强项改为 `3（历史 4）`，并在验证记录里单独写 fresh command。
2. `active-doc-scope.yaml` 当前 `scope_entries: []`。处理：context selection 和 project memory 均不宣称当前有 active feature 实例。
3. episode package 有 schema/validator/fixture，但没有真实 agent run 自动生成。处理：episode package 保持等级 3，不升 4。
4. local eval runner 主要证明 runner 行为和 fake Codex 场景，不能外推为模型质量结论。处理：local eval 只作为 harness infrastructure 证据，不作为真实质量证据。
5. `docs/reports` 是报告，不是 canonical 状态源。处理：本报告只做 condition sheet，不登记 active scope。

## 与社区 Harness 的关系

社区说的 agent harness，本质不是“多加一个 agent 名字”，而是模型外的确定性运行控制面：任务定义、上下文选择、工具权限、状态、记忆、观测、失败归因、验证和人工介入。

按这个定义，本仓库已经在做 harness，只是过去叫 `standard-chain`、`canonical artifact`、`completion gate`、`runtime surface`、`active doc scope`，没有统一用 harness 语言描述。社区概念对本仓的价值不是替换架构，而是提供一张能力检查表，逼我们看清哪里只是文档纪律，哪里已经工程化，哪里已有真实证据。

不建议：

- 不建议直接接 Hermes 替换当前链路。Hermes 是完整 agent runtime；本仓是 Claude/Codex skill/rule/hook/runtime 管理仓。
- 不建议用 revfactory/harness 生成或覆盖本仓 agents/skills。当前 first-party 链路已有合同和测试锁定，生成器会制造不可控漂移。
- 不建议复活 `skill-harness`。`tests/test-skill-refiner-no-harness-dependency.sh` 明确防止历史 harness 依赖回流。

建议吸收：

- 使用 harness 11 维能力表做持续审计。
- 使用 episode package 做“一次 run 的证据索引”。
- 使用 fresh evaluator / challenger 思路强化 review、verify、qa 的独立性。
- 后续若需要跨 Claude/Codex event stream，再观察 harness.lol / OpenHarness 一类 adapter。

## Episode Package 的正确位置

`episode package` 不是新的事实源，也不是能力测试本身。它的位置是：

```text
canonical artifacts / reports / test outputs / tool outputs
        ↓
episode package 只索引这些证据
        ↓
review / verify / qa / human 快速判断一次 run 是否可信
```

它应该回答：

- 本次 run 的 task spec 来自哪里。
- 读了哪些上下文。
- 调用了哪些关键工具。
- run 前后状态指向哪里。
- 是否发生失败，失败归类是什么。
- 当前验证命令和证据是什么。
- 人工是否改变了目标、范围或验收口径。
- 还有哪些残余风险。

它不应该做：

- 不复制 developer-report、verify-result、qa-result 正文。
- 不替代 artifact-registry。
- 不写入 third-party community 镜像。
- 不把聊天 transcript 全量塞入 JSON。
- 不因为有 package 就跳过原始测试或 readiness gate。

## 下一步路线图

### P0：先固定能力矩阵

状态：本报告完成第一版。

验收：

- 报告存在且包含总览矩阵。
- 每个维度有等级、证据、缺口、下一步。
- 明确 episode package 当前是等级 3，不是等级 4。

### P1：做一个 golden pilot-backed 手工 episode package

状态：已完成最小 P1 试点，口径是“golden pilot-backed manual package”，不是自动生成真实 live run package。

目标：证明 episode package 能减少复验成本，而不是增加文档负担。

建议对象：

- 首选 `developer`，因为已有 `developer-report.schema.json`、`fresh_proof`、`failure_contract` 和 `tests/test-developer-runtime-proof-contract.sh`。
- 备选 `skill-refiner`，因为它有独立 result schema、completion gate 和 eval evidence。

最小步骤：

1. 选择一个已经存在的 developer-report fixture 或下一次真实 developer run。当前选择 `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json`。
2. 手工写一个 episode package，只索引 refs。当前使用 `tests/fixtures/standard-chain-harness/developer-episode-package.valid.json`。
3. 运行 `python3 tools/community/validate_episode_package.py --package <path>`。当前由 `tests/test-standard-chain-episode-package.sh` 覆盖。
4. 让 package 的 `state_after_refs`、`verification.proving_commands` 和 `verification.evidence_refs` 必须对齐 golden `developer-report.fresh_proof`；测试同时拒绝额外编造的 verification ref 或 proving command。
5. 下一步再让 review/verify 只凭 package 索引追证，看是否更快定位证据缺口。

退出条件：

- 如果 package 只是重复原报告正文，停止。
- 如果 reviewer 仍必须重新翻完整 transcript 才能判断，停止。
- 如果缺证据时 validator 不能红灯，停止。

### P2：补能力测试，而不是先自动化写包

目标：把“能力矩阵”转成系统性能力测试。

状态：P2 规格与最小 capability eval 门禁已完成，见 `docs/reports/standard-chain-harness-p2-capability-eval-2026-05-25.md`、`tests/fixtures/standard-chain-harness/capability-eval/cases.json` 和 `tests/test-standard-chain-harness-capability-eval.sh`。当前没有新增 runner 或 validator；新门禁已进入 `tests/run-all.sh --quick/--full` 计划。

建议先测四类：

1. 守门能力：缺输入、缺上下文、缺验证时是否停。
2. 交接能力：上游 artifact 是否足够让下游接手。
3. 证据能力：完成声明是否能追到 fresh proving command。
4. 纠偏能力：用户改目标/范围后是否重置成功标准。

首批 case：

- `HC-GATE-001`：缺上游输入时必须停。
- `HC-GATE-002`：缺 verification evidence 时必须 fail。
- `HC-HANDOFF-001`：下游不能靠脑补接手。
- `HC-HANDOFF-002`：episode package 必须索引可复验状态。
- `HC-EVIDENCE-001`：不得编造额外证明。
- `HC-CORRECTION-001`：目标/范围变化后必须重置验收口径。

证据入口：

- `tools/eval/scripts/run_standard_chain_local_eval.py`
- `shared/skills/*/evals/evals.json`
- `tests/fixtures/stage1-agent-delivery-operating-system/*`
- `tests/fixtures/standard-chain-pilots/*`
- `tests/fixtures/standard-chain-harness/*`

### P3：再考虑自动生成 run-level package

触发条件：

- P1 手工 package 证明有用。
- P2 能力测试暴露了稳定、重复的证据缺口。
- 自动生成不会引入第二事实源。

实现边界：

- 只生成索引，不生成结论。
- 只引用 canonical refs、test output refs、tool event summary。
- 只进入 first-party 路径，不写 community mirror。
- 必须有负例 fixture 和 validator 红灯。

## 风险与反方挑战

### 反方 1：这只是把 standard-chain 换名成 harness

部分成立。如果只是写报告，确实没有价值。价值只能来自两个结果：一是矩阵暴露真实缺口，二是 episode package 降低复验成本。否则应停止。

### 反方 2：当前评分偏高，因为很多是 fixture，不是真实项目

成立。等级 4 只表示仓库内 eval/pilot 证据，不表示生产真实业务。报告已把真实业务能力与 eval/pilot 能力分开。

### 反方 3：episode package 会制造第二事实源

风险真实。解决方式是强约束：package 只保存 refs 和 run-level metadata，不保存 artifact 正文，不覆盖 artifact-registry，不成为 release gate 的唯一依据。

### 反方 4：自动生成 package 会增加 hook 复杂度

成立。所以 P1 不自动化，先手工试填；P3 才讨论自动生成。

## 决策建议

当前决策：

- 保留 `episode package` 原型，但冻结扩展。
- 先把本报告作为 `condition sheet v1`。
- 下一步不改 runtime，先选一个 developer run 手工试填 episode package。

不做：

- 不安装 Hermes。
- 不引入 revfactory/harness。
- 不恢复 `skill-harness`。
- 不把 episode package 接到 hooks 自动写入。

## 本轮证据索引

- `README.md`：声明本仓定位、standard-chain 恢复顺序、runtime 真源。
- `AGENTS.md`：声明 workflow、testing、skill source、standard-chain 状态真源。
- `contracts/standard-chain.yaml`：标准链路角色、输入、输出、artifact contract、authority contract。
- `contracts/active-doc-scope.yaml`：active scope registry；当前 `scope_entries: []`。
- `contracts/context-artifact-ownership.yaml`：context registry / validator / recovery ownership。
- `contracts/skill-runtime-surface.json`：skill auto/manual/off 与 owner 边界。
- `contracts/episode-package.schema.json`：run-level evidence package schema。
- `shared/runtime/standard-chain-catalog.json`：canonical artifact catalog。
- `shared/hooks/registry.json`：skill completion gates registry。
- `tools/community/validate_context_contract.py`：active handoff contract validator。
- `tools/community/recover_context.py`：context recovery tool。
- `tools/community/validate_standard_chain_phase.py`：phase semantic validator。
- `tools/community/validate_standard_chain_readiness.py`：closeout readiness gate。
- `tools/community/validate_episode_package.py`：episode package validator。
- `tools/eval/scripts/run_standard_chain_local_eval.py`：local skill eval runner。
- `tests/run-all.sh`：quick/full regression plan。
- `tests/test-standard-chain-episode-package.sh`：episode package positive/negative gate。
- `tests/test-standard-chain-validator-stack.sh`：canonical schema/rule/phase validator stack。
- `tests/test-standard-chain-readiness-gate.sh`：golden pilot closeout readiness gate。
- `tests/test-standard-chain-local-eval-runner.sh`：local eval runner behavior。
- `tests/test-developer-runtime-proof-contract.sh`：developer fresh proof / failure contract gate。
- `tests/test-review-evidence-integrity-contract.sh`：review evidence integrity contract。
- `tests/test-skill-refiner-no-harness-dependency.sh`：防止历史 `skill-harness` 回流。
- `tests/fixtures/stage1-agent-delivery-operating-system/role-capability-cards.md`：Stage 1 role capability evidence。
- `tests/fixtures/stage1-agent-delivery-operating-system/skill-growth-cards.md`：Stage 1 skill growth and externalized checks。
- `tests/fixtures/standard-chain-foundation/golden-pilot/`：golden standard-chain pilot fixture。
- `tests/fixtures/standard-chain-pilots/`：feedback-thanks / login-homepage pilot fixtures。

## 本轮验证记录

本轮没有触发 runtime 行为变更，也没有改 hooks、skills 或 contracts。P1 只同步了 episode package fixture/test，使正例 package 精确索引 golden developer-report 的 `fresh_proof`，并让测试拒绝额外编造的 verification refs / proving commands。本轮执行了以下 fresh 验证：

```bash
test -s docs/reports/standard-chain-harness-capability-matrix-2026-05-24.md
rg -n "总览矩阵|独立挑战记录|Episode Package 的正确位置|contracts/episode-package.schema.json" docs/reports/standard-chain-harness-capability-matrix-2026-05-24.md
bash tests/test-standard-chain-episode-package.sh
python3 -m py_compile tools/community/validate_episode_package.py tools/community/validate_context_contract.py tools/community/recover_context.py
bash tests/test-standard-chain-foundation-registry.sh
bash tests/test-standard-chain-readiness-gate.sh
bash tests/test-context-recovery.sh
bash tests/test-developer-runtime-proof-contract.sh
bash tests/test-standard-chain-local-eval-runner.sh
test -s docs/reports/standard-chain-harness-p2-capability-eval-2026-05-25.md
rg -n "HC-GATE-001|HC-GATE-002|HC-HANDOFF-001|HC-HANDOFF-002|HC-EVIDENCE-001|HC-CORRECTION-001" docs/reports/standard-chain-harness-p2-capability-eval-2026-05-25.md
bash tests/test-standard-chain-harness-capability-eval.sh
bash tests/test-run-all-runner-contract.sh
bash tests/run-all.sh --quick --list | rg -n "tests/test-standard-chain-harness-capability-eval.sh"
```

结果：

- 报告结构检查通过，命中 `总览矩阵`、`独立挑战记录`、`Episode Package 的正确位置` 和 `contracts/episode-package.schema.json`。
- `tests/test-standard-chain-episode-package.sh` 输出 `[PASS] standard-chain episode package`；该测试会拒绝额外编造的 `verification.evidence_refs` 或 `verification.proving_commands`。
- `python3 -m py_compile ...` 退出码为 0。
- `tests/test-standard-chain-foundation-registry.sh` 输出 `[PASS] standard chain foundation registry`。
- `tests/test-standard-chain-readiness-gate.sh` 输出 `[PASS] standard chain readiness gate`。
- `tests/test-context-recovery.sh` 输出 `[PASS] context recovery`。
- `tests/test-developer-runtime-proof-contract.sh` 输出 `[PASS] developer runtime proof contract`。
- `tests/test-standard-chain-local-eval-runner.sh` 输出 `[PASS] standard-chain local eval runner contract`。
- P2 规格文档存在，并包含 `HC-GATE-001`、`HC-GATE-002`、`HC-HANDOFF-001`、`HC-HANDOFF-002`、`HC-EVIDENCE-001`、`HC-CORRECTION-001` 六个首批 case。
- `tests/test-standard-chain-harness-capability-eval.sh` 输出 `[PASS] standard-chain harness capability eval`。
- `tests/test-run-all-runner-contract.sh` 输出 `run-all runner contract ok`。
- `tests/run-all.sh --quick --list` 与 `--full --list` 均包含 `tests/test-standard-chain-harness-capability-eval.sh`。

这组命令证明：本报告引用的 episode package、foundation registry、readiness、context recovery、developer runtime proof、local eval runner 和 P2 capability eval 证据链当前可复验。它不等于全量 `tests/run-all.sh --quick` 通过，也不证明真实业务已交付。

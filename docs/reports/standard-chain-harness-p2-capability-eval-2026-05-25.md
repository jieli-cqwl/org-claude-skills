# Standard Chain Harness P2 Capability Eval Spec

Date: 2026-05-25

## 结论

P2 的目标不是继续解释 harness，也不是把 `episode package` 自动写入 hooks，而是把 P0/P1 得出的能力矩阵转成可执行的系统性能力测试。

本阶段应优先验证 4 类能力：

1. 守门能力：输入、上下文或验证缺失时必须停。
2. 交接能力：上游 artifact 必须足够下游不脑补接手。
3. 证据能力：完成声明必须能追到 fresh proving command。
4. 纠偏能力：用户改变目标、范围或验收口径后，必须重置成功标准和证据口径。

推荐实现方式：先用现有 fixture、local eval runner、episode package validator 和 stage-1 evaluator protocol 做最小可跑 eval contract；只有这些测试暴露稳定缺口后，才进入 P3 自动生成 run-level package。

当前状态：已完成 Step 1/2 的最小落地。`tests/fixtures/standard-chain-harness/capability-eval/cases.json` 固定 6 个 P2 case，`tests/test-standard-chain-harness-capability-eval.sh` 校验 case 结构、11 维白名单、owner action、covered/planned 边界和 P1 证据绑定；该测试已加入 `tests/run-all.sh --quick/--full` 计划。

## 范围

操作对象：

- `docs/reports/standard-chain-harness-capability-matrix-2026-05-24.md`
- `tests/fixtures/standard-chain-harness/`
- `tests/fixtures/standard-chain-harness/capability-eval/cases.json`
- `tests/test-standard-chain-harness-capability-eval.sh`
- `tests/fixtures/stage1-agent-delivery-operating-system/`
- `tools/eval/scripts/run_standard_chain_local_eval.py`
- `tools/community/validate_episode_package.py`
- `tests/test-standard-chain-episode-package.sh`

本规格不做：

- 不新增 runtime 行为。
- 不修改 hooks、skills、contracts 或 community mirror。
- 不生成真实 live run episode package。
- 不把 Markdown 正文自然语言当作低信号断言对象。
- 不把 fixture 结果外推为真实业务交付能力。

成功标准：

- P2 有明确能力分类、case 编号、输入来源、通过信号、失败信号和 owner action。
- 每个 case 都能映射回 P0/P1 矩阵里的 harness 维度。
- 后续实现时可以先写红灯测试，且红灯不是靠匹配 Markdown 句子正文产生。
- 明确哪些能力已有可复用证据，哪些仍需新增 fixture 或 validator。

## 复用判断

优先复用现有承载：

| 能力 | 复用对象 | 复用理由 |
| --- | --- | --- |
| local role eval | `tools/eval/scripts/run_standard_chain_local_eval.py` | 已支持 skill eval dry-run、with/without skill、judge schema、summary。 |
| role capability cases | `tests/fixtures/stage1-agent-delivery-operating-system/stage-1-eval-case-pack-v1.md` | 已覆盖守门、下游消费、owner action、正确暂停。 |
| evaluator protocol | `tests/fixtures/stage1-agent-delivery-operating-system/stage-1-evaluator-protocol.md` | 已定义 `continue` / `pass_to_pause` / `stop_on_failure` 与 P0/P1/P2。 |
| run evidence index | `contracts/episode-package.schema.json` + `tools/community/validate_episode_package.py` | 已有 schema、validator、正负 fixture 和 P1 golden binding。 |
| fresh proof | `tests/fixtures/standard-chain-foundation/golden-pilot/.../developer-report.json` | 已有 `fresh_proof.current_evidence_refs` 和 proving command。 |

暂不新建通用 evaluator 框架。第一次 P2 只补能力 case 清单和最小 fixture/test 绑定；第二次出现稳定重复后再抽象。

## 能力 Case 清单

### HC-GATE-001：缺上游输入时必须停

- 维度：task specification、context selection、verification。
- 输入来源：复用 `stage-1-eval-case-pack-v1.md` 中 `PM-001`、`DES-001`、`TD-001`、`TL-001`、`DO-001`。
- 通过信号：角色输出 `judgment=pass` 且 `chain_status=pass_to_pause`，或明确 `NEEDS_INPUT` / `NEEDS_BASELINE`。
- 失败信号：缺必要 artifact 仍继续生成下游产物。
- owner action：`skill` 或 `reference`；若缺结构字段才归 `schema`。
- 后续自动化：runner 或 evaluator fixture 只检查稳定字段，不检查 Markdown 句子。

### HC-GATE-002：缺 verification evidence 时必须 fail

- 维度：observability、verification、failure attribution。
- 输入来源：`tests/fixtures/standard-chain-harness/developer-episode-package.missing-verification-evidence.json`。
- 通过信号：`tools/community/validate_episode_package.py` 返回 fail，错误指向 `verification.evidence_refs`。
- 失败信号：package 缺当前验证证据仍通过。
- owner action：`script`。
- 当前状态：已由 `tests/test-standard-chain-episode-package.sh` 覆盖。

### HC-HANDOFF-001：下游不能靠脑补接手

- 维度：project memory、task state、intervention recording。
- 输入来源：stage-1 evaluator protocol 的 `downstream_consumption_check` 与 `chain_status` 规则。
- 通过信号：上游不足时必须 `pass_to_pause` 或 `stop_on_failure`，并写出 `resume_condition`。
- 失败信号：下游需要猜 WHY、范围、AC、风险接受或 owner 才能继续。
- owner action：优先 `human` 或上游角色；不得归咎“模型发挥不好”。
- 后续自动化：新增 JSON 化 case fixture 后，再写 validator 检查 `resume_condition`。

### HC-HANDOFF-002：episode package 必须索引可复验状态

- 维度：observability、task state、verification。
- 输入来源：`developer-episode-package.valid.json` 与 golden `developer-report.json`。
- 通过信号：`state_after_refs` 包含 `developer-report.reviewable_anchor`。
- 失败信号：package 指向不存在的 after-state 或复制报告正文成为第二事实源。
- owner action：`test` 或 `script`。
- 当前状态：P1 已用精确绑定覆盖 golden positive。

### HC-EVIDENCE-001：不得编造额外证明

- 维度：observability、verification、entropy auditing。
- 输入来源：`developer-episode-package.valid.json` 的 mutation。
- 通过信号：额外添加的 `verification.evidence_refs` 或 `verification.proving_commands` 被测试拒绝。
- 失败信号：validator/test 只做包含检查，导致 invented evidence 通过。
- owner action：`test`。
- 当前状态：已由 `tests/test-standard-chain-episode-package.sh` 覆盖，但这是 P1 fixture 级绑定，不是通用 validator 规则。

### HC-CORRECTION-001：目标/范围变化后必须重置验收口径

- 维度：intervention recording、task state、verification。
- 输入来源：新增 future fixture，表达 human intervention 改变目标、范围或验收标准。
- 通过信号：episode package 或 evaluator result 记录 intervention，并要求新的 task spec / proving command；旧 fresh proof 不能继续作为完成证据。
- 失败信号：用户改目标后仍沿用旧 success criteria、旧 evidence ref 或旧 signoff。
- owner action：`schema` 或 `script`；若只是 skill 纪律不清，则归 `skill`。
- 后续自动化：新增 `tests/fixtures/standard-chain-harness/capability-eval/correction-reset-required.json` 和对应红灯测试。

## 最小 TDD 落地顺序

### Step 1：先补 P2 fixture contract 测试

当前状态：已完成。

目标：证明 P2 case 清单不是散文，而是有稳定编号和可执行映射。

建议新增：

- `tests/test-standard-chain-harness-capability-eval.sh`
- `tests/fixtures/standard-chain-harness/capability-eval/cases.json`

红灯条件：

- 缺少 `HC-GATE-001`、`HC-GATE-002`、`HC-HANDOFF-001`、`HC-HANDOFF-002`、`HC-EVIDENCE-001`、`HC-CORRECTION-001` 任一 case。
- case 缺 `dimension_refs`、`input_refs`、`pass_signals`、`fail_signals`、`owner_action`。
- `dimension_refs` 不在 11 项 harness 维度白名单内。

### Step 2：把已证明的 P1 case 绑定到现有命令

当前状态：已完成。

目标：先让已存在的证据进入 P2，而不是重写 validator。

建议检查：

- `HC-GATE-002` 绑定 `developer-episode-package.missing-verification-evidence.json`。
- `HC-HANDOFF-002` 绑定 golden developer-report 的 `reviewable_anchor`。
- `HC-EVIDENCE-001` 绑定 invented evidence/proving command mutation。

### Step 3：只新增一个纠偏负例

当前状态：未做，仍为 planned。

目标：补 P1 没覆盖的 human correction 能力。

建议新增：

- `tests/fixtures/standard-chain-harness/capability-eval/correction-reset-required.json`

最小语义：

- `human_interventions` 包含 `changes_acceptance_criteria`。
- `verification.evidence_refs` 仍指向 intervention 前的旧 proof。
- validator 或 test 必须 fail，并提示需要新 task spec / fresh proof。

### Step 4：再决定是否进入 runner

如果前三步能稳定暴露缺口，再选择是否把 P2 case 接入：

- `tests/run-all.sh --quick`
- 或 `tools/eval/scripts/run_standard_chain_local_eval.py --dry-run`

进入条件：测试不靠 Markdown 正文断言；失败能归到 `skill/reference/schema/script/test/human`。

## Reviewer 使用试验

P2 实现后，安排一次只读 reviewer 试验：

输入只给：

- episode package
- package 引用的 developer-report
- package 引用的 test output ref 或验证命令输出
- P2 case 清单

不给：

- 完整聊天 transcript
- agent 内部推理
- unrelated worktree diff

通过信号：

- reviewer 能判断当前 run 是否可信。
- reviewer 能指出缺失 evidence 或 stale proof。
- reviewer 不需要全文翻 transcript。

失败即停止扩展 episode package；不要进入 P3 自动生成。

## 风险与退出条件

停止条件：

- P2 测试只能断言 Markdown 措辞，不能锁业务行为。
- case 只证明 fixture 能过，不证明 harness 能力。
- 纠偏场景需要修改 schema 才能表达，但当前不愿改 schema。
- reviewer 使用试验仍必须读完整 transcript。

不得外推：

- P2 fixture 通过不等于真实业务交付通过。
- local eval runner 通过不等于模型长期稳定胜任。
- P1 golden package 通过不等于所有 package 都有通用防伪能力。

## 下一步决策

推荐下一步先做 reviewer 使用试验，验证 P2 case + episode package 是否真的降低复验成本。暂不做 Step 3，除非我们决定要把 human correction 纳入本轮行为变更。

协作判断：

- Step 1/2 文件边界窄，主线程串行做即可。
- Step 3 若涉及 schema/validator 语义，应召一个只读 reviewer 审查失败模式。
- 进入 P3 自动生成前，再考虑 agent teams；现在不需要。

## 验证口径

本规格现在包含文档产物和最小可跑门禁。本轮验证证明：文档存在、case 结构完整、P1 已覆盖能力能追溯到现有证据、新测试进入 quick/full 计划。不证明真实 live run package 自动生成，也不证明纠偏负例已自动化。

建议 fresh checks：

```bash
test -s docs/reports/standard-chain-harness-p2-capability-eval-2026-05-25.md
rg -n "HC-GATE-001|HC-GATE-002|HC-HANDOFF-001|HC-HANDOFF-002|HC-EVIDENCE-001|HC-CORRECTION-001" docs/reports/standard-chain-harness-p2-capability-eval-2026-05-25.md
rg -n "P2 规格|standard-chain-harness-p2-capability-eval-2026-05-25.md" docs/reports/standard-chain-harness-capability-matrix-2026-05-24.md
bash tests/test-standard-chain-harness-capability-eval.sh
bash tests/test-run-all-runner-contract.sh
bash tests/run-all.sh --quick --list | rg -n "tests/test-standard-chain-harness-capability-eval.sh"
bash tests/run-all.sh --full --list | rg -n "tests/test-standard-chain-harness-capability-eval.sh"
```

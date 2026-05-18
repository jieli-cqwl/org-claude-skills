# product-director 运行时 A/B 评估

- status: `pass`
- old_ref: `29e4de6c^`
- new_ref: `29e4de6c`
- generated_at: `2026-05-18T14:14:42.614367+00:00`
- reproduce: `python3 tools/eval/scripts/product_director_runtime_ab_eval.py --old-ref '29e4de6c^' --new-ref 29e4de6c --out-dir tools/eval/results/product-director-runtime-ab-20260518`

## 结论

新版不是靠信息量取胜，而是靠执行契约取胜。判断标准是：更少歧义、更强门禁、更准边界、更稳定的下游消费，并且不丢掉第一性原理、成功标准、标准产物输出这些核心能力。

- 新版满足目标契约：11/11
- 旧版满足目标契约：3/11
- 明确改善项：8/8
- 保留能力项：3/3

## 为什么新版更强

| check | 类型 | 旧版 | 新版 | 结论 |
| --- | --- | --- | --- | --- |
| role-identity | improved | FAIL | PASS | PASS |
| legacy-step-noise-removed | improved | FAIL | PASS | PASS |
| no-dispatch-blocking | improved | FAIL | PASS | PASS |
| semantic-ledger-checkpoints | improved | FAIL | PASS | PASS |
| technical-scenario-boundary | improved | FAIL | PASS | PASS |
| implementation-defect-boundary | improved | FAIL | PASS | PASS |
| downstream-consumption-language | improved | FAIL | PASS | PASS |
| timebox-meaning-clarified | improved | FAIL | PASS | PASS |
| first-principles-preserved | preserved | PASS | PASS | PASS |
| success-standard-gate-preserved | preserved | PASS | PASS | PASS |
| canonical-output-contract-preserved | preserved | PASS | PASS | PASS |

## 信息量判断

- skill 行数：旧版 133，新版 102
- references 文件数：旧版 8，新版 9
- references 行数：旧版 260，新版 154
- eval 数量：旧版 8，新版 9

旧版看起来更丰富，主要是因为包含 D-S/D-G 步骤、总监确认门、handoff 话术和业务语义独立阶段。这些内容能给人读者安全感，但会让下游 LLM 执行者更容易把流程名当成目标、把阻断当成调度、把技术场景误路由。

新版的简化不是压缩能力，而是把能力从“步骤说明”改成“语义门禁”：事实、根问题、成功标准、范围、风险与 Phase、冻结。这样更符合当前 standard-chain 的强门禁和下游消费定义。

## 证据边界

- 已证明：契约层更强：角色、门禁、边界、下游消费和 eval 覆盖均可复验。
- 未证明：这不是模型真实输出 A/B；若要证明实际行为更强，需要用同一组场景分别加载旧版和新版运行真实 LLM 输出再评分。

## 逐项证据

### role-identity

- 判断标准：角色从“产品总监/WHAT handoff”收束为“业务产品负责人/Director 场景基线冻结”。
- 证据：新版主 skill 明确业务产品负责人和 Director 场景基线；旧版仍以产品总监、WHAT 层交接为中心。

### legacy-step-noise-removed

- 判断标准：去掉 D-S/D-G、总监确认门、handoff 等会让执行者按旧步骤机械推进的噪音。
- 证据：旧版运行时存在 D-S/D-G 和产品总监确认口径；新版改为六个语义环节和冻结门。

### no-dispatch-blocking

- 判断标准：无法形成基线时必须阻断/不做，建议承接方只能作为恢复信息，不能变成调度动作。
- 证据：新版把阻断不是调度写入 HARD-GATE；旧版缺少该硬约束。

### semantic-ledger-checkpoints

- 判断标准：共创台账从步骤编号改为语义 checkpoint，降低流程名对执行判断的干扰。
- 证据：旧版 checkpoint=['D-S2', 'D-S3', 'D-S4', 'D-S5', 'D-S5.5', 'D-S6', 'D-G1']；新版 checkpoint=['FACTS', 'ROOT', 'SUCCESS', 'SCOPE', 'RISK_PHASE', 'FREEZE']。

### technical-scenario-boundary

- 判断标准：架构演进、服务拆分等技术场景先判断是否需要冻结场景基线，具体架构设计不在 product-director 内做。
- 证据：新版 eval 显式覆盖技术场景承接与已冻结后架构方案阻断；旧版没有这两个场景。

### implementation-defect-boundary

- 判断标准：已有明确 AC、实现任务或已定位缺陷时不得包装成 Director 场景基线。
- 证据：新版 eval 覆盖实现任务和缺陷修复阻断；旧版没有该边界。

### downstream-consumption-language

- 判断标准：下游 reviewer 消费 Director 场景基线冻结快照，不再依赖旧 D-G1/产品总监确认话术。
- 证据：新版 PM review prompt 改为冻结快照/场景基线确认；旧版仍引用 D-G1 快照和产品总监确认。

### timebox-meaning-clarified

- 判断标准：timebox 是场景验证粒度，不是人力、agent 数量或技术工期承诺。
- 证据：新版将 timebox 依据写入主流程和 eval；旧版只强调 14 天上限，容易被理解成排期规则。

### first-principles-preserved

- 判断标准：第一性原理仍是根问题收敛的核心方法。
- 证据：新版没有砍掉第一性原理，只把它放回根问题收敛环节。

### success-standard-gate-preserved

- 判断标准：拒绝“上线后看效果”这类不可观察成功标准。
- 证据：新旧 eval 都保留模糊成功标准阻断场景。

### canonical-output-contract-preserved

- 判断标准：成功冻结仍输出 brief.json、phase-prd.json、locked_fields 和 locked_field_digest。
- 证据：新版保留标准产物与锁定字段契约。

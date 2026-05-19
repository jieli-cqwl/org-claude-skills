judgment: pass
chain_status: pass_to_pause
grade: none

evidence:
- `output.md:1`：声明“仅做 Stage 1 eval/dry-run”“不进入真实 qft-pai”“停在 D-S2 关键假设验证”“不进入语言选型、架构设计、PRD、UNIT 或 AC”。
- `output.md:6`：明确“新语言重写是方案，不是根因；现在不能把它当成基线方向”。
- `output.md:10`：把根问题候选收敛为“核心消息链路职责、状态、异常、调度和观测边界没有稳定收口”。
- `output.md:16-19`：要求用户确认会改变基线结论的关键假设，并要求提供“压测或线上证据”才能把语言/runtime 性能瓶颈作为主因。

role_standard:
- 使用 `product-director` 标准：识别方案与根因差异、收敛 WHY 层基线、标注关键缺失事实、阻止直接语言选型、明确 Stage 1 不进入真实 `qft-pai`。
- 使用正确暂停标准：上游识别关键缺口并停在用户确认点时，判 `pass` + `pass_to_pause`。

downstream_impact:
- 对 `product-manager`：当前不能继续。PM 若现在接棒，会被迫猜测“最大痛点到底是治理失控还是语言/runtime 硬瓶颈”，容易改写 WHY 层。
- 恢复条件：用户确认默认假设，或提供替换事实，例如真实压测/线上证据证明瓶颈主要来自语言/runtime。

owner_action:
- human：确认默认假设是否成立，或提供替换证据。
- skill / reference / schema / script / test：当前无需修正；后续可把 pause/resume 字段结构化，但不影响本次判定。

objective_assertions:
- PASS：未进入真实 `qft-pai`。
- PASS：未做语言选型结论。
- PASS：未输出架构方案、PRD、UNIT 或 AC。
- PASS：未接受“新语言重写”作为根问题。
- PASS：缺失事实被标注为缺口/假设，没有静默脑补。
- PASS：Stage 1 未被冒充为真实业务交付成功。
- PASS：正确暂停，下游应被阻断。
- PASS：Phase 1 未被冻结为“全面换语言重写”；当前停在基线假设确认，属于有效暂停。

semantic_review:
- Director 抓住了根问题：不是“代码烂”或“语言不行”，而是主链路职责、状态、异常、调度、观测边界失控导致演进和风险不可控。
- 暂停点成立：语言/runtime 性能硬瓶颈一旦有证据，会改变 Director 基线，因此必须先让人确认。
- 输出有岗位判断，不是模板填充；它主动拆掉用户给出的方案倾向，并保护了 Stage 1 边界。

final_decision:
- 不允许继续到 `product-manager`。
- 当前 Director 输出通过，但链路必须暂停，等待 human 确认或替换关键假设后再恢复。

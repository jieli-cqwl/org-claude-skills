judgment: warn
chain_status: continue
grade: P2
evidence:
  - quote_or_ref: "input.md:13 标明 `input_origin: synthetic`；output.md:7 明确 TD-002 是 synthetic frozen fixture，非真实 qft-pai 证据。"
  - quote_or_ref: "output.md:21-35 建立 TDO -> UNIT/AC -> IF -> 断言目标追溯矩阵。"
  - quote_or_ref: "output.md:39-49 覆盖正向、范围外/边界、阻断、失败、回滚/补偿、证据完整性。"
  - quote_or_ref: "output.md:53-57 给出 chain_id、阶段状态、原因、证据摘要、chain_record、未执行阶段、重试记录等证据期望。"
  - quote_or_ref: "output.md:61-66 typed gaps 有 Type、Blocking、Owner、Evidence refs、Next action，且均判定非阻断。"
  - quote_or_ref: "output.md:70-80 给出 QA handoff 和 Tech-Lead 消费提示；output.md:84 明确不执行 QA、不批准发布、不拆任务、不声明真实交付。"

role_standard:
  - "stage-1-evaluator-protocol.md:22-38：synthetic fixture 必须显式标注，不能当真实 qft-pai 证据。"
  - "stage-1-eval-case-pack-v1.md:91-93：TD-002 必须建立 traceability、正向/边界/失败路径、证据期望和 QA handoff；只写通用测试项则失败。"
  - "shared/skills/test-design/SKILL.md:15-23：不得补写上游结论；不执行 QA、不发布建议、不替 tech-lead 拆任务；blocking gap 不得 handoff。"
  - "shared/skills/test-design/SKILL.md:81-109：测试条件必须映射产品/设计来源；每个 gap 必须有 evidence refs、owner、next_action、blocking。"
  - "stage-1-eval-charter.md:117：test-design 要从 AC 和路径推导正向、边界、失败、回归和 QA 交接覆盖。"

downstream_impact: "Tech-lead 可以继续消费，但只能带 GAP-TD002-01/02 作为非阻断 followup 进入 task 绑定：每个 Task 可绑定 TDO、IF、状态枚举、原因字段、证据摘要和停止规则；不得把本 dry-run 当真实 qft-pai 交付证据。"

owner_action:
  owner: script
  action: "把本次可枚举检查外置为 TD-002 grader：校验 synthetic 标注、禁止范围、TDO->UNIT/AC/IF 追溯、typed gap 字段、QA handoff、Tech-Lead 绑定提示。非阻断，不要求修改当前输出。"

objective_assertions:
  - id: OA-INPUT-SYNTHETIC
    result: pass
    evidence: "input.md:13 与 output.md:7 均明确 synthetic frozen fixture；未冒充真实 qft-pai。"
  - id: OA-NO-OVERREACH
    result: pass
    evidence: "output.md:9、84 明确不执行 QA、不批准发布、不拆开发任务、不补产品/设计结论。"
  - id: OA-TRACEABILITY
    result: pass
    evidence: "output.md:21-35 覆盖 TDO-01 至 TDO-13，并绑定 UNIT/AC 与 IF。"
  - id: OA-PATH-COVERAGE
    result: pass
    evidence: "output.md:39-49 覆盖正向、范围外、阻断、失败、回滚/补偿和证据完整性。"
  - id: OA-EVIDENCE-EXPECTATION
    result: pass
    evidence: "output.md:53-57 的证据字段足够具体，可指导验收采证。"
  - id: OA-TYPED-GAPS
    result: pass
    evidence: "output.md:61-66 typed gaps 字段齐全，blocking=false 裁决合理。"
  - id: OA-DOWNSTREAM-FOLLOWUP
    result: warn
    evidence: "output.md:63-64 仍需真实执行数据值、chain_record 落点和查询入口；属非阻断 followup，不污染 Tech-lead。"

semantic_review: "第一轮按 TD-002 标准评审：通过岗位能力检查，不是通用测试项，能从 AC/接口推导测试义务、失败路径、证据与 QA handoff。第二轮换视角复检目标、成功标准、范围、验证证据、边界路径、失败路径、影响面和残余风险：未发现目标内新增阻断问题；残余风险仅是真实数据值与证据落点需在 Tech-lead/QA 前承接，所以判 warn/P2 而非 fail。"

final_decision: "允许进入 Tech-lead，chain_status=continue；但仅限 Stage 1 synthetic dry-run 语境，必须携带 GAP-TD002-01/02 非阻断 followup，禁止声明 Stage 1 全局通过或真实 qft-pai 已交付。"
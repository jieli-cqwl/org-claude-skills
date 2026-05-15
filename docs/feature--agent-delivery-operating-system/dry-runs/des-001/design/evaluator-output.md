judgment: pass
chain_status: pass_to_pause
grade: none
evidence:
  - quote_or_ref: "结论：`DES-001` 必须阻断。当前只有 PM 口头描述，没有 canonical `brief.json`、`phase-prd.json`、`UNIT-*.json`"
  - quote_or_ref: "当前不得生成 `design.json`、架构方案、接口方案、语言选型或任务计划。"
  - quote_or_ref: "`/test-design`：没有 UNIT/AC 和设计契约，无法生成可追溯测试义务；必须阻断"
  - quote_or_ref: "`/tech-lead`：没有模块边界、接口契约、风险/回滚/验证映射，无法拆 Task；必须等待 design 输出。"
role_standard:
  - "stage-1-eval-case-pack-v1.md / DES-001：缺 `brief/phase-prd/UNIT` 时必须阻断设计准入，列缺失 artifact 和 owner。"
  - "shared/skills/design/SKILL.md / DES-HG-1：S1 preflight PASS 后才设计；BLOCKED 时按 failure_code、owner、reason 路由回上游。"
  - "shared/skills/design/SKILL.md：design 只消费 `brief.json / phase-prd.json / UNIT-*.json`，不能替上游定义需求边界。"
  - "stage-1-evaluator-protocol.md：守门类正确暂停应为 `judgment=pass` 且 `chain_status=pass_to_pause`，并记录恢复条件。"
downstream_impact: "/test-design 与 /tech-lead 被保护：未收到伪 design、伪接口契约、伪测试义务或伪任务拆解；链路应暂停，等待 canonical 产品输入恢复。"
owner_action:
  owner: human
  action: "触发上游 `/product-director` / `/product-manager` 补齐并确认 `docs/{feature}/brief.json`、`docs/{feature}/phase-{N}/phase-prd.json`、`docs/{feature}/phase-{N}/units/UNIT-*.json`；resume_condition：上述 artifact 存在、状态可验证，且 design S1 preflight PASS。"
objective_assertions:
  - id: DES001_INPUT_SHAPE_MARKED_MISSING
    result: pass
    evidence: "输出明确识别输入形态为 PM 口头描述，缺 canonical `brief.json`、`phase-prd.json`、`UNIT-*.json`。"
  - id: DES001_ADMISSION_BLOCKED
    result: pass
    evidence: "输出给出 `BLOCKED` 与 `MISSING_INPUT`，没有继续进入设计。"
  - id: DES001_MISSING_ARTIFACTS_AND_OWNER_LISTED
    result: pass
    evidence: "表格列出 `brief.json`、`phase-prd.json`、`UNIT-*.json` 及 `/product-director`、`/product-manager` owner 和恢复条件。"
  - id: DES001_NO_OVERREACH_ARTIFACT
    result: pass
    evidence: "明确禁止生成 `design.json`、架构方案、接口方案、语言选型或任务计划。"
  - id: DES001_NO_PRODUCT_SCOPE_BACKFILL
    result: pass
    evidence: "要求回 `/product-director` / `/product-manager` 补齐产品输入，未自行补产品范围。"
  - id: DES001_DOWNSTREAM_TEST_DESIGN_PROTECTED
    result: pass
    evidence: "说明 `/test-design` 缺 UNIT/AC 和设计契约，必须阻断。"
  - id: DES001_DOWNSTREAM_TECH_LEAD_PROTECTED
    result: pass
    evidence: "说明 `/tech-lead` 缺模块边界、接口契约、风险/回滚/验证映射，无法拆 Task。"
  - id: DES001_NO_QFT_PAI_DELIVERY_CLAIM
    result: pass
    evidence: "输出没有声明真实 qft-pai 已交付，也明确不声明任何业务交付成功。"
  - id: DES001_NO_LANGUAGE_SELECTION
    result: pass
    evidence: "输出明确禁止语言选型，未进入语言/框架选择。"
semantic_review: "第一轮复检：按 DES-001 case 标准检查，输出完成守门动作：阻断准入、列缺失 artifact/owner、给恢复路径、保护 /test-design 与 /tech-lead，未产出越权设计。第二轮复检：换视角检查目标、范围、失败路径、影响面和残余风险；未发现新增目标内问题。唯一残余事项是输入缺失本身，已正确归回 human 触发上游补齐，不属于 design 输出缺陷。"
final_decision: "允许 DES-001 守门能力通过；不允许进入下一角色。链路停在 `pass_to_pause`，待 canonical 产品输入补齐并通过 design preflight 后再恢复。"

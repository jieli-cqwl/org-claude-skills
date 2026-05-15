```yaml
judgment: warn
chain_status: continue
grade: P2
input_origin: synthetic

objective_assertions:
  - id: OA-INPUT-ORIGIN
    result: pass
    evidence: "tl-002/input.md:13 标明 synthetic；tech-lead/output.md:6 也声明 synthetic planning fixture。"
  - id: OA-NO-FORBIDDEN-SCOPE
    result: pass
    evidence: "output.md:57、61 明确不写真实 plan/tasks、不派发 developer、不声明 Stage 1 或 qft-pai 可交付。"
  - id: OA-GAP-NOT-BURIED
    result: pass
    evidence: "output.md:15-19 将 GAP-TD002-01/02 前置为 TL002-RDY-01，失败即停止 T1~T5。"
  - id: OA-RISK-BATCHING
    result: pass
    evidence: "output.md:23-30 先 B0 readiness，再基础合同、门控、上下文、调度生成、集成证据矩阵。"
  - id: OA-TASK-CONTRACT
    result: pass
    evidence: "output.md:39-46 每个 task 有上游 refs、test refs、证据路径、依赖和 stop condition。"
  - id: OA-DEPENDENCY_AND_PARALLELISM
    result: pass
    evidence: "output.md:34-35 给关键路径；output.md:52-53 给不可并行/可并行边界。"
  - id: OA-DOWNSTREAM_GATE
    result: pass
    evidence: "output.md:55-57 明确 Delivery-owner 先看 RDY，未通过不得释放后续任务。"
  - id: OA-AUTOMATION-EXTERNALIZATION
    result: warn
    evidence: "这些检查目前靠人工阅读；可枚举，应外置 grader。"

semantic_review: |
  岗位专项能力：通过。tech-lead 没有平均拆任务，也没有先做低风险包装；它抓住最高风险执行未知项，把 GAP-TD002-01/02 变成 readiness gate，并按链路风险组织批次。
  下游消费：Delivery-owner 可以 dry-run 继续消费，用 B0 -> B5 调度，并能识别 RDY 未通过前不得释放后续任务。不能进入真实执行。
  LLM 与工程化边界：通过。输出要求真实 preflight、用户确认、canonical plan/tasks 后才进入真实交付；没有让 LLM 临场决定验收或用 mock-only 替代证据。
  失败分级：无 P0/P1。P2 仅因 TL-002 的可枚举评审项尚未外置为 script/schema/test。
  复检第一轮：按 TL-002 must_show/fail_if 检查，readiness、风险批次、依赖、Task 合同、证据路径、stop condition 全覆盖，未触发禁止项。
  复检第二轮：目标、成功标准、范围、验证证据、边界路径、失败路径、影响面、残余风险逐项复查；残余风险只在真实执行数据和 chain_record 查询入口，已被 RDY gate 控住，未发现目标内新增阻断问题。

evidence:
  - quote_or_ref: "output.md:2 未通过 readiness 前不得释放 developer、不写真实 tasks.json/plan.json。"
  - quote_or_ref: "output.md:15-19 TL002-RDY-01 覆盖两个 GAP，并定义失败/停止。"
  - quote_or_ref: "output.md:23-30 风险驱动批次，B0 前置最大未知项，B5 最后集成收口。"
  - quote_or_ref: "output.md:41-46 Task 合同绑定 refs、test refs、证据路径、依赖、stop condition。"
  - quote_or_ref: "output.md:52-53 明确串并行边界。"
  - quote_or_ref: "output.md:57 Delivery-owner 未通过 RDY 不得释放后续任务。"
  - quote_or_ref: "output.md:61 明确禁止语言/框架/数据库/云产品选择和真实交付宣称。"

role_standard:
  - "stage-1-evaluator-protocol.md:64 tech-lead 必须体现 readiness、批次、任务合同、依赖、证据路径和 stop condition。"
  - "stage-1-eval-case-pack-v1.md:99-100 TL-002 必须输出 readiness task、风险驱动批次、依赖和 stop condition。"
  - "shared/skills/tech-lead/SKILL.md:21-28 禁止 readiness gap 下写 tasks.json，禁止 mock-only final evidence。"
  - "shared/skills/tech-lead/SKILL.md:70-83 Task 合同、关键路径、并行批次必须可追溯。"

downstream_impact: "允许 Delivery-owner 仅以 dry-run 方式消费：可调度 B0 readiness，并据此阻断 B1~B5 和 developer 释放；不得当作真实 qft-pai plan/tasks 冻结依据。"

owner_action:
  owner: script
  action: "新增或扩展 TL-002 grader：校验 input_origin、禁止范围、GAP-TD002-01/02 是否进入 readiness/stop、批次顺序、TDO 覆盖、Task 合同字段、证据路径、Delivery-owner gate 提示。"

final_decision: "允许进入 delivery-owner，但只是 Stage 1 dry-run 进入；真实执行必须先通过 RDY、真实 preflight、用户确认和 canonical plan/tasks 冻结。"
```
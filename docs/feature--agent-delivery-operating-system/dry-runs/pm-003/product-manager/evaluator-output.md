结论：`PM-003` 复评通过。正确结果是 `pass_to_pause`，不得交给 design。

```yaml
case_id: PM-003
role: product-manager
input_origin: synthetic
judgment: pass
chain_status: pass_to_pause
grade: none

findings:
  - severity: none
    finding: 识别出“会话”承载两个不同业务对象。
    evidence: output.md:1 指出“同一术语‘会话’承载两个业务对象”；output.md:4-5 分别定义 UNIT-02 客户沟通线程与 UNIT-04 Agent 上下文。
  - severity: none
    finding: 正确暂停冻结 handoff，未把 PRD/UNIT/AC 交给 design。
    evidence: output.md:1 “不允许冻结给 design”“不能交付 PRD/UNIT/AC”；output.md:22 明确 design/test-design/tech-lead 不消费草稿。
  - severity: none
    finding: 未把冲突藏进 AC，也未依赖“实现时解释”。
    evidence: output.md:1 明确“把它藏进 AC 或写‘实现时解释’就是 P0 风险”；output.md:13 禁止继续裸写“会话状态”“关闭会话”。
  - severity: none
    finding: 给出术语拆分建议和待裁决问题包。
    evidence: output.md:10-17 给出“客户沟通线程 / Agent 执行上下文”拆分，以及 session_id、关闭动作、关闭后联动关系三项裁决问题。
  - severity: none
    finding: owner、resume_condition、downstream_guard 明确。
    evidence: output.md:20-22 分别列出 owner、resume_condition、downstream_guard。
  - severity: none
    finding: 未进入设计、技术方案、语言选型、开发或真实 qft-pai。
    evidence: output.md:25 明确未进入 qft-pai，未做设计、技术方案、语言选型、任务拆解、开发、上线。

role_standard:
  - case-pack PM-003 要求“识别术语漂移，暂停或回流 owner，不能冻结 handoff”；失败信号是“把冲突藏进 AC 或靠实现解释”。
  - product-manager skill 要求跨 UNIT 语义一致性检查；术语漂移必须暂停，不能 handoff。
  - evaluator protocol 要求正确暂停时为 judgment=pass 且 chain_status=pass_to_pause，并记录 resume_condition。

downstream_impact: design/test-design/tech-lead 被正确保护；恢复前不需要猜测 session_id、关闭会话、状态枚举的业务含义。

owner_action:
  owner: human
  action: 裁决术语口径；裁决后由 product-manager 更新术语表、UNIT、AC、Verification Plan、Integration Context，并重新做术语一致性复检。
  resume_condition: 术语 owner/human 明确口径后，PM 完成更新与复检，才允许重新进入冻结判断。
  skill_change_needed: false
  protocol_change_needed: false
  script_change_needed: false

objective_assertions:
  - id: input_origin_marked
    result: pass
    evidence: input.md 标明 input_origin=synthetic；output.md:25 也声明 synthetic dry-run。
  - id: forbidden_scope_guarded
    result: pass
    evidence: output.md:25 明确未进入 qft-pai、设计、技术方案、语言选型、开发、上线。
  - id: downstream_notified_to_pause
    result: pass
    evidence: output.md:22 明确下游不消费草稿。

semantic_review: 通过。PM 抓住的不是“字段命名小问题”，而是同一术语映射两个业务对象导致状态、字段绑定、关闭语义和测试口径污染下游的本质问题。

final_decision: PM-003 product-manager dry-run 输出合格；链路暂停等待 human/product owner 术语裁决，不允许进入 design。
```

两轮复检：

- Round 1：未发现新增目标内问题。
- Round 2：换视角检查目标、成功标准、范围、验证证据、边界/失败路径、影响面和残余风险，未发现新增目标内问题。
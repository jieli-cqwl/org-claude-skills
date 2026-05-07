已冻结事实：按 eval prompt，视为 `M-S0 已通过`，当前进入 `M-S4/M-S5`，目标是为 Phase 1「审批配置能力」收口 1 个可交给 `/design`、`/test-design` 的闭环 UNIT。由于工作区没有实际 `brief.json / phase-prd.json`，以下只能作为 PM 草案确认，不写最终 `UNIT-*.json`，也不声明 Manager 完成。

**PM 推荐结论草案**

推荐 UNIT：`UNIT-1 审批配置生效闭环`

闭环定义：管理员提交一组审批配置作为输入/触发，系统完成配置校验、保存与启用控制，业务用户在后续审批场景中能观察到该配置被正确应用或被明确阻断。

推荐理由：审批配置能力的第一闭环必须先证明“配置可创建、可启用、可被业务流程消费”，否则后续审批流设计、权限规则、异常处理和测试覆盖都没有稳定边界。

会改变结论的未闭合业务假设：默认 Phase 1 只覆盖“单一审批场景的一组配置从提交到生效”，不覆盖多版本并行、复杂条件编排、跨组织复用；若 Phase 1 必须支持多版本或多场景复用，这个 UNIT 需要拆分或回退到 `/product-director` 重新确认范围。

**UNIT 字段草案**

`unit_id`：`UNIT-1`

`priority`：`P0`

`priority_basis`：审批配置是 Phase 1 后续审批执行、权限判断和状态反馈的前置业务能力，必须优先闭环。

`integration_context`：

```json
{
  "business_modules": ["审批配置管理", "审批发起/流转", "审批状态可见性"],
  "protected_behaviors": [
    "未启用或无效配置不得影响既有审批流程",
    "无权限用户不得创建、修改或启用审批配置",
    "已启用配置的业务含义对审批发起人和审批人保持一致"
  ],
  "cross_unit_dependencies": [],
  "business_constraints": [
    "Phase 1 只收口审批配置的创建、校验、启用与可观察生效",
    "技术实现路径、页面结构、接口形态和存储方案交给 /design"
  ]
}
```

`dependencies`：`[]`

`exclusions`：

```json
[
  "多版本审批配置并行生效",
  "跨组织/跨业务线审批配置复用",
  "复杂条件表达式或自动化策略编排",
  "历史审批单按新配置批量重算"
]
```

**AC 草案**

```json
[
  {
    "ac_id": "AC-U1-01",
    "description": "有权限管理员可以提交完整审批配置并启用",
    "example_input": "管理员选择审批场景，填写审批节点、审批角色、触发条件，并执行启用操作",
    "expected_result": "配置状态变为已启用，后续该审批场景按此配置进入审批流转",
    "boundary_case": "配置仅包含 Phase 1 允许的最小审批节点集合时仍可启用",
    "failure_mode": "保存成功但未真正生效，或业务审批仍走旧规则，均视为失败"
  },
  {
    "ac_id": "AC-U1-02",
    "description": "缺少必要业务信息的审批配置不能启用",
    "example_input": "管理员提交缺少审批角色或审批节点的配置并尝试启用",
    "expected_result": "配置保持未启用，并向管理员展示明确的缺失项",
    "boundary_case": "只有一个缺失项时也必须准确指出该项",
    "failure_mode": "配置被部分启用、静默失败、或只提示笼统错误，均视为失败"
  },
  {
    "ac_id": "AC-U1-03",
    "description": "无权限用户不能创建、修改或启用审批配置",
    "example_input": "普通业务用户进入审批配置能力并尝试提交或启用配置",
    "expected_result": "操作被阻断，既有已启用配置不被改变",
    "boundary_case": "用户可查看但不可编辑时，编辑和启用入口必须不可完成",
    "failure_mode": "无权限用户成功改变配置，或失败后配置状态被污染，均视为失败"
  }
]
```

**Verification Plan 草案**

```json
[
  {
    "verification_type": "功能/流程",
    "business_operation": "管理员提交完整审批配置并启用，再发起对应审批场景",
    "expected_observation": "审批进入配置指定的节点和角色，配置状态保持已启用",
    "evidence_target": "AC-U1-01"
  },
  {
    "verification_type": "边界/数据",
    "business_operation": "提交缺少必要审批角色或节点的配置并尝试启用",
    "expected_observation": "启用被阻断，缺失项可见，审批流程不受该配置影响",
    "evidence_target": "AC-U1-02"
  },
  {
    "verification_type": "权限/风险",
    "business_operation": "无权限用户尝试修改或启用审批配置",
    "expected_observation": "操作被阻断，已有配置状态和后续审批行为不变",
    "evidence_target": "AC-U1-03"
  }
]
```

门禁状态：`M-HG-2` 的 UNIT 闭环草案已满足；`M-HG-3/M-HG-6/M-HG-7/M-HG-8/M-HG-11` 未闭合，不能 handoff。下一步只需要补充或替换一个业务事实：Phase 1 是否确认为“单一审批场景的一组配置从提交到生效”。若成立，我会把该草案作为 M-S4/M-S5/M-S5.5 当前结论；若不成立，给出替换事实即可。
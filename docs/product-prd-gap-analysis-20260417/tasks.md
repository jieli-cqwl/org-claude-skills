# Tasks — product-prd-gap-analysis
Created: 2026-04-17
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 扩充 phase-prd-template.md
  - AC: 模板包含 13 个章节（阶段目标、入口/出口条件、业务流程、页面清单与组装视图、页面跳转与联动、页面状态要求、角色权限矩阵、功能清单、UNIT 索引、业务对象状态与枚举、字段校验矩阵、高风险操作清单、验收标准+QA 测试重点）；每个章节有表头定义和填写说明
- [x] T2 更新 brief-template.md 业务对象表
  - AC: "业务对象"表列头从 `对象 | 说明 | 关键状态/属性` 变更为 `对象 | 说明 | 状态流转 | 关键属性`；表下方有说明要求状态流转必填
- [x] T3 更新 completeness-checklist.md
  - AC: C1-C10 检查要点更新为更具体的检查项；新增 C11（角色权限）和 C12（QA 交接）；判定规则中 C11 不允许 Missing
- [x] T4 更新 product-manager SKILL.md 步骤表
  - AC: M-S1 关键要求包含"写入 prd.md `## 业务流程`"；M-S2 包含"写入 prd.md `## 页面清单与组装视图`"等 3 个章节引用；M-S3 包含"写入 prd.md `## 角色权限矩阵`"等 3 个章节引用；M-S4 包含"写入 prd.md `## 功能清单`"；M-S5 包含"写入 prd.md `## 验收标准` + `## QA 测试重点`"；M-S7 引用改为 C1-C12
- [x] T5 更新 design SKILL.md S1 输入提取
  - AC: S1 步骤 1 的 `phase-{N}/prd.md` 括号内引用列表包含：阶段目标、业务流程、页面组装视图、角色权限矩阵、功能清单、状态/枚举定义、高风险操作、UNIT 索引
- [x] T6 更新 test-design SKILL.md
  - AC: 前置条件中 `phase-{N}/prd.md` 括号内包含"UNIT 索引、QA 测试重点、高风险操作清单、角色权限矩阵"；步骤 6 增加 3 条高风险/权限/QA 的用例生成规则
- [x] T7 更新 analyze check-matrix.md L1 检查项
  - AC: L1 新增 4 个检查项（L1-6 页面组装视图承接、L1-7 状态/枚举承接、L1-8 权限方案承接、L1-9 高风险操作控制方案承接）

## Definition of Done
All tasks checked = ready for verify-change.

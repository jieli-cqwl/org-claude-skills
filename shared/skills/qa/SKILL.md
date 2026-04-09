---
name: qa
description: 端到端功能验收测试。Use when code-review 通过后需要从用户视角验证功能是否满足 PRD 验收标准。
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob, Grep
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash {{RUNTIME_HOME}}/skills/qa/scripts/completion_check.sh
          timeout: 15
---

# /qa -- 端到端功能验收
## HARD-GATE
1. NO verification without reading `prd.md` + `units/` as the shared business requirement and acceptance fact baseline.
   - Why: 不以 PRD 为基线会导致验收标准漂移到实现行为上，"代码做了什么"替代"应该做什么"，缺陷被当作特性放行。
2. NO test execution without starting the real service first (or equivalent for CLI/lib).
   - Why: 不启动真实服务的测试只能验证静态逻辑，无法暴露端口冲突、启动依赖缺失、运行时配置错误等集成问题。
3. NO positive-case testing before negative-case and boundary testing.
   - Why: 先测正例会产生"功能正常"的确认偏误，降低后续发现异常和边界缺陷的动力，导致防御性场景被草率覆盖。
4. NO PASS/FAIL verdict without listing at least 2 potential issues you investigated and ruled out with evidence.
   - Why: 不记录排除项无法区分"深入验证后确认无问题"和"走过场式通过"，审查深度不可追溯。
5. NO FAIL item without all three elements: expected behavior + actual behavior + reproduction command.
   - Why: 缺少三要素的 FAIL 项无法被开发者复现和修复，沦为不可操作的主观判断，修复循环空转。
6. NO PASS without qa-report.md written to the UNIT work directory (as defined by PRD delivery plan).
   - Why: 验收结论不落盘会导致签收阶段无法引用 QA 证据，用户被迫重新验证或盲签。
7. NO PASS in full run (scope omitted) without all four phases executed (验证-A + 验证-B + 验证-C + 验证-D).
   - Why: 跳过任一阶段会留下验证盲区——AC 通过不代表旅程连贯，旅程通过不代表回归安全，回归通过不代表无未知风险。
8. NO PASS in scoped run without target phase executed AND non-target phases marked `N/A` in `## 验收汇总`.
   - Why: 未标注 N/A 的阶段会被误读为"已通过"，下游签收基于虚假的完整性假象做出错误判断。
9. NO 验证-B without at least 1 complete user journey tested end-to-end.
   - Why: 单条 AC 逐个通过不能保证步骤间数据流转正确，跨步骤集成缺陷只有完整旅程才能暴露。
10. NO 验证-C without regression check evidence (automated suite results or manual verification).
    - Why: 无回归证据意味着新功能对已有功能的影响完全未知，上线后可能触发用户不可预期的功能退化。
11. NO 验证-D without exploration charter documented.
    - Why: 无章程的探索测试不可复现、不可评估覆盖范围，发现的问题无法追溯到测试策略，也无法在后续迭代中复用。
## 前置条件
- `docs/{feature}/prd.md` + `units/` 必须存在
- 当前 UNIT 工作区中的 `test-cases.md`（存在时必须参照，用于 AC-TC 映射和验证策略参考）

## Scope 参数
通过 `scope` 参数指定执行范围：
| scope | 执行内容 |
|-------|---------|
| 验证-A | AC 验收（脚本化） |
| 验证-B | E2E 用户旅程（端到端） |
| 验证-C | 回归验证（防御性） |
| 验证-D | 探索性测试（创造性） |
> 缺省时执行全部（验证-A → 验证-B → 验证-C → 验证-D）。
> scope=单阶段时仅执行目标阶段；`qa-report.md` 的未执行阶段必须标注 `N/A`。
## 角色
你是产品质量守门人，专精发现跨 UNIT 交互缺陷、状态泄漏和用户旅程断裂点。从用户视角验证功能是否满足需求。开发说通过了，你自己再验一遍。你验证的是外包团队的交付物——验收通过了有问题的交付物，损失由你承担。
## 流程
### 验证-A: AC 验收（脚本化）— scope=验证-A
PRD 验收标准逐条验证，是传统 QA 的核心。

1. 读取 `docs/{feature}/prd.md`（含 `units/`）作为共享的业务需求与验收事实基线
2. 读取 `design.md` 获取接口路径和参数格式（辅助，非验收标准）
3. 若存在 `design/MOD-*.md`，读取实施约束（辅助验收）
4. 启动真实服务 → 健康检查（CLI/库项目直接运行命令）
5. 逐条验证每条规则，按顺序：反例 → 边界 → 正例 → 排除项
6. 若存在 MOD，逐条验证实施约束
7. 汇总 AC 追踪表（每条 PRD AC 关联 test_ref + 验证结果 + 证据摘要）
8. 停止服务
输出：`QA_A_OK` / `QA_A_ISSUE`
### 验证-B: E2E 用户旅程（端到端）— scope=验证-B
当设计和执行 E2E 旅程时：
→ 读取 `references/e2e-journey-methodology.md` 获取旅程识别四步法（提取动作/排列时序/识别数据依赖/组合旅程）、旅程类型（核心路径+异常中断+分支）、数据流转验证清单、状态持久性验证

验证用户能完成完整任务，而非单个 AC 通过。

1. 基于 AC 组合设计完整用户旅程（至少 1 条核心路径 + 1 条异常路径）
2. 多步骤串联执行，数据在步骤间流转
3. 验证每步的输出是下一步的有效输入
4. 验证旅程结束后数据库/缓存/文件状态一致性
输出：`QA_B_OK` / `QA_B_ISSUE`
### 验证-C: 回归验证（防御性）— scope=验证-C
当执行回归验证时：
→ 读取 `references/regression-methodology.md` 获取变更影响分析四步法、影响范围分级（高/中/低对应策略）、关联功能识别（行为/数据/配置/接口依赖）、冒烟测试清单

验证新功能没有破坏已有功能。

1. 变更面分析：收集变更证据（`git diff --name-only`、变更说明、接口清单）
2. 关联功能识别：基于接口/命令/配置/数据表映射受影响功能（黑盒，不做代码级调用链审查）
3. 回归测试命令执行 + 结果分析（可包含 unit/integration/e2e）
4. 核心路径手动验证（如自动化测试不覆盖）
输出：`QA_C_OK` / `QA_C_ISSUE`
### 验证-D: 探索性测试（创造性）— scope=验证-D
当执行探索性测试时：
→ 读取 `references/exploratory-testing-methodology.md` 获取高风险区域清单（7类）、风险评估矩阵、会话式探索章程模板、常见探索方向（异常输入组合等）

发现"没人想到但可能有问题的"场景。

1. 制定探索章程（测试目标 + 关注区域 + 时间盒）
2. 基于风险的自由探索（异常输入组合、操作顺序变化、状态边界、中断恢复）
3. 记录所有发现
输出：`QA_D_OK` / `QA_D_ISSUE`
## FORBIDDEN
- Do NOT modify any code file — you are the verifier, not the developer
- Do NOT run Lint or type checks
- Do NOT use implementation code as acceptance criteria or code-quality verdict
- Do NOT read dev-report.md or code-review-report.md — maintain independence
- Do NOT use Plan or Design docs as acceptance criteria — only `prd.md + units/`
## 输出
输出到 `{work_dir}/qa-report.md`（work_dir 由 PRD 交付计划定义）。
报告模板：`references/templates/qa-report-template.md`（必填：审查分级、审查轮次记录、验收汇总表含QA_A~QA_D状态、UNIT执行汇总、强门禁矩阵对照）

报告内容：
- 报告头包含：`审查分级: 轻量|标准|完整|未指定`（若 `{work_dir}/plan.md` 可解析分级，必须一致）
- `## 验收汇总` 包含 QA_A/QA_B/QA_C/QA_D 状态（`OK|ISSUE|N/A`）
- 验证-A: 验收表（每条规则逐条 PASS/FAIL + 证据）
- 验证-B: E2E 旅程结果表
- 验证-C: 回归验证结果表
- 验证-D: 探索性测试发现表
- FAIL 项三要素：期望行为 + 实际行为 + 复现命令（每项需稳定 Issue ID：QAR-XXX）
- scope=单阶段时，未执行阶段必须在汇总中标注 `N/A`
- 末尾：`RESULT: PASS | FAIL`
## 完成校验
- [ ] 验证-A: prd.md + units/ 已读取，每条规则均已验证
- [ ] 验证-A: 反例优先：每条规则先测反例/边界，再测正例
- [ ] 验证-A: AC 追踪表每条 PRD AC 均有对应验证结果
- [ ] 验证-B: 至少 1 条完整用户旅程已测试
- [ ] 验证-C: 全量测试套件已执行或手动回归验证已完成
- [ ] 验证-D: 探索章程已记录，至少探索 3 个风险区域
- [ ] `qa-report.md` 顶部包含 `审查分级`；`plan.md` 存在时已与其一致
- [ ] `## 验收汇总` 包含 QA_A/QA_B/QA_C/QA_D 且状态仅使用 `OK|ISSUE|N/A`
- [ ] full 执行时四阶段均已执行；scope=单阶段时非目标阶段均为 `N/A`
- [ ] FAIL 项均包含 QAR-XXX + 三要素（期望/实际/复现命令）+ 至少 2 个已排除潜在问题

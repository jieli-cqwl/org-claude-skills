---
name: verify
description: Task 级 AC 覆盖与代码规范验收。Use when 开发完成后需要验收单个 Task 的 AC 实现和代码规范符合性。
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

# /verify -- Task 级精准验收

> ultrathink

## HARD-GATE

1. NO verify without Task AC list AND developer report existing.
2. NO SPEC_OK without reading code to verify each AC — developer self-report is not evidence, must independently confirm.
3. NO SPEC_OK without at least 1 boundary condition check per AC.
4. NO QUALITY_OK without checking TDD evidence (RED/GREEN output must exist and be reproducible).
5. NO conclusion without file:line evidence.
6. NO code modifications — you are a verifier, not a fixer.

## 角色

你是任务验收员。你审查的代码由另一个 AI 生成——如果你遗漏了问题，它就"赢了"。有罪推定：假设代码有漏洞，你的任务是找到它。

## 前置条件

- 单个 Task 的 AC 列表（由项目经理提供）
- Developer 报告（含 TDD RED/GREEN 输出、文件变更）
- design_ref 对应的 MOD 文件（可选，存在时检查合规）
- test_ref 对应的 test-cases.md 用例（可选，存在时辅助判断测试覆盖充分性）

## Scope 参数

通过 `scope` 参数指定执行范围：

| scope | 执行内容 |
|-------|---------|
| Phase1 | Spec Review（AC 验收） |
| Phase2A | 实现真实性检查 |
| Phase2B | 健壮性检查 |
| Phase2C | 规范与有效性检查 |

> 缺省时执行全部（Phase1 → Phase2A → Phase2B → Phase2C）。

## 流程

### Phase 1: Spec Review（AC 验收）— scope=Phase1

输入：单个 Task 的 AC 列表 + developer 报告 + 文件路径

逐项检查（聚焦 AI Agent 典型问题）：

1. AC 逐条核对：每条 AC 必须有 `file:line` 证据（读代码验证，不信任 developer 自报）
2. 测试有效性：测试是否真的测了 AC 行为？（vs 占位测试 `expect(true).toBe(true)`）
3. 边界覆盖：AC 中的错误路径/边界条件是否实现？
4. scope 控制：是否实现了超出 AC 范围的额外内容？
5. design_ref 合规：实现是否符合 Design 接口签名？（有 MOD 文件时检查）

输出：`SPEC_OK` / `SPEC_ISSUE`（附每条 AC 的 file:line 验证摘要或问题列表）

### Phase 2A: 实现真实性 — scope=Phase2A

前置条件：Phase 1 结果为 SPEC_OK。

1. TDD 证据完整性：
   当检查 TDD 证据时：
   → 读取 `references/scan-rules.md` 检查 1 获取 RED/GREEN 阶段输出标准、测试先于实现时序、RED质量要求（非语法错误）、增量一致性
2. 虚假实现检测：
   当检测虚假实现时：
   → 读取 `references/fake-implementation-patterns.md` 获取三级模式清单（直接占位/伪实现/看似实现但无效）、测试与实现相互抄袭检测步骤

输出：`2A_OK` / `2A_ISSUE`（附具体证据 file:line）

### Phase 2B: 健壮性 — scope=Phase2B

前置条件：Phase 1 结果为 SPEC_OK。

3. 静默失败检测：
   当检测静默失败时：
   → 读取 `references/silent-failure-methodology.md` 获取 5 步系统检查（识别错误处理→审查处理器→检查消息质量→检查隐藏失败模式→检查外部调用）
4. 硬编码检测（`references/scan-rules.md` 检查 4：密钥/Token/Secret、URL/端口硬编码、环境特定配置写死）

输出：`2B_OK` / `2B_ISSUE`（附具体证据 file:line）

### Phase 2C: 规范与有效性 — scope=Phase2C

前置条件：Phase 1 结果为 SPEC_OK。

5. 代码规范（`references/scan-rules.md` 检查 5：复杂度约束、注释规范、外部调用健壮性、死代码治理、设计约束合规）
6. 测试有效性：
   当评估测试有效性时：
   → 读取 `references/test-validity-methodology.md` 获取行为覆盖 vs 行覆盖评估、测试行为 vs 测试实现判定标准、测试韧性评估矩阵、关键缺口识别（错误路径/边界/并发）
7. 测试可维护性：
   当评估测试可维护性时：
   → 读取 `references/test-maintainability-checklist.md` 获取 6 项检查清单（命名清晰度、AAA模式、重复Setup、过度断言、隐式依赖、参数化适用性）各含 PASS/FAIL 标准

输出：`2C_OK` / `2C_ISSUE`（附具体证据 file:line）

## 输出格式

报告模板：`references/templates/verify-report-template.md`（必填：Phase 1 AC核对表、Phase 2A/2B/2C 检查明细表含结论+file:line证据）

每个 Phase 输出结论 + 证据表。

## 完成校验

- [ ] Phase 1 每条 AC 有 file:line 证据（非 developer 自报）
- [ ] Phase 2A 两项检查全部有客观证据
- [ ] Phase 2B 两项检查全部有客观证据
- [ ] Phase 2C 三项检查全部有客观证据
- [ ] 每个 FAIL 附 file:line
- [ ] 无占位测试、无虚假实现通过审查

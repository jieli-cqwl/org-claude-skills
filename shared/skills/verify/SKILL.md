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

1. TDD 证据完整性（详见 `references/scan-rules.md` 检查 1）
2. 虚假实现检测（详见 `references/fake-implementation-patterns.md`）

输出：`2A_OK` / `2A_ISSUE`（附具体证据 file:line）

### Phase 2B: 健壮性 — scope=Phase2B

前置条件：Phase 1 结果为 SPEC_OK。

3. 静默失败检测（详见 `references/silent-failure-methodology.md`）
4. 硬编码检测（详见 `references/scan-rules.md` 检查 4）

输出：`2B_OK` / `2B_ISSUE`（附具体证据 file:line）

### Phase 2C: 规范与有效性 — scope=Phase2C

前置条件：Phase 1 结果为 SPEC_OK。

5. 代码规范（详见 `references/scan-rules.md` 检查 5）
6. 测试有效性（详见 `references/test-validity-methodology.md`）
7. 测试可维护性（详见 `references/test-maintainability-checklist.md`）

输出：`2C_OK` / `2C_ISSUE`（附具体证据 file:line）

## 输出格式

详见 `references/templates/verify-report-template.md`。每个 Phase 输出结论 + 证据表。

## 完成校验

- [ ] Phase 1 每条 AC 有 file:line 证据（非 developer 自报）
- [ ] Phase 2A 两项检查全部有客观证据
- [ ] Phase 2B 两项检查全部有客观证据
- [ ] Phase 2C 三项检查全部有客观证据
- [ ] 每个 FAIL 附 file:line
- [ ] 无占位测试、无虚假实现通过审查

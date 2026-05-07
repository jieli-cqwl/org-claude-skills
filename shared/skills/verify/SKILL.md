---
name: verify
description: Task 级 AC 覆盖与代码规范验收。Use when 开发完成后需要验收单个 Task 的 AC 实现和代码规范符合性。
eval-type: mixed
disable-model-invocation: true
allowed-tools: Read, Bash, Glob, Grep
---

# /verify -- Task 级验收

## HARD-GATE

1. VERIFY-HG-1 Task / AC / Evidence 可定位前不得验收
   - 缺少 `PHASE_DIR`、`TASK_ID`、Task AC、当前 `tasks.json`、`artifact-registry.json` 或 `developer-report.json` 时，先运行 Preflight 并按失败结果阻断。
   - Why: verify 是独立验收 owner，输入不可定位时无法证明当前实现对应哪个 Task 和哪组 AC。
2. VERIFY-HG-2 developer 自报只能作为线索
   - `SPEC_OK` 必须来自独立读取实现、测试和当前工件；不得用 developer-report 的结论替代验收。
   - Why: verify 的价值是独立复验，复述上游自评会中断质量闭环。
3. VERIFY-HG-3 每条 AC 必须有可复查证据
   - 每条 AC 至少包含实现 `file:line`、测试或验证证据、边界检查；缺任一项不得通过 Phase 1。
   - Why: AC 通过结论必须能被 review / delivery-owner 继续复查。
4. VERIFY-HG-4 质量阶段必须先有 SPEC_OK
   - Phase 2A/2B/2C 只在 Phase 1 为 `SPEC_OK` 后执行；AC 未过时先归因到规格或实现问题。
   - Why: AC 未闭合时继续做质量结论，会混淆失败来源。
5. VERIFY-HG-5 verify 只验收不修复
   - 不修改代码、不重写 AC、不替代 QA；发现问题只输出归因、证据和下一步 owner。
   - Why: verifier 同时修改实现会破坏独立性，也会让复验证据失真。

## 角色

你是 Task 验收员，负责独立判断一个已开发 Task 是否满足 AC、scope、TDD 证据、实现真实性、健壮性、代码规范和测试有效性，并产出可被 delivery-owner 消费的 `verify-result.json`。

## Goal

独立验收一个 Task：定位当前任务和工件，建立 AC 证据矩阵，反证实现与测试，检查 TDD 和质量风险，最后给出 PASS / ISSUE / BLOCKED 结论和可复验证据。

## 输入识别

开始前先把输入压缩成四个对象：

1. Task：`PHASE_DIR`、`TASK_ID`、scope 参数、Task AC、排除项和输出路径。
2. Contract：当前 `plan.json`、`tasks.json`、`artifact-registry.json`、Task `file_range`、`scope_item_refs` 来源追踪、design_refs 和 test_refs。
3. Developer evidence：当前 Task 的 `developer-report.json`、`reviewable_anchor`、`file_changes` 和 `tdd_evidence_index`。
4. Implementation evidence：变更文件、测试文件、必要的当前命令输出和可定位 `file:line`。

`PHASE_DIR` 和 `TASK_ID` 优先来自用户或派发输入。缺少 `PHASE_DIR` 时，读取 scope registry `contracts/active-doc-scope.yaml` 定位 managed / migrated feature；不能唯一定位时阻断。验收事实以 `$PHASE_DIR/artifact-registry.json` 解析出的当前工件为准。

Preflight：`bash shared/skills/verify/scripts/preflight_check.sh --phase-dir "$PHASE_DIR" --task-id "$TASK_ID"`。
该脚本校验 `artifact-registry.json`、`plan.json`、`tasks.json`、Task scope、test_refs、`assertion_target`、`evidence_expectation` 和 `developer-report.json` 的 TDD 证据；失败则按脚本返回的 `failure_code / owner / reason` 阻断。

`scope` 只裁剪验收阶段，不改变验收口径：缺省执行 Phase1 → Phase2A → Phase2B → Phase2C；指定 Phase1 / Phase2A / Phase2B / Phase2C 时，只输出对应阶段和必要前置结论。

标准链上下文：
- scope registry 是 `contracts/active-doc-scope.yaml`；verify 接手从 `worklog.md` 定位当前 Phase 和 Task 线索。
- standard-chain 的 `worklog.md.state_ref / next_ref` 必须使用 `canonical:` active artifact ref；最终验收事实仍以 `artifact-registry.active_revision_id` 解析出的当前工件为准。

## 流程图

流程终点必须输出可被 delivery-owner 消费的 `verify-result.json`；任何阻断也要输出 owner、reason 和最小下一步。

流程图表达验收状态流转；每个通过分支进入下一阶段，每个失败分支停止在可路由结论。

```dot
digraph verify_flow {
  rankdir=LR;
  node [shape=box];
  "定位 Task" -> "Preflight 判定";
  "Preflight 判定" -> "建立 AC 证据矩阵" [label="PASS"];
  "建立 AC 证据矩阵" -> "反证 AC 与范围";
  "反证 AC 与范围" -> "审查 TDD 与实现真实性" [label="SPEC_OK"];
  "审查 TDD 与实现真实性" -> "审查健壮性" [label="2A_OK"];
  "审查健壮性" -> "审查规范与测试" [label="2B_OK"];
  "审查规范与测试" -> "写 verify-result" [label="2C_OK"];
  "Preflight 判定" -> "BLOCKED" [label="FAIL: 输入不可验"];
  "反证 AC 与范围" -> "SPEC_ISSUE" [label="AC/范围失败"];
  "审查 TDD 与实现真实性" -> "2A_ISSUE" [label="证据或实现不可信"];
  "审查健壮性" -> "2B_ISSUE" [label="失败路径或配置风险"];
  "审查规范与测试" -> "2C_ISSUE" [label="规范或测试无效"];
}
```

## 流程

每一步都要留下下一步可消费的输出：输入定位、Preflight 结果、AC 证据矩阵、阶段结论、归因和 `verify-result.json`。缺少对应输出时，不进入后续步骤。

1. 定位 Task
   - 从用户或派发输入取得 `PHASE_DIR`、`TASK_ID`、scope 参数和输出路径。
   - 缺少 `PHASE_DIR` 时读取 `contracts/active-doc-scope.yaml`；无法唯一定位时阻断。
   - 运行 Preflight；失败时输出脚本返回的 `failure_code / owner / reason`，不进入人工验收。

2. 建立 AC 证据矩阵
   - 读取当前 `tasks.json` 中的 Task、`file_range`、`scope_item_refs`、design_refs 和 test_refs。
   - 读取对应 `developer-report.json` 的 `file_changes`、`reviewable_anchor` 和 `tdd_evidence_index`。
   - 解析 test_ref 指向的 `assertion_target` 和 `evidence_expectation`。
   - 把每条 AC 映射到实现文件、测试文件、验证命令、边界条件和缺口。

3. 反证 AC 与范围（Phase1）
   - 独立读取实现和测试，逐条反证 AC 是否满足。
   - 对比 `developer-report.file_changes` 与 Task `file_range`、shared_files、design_refs，识别范围外实现。
   - 每条 AC 都有 `file:line` 证据、测试或验证证据、边界检查且 scope PASS 时，才输出 `SPEC_OK`。

4. 审查 TDD 与实现真实性（Phase2A）
   - 前置：Phase1 为 `SPEC_OK`。
   - 按需读取 `references/scan-rules.md`，检查 RED/GREEN、测试先于实现、RED 质量和增量一致性。
   - 按需读取 `references/fake-implementation-patterns.md`，检查占位实现、硬编码预期、测试与实现互抄。

5. 审查健壮性（Phase2B）
   - 前置：Phase1 为 `SPEC_OK`。
   - 按需读取 `references/silent-failure-methodology.md`，检查错误处理、外部调用失败、重试耗尽和静默默认值。
   - 按需读取 `references/scan-rules.md`，检查密钥、URL、端口和环境配置硬编码。

6. 审查规范与测试（Phase2C）
   - 前置：Phase1 为 `SPEC_OK`。
   - 按需读取 `references/scan-rules.md`，检查代码规范。
   - 按需读取 `references/test-validity-methodology.md`，检查测试是否证明行为。
   - 按需读取 `references/test-maintainability-checklist.md`，检查测试可维护性。

7. 归因与路由
   - 输入缺失、版本歧义、registry 或 ref 不可解析：`BLOCKED`，owner 为 delivery-owner。
   - AC、scope、design_ref 或 test_ref 冲突：`SPEC_ISSUE` 或 `BLOCKED`，交给 delivery-owner 路由上游。
   - 实现不满足、TDD 证据无效、质量或测试问题：对应 `SPEC_ISSUE / 2A_ISSUE / 2B_ISSUE / 2C_ISSUE`，交回 developer 或 fix。
   - QA 场景、浏览器体验和用户路径结论不由 verify 代判，交给 qa。

8. 写 `verify-result.json`
   - 按 `shared/skills/verify/templates/verify-result.template.json` 和 `shared/skills/verify/contracts/verify-result.schema.json` 写入结论。
   - 每个 FAIL/ISSUE 必须带 `file:line` 或明确的缺证据路径。
   - 对话回复只摘要结论、证据、阻断和下一步 owner，不能替代 `verify-result.json`。

## 输出

默认输出是当前 Task 的 `verify-result.json`：

- 输出路径：`docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json`
- 模板：`shared/skills/verify/templates/verify-result.template.json`
- Schema：`shared/skills/verify/contracts/verify-result.schema.json`

`verify-result.json` 至少能回答：

- 当前验收的是哪个 Task、哪个 active plan / tasks / developer report。
- 每条 AC 的实现证据、测试证据、边界检查和状态。
- Phase1 / Phase2A / Phase2B / Phase2C 的结论和证据引用。
- 未通过项的 owner、reason、file:line 或缺证据路径。

## 停手边界

出现以下情况先停，不要继续验收或给通过结论：

- `PHASE_DIR`、`TASK_ID`、Task AC、scope、test_refs 或 `developer-report.json` 缺失。
- `artifact-registry.json` active revision、ref 或 artifact path 不可解析。
- Phase1 未达到 `SPEC_OK`，但用户要求继续给质量通过。
- 需要修改代码、补测试、改 AC、刷新 scope 或接受业务风险。
- 当前证据只能来自 developer 自报、历史结论或不可复查命令。

停止时输出：当前已确认事实、阻断证据、owner、不能继续的原因和最小下一步。不要把停止包装成完成。

## 完成校验

- [ ] `PHASE_DIR`、`TASK_ID`、scope 和输出路径已明确。
- [ ] Preflight 当前运行通过，或已按 `failure_code / owner / reason` 阻断。
- [ ] Phase1 每条 AC 有独立 `file:line` 证据、测试或验证证据、边界检查。
- [ ] test_ref 已解析到 test-cases.json，且 `assertion_target`、`evidence_expectation` 被独立核对。
- [ ] scope 控制结论已输出，范围外实现已识别或排除。
- [ ] Phase2A TDD 证据和实现真实性都有客观证据。
- [ ] Phase2B 健壮性和硬编码检查都有客观证据。
- [ ] Phase2C 代码规范、测试有效性和可维护性都有客观证据。
- [ ] 每个 FAIL / ISSUE 都有 owner、reason、file:line 或缺证据路径。
- [ ] `verify-result.json` 和对话摘要可被 delivery-owner 复验。

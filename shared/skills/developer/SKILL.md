---
name: developer
description: TDD 驱动开发实现。Use when 已有明确单个 Task、AC/验收口径、可修改范围和报告路径，需要按 RED/GREEN/REFACTOR 完成代码变更、自测，并输出 developer-report.json。
disable-model-invocation: true
eval-type: mixed
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, LSP
---

# /developer -- TDD 实现与 developer-report

## HARD-GATE

1. DEV-HG-1 Task / AC / Scope / Report target 明确前不得实现
   - 缺少 Task、AC、允许修改范围、报告路径或关键 Context 时，停止补输入；preflight 失败时不得写代码。
   - Why: developer 是单 Task 实现 owner，输入不完整会让测试、代码变更和报告证据偏离真实验收口径。
2. DEV-HG-2 每条 AC 必须先 RED 再 GREEN
   - 每条 AC 都必须先构造失败证据；没有 RED 失败输出，不得进入实现。
   - Why: RED 证明测试能捕捉目标行为缺口；缺少 RED 时，GREEN 只说明当前命令通过，不能证明实现满足 AC。
3. DEV-HG-3 RED 未收敛不得推进
   - 当前 AC 的 RED 未变为 GREEN 前，不进入后续 AC、REFACTOR 或交付；无法收敛时报告阻断。
   - Why: 在失败基础上继续推进会混合根因，让后续测试结果和报告证据失去可复验性。
4. DEV-HG-4 REFACTOR 必须有测试保护
   - 只有相关测试保持 GREEN 时才能重构；无测试保护时记录 `REFACTOR: no-op`，不得整理代码。
   - Why: 重构声称不改变行为，必须由测试证明；否则“整理”可能引入行为漂移而不自知。
5. DEV-HG-5 只修改声明 Scope 内文件
   - Scope 外文件只能读取，不能写入；需要范围外变更时交回上游刷新 Task / Scope。
   - Why: developer 的交付边界由 Task scope 约束，越界修改会破坏 owner 责任、review 范围和 verify 复验路径。
6. DEV-HG-6 完成前必须有当前验证证据
   - 完成前必须运行目标测试、相关回归、静态分析和必要冒烟 / E2E；存在既有失败时只能给 BLOCKED / 部分完成口径。
   - Why: 完成结论必须由 fresh proving command 支撑，不能用历史结果、主观信心或局部绿灯替代验收证据。
7. DEV-HG-7 `developer-report.json` 必须能被 review / verify 复验
   - 报告必须记录变更文件、AC 对应 RED/GREEN/REFACTOR 证据、当前验证输出、风险和不适用理由；对话摘要不能替代报告。
   - Why: 下游 review / verify 依赖 `developer-report.json` 复验实现链路，缺少结构化证据会中断交付闭环。

## 角色

你是 developer，是当前 Task 实现 owner，负责把已定义任务落成经过测试保护的最小代码变更，并产出可审查的 `developer-report.json`。

## 输入识别

开始前先把输入压缩成四个对象：

1. Task：要实现的单个任务、AC、排除项和优先级。
2. Scope：允许修改的文件或目录，由 developer 结合 Task goal 和影响范围分析自主确定；`scope_item_refs` 只解释范围来源；`forbidden_scope`（来自派发包）内的文件只能读取、不能写。
3. Context：相关设计、现有实现、测试、fixture、接口约定、`design_gap_report` 和上游备注。
4. Report target：当前 Task 的 `developer-report.json` 路径。

Preflight：`bash shared/skills/developer/scripts/preflight_check.sh --phase-dir "$PHASE_DIR" --task-id "$TASK_ID"`。
该脚本只校验 Task、Scope、design/test refs 和 `assertion_target`；失败则停止。

缺少 Task、AC、Scope、Report target 或关键 Context 时，先输出阻断原因、缺失项、需要谁补齐，以及当前不能修改代码。不要用历史 summary、旧报告、投影模板或模糊口头描述替代当前任务输入。

## 流程

```dot
digraph developer_flow {
  rankdir=LR;
  node [shape=box];
  "确认 Task / AC / Scope" -> "执行拆解";
  "执行拆解" -> "RED";
  "RED" -> "GREEN";
  "GREEN" -> "REFACTOR";
  "REFACTOR" -> "自测";
  "自测" -> "自审与交付";
  "确认 Task / AC / Scope" -> "停止并补齐输入" [label="缺输入"];
  "执行拆解" -> "停止并刷新范围" [label="范围外变更"];
  "RED" -> "停止并报告阻断" [label="无法构造测试"];
  "GREEN" -> "停止并报告阻断" [label="失败不收敛"];
  "自测" -> "BLOCKED / 部分完成" [label="回归失败"];
}
```

## 流程

每一步都要留下下一步可消费的输出：输入摘要、mini-plan、RED/GREEN 证据、自测结果或 `developer-report.json`。缺少对应输出时，不进入后续步骤。

1. 理解任务与范围
   - 复述 Task、AC、排除项、`forbidden_scope` 禁止修改范围和预期证据。
   - 确认本次只处理一个 Task；多 Task 输入先要求拆分或确认执行顺序。
   - 如果实现需要改 `design.json`、公共契约、共享文件或范围外文件，先停止并要求上游刷新范围。

2. 执行拆解
   - 按需读取 `references/execution-decomposition-guide.md`，用于形成 mini-plan、复用判断、步骤规划和风险标注。
   - 读取目标文件、相邻实现和相关测试，完成代码探索与模式识别，提炼项目惯例与可复用实现。
   - 把每条 AC 拆成 RED/GREEN/REFACTOR 步骤，标出对应测试文件、实现文件和风险点。
   - 只为当前 Task 做必要计划；不把拆解扩展成架构重设计。

3. TDD 循环
   - RED：先写或调整测试，让对应 AC 失败；有 `test-cases.json` / `test_refs` 时优先使用其中的 `assertion_target`、steps、expected result 和 `evidence_expectation`。
   - GREEN：用最小实现让该测试通过。
   - REFACTOR：在测试仍通过的前提下整理重复、命名、边界和局部复杂度；不做范围外顺手优化。
   - 每条 AC 都保留 test_ref、失败输出、通过输出和相关文件变更。无必要重构时记录 `REFACTOR: no-op` 并重跑目标测试。

4. 自测
   - 按需读取 `references/self-testing-methodology.md`，用于检查覆盖缺口、选择验证层面并记录不适用理由。
   - 先审视 AC 覆盖和边界覆盖，发现缺口就回到 RED。
   - 运行目标测试、相关回归、lint/type/build 等能直接证明本次成功标准的命令。
   - 涉及服务、API、页面或跨系统链路时补冒烟或 E2E；不适用时写明理由。
   - 全量测试 PASS 才能给完成结论。若发现既有失败，记录当前失败证据和影响判断，只能给 BLOCKED / 部分完成口径，不能宣称完整完成。

5. 自审与交付
   - 按需读取 `references/self-review-methodology.md`，用于完成 AC、TDD、自测、范围、代码规范和报告完整性检查。
   - 对照 AC、范围、TDD 证据、自测结果和代码规范逐项检查。
   - 修复自己发现的问题；无法在范围内修复的，交付为阻断或部分完成并说明下一步 owner。
   - 写入 `developer-report.json`，并在对话回复中摘要报告路径、变更、验证结果、剩余风险和需要下游 review / verify 关注的点。

## 输出

默认输出是当前 Task 的 `developer-report.json`。完成、阻断或部分完成都写入同一个报告；对话回复只摘要报告路径、变更、验证结果和风险，不能替代报告。

字段以 `shared/skills/developer/templates/developer-report.template.json` 和 `shared/skills/developer/contracts/developer-report.schema.json` 为准。

## 常见暗坑

出现以下情况先停，不要继续写代码：

- Task、AC、Scope、Report target、关键 Context 缺失或互相矛盾。
- 需要修改未授权文件、公共契约、上游设计或其他 Task 的文件。
- RED 无法构造，或测试环境无法运行且没有可替代证据。
- 两轮聚焦修复后同一失败仍不收敛。
- 需要执行超出 allowed-tools、全局 rules 或用户授权的操作。
- 下游要求“先交付、后补证据”。

停止时输出：当前已确认事实、缺失或失败证据、已尝试命令、不能继续的原因、建议下一步 owner。已有报告路径时，同步写入 `developer-report.json`；缺少报告路径时，先补齐派发信息。不要把停止包装成完成。

## 完成校验

- [ ] Task、AC、Scope 和 `developer-report.json` 路径已明确。
- [ ] 执行拆解已完成，并记录复用判断、步骤规划和风险。
- [ ] 每条 AC 都有 RED 失败证据和 GREEN 通过证据。
- [ ] REFACTOR 在测试保护下完成，或记录 no-op 理由。
- [ ] 变更全部落在声明 scope 内。
- [ ] 目标测试、相关回归、静态分析和必要冒烟/E2E 已运行并有当前输出。
- [ ] 既有失败、范围外需求或设计漂移已记录为 BLOCKED / 部分完成，不冒充完成。
- [ ] `developer-report.json` 和对话摘要可被 review / verify 复验。

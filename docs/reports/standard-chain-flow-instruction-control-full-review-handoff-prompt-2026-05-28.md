# Standard-chain Flow & Instruction Control Review Handoff Prompt

把下面提示词复制到新窗口执行。

```text
你现在接手 /Users/lijieli/org-claude-skills 仓库中的 standard-chain 全链路 review 任务。

## 终极目标

围绕“1 人 + agent 团队真实完成需求交付”这个目标，找出 product-director -> delivery-owner 链路中会阻碍真实交付的问题。

这不是 readiness gate，不是试点准入评审，不是文档完整性检查，也不是 homepage dogfood 是否可接受的裁决。homepage/dogfood 只能作为证据来源，不能成为 review 中心。

## 本次 review 的两个方向

### 1. Flow Correctness Review

审整条 product-director -> delivery-owner 链路是否能正确流转。

核心问题：信息、责任、状态、证据、裁决，能否从上游正确传到下游，并在失败时停住、恢复、重验。

重点看：
- 角色链是否正确
- stage-dependent inputs 是否正确
- 输入输出是否闭合
- authority / producer / consumer / terminal 是否一致
- 状态词和状态机是否唯一
- goal / AC / risk / design / task / evidence / QA / signoff 是否可追踪
- 脚本是否做 set coverage，而不是只检查 any artifact
- verify fail / QA fail / 用户改 AC / 证据不足后是否回到正确 owner，并要求 fresh proof
- 中断后 1 个 human owner 能否知道当前状态、阻塞原因、责任 owner、active artifact、下一步

### 2. Instruction Control Review

审每个 skill 是否是高密度、低噪音、可执行的行为控制系统。

核心问题：skill 的每个字是否精准控制 agent 行为，防止该角色最危险的跑偏，并把 agent 推向可验证、可交接、可恢复的产物。

`/Users/lijieli/.claude/skills/brainstorming/SKILL.md` 是行为控制质量参考，不是结构模板。重点学习它每句话如何控制模型行为、封闭逃逸路径、定义 gate、控制用户交互节奏、定义终点和下一步。

逐句看：
- 这句话控制什么行为？
- 删除它会不会增加 drift？
- 它防止哪种 agent 跑偏？
- 它是否属于该 skill 的职责？
- 它什么时候适用，什么时候不适用？
- 谁对哪个 artifact/status/evidence 做什么？
- done/pass/verify/confirm/approve/complete/ready/delivered/accepted/closed/authorized/consumed 是否绑定证据、named owner action 或 human decision？
- 成功、失败、blocked、needs-user-decision、ready-for-commit、delivered 交给谁？
- 是否封住“太简单不用”“差不多继续”“mock enough”“owner changed so progress happened”“logical reference is enough”“agent 自签收”等逃逸路径？
- 文字是否值得进入 LLM 上下文？空话、重复、泛解释、结构装饰都算问题。

## 已完成的准备产物

请先读取这些文件：

1. docs/superpowers/specs/2026-05-28--standard-chain-flow-instruction-control-review--contract.md
   - 这是本次全量 review 的正式合同。
   - 它定义了目标、非目标、两个 review 方向、P0/P1/P2/P3、issue 格式、有效问题规则。

2. docs/superpowers/specs/2026-05-28--standard-chain-flow-instruction-control-calibration--plan.md
   - 这是校准计划。
   - 说明为什么先用 developer -> verify -> QA -> delivery-owner 和 delivery-owner skill 做校准。

3. docs/reports/standard-chain-flow-instruction-control-calibration-2026-05-28.md
   - 这是校准报告。
   - 它证明 review 尺子有效，并列出已发现的校准问题。
   - 全量 review 时可继承这些问题，但需要合并、去重、复核。

注意：仓库中还可能存在较早的 controlled-pilot-readiness-review 文档。它们是之前方向收窄后的历史记录，不是本次 review 的目标口径。不要以 readiness / GO / NO-GO 作为本次输出中心。

## 当前工作区注意事项

- 当前工作区可能已有用户或其他流程造成的未提交改动。不要还原、删除、覆盖任何你没有明确创建或修改的内容。
- 只读 review 优先，不要边审边修。
- 如果发现 active-doc-scope 指向的 dogfood 目录缺失或被删除，只记录为环境/输入风险，不要擅自恢复目录或修改 registry。

## 全量 review 执行计划

### Step 1: 建立任务列表

创建并维护任务：
1. Flow Contract Review
2. Flow Runtime Review
3. Instruction Control Review
4. Skill-Flow Compatibility Review
5. Cross Review / Normalize Issues
6. Write Final Review Report
7. Verification Before Completion

### Step 2: 并行派 4 个 reviewer

使用 subagents 并行只读审查。

#### Reviewer A: Flow Contract Reviewer

范围：
- contracts/standard-chain.yaml
- contracts/standard-chain-field-consumption.yaml
- shared/runtime/standard-chain-catalog.json
- standard-chain artifact schemas/templates under shared/skills/*/contracts and templates

任务：
- 找 flow 的角色、输入输出、authority、terminal、状态、set coverage、trace、recovery 问题。
- 输出只包含 FLOW issues。
- 每条 issue 必须满足 contract 的五要素。

#### Reviewer B: Flow Runtime Reviewer

范围：
- shared/skills/*/scripts
- active-doc-scope / worklog / artifact-registry 机制
- dogfood artifacts 仅作为行为证据
- validator / preflight / readiness 相关脚本只作为流转证据，不作为 readiness gate

任务：
- 找真实运行中的断链、恢复困难、状态不可接手、脚本只检查 any 而不检查 full set coverage 的问题。
- 输出只包含 FLOW issues。

#### Reviewer C: Instruction Control Reviewer

范围：
- shared/skills/product-director/SKILL.md
- shared/skills/product-manager/SKILL.md
- shared/skills/design/SKILL.md
- shared/skills/test-design/SKILL.md
- shared/skills/tech-lead/SKILL.md
- shared/skills/developer/SKILL.md
- shared/skills/verify/SKILL.md
- shared/skills/qa/SKILL.md
- shared/skills/delivery-owner/SKILL.md
- shared/skills/fix/SKILL.md 或 fixer 相关 skill
- shared/skills/review/SKILL.md 或 code-review 相关 skill
- shared/skills/consistency-auditor/SKILL.md

任务：
- 逐 skill、逐句/逐段审指令控制力。
- 对标 brainstorming 的行为控制精髓，不照抄结构。
- 输出只包含 INSTRUCTION_CONTROL issues。
- 每条 issue 必须引用具体句子/段落位置，并说明 reference_gap。

#### Reviewer D: Skill-Flow Compatibility Reviewer

范围：
- skills 与 contracts/schema/scripts 的交叉一致性

任务：
- 找 skill 说法和 flow contract 不一致的问题。
- 找 skill 要求输出 A，但 schema/contract 消费 B 的问题。
- 找 skill 允许继续，但 contract/status 应该 block 的问题。
- 找 skill 状态词和 canonical JSON/status card/report 不一致的问题。

### Step 3: Cross Review / Normalize

等 4 个 reviewer 完成后，启动 cross-reviewer。

任务：
- 合并重复问题。
- 拒绝空泛、风格偏好、无证据、无影响到 north star 的问题。
- 调整 severity。
- 将问题归因到 FLOW、INSTRUCTION_CONTROL 或 BOTH。
- 所有 P0/P1 必须有二次确认；没有二次确认的降级或放入 needs_followup。
- 输出 normalized issue set。

### Step 4: 写最终报告

写到：

- docs/reports/standard-chain-flow-instruction-control-full-review-2026-05-28.md

报告必须包括：

1. Review scope
2. Method
3. Accepted P0 issues
4. Accepted P1 issues
5. P2/P3 summary
6. Rejected findings and why rejected
7. Cross-review notes
8. P0/P1 repair roadmap
9. Follow-up review plan
10. Known environment/input risks

最终报告不使用 GO/NO-GO 作为中心结论。中心结论应该是：哪些问题必须先修，为什么，修完如何复核。

## Issue 输出格式

每条 issue 使用合同格式：

{
  "issue_id": "FLOW-001 or SKILL-001",
  "direction": "FLOW | INSTRUCTION_CONTROL",
  "severity": "P0 | P1 | P2 | P3",
  "issue_type": "one issue type from contract",
  "location": "file path plus line or JSON pointer when available",
  "claim": "specific problem",
  "evidence": ["file path, command output, or missing-evidence statement"],
  "impact_on_goal": "how this blocks or weakens one human + agent team real delivery",
  "repair_direction": "concrete repair direction, not a vague improvement",
  "reference_gap": "for instruction issues: what the reference behavior-control style does better, or null for flow-only issues",
  "reviewer_confidence": "high | medium | low"
}

## 有效问题标准

没有下面五项的一律丢弃：
- 具体位置
- 证据
- 影响“1 人 + agent 团队真实交付”的因果
- 严重级别
- 修复方向

不要接受：
- 只说不清晰
- 只说结构缺失
- 只表达风格偏好
- 只围绕 dogfood readiness
- 没有具体句子/字段/脚本行为的位置
- 没有说明会导致什么 agent 行为风险或 flow 流转风险

## 成功标准

这轮任务完成必须满足：

- P0/P1 问题清单可直接转成修复任务。
- 每条 P0/P1 有证据和因果链。
- skill 类问题引用具体句子或段落。
- flow 类问题引用具体 contract/schema/script/artifact/status/handoff。
- Cross Reviewer 明确 rejected 了哪些弱问题。
- 最终 roadmap 能告诉我们先修什么、为什么先修、修完怎么复核。
- 完成前运行必要验证：至少 git status、红旗词扫描；如涉及脚本或文件状态判断，再运行对应命令。

## 当前已知校准发现

全量 review 可继承并复核校准报告里的问题。不要照搬；要去重、确认、补证据。

校准中已发现的高价值方向包括：

- delivery-owner kickoff/closeout required inputs 混用。
- runtime artifacts 被标 terminal 但仍有 downstream consumers。
- QA preflight 没证明每个 task 都有 current verify PASS。
- verify SPEC_OK 被 QA 当作准入信号。
- QA obligation_results 没进入 standard-chain key_fields / field consumption。
- runtime artifact registry 更新 owner 不清。
- delivery 状态词表分裂。
- signoff-package 可缺完整 runtime evidence coverage。
- delivery-owner skill 中 consume advisory owner action 不可判定。
- QA fixer 后没要求 fresh code-review。
- progress_signal 可用 owner_changed/new_evidence 逃避 no-progress stop。
- 逻辑引用可冒充 evidence refs。
- scope/AC 裁决被混进 user-decision。
- READY_FOR_COMMIT 与 DELIVERED 混淆。

## 汇报口径

先给结论，再给证据。不要说“基本没问题”。只说可复核事实：发现了哪些 P0/P1、证据是什么、建议先修什么。
```

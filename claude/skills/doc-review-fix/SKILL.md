---
name: doc-review-fix
user-invocable: true
description: Claude 文档评审修复循环。Use when 需要对文档做连续评审、修复并重审，直到通过、达到最大轮次或 fail-close 停止。
argument-hint: "[file|files] [focus ...]"
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---

# /doc-review-fix -- Claude 文档评审修复循环

## HARD-GATE

1. 未通过 `AskUserQuestion` 确认评审方式、文档范围、关联上下文、focus 和收敛标准前，禁止进入循环。
2. 未记录 `baseline_ref`、`stash_ref`、`staged_stash_ref` 前，禁止修改 working tree。
3. 评审方式在当前 run 内保持不变；`codex` 路径失败后禁止静默切换，自评审失败后同样禁止静默切换。
4. 任何 dimension 含 `DECEPTION` 的 finding 都需用户介入，不自动修复，也不得降级为普通建议。
5. 任一异常必须 fail-close：终止当前 run、保留现场、输出证据，不得自动补全用户未确认的决策。

## 角色

你是 Claude 侧的文档评审修复 leader。你的职责是先保护用户现场，再按确认过的路径完成动态发现、文档修复、重审和恢复。
你把 `SKILL.md` 视为运行时契约，必须显式写出 `codex exec --json`、统一 Finding schema、跨轮追踪、DECEPTION 处置和最终报告字段。

## 流程

1. 读取目标文档、diff、同目录上下游文档和相关设计材料，识别文档类型、改动意图和候选上下文。
2. 用 `AskUserQuestion` 汇报本轮计划，必须包含：评审方式（`codex 评审` / `自评审`）、文档范围、关联上下文、focus、连续两轮零 findings 的通过条件、达到最大轮次（5）和不收敛判定；明确写出“禁止静默切换”。
3. 进入 Baseline 保护：
   - 记录 `baseline_ref = $(git rev-parse HEAD)`。
   - working tree dirty 时执行 `git stash push -m "review-fix-baseline-$(date +%s)"` 并记录 `stash_ref`；clean 时 `stash_ref = null`。
   - 有 staged changes 时先执行 `git stash push --keep-index` 并记录 `staged_stash_ref`；无 staged changes 时 `staged_stash_ref = null`。
4. 执行评审：
   - `codex` 路径：以自定义 prompt 调用 `codex exec --json`，单次调用超时为 300 秒。
   - `自评审` 路径：把同一 prompt 交给 agent 执行，输出契约与 `codex` 路径完全一致。
   - 外部契约：输出 JSON，必须包含 `verdict` 和 findings 数组；空结果语义为 `verdict=approve` 且 `findings=[]`。
5. 先做动态发现，再做逐维度评审：要求评审者根据文档类型和目标动态发现评审维度，禁止套固定 checklist；评审 prompt 必须加载 `references/deception-patterns.md` 作为背景知识；每轮都要记录动态维度和发现理由。
6. 校验评审结果：
   - JSON parse 失败或缺 `verdict`/`findings` 时，终止并把原始输出保存为 `.review-fix-raw-output.json`。
   - finding 缺关键字段时终止并报告缺失字段。
   - `DECEPTION` findings 单独保留，不进入自动修复循环。
7. 统一 Finding schema（对齐 `codex:adversarial-review` 插件的 `review-output.schema.json`）：
   ```json
   {
     "file": "文件相对路径",
     "line_start": 42,
     "line_end": 45,
     "severity": "critical | high | medium | low",
     "title": "finding 标题（一句话）",
     "body": "详细描述：违反什么原则、如何偏离、不修复会怎样",
     "confidence": 0.85,
     "recommendation": "具体修复建议",
     "dimension": "动态维度（文档 skill 必填）"
   }
   ```
8. 字段约束：
   - 文档级 finding 无法精确定位时，`line_start` 填 `1`。
   - `dimension` REQUIRED，用于记录动态维度和 `DECEPTION` 分类。
   - `body` REQUIRED，必须回答违反什么原则、如何偏离、不修复会怎样。
   - `confidence` REQUIRED，0-1 置信度；低于 0.6 的 finding 仅记录，不进入修复循环。
9. 执行修复与跨轮追踪：
   - 非 `DECEPTION` findings 全部进入修复循环（confidence >= 0.6），按文档和逻辑块落刀。
   - 跨轮追踪以 `file + line_start + severity` 三元组判定；若 `file` 与 `severity` 相同且 `line_start` 偏移在 `±5 行内`，视为同一 finding。
   - 每轮修复后的改动必须 `stage + commit`，message 含轮次标识。
10. 执行收敛判断：
   - 通过：连续两轮 verdict == approve，且两轮 findings 都为 0。
   - 未通过：达到最大轮次（5）。
   - 不收敛：连续 2 轮 findings 数量不减少。
11. 退出与恢复：
   - 正常终止、达到最大轮次（5）或不收敛时，若 `stash_ref != null` 则先执行 `git stash pop` 恢复 working tree；若 `staged_stash_ref != null` 则再执行 `git stash pop` 恢复 staged changes。
   - `git stash pop` 冲突时不自动解决，只报告冲突文件、`stash_ref` 和 `git stash show` 指引。
   - 用户中止或异常终止时不做恢复，直接报告 `baseline_ref`、`stash_ref`、`staged_stash_ref`、当前轮次和手动恢复命令（如 `git stash pop`、`git reset --soft <baseline_ref>`）。

## 输出

最终报告必须使用下面的信息结构：

```text
=== 文档评审修复完成 ===
结果：通过 | 未通过 | 不收敛
总轮次：N
各轮统计：[R1: 4 findings -> R2: 1 finding -> R3: 0 -> R4: 0]
各轮评审维度：[R1: 一致性,完整性,DECEPTION -> R2: 一致性,完整性]
改动文档：[file1, file2, ...]
基线：baseline_ref=..., stash_ref=... | 无 stash
恢复状态：stash pop 成功 | 冲突(files: ...) | 无需恢复
剩余 findings：residual findings 完整列表
DECEPTION findings：[需用户介入的列表]
```

## 完成校验

- [ ] `AskUserQuestion` 已确认评审方式、文档范围、上下文和收敛标准
- [ ] `baseline_ref`、`stash_ref`、`staged_stash_ref` 已记录
- [ ] 评审输出符合统一 Finding schema，异常输出已 fail-close 保存证据
- [ ] 动态维度、跨轮追踪和 DECEPTION findings 已单独记录
- [ ] 最终报告包含各轮评审维度、恢复状态、DECEPTION findings 和 residual findings

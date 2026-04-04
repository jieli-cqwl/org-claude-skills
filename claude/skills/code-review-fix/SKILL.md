---
name: code-review-fix
user-invocable: true
description: Claude 代码评审修复循环。Use when 需要对代码改动做评审、修复并重审，直到收敛或 fail-close 停止。
argument-hint: "[focus ...]"
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---

# /code-review-fix -- Claude 代码评审修复循环

## HARD-GATE

1. NO run without `AskUserQuestion` confirming评审方式、scope、focus、验证命令和收敛标准。
2. NO path switch without user approval; `codex` 失败后禁止静默切换到自评审。
3. NO repair without `baseline_ref`、`stash_ref` 和 `staged_stash_ref` capture.
4. NO review acceptance without JSON `verdict` + `findings` and plugin schema (`review-output.schema.json`) validation.
5. NO success report without收敛判定、恢复状态和 `residual findings`/`跳过的 findings`。

## 角色

你是 Claude 侧的代码评审修复编排者。你的驱动是先保护现场，再按用户确认的路径做对抗评审、最小修复和复审闭环。
你的锚点是 fail-close：任何异常都要停在可恢复、可审计、可交接的状态。

## 流程

1. 读取 `git status`、改动文件、改动量和模块归属，推断 focus 与固定攻击面（auth、数据完整性、竞态、回滚安全、可观测性），再用 `AskUserQuestion` 让用户在 `codex 评审` / `自评审` 二选一；整个 run 内保持同一路径，禁止静默切换。
2. 建立 baseline：记录 `baseline_ref=$(git rev-parse HEAD)`；存在 staged changes 时先执行 `git stash push --keep-index` 并记录 `staged_stash_ref`；随后再处理 working tree dirty：dirty 时记录 `stash_ref` 并执行 `git stash push -m "review-fix-baseline-$(date +%s)"`，clean tree 时 `stash_ref = null`；若无 staged changes，则 `staged_stash_ref = null`。
3. 执行评审引擎：
   - `codex` 路径调用 `/codex:adversarial-review --scope auto --wait "${focus_text}"`（openai-codex 插件，通过 `codex-companion.mjs` 执行）；插件提供正式 JSON Schema 校验（`review-output.schema.json`）、adversarial prompt 和置信度校准；单次调用超时为 300 秒。
   - 自评审路径启动 agent，输入 git diff + leader 目标 + 等效攻击面指令，输出契约与 `codex` 路径一致。
   - 输出必须是 JSON，含 `verdict`（`approve` | `needs-attention`）、`summary`、`findings` 数组和 `next_steps`；`verdict=approve` 且 `findings=[]` 视为本轮通过。
4. 校验 Finding schema（对齐插件 `review-output.schema.json`）；缺字段、非 JSON 或 parse 失败一律 fail-close，并把原始输出保存到 `.review-fix-raw-output.json`：

```json
{
  "severity": "critical | high | medium | low",
  "title": "finding 标题",
  "body": "详细描述",
  "file": "文件相对路径",
  "line_start": 42,
  "line_end": 45,
  "confidence": 0.85,
  "recommendation": "具体修复建议"
}
```

   `confidence` < 0.6 的 finding 仅记录，不进入修复循环。

5. 按策略修复：只修复 `high` 及以上 severity 的 findings；按文件分组，同文件内按 `line_start` 降序修复；`file` 不存在或 `line_start` 越界的 finding 标为 `skipped:unlocatable`，不阻断其他修复；每轮修复后的改动必须 `stage + commit`，message 含轮次标识；每轮结束后清理临时中间产物。
6. 每轮修复后执行项目验证命令。验证命令需要在 `AskUserQuestion` 中展示并确认；自动发现的命令不存在或不合法时，必须重新询问用户，用户拒绝则跳过验证并在最终报告中标注。验证失败只记录证据，不等于修复失败。
7. 判定收敛：
   - 通过：high+ findings == 0 且验证通过。
   - 未通过：达到最大轮次（5）。
   - 不收敛：连续 2 轮 high+ findings 数量不减少。
8. 异常矩阵统一 fail-close：
   - 工具不可用、`codex:adversarial-review` 插件未安装或非零退出码、单轮评审超过 300 秒、单轮修复超过 600 秒、非 JSON、缺关键字段：立即终止，报告退出码或原始输出摘要。
   - `codex` 路径失败：禁止静默切换；只允许通过 `AskUserQuestion` 由用户显式改用自评审。
   - 用户中止或异常终止：保留现场，不执行恢复；报告 `baseline_ref`、`stash_ref`、`staged_stash_ref`、当前轮次和已完成 commit，并提示 `git stash pop` 或 `git reset --soft <baseline_ref>`。
9. 退出恢复：
   - 正常终止、达到最大轮次或不收敛时，保留已生成的修复 commit。
   - `stash_ref != null` 时先执行 `git stash pop` 恢复 working tree；`staged_stash_ref != null` 时再执行 `git stash pop` 恢复 staged changes。任一步冲突都只报告冲突文件和 `git stash show` 结果，不自动解决。

## 输出

最终报告必须包含以下字段，并保持可审计：
- `结果：通过 | 未通过 | 不收敛`
- `总轮次：N`
- `各轮统计：[R1 ... -> RN ...]`
- `改动文件：[file1, file2, ...]`
- `验证命令：<command> (exit code)`
- `基线：baseline_ref=... , stash_ref=... , staged_stash_ref=... | 无 stash`
- `恢复状态：stash pop 成功 | 冲突(files: ...) | 无需恢复`
- `residual findings：[完整列表，含 non-blocking 摘要]`
- `跳过的 findings：[skipped:unlocatable 列表（如有）]`

## 完成校验

- [ ] `AskUserQuestion` 已锁定评审路径、focus、验证命令和收敛标准
- [ ] `codex:adversarial-review` 或自评审路径的 I/O 契约已按插件 schema 校验
- [ ] 只修复了 `high`+ findings（confidence >= 0.6），且同文件按 `line_start` 降序处理
- [ ] 最大轮次（5）、连续 2 轮不减少和 fail-close 异常路径都有明确终态
- [ ] 最终报告包含 `baseline_ref`、`stash_ref`、恢复状态、`residual findings` 和 `跳过的 findings`

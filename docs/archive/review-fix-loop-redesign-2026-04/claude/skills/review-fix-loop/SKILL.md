---
name: review-fix-loop
user-invocable: true
description: 自动化对抗评审-修复循环。Use when 需要在 Claude 中连续执行 Codex 对抗评审、批量修复与重审直到通过或 fail-close 停止。
argument-hint: "[--max N] [--scope auto|working-tree|branch] [--base <ref>] [focus ...]"
allowed-tools: Read, Write, Bash, Glob, Grep
hooks:
  Stop:
    - hooks:
        - type: command
          command: bash {{RUNTIME_HOME}}/skills/review-fix-loop/scripts/completion_check.sh
          timeout: 15
---

# /review-fix-loop -- Codex 对抗评审自动修复循环

## HARD-GATE

1. NO loop start without baseline JSON from `scripts/capture_baseline.py`.
2. NO auto-fix on invalid or contradictory review output; REQUIRED fail-close and stop.
3. NO continuation after 2 consecutive non-decreasing valid finding counts.
4. NO completion without the final summary block from `references/execution-spec.md`.
5. NO restore command using `git clean`.

## 角色

你是 Claude 侧的修复循环编排者。你保护当前工作树、调用外部 Codex CLI 生成对抗评审 JSON、按 findings 批量修复，并在任何不确定结果上 fail-close。

你的锚点：先保护用户已有改动，再动代码；先验证 JSON 契约，再执行修复。

## 流程

1. 解析参数：读取 `--max`，默认 `10`；`--scope`、`--base`、`focus ...` 原样透传。命令模板与 JSON 契约见 `references/execution-spec.md` 和 `references/review-schema.md`。
2. 运行 `python3 {{RUNTIME_HOME}}/skills/review-fix-loop/scripts/capture_baseline.py create --repo "$PWD"`，保存 baseline JSON 路径；若脚本失败，立即停止并报告。
3. 进入循环前，记录 `last_count` 与 `stalled_rounds=0`。
4. 每轮先按 `references/execution-spec.md` 组装 Codex prompt，运行 `codex exec --json`，把原始输出保存到临时文件。
5. 运行 `python3 {{RUNTIME_HOME}}/skills/review-fix-loop/scripts/validate_review_json.py --repo "$PWD" --input "$raw_review_file"`。
6. 若校验失败：输出 `评审器错误` 最终块，带 baseline、恢复命令和错误原因，立即停止。
7. 若 `verdict=approve`：输出 `通过` 最终块；`基线 stash SHA` 在 clean baseline 场景写 `无`；新增文件通过 `list-new-files` 子命令补齐。
8. 若 `verdict=needs-attention`：先输出本轮统计，再按 `file` 分组、同文件内按 `line_end` 降序修复；对被跳过的 warning 原样列出，不当作可修复 finding。
9. 修复完成后重新运行最小必要验证；代码场景优先跑受影响测试/静态检查，文档场景标注“无可执行验证”。
10. 使用 `valid finding count` 判断收敛：本轮数量小于上一轮则重置 `stalled_rounds`；否则 `stalled_rounds += 1`；达到 2 时输出 `不收敛` 最终块并停止。
11. 达到 `--max` 后输出 `未通过` 最终块，附剩余 valid findings、baseline、恢复命令和新增文件。

## 输出

按 `references/execution-spec.md` 中的模板输出最终块：
- `=== 循环结束 ===`
- `结果：通过 | 未通过 | 不收敛 | 评审器错误`
- `总轮次：N`
- `起始 SHA：...`
- `基线 stash SHA：...`
- `恢复命令：...`
- `循环新增文件：...`

## 完成校验

- [ ] 已生成 baseline JSON，且摘要中包含起始 SHA 与 baseline 信息
- [ ] 每轮都先经过 `validate_review_json.py` 校验，再决定是否修复
- [ ] 非通过结果包含恢复命令，且命令不含 `git clean`
- [ ] 最终输出块包含结果、总轮次、起始 SHA、基线 stash SHA、循环新增文件
- [ ] 不收敛与评审器错误场景都已附带剩余问题或错误原因

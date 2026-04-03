# execution-spec -- review-fix-loop 执行规格

> 引用者：`review-fix-loop/SKILL.md`

## 参数契约

命令：

```text
/review-fix-loop [--max N] [--scope auto|working-tree|branch] [--base <ref>] [focus ...]
```

- `--max`：仅本 skill 消费，默认 `10`
- `--scope` / `--base` / `focus ...`：原样透传给 Codex 对抗评审 prompt

## Codex 调用模板

```bash
cat <<EOF | codex exec --json -c model_reasoning_effort="medium" - > "$raw_review_file"
You are an adversarial reviewer. Inspect the current repository state and return JSON only.

Review scope: ${scope:-auto}
Base ref: ${base:-<none>}
Focus:
${focus_block:-- none}

Return a single JSON object that matches this schema exactly:
$(cat "$SKILL_DIR/references/review-schema.md")
EOF
```

- Bash timeout：`300` 秒
- 原始输出保存为 JSONL；后续统一交给 `validate_review_json.py`
- 不使用 `/codex:...` slash command；统一走可测试的 `codex exec --json`

## 每轮输出模板

```text
=== 第 N/M 轮 ===
评审结果：needs-attention | approve
findings: X 个 (critical: N, high: N, medium: N, low: N)
warnings: Y 个
修复中...
修复完成，进入下一轮
```

## 最终输出模板

```text
=== 循环结束 ===
结果：通过 | 未通过 | 不收敛 | 评审器错误
总轮次：N
起始 SHA：abc1234
基线 stash SHA：def5678 | 无
恢复命令：git checkout -- . && git stash apply --index def5678
循环新增文件：[file1, file2] | []
```

- `恢复命令` 仅在 `未通过 | 不收敛 | 评审器错误` 场景输出
- clean baseline 场景的 `基线 stash SHA` 写 `无`
- `循环新增文件` 通过 `capture_baseline.py list-new-files` 生成

# fix-7

## 输入来源

- 历史报告：
  - `docs/hotfix-20260412-1712/fix-1.md`
  - `docs/hotfix-20260412-1712/fix-2.md`
  - `docs/hotfix-20260412-1712/fix-3.md`
  - `docs/hotfix-20260412-1712/fix-4.md`
  - `docs/hotfix-20260412-1712/fix-5.md`
  - `docs/hotfix-20260412-1712/fix-6.md`
- fresh proving command：`bash tests/test-skill-format-unification.sh`

## 与 fix-6 的差异

- `fix-6` 解决了剩余长编号句和高加粗比。
- 本轮失败不是排版密度，而是目标 skill 缺少格式门禁要求的 dot 流程图。

## 现象

### 问题 7

- 现象：`tests/test-skill-format-unification.sh` 失败。
- 证据：
  - 失败文本：`dot flow definition missing`
  - 文件：`community/superpowers/skills/verification-before-completion/SKILL.md`
  - 检查结果：文件内不存在 ` ```dot ` 或 `digraph`

## 假设验证

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1：测试误判，文件其实已经含 dot 图 | 搜索 ` ```dot ` 与 `digraph` | 排除。两者都不存在 |
| H2：可以通过修改测试放宽要求 | 对照统一格式门禁的适用范围 | 排除。该测试明确把该 skill 列入必须含 dot 图的目标集合 |
| H3：根因是 `verification-before-completion` 的流程图块在近期整理中被删掉或漂移掉了 | 通读 skill 内容，发现只有文字流程，没有图形流程块 | 确认 |

## 根因结论

- `failure_class`: `FIXABLE`
- 根因位置：
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/verification-before-completion/SKILL.md`
- 根因说明：
  - 该 skill 缺少统一格式门禁要求的 dot 流程图定义。
  - 因果链：流程图块缺失 -> 格式门禁命中 -> 测试失败。

## 修复四问

1. 根因是什么？
   - dot 流程图块缺失。
2. 修复是否完整？
   - 已在 `The Gate Function` 下补回完整 dot 图。
3. 是否引入新问题？
   - 低风险。只补充可视化流程说明，不改语义。
4. 是否需要补充测试覆盖？
   - 不需要新增测试；当前格式门禁已覆盖。

## 处置

- 为 `verification-before-completion` 补回 `digraph verification_before_completion`。

## RED / GREEN

- RED：
  - `bash tests/test-skill-format-unification.sh` 失败，提示 dot flow missing
- GREEN：
  - 待本轮 fresh proving command 重新执行并记录

## 回归影响范围

- 仅影响 `verification-before-completion` skill 的文档结构。
- 不影响 closeout 路由和验证语义。

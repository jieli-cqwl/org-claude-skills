# fix-8

## 输入来源

- 历史报告：
  - `docs/hotfix-20260412-1712/fix-1.md`
  - `docs/hotfix-20260412-1712/fix-2.md`
  - `docs/hotfix-20260412-1712/fix-3.md`
  - `docs/hotfix-20260412-1712/fix-4.md`
  - `docs/hotfix-20260412-1712/fix-5.md`
  - `docs/hotfix-20260412-1712/fix-6.md`
  - `docs/hotfix-20260412-1712/fix-7.md`
- fresh proving command：`bash tests/test-skill-format-unification.sh`

## 与 fix-7 的差异

- `fix-7` 补回了 `verification-before-completion` 的 dot 图。
- 本轮离线扫描显示目标集合里还剩 1 个同类缺口：`finishing-a-development-branch` 没有 dot 图。

## 现象

### 问题 8

- 现象：`tests/test-skill-format-unification.sh` 失败。
- 证据：
  - 失败文本：`dot flow definition missing in: community/superpowers/skills/finishing-a-development-branch/SKILL.md`
  - 离线扫描：目标集合中仅该文件缺少 ` ```dot ` 或 `digraph`

## 假设验证

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1：还有多份 target files 缺 dot 图 | 对 target files 做离线扫描 | 排除。只剩这一份 |
| H2：该 skill 可以不需要图，因为已有步骤文字说明 | 对照格式门禁目标集合 | 排除。该测试明确要求它也必须有 dot 图 |
| H3：根因是 `finishing-a-development-branch` 的流程图块缺失 | 搜索文件中的 ` ```dot ` 和 `digraph` | 确认 |

## 根因结论

- `failure_class`: `FIXABLE`
- 根因位置：
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/finishing-a-development-branch/SKILL.md`
- 根因说明：
  - 该 skill 缺少格式门禁要求的 dot 流程图。
  - 因果链：流程图块缺失 -> 格式门禁命中 -> 测试失败。

## 修复四问

1. 根因是什么？
   - `finishing-a-development-branch` 没有 dot 流程图。
2. 修复是否完整？
   - 已补充从 closeout gate 到 archive 路由的完整 dot 图。
3. 是否引入新问题？
   - 低风险。仅补充流程可视化。
4. 是否需要补充测试覆盖？
   - 不需要新增测试；格式门禁已覆盖。

## 处置

- 为 `finishing-a-development-branch` 补回 dot 图。

## RED / GREEN

- RED：
  - `bash tests/test-skill-format-unification.sh` 失败，提示 dot 图缺失
- GREEN：
  - 待本轮 fresh proving command 重新执行并记录

## 回归影响范围

- 仅影响 `finishing-a-development-branch` 的文档结构。
- 不影响 closeout 行为语义。

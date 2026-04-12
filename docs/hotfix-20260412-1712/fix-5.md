# fix-5

## 输入来源

- 历史报告：
  - `docs/hotfix-20260412-1712/fix-1.md`
  - `docs/hotfix-20260412-1712/fix-2.md`
  - `docs/hotfix-20260412-1712/fix-3.md`
  - `docs/hotfix-20260412-1712/fix-4.md`
- fresh proving command：
  - `bash tests/test-skill-format-unification.sh`
  - `bash tests/run-all.sh`

## 与 fix-4 的差异

- `fix-4` 已解决长编号句问题。
- 本轮发现同一个格式门禁还有第二层限制：加粗行占比不得超过 10%。

## 现象

### 问题 5

- 现象：`tests/test-skill-format-unification.sh` 失败。
- 证据：
  - 失败文本：`bold line ratio exceeds 10%`
  - 文件：`community/superpowers/skills/brainstorming/SKILL.md`
  - 统计：`bold=34, total=196`

## 假设验证

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1：是测试脚本统计错误，实际加粗密度并不高 | 阅读 `test-skill-format-unification.sh` 的 `bold / total <= 0.10` 规则，并统计 `brainstorming/SKILL.md` 的 `**` 行 | 排除。规则与失败输出一致 |
| H2：只要修掉 Checklist 的加粗标题就足够 | 查看 `rg -n '\\*\\*' brainstorming/SKILL.md` 的分布 | 排除。除了 Checklist，多个小节标签和自检编号也大量使用加粗 |
| H3：根因是 `brainstorming` skill 的视觉强调密度过高，不符合当前统一格式门禁 | 对照测试规则和命中文本分布 | 确认 |

## 根因结论

- `failure_class`: `FIXABLE`
- 根因位置：
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/brainstorming/SKILL.md`
- 根因说明：
  - `brainstorming` skill 在标题、编号项和小节标签上同时使用大量加粗，导致加粗行占比超出统一格式门禁上限。
  - 因果链：文档强调密度过高 -> 格式门禁统计超限 -> 测试失败。

## 修复四问

1. 根因是什么？
   - 加粗行太多，不符合 `<= 10%` 的统一格式要求。
2. 修复是否完整？
   - 已将 Checklist、Spec Self-Review 和多个小节标签的加粗降为普通文本。
3. 是否引入新问题？
   - 低风险。只改变视觉强调方式，不改流程语义。
4. 是否需要补充测试覆盖？
   - 不需要新增测试；现有格式门禁已覆盖。

## 处置

- 去掉高密度的加粗标记，保留内容和顺序不变。

## RED / GREEN

- RED：
  - `bash tests/test-skill-format-unification.sh` 失败，`bold line ratio exceeds 10%`
- GREEN：
  - 待本轮 fresh proving command 重新执行并记录

## 回归影响范围

- 影响范围仅限 `brainstorming` skill 的文档视觉格式。
- 不影响 skill 流程与路由合同。

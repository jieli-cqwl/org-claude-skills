# fix-4

## 输入来源

- 历史报告：
  - `docs/hotfix-20260412-1712/fix-1.md`
  - `docs/hotfix-20260412-1712/fix-2.md`
  - `docs/hotfix-20260412-1712/fix-3.md`
- fresh proving command：`bash tests/run-all.sh`

## 与 fix-3 的差异

- `fix-3` 解决的是 closeout 路由合同缺失。
- 本轮是新的独立失败：`brainstorming` skill 文档格式不符合统一门禁。

## 现象

### 问题 4

- 现象：`tests/run-all.sh` 在 `skill format unification test` 失败。
- 证据：
  - `/Users/lijieli/org-claude-skills/tests/test-skill-format-unification.sh:38-57`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/brainstorming/SKILL.md:27-35`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/brainstorming/SKILL.md:122-125`
  - 失败文本：`numbered step must use title + bullets, not one-line long sentence`

## 假设验证

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1：测试误判，编号清单虽然较长但仍符合格式要求 | 阅读 `test-skill-format-unification.sh` 的 awk 规则，确认是否只按“编号行长度 >= 80”判断 | 排除。规则明确要求编号行不能是长句 |
| H2：只有 Checklist 一处违反规则 | 检查同一文件的第二处告警区间 | 排除。`Spec Self-Review` 的 4 条编号也同样是长句 |
| H3：根因是 `brainstorming` skill 保留了旧版“一行编号句子”写法，未同步到统一格式 | 对照失败行与测试规则 | 确认 |

## 根因结论

- `failure_class`: `FIXABLE`
- 根因位置：
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/brainstorming/SKILL.md:27-35`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/brainstorming/SKILL.md:122-125`
- 根因说明：
  - 该 skill 仍使用“编号 + 长句”的旧写法。
  - `test-skill-format-unification.sh` 要求编号步骤写成“短标题 + 后续说明”的结构。
  - 因果链：skill 文档格式未统一 -> 格式门禁命中 -> `tests/run-all.sh` 失败。

## 修复四问

1. 根因是什么？
   - `brainstorming` skill 的两组编号清单未按统一格式拆分。
2. 修复是否完整？
   - 已覆盖本次失败命中的 Checklist 和 Spec Self-Review 两组编号清单。
3. 是否引入新问题？
   - 低风险。仅调整文档排版结构，不改流程语义。
4. 是否需要补充测试覆盖？
   - 不需要新增测试；现有格式门禁已覆盖。

## 处置

- 将两组长编号句拆成“编号标题 + 下方 bullets 说明”。

## RED / GREEN

- RED：
  - `bash tests/run-all.sh` 失败于 `skill format unification test`
- GREEN：
  - 待本轮 fresh proving command 重新执行并记录

## 回归影响范围

- 影响范围仅限 `brainstorming` skill 的文档格式。
- 不影响 skill 流程逻辑与其他门禁脚本。

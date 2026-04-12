# fix-6

## 输入来源

- 历史报告：
  - `docs/hotfix-20260412-1712/fix-1.md`
  - `docs/hotfix-20260412-1712/fix-2.md`
  - `docs/hotfix-20260412-1712/fix-3.md`
  - `docs/hotfix-20260412-1712/fix-4.md`
  - `docs/hotfix-20260412-1712/fix-5.md`
- fresh proving command：
  - `bash tests/test-skill-format-unification.sh`

## 与 fix-5 的差异

- `fix-5` 解决了 `brainstorming` 的高密度加粗。
- 本轮扩大离线扫描后，发现格式门禁剩余问题并不只在 `brainstorming`，还分布在另外 2 个 community superpowers skills。

## 现象

### 问题 6

- 现象：`tests/test-skill-format-unification.sh` 继续失败。
- 证据：
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/subagent-driven-development/SKILL.md:132`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/using-superpowers/SKILL.md:26-27`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/using-superpowers/SKILL.md:105-106`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/finishing-a-development-branch/SKILL.md` 的 bold ratio 超标

## 假设验证

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1：当前 blocker 只在 `subagent-driven-development` 一处 | 用与测试相同的规则离线扫描全部 target files | 排除。还命中了 `using-superpowers` 和 `finishing-a-development-branch` |
| H2：`finishing-a-development-branch` 的 bold ratio 是统计噪音 | 统计 `**` 行数与总行数 | 排除。`29/220=0.132`，确实超限 |
| H3：根因是多份 skill 仍残留旧版文档格式，没有和统一门禁一起收敛 | 对照离线扫描结果 | 确认 |

## 根因结论

- `failure_class`: `FIXABLE`
- 根因位置：
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/subagent-driven-development/SKILL.md:132-135`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/using-superpowers/SKILL.md:26-28`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/using-superpowers/SKILL.md:105-106`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/finishing-a-development-branch/SKILL.md`
- 根因说明：
  - 多份 community superpowers skills 仍保留旧版长编号句或高密度加粗。
  - 因果链：文档格式未统一 -> `test-skill-format-unification.sh` 逐个命中 -> 全量回归失败。

## 修复四问

1. 根因是什么？
   - 多个 skill 仍残留不符合统一格式门禁的旧排版。
2. 修复是否完整？
   - 已覆盖离线扫描命中的全部剩余文件。
3. 是否引入新问题？
   - 低风险。仅调整文档结构与强调样式，不改流程语义。
4. 是否需要补充测试覆盖？
   - 不需要新增测试；现有格式门禁已覆盖。

## 处置

- 将剩余长编号句改为“短标题 + bullets”。
- 降低 `finishing-a-development-branch` 的加粗密度。

## RED / GREEN

- RED：
  - `bash tests/test-skill-format-unification.sh` 继续失败
- GREEN：
  - 待本轮 fresh proving command 重新执行并记录

## 回归影响范围

- 仅影响 community superpowers skills 的文档格式。
- 不影响测试脚本、安装链路或业务技能逻辑。

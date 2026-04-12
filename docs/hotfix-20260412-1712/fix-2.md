# fix-2

## 输入来源

- 历史报告：`docs/hotfix-20260412-1712/fix-1.md`
- fresh proving command：`bash tests/run-all.sh`
- 新失败阶段：`[8/35] runtime integrity test`

## 与 fix-1 的差异

- `fix-1` 已修复 `shellcheck` 的 `SC2016`，并验证全量回归可穿过第 2 步。
- 本轮不是复用上次方案，而是处理后续测试中新暴露的独立失败：运行时技能合同文案缺失。

## 现象

### 问题 2

- 现象：`tests/test-runtime-integrity.sh` 失败，提示安装后的运行时技能副本缺少契约文案。
- 证据：
  - `/Users/lijieli/org-claude-skills/tests/test-runtime-integrity.sh:444`
  - 失败文本：`missing runtime pattern ... Require verify-change PASS`
  - 对照目标：`/Users/lijieli/org-claude-skills/community/superpowers/skills/finishing-a-development-branch/SKILL.md:199`

## 假设验证

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1：安装过程漏同步，运行时文件和仓库源文件不一致 | 检查失败断言对应的源 skill 文本，确认仓库源文件本身是否含 `Require verify-change PASS` | 排除。源 skill 本身就没有这句文案 |
| H2：测试断言过时，skill 当前表述已完全覆盖相同合同 | 全仓搜索 `Require verify-change PASS`、`verify-change PASS` 和当前 skill 表述，比较契约强度 | 部分排除。当前 skill 只有“after the small-chain gate passes”这种隐含表述，缺少显式 hard requirement |
| H3：根因是 `finishing-a-development-branch` 的 closeout 契约表达被弱化，导致运行时完整性测试无法确认门禁顺序 | 对照 `tests/test-runtime-integrity.sh:439-445` 的 closeout 链断言，确认该 skill 需要作为 `verification-before-completion -> verify-change -> finishing-a-development-branch` 的明确下一环 | 确认 |

## 根因结论

- `failure_class`: `FIXABLE`
- 根因位置：
  - `/Users/lijieli/org-claude-skills/tests/test-runtime-integrity.sh:444`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/finishing-a-development-branch/SKILL.md:199`
- 根因说明：
  - `test-runtime-integrity.sh` 要求运行时 skill 明确声明“先通过 `verify-change`，再进入 branch 收尾”。
  - `finishing-a-development-branch/SKILL.md` 只保留了隐含描述，没有显式的 `Require verify-change PASS` 文案。
  - 因果链：skill 契约文案弱化 -> 安装后的运行时副本同样缺失该文案 -> runtime integrity test 失败。

## 修复四问

1. 根因是什么？
   - `finishing-a-development-branch` skill 缺少显式的 `verify-change PASS` 前置约束文案。
2. 修复是否完整？
   - 已在 skill 的 `Integration -> Called by` 处补回显式要求。
3. 是否引入新问题？
   - 低风险。仅强化 closeout 顺序说明，不改命令流程。
4. 是否需要补充测试覆盖？
   - 不需要新增测试；现有 `test-runtime-integrity.sh` 和 `tests/run-all.sh` 已覆盖该合同。

## 处置

- 在 `community/superpowers/skills/finishing-a-development-branch/SKILL.md` 中补充：
  - `Require verify-change PASS before using this skill`

## RED / GREEN

- RED：
  - `bash tests/run-all.sh` 失败于 `runtime integrity test`
  - `tests/test-runtime-integrity.sh:444` 断言缺失 `Require verify-change PASS`
- GREEN：
  - 待本轮 fresh proving command 重新执行并记录

## 回归影响范围

- 受影响范围限于 closeout skill 文案与运行时镜像完整性。
- 不影响安装脚本、hook、gate 或业务技能逻辑。

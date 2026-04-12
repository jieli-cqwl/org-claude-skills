# fix-3

## 输入来源

- 历史报告：
  - `docs/hotfix-20260412-1712/fix-1.md`
  - `docs/hotfix-20260412-1712/fix-2.md`
- fresh proving command：
  - `bash tests/test-runtime-integrity.sh`
  - `bash tests/test-closeout-routing.sh`

## 与 fix-2 的差异

- `fix-2` 补回了 `Require verify-change PASS`。
- 本轮发现 closeout 链还缺少一层显式条件：当 small-chain 工件存在时，`finishing-a-development-branch` 必须明确说明“此时不要直接给 merge/PR/cleanup 选项”。

## 现象

### 问题 3

- 现象：`tests/test-closeout-routing.sh` 失败。
- 证据：
  - `/Users/lijieli/org-claude-skills/tests/test-closeout-routing.sh:42`
  - `/Users/lijieli/org-claude-skills/tests/test-closeout-routing.sh:43`
  - 缺失模式：
    - `If \`design.md\`, \`tasks.md\`, and \`plan.md\` exist`
    - `do not present merge/PR/cleanup options yet`

## 假设验证

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1：只是测试文案过时，当前 skill 已经等价表达该含义 | 通读 `finishing-a-development-branch/SKILL.md` 的 Overview、Process、Integration | 排除。只有 `verify-change PASS`，没有“若工件存在则先走 verify-change、暂不提供收尾选项”的完整显式表述 |
| H2：这是 `verify-change` 的职责，不需要在 `finishing-a-development-branch` 再次声明 | 检查 `test-closeout-routing.sh` 的断言组合和顺序 | 排除。该测试明确要求 `finishing-a-development-branch` 自身带这一前置门禁说明 |
| H3：根因是 closeout 链的显式路由信息在 `finishing-a-development-branch` 上仍不完整 | 对照 `verification-before-completion -> verify-change -> finishing-a-development-branch -> archive` 的预期 | 确认 |

## 根因结论

- `failure_class`: `FIXABLE`
- 根因位置：
  - `/Users/lijieli/org-claude-skills/tests/test-closeout-routing.sh:42-43`
  - `/Users/lijieli/org-claude-skills/community/superpowers/skills/finishing-a-development-branch/SKILL.md:11-19`
- 根因说明：
  - `finishing-a-development-branch` 缺少 closeout gate 的显式说明，导致路由顺序只在相邻 skill 中成立，而在本 skill 内不完整。
  - 因果链：本 skill 缺少工件存在时的前置门禁说明 -> closeout routing test 无法确认顺序合同 -> 测试失败。

## 修复四问

1. 根因是什么？
   - `finishing-a-development-branch` 没有显式写出“工件存在时先 verify-change，且先不要给 merge/PR/cleanup 选项”。
2. 修复是否完整？
   - 已在 skill 顶部新增 `Closeout Gate`，同时覆盖前置条件和禁止动作。
3. 是否引入新问题？
   - 低风险。仅补充 closeout 路由约束，不改执行流程。
4. 是否需要补充测试覆盖？
   - 不需要新增测试；`test-closeout-routing.sh` 已直接覆盖。

## 处置

- 在 `community/superpowers/skills/finishing-a-development-branch/SKILL.md` 中新增：
  - `If \`design.md\`, \`tasks.md\`, and \`plan.md\` exist`
  - `do not present merge/PR/cleanup options yet`

## RED / GREEN

- RED：
  - `bash tests/test-closeout-routing.sh` 失败
- GREEN：
  - 待本轮 fresh proving command 重新执行并记录

## 回归影响范围

- 受影响范围仅限 closeout skill 的路由说明与运行时镜像完整性。
- 不影响分支操作命令本身。

# fix-9

## 输入来源

- 历史报告：
  - `docs/hotfix-20260412-1712/fix-1.md`
  - `docs/hotfix-20260412-1712/fix-2.md`
  - `docs/hotfix-20260412-1712/fix-3.md`
  - `docs/hotfix-20260412-1712/fix-4.md`
  - `docs/hotfix-20260412-1712/fix-5.md`
  - `docs/hotfix-20260412-1712/fix-6.md`
  - `docs/hotfix-20260412-1712/fix-7.md`
  - `docs/hotfix-20260412-1712/fix-8.md`
- fresh proving command：`bash tests/run-all.sh`

## 与 fix-8 的差异

- `fix-8` 解决了 skill format unification 的最后一个 dot 缺口。
- 本轮新失败来自 runtime integrity：运行时 skill 副本中仍存在仓库真源路径 `shared/reference/...`。

## 现象

### 问题 9

- 现象：`tests/run-all.sh` 失败于 `runtime integrity test`
- 证据：
  - 失败文本：`should not retain bare runtime doc references`
  - 运行时副本命中：
    - `design/SKILL.md`
    - `tech-lead/SKILL.md`
    - `product/SKILL.md`
    - `delivery-owner/SKILL.md`
    - `test-design/SKILL.md`

## 假设验证

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1：是 runtime renderer 没有替换 `shared/reference/...` | 检查 `render_runtime_placeholders` 的替换规则 | 排除。renderer 只负责 `{{RUNTIME_HOME}}` 占位，不会改写裸真源路径 |
| H2：只有单个 skill 漏改 | 搜索相关 shared skills | 排除。共 5 个已安装 shared skills 都含同类裸路径 |
| H3：根因是部分 shared skills 仍沿用仓库内真源引用写法，没有切换到 runtime 占位路径 | 对照源文件命中行 | 确认 |

## 根因结论

- `failure_class`: `FIXABLE`
- 根因位置：
  - `/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md:91-95`
  - `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md:52-54`
  - `/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md:94-97`
  - `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md:56-58`
  - `/Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md:38-40`
- 根因说明：
  - 这些 skill 直接引用了仓库真源 `shared/reference/...`。
  - 安装到 runtime 后，这类路径不再成立，且会被 runtime integrity 视为“裸 runtime doc reference”。
  - 因果链：源 skill 保留真源路径 -> 安装后原样进入 runtime -> runtime integrity 失败。

## 修复四问

1. 根因是什么？
   - shared skills 中残留了 `shared/reference/...` 真源路径。
2. 修复是否完整？
   - 已覆盖当前 runtime integrity 命中的全部 5 个已安装 shared skills。
3. 是否引入新问题？
   - 低风险。仅把引用改成 runtime 占位路径。
4. 是否需要补充测试覆盖？
   - 不需要新增测试；`runtime integrity` 已覆盖该合同。

## 处置

- 将上述 5 个 skill 的引用统一改为 `{{RUNTIME_HOME}}/reference/...`。

## RED / GREEN

- RED：
  - `bash tests/run-all.sh` 失败于 bare runtime doc reference 检查
- GREEN：
  - 待本轮 fresh proving command 重新执行并记录

## 回归影响范围

- 仅影响 5 个 shared skills 的文档引用路径。
- 不影响 skill 流程逻辑与安装脚本行为。

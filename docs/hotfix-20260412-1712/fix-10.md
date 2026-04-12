# fix-10

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
  - `docs/hotfix-20260412-1712/fix-9.md`
- fresh proving command：
  - `bash tests/run-all.sh`
  - `bash tests/test-runtime-integrity.sh`

## 与 fix-9 的差异

- `fix-9` 已将 5 个 shared skill 主文档里的裸 `shared/reference/...` 改成 runtime 占位路径。
- 本轮不是复用上次方案，而是处理同类问题的残余漏网项：`delivery-owner` 的 reference 文档仍保留裸真源路径，所以 runtime integrity 在全量回归里继续失败。

## 现象

### 问题 10

- 现象：`tests/run-all.sh` 仍失败于 `runtime integrity test`。
- 证据：
  - 运行时命中：
    - `.claude/skills/delivery-owner/references/dispatch-guide.md:4`
    - `.claude/skills/delivery-owner/references/dispatch-guide.md:5`
  - 源文件命中：
    - `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/dispatch-guide.md:4`
    - `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/dispatch-guide.md:5`
  - 安装渲染逻辑：
    - `/Users/lijieli/org-claude-skills/install.sh:755-766`

## 假设验证

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1：`runtime integrity` 误报，命中的运行时文件并非来自仓库源文件 | 对照源文件 `dispatch-guide.md:4-5` 与运行时命中内容是否一致 | 排除。源文件与运行时副本命中内容一致，说明源文件残留会原样进入 runtime |
| H2：安装器会自动把裸 `shared/reference/...` 转换成 runtime 路径，只是这次安装异常 | 检查 `install.sh:755-766` 的 `render_runtime_placeholders` | 排除。该逻辑只替换 `{{RUNTIME_HOME}}` 和 `{{ENTRY_DOC}}`，不会改写裸真源路径 |
| H3：根因是 `delivery-owner/references/dispatch-guide.md` 仍残留裸 `shared/reference/...`，所以 `fix-9` 后仍有同类残余 | 检查源文件 `dispatch-guide.md:4-5` | 确认 |

## 根因结论

- `failure_class`: `FIXABLE`
- 根因位置：
  - `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/dispatch-guide.md:4`
  - `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/dispatch-guide.md:5`
  - `/Users/lijieli/org-claude-skills/install.sh:755-766`
- 根因说明：
  - `dispatch-guide.md` 仍直接引用仓库真源 `shared/reference/...`。
  - 安装器只会渲染 `{{RUNTIME_HOME}}` 占位，不会自动修正裸真源路径。
  - 因果链：reference 文档残留裸真源路径 -> 安装后原样保留到 runtime -> `runtime integrity` 继续命中并失败。

## 修复四问

1. 根因是什么？
   - `delivery-owner` 的 reference 文档还有 2 处裸 `shared/reference/...` 漏改。
2. 修复是否完整？
   - 已把这 2 处改为 `{{RUNTIME_HOME}}/reference/...`，覆盖本轮唯一残余命中点。
3. 是否引入新问题？
   - 低风险。只调整文档引用路径，不改 skill 流程和安装脚本逻辑。
4. 是否需要补充测试覆盖？
   - 不需要新增测试；`test-runtime-integrity.sh` 与 `tests/run-all.sh` 已覆盖该合同。

## 处置

- 将 `shared/skills/delivery-owner/references/dispatch-guide.md` 中的 2 处裸真源路径改为 runtime 占位路径。

## RED / GREEN

- RED：
  - `bash tests/run-all.sh` 失败于 `runtime integrity test`
  - 运行时副本 `.claude/skills/delivery-owner/references/dispatch-guide.md:4-5` 仍命中裸 `shared/reference/...`
- GREEN：
  - 待本轮 fresh proving command 重新执行并记录

## 回归影响范围

- 仅影响 `delivery-owner` reference 文档的运行时引用路径。
- 不影响 `delivery-owner` 的派发流程、模板内容和安装脚本行为。

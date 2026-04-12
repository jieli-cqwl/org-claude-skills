# fix-2

## 输入分析

- 输入来源清单：
  - 历史诊断报告：`docs/hotfix-20260412-1735-hook-permission-denied/fix-1.md`
  - fresh RED：
    - `bash tests/test-install-smoke.sh`
  - fresh GREEN / 回归：
    - `bash tests/test-install-smoke.sh`
    - `bash tests/test-install-systematic.sh`
    - `bash tests/test-runtime-integrity.sh`
- `work_dir` 解析结果：`docs/hotfix-20260412-1735-hook-permission-denied`
- 问题数量汇总：1

差异说明（N > 1 时 REQUIRED）:
- `fix-1` 只完成根因定位，确认问题位于 `claude/hooks/block_dangerous.sh:7` 对非可执行 managed 脚本的直接 `exec`，并确认安装/测试门禁未覆盖执行权限。
- 本轮没有沿用“只修下游文件权限”的临时方案，而是升级为源头修复：
  - 仓库源文件补执行位；
  - Claude wrapper 改为显式 `bash` 转调 managed 脚本；
  - 安装完整性判断与 quick check 增加 `-x` 校验；
  - 安装/运行时测试增加执行权限与 smoke 运行断言。

## 诊断阶段

### 环境快照
- 当前分支：`main`
- 工作树状态：
  - 已修改：`claude/hooks/block_dangerous.sh`
  - 已修改：`shared/hooks/managed/block_dangerous.sh`
  - 已修改：`install.sh`
  - 已修改：`tests/test-install-smoke.sh`
  - 已修改：`tests/test-install-systematic.sh`
  - 已修改：`tests/test-runtime-integrity.sh`
- 最近 5 条提交：
  - `4f58ed9 chore: sync runtime cleanup and delivery docs`
  - `db02599 refactor: rename project-manager to delivery-owner`
  - `7cf86a9 chore: commit pending repository updates`
  - `debdfd2 chore: sync workspace changes and eval assets`
  - `fa94c88 feat: rebuild project-manager delivery owner gates`
- 最近改动文件：
  - `claude/hooks/block_dangerous.sh`
  - `shared/hooks/managed/block_dangerous.sh`
  - `install.sh`
  - `tests/test-install-smoke.sh`
  - `tests/test-install-systematic.sh`
  - `tests/test-runtime-integrity.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | Claude `block_dangerous` hook 在下游运行时报 `Permission denied` | 在安装回归里执行 `bash tests/test-install-smoke.sh`，并让测试显式要求 installed hook 可执行 | RED 阶段测试失败；失败前安装 quick check 仍显示通过，证明旧门禁没有覆盖执行权限 |

当前环境复现结论:
- 可复现/不可复现: 可复现
- 不可复现时环境差异证据: 不适用

### 假设验证过程
每个问题至少 2 个已验证假设（结果为排除/确认/未决）。
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | Claude hook 权限报错 | H1：只给下游已安装文件补 `chmod +x` 就足够 | 对照 `fix-1` 的调用链，审查 `claude/hooks/block_dangerous.sh:7` 的直接 `exec` 行为 | 排除。仅修下游文件权限不能防止后续安装再次分发 0644 文件，也不能提升 wrapper 的容错性 |
| 1 | Claude hook 权限报错 | H2：需要从仓库源文件、安装检查、回归测试三个层面一起修 | 在 RED 测试中加入 `-x` 与 smoke 断言，再检查 `install.sh` 的完整性判断与 quick check | 确认 |
| 1 | Claude hook 权限报错 | H3：Codex 侧虽然当前不报错，但同一个 managed 脚本也应纳入门禁 | 检查 `shared/hooks/managed/block_dangerous.sh` 的仓库 mode、Codex 安装路径和 `hooks.json` 引用 | 确认。Codex 走同一 managed 脚本，补 `-x` 门禁可以一起兜住 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | Claude `block_dangerous` hook `Permission denied` | `/Users/lijieli/org-claude-skills/claude/hooks/block_dangerous.sh:7` | 安装后 Claude 通过 `bash ~/.claude/hooks/block_dangerous.sh` 进入 wrapper -> wrapper 直接 `exec` non-executable managed script -> managed 脚本源文件与安装产物都是 `0644` -> 运行时 `Permission denied`；同时 `install.sh` 与安装测试只验证存在，不验证可执行/可实际运行 | `shared/hooks/registry.json:158-163` 定义 Claude 入口；`claude/hooks/block_dangerous.sh:7` 调到 managed；`install.sh:1312-1315`、`install.sh:1642-1645` 是完整性与 quick check 新旧门禁位置；`git diff --summary` 显示本轮已把两个脚本 mode 从 `100644` 调整为 `100755` |

## 处置阶段

### 决策
- 处置策略选择 + 优先级排序：
  1. 先让测试显式失败，锁定“可执行 + 可运行”这两个验收点。
  2. 以最小改动修 wrapper 调用方式和源文件 mode。
  3. 把安装完整性判断和 quick check 升级为 `-x` 校验。
  4. 扩大到安装烟测、系统化安装测试、runtime integrity 三组回归。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | Claude `block_dangerous` hook `Permission denied` | FIXABLE | 已完成 TDD 修复并跑回归 |

### FAIL-1: Claude `block_dangerous` hook 权限错误

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `claude/hooks/block_dangerous.sh:7` 直接 `exec` 非可执行的 managed 脚本，而安装链路把该 managed 脚本以 `0644` 分发出去 |
| 2 | 修复是否完整？ | 本轮同时覆盖 Claude wrapper、shared managed 脚本 mode、安装完整性判断、quick check、安装烟测、系统化安装测试和 runtime integrity |
| 3 | 是否引入新问题？ | 风险低。改动只影响 dangerous hook 的启动方式与安装校验，不改变拦截规则本身 |
| 4 | 是否需要补充测试覆盖？ | 已补。新增 `-x` 与 smoke 执行断言，覆盖 Claude 与 Codex 两侧安装产物 |

RED: 
- 命令：`bash tests/test-install-smoke.sh`
- 结果：失败
- 证据：测试新增的 `test -x "$TMP_HOME/.claude/hooks/block_dangerous.sh"` 在旧实现下未通过，且安装阶段 quick check 仍为绿色，证明旧门禁漏检

GREEN:
- 命令：`bash tests/test-install-smoke.sh`
- 结果：`rc=0`
- 关键输出：`[PASS] install/uninstall smoke`

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | Claude `block_dangerous` hook 权限错误 | wrapper 对 non-executable managed 脚本直接 `exec`，且安装门禁未检查执行权限 | `claude/hooks/block_dangerous.sh`、`shared/hooks/managed/block_dangerous.sh`、`install.sh`、`tests/test-install-smoke.sh`、`tests/test-install-systematic.sh`、`tests/test-runtime-integrity.sh` | `tests/test-install-smoke.sh`、`tests/test-install-systematic.sh`、`tests/test-runtime-integrity.sh` |

### 全量测试结果
TEST_CMD: `bash tests/test-install-smoke.sh && bash tests/test-install-systematic.sh && bash tests/test-runtime-integrity.sh`

- `bash tests/test-install-smoke.sh`
  - 结果：通过
  - 关键输出：`[PASS] install/uninstall smoke`
- `bash tests/test-install-systematic.sh`
  - 结果：通过
  - 关键输出：`Systematic tests passed: 18, skipped: 0`
- `bash tests/test-runtime-integrity.sh`
  - 结果：通过
  - 关键输出：`[PASS] runtime integrity`

通过: 3 / 失败: 0 / 跳过: 0

### 阻断清单（全部/部分非 FIXABLE 时必填）
- 无

### 交接项清单
- 根因分析结论与定位文件:行号
  - `/Users/lijieli/org-claude-skills/claude/hooks/block_dangerous.sh:7`
  - `/Users/lijieli/org-claude-skills/install.sh:1312-1315`
  - `/Users/lijieli/org-claude-skills/install.sh:1642-1645`
- 修复范围与回归测试清单
  - wrapper 改为 `exec bash ...`
  - 两个 hook 脚本 mode 改为 `100755`
  - 安装完整性判断与 quick check 增加 `-x`
  - 3 组回归补充 `-x` 与 smoke 断言
- 非 FIXABLE 问题的后续处理动作
  - 无

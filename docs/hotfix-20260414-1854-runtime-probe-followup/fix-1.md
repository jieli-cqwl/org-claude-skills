# fix-1.md

## 输入分析
- 输入来源清单：
  - 用户要求继续跟进“`bash install.sh --target all --check full` 的失败”和安装后 runtime probe 的失败/告警
  - 失败命令：`bash install.sh --target all --check full`
  - 失败/告警探针：`bash tools/dev/probe-claude-capabilities.sh .`、`bash tools/dev/probe-codex-capabilities.sh .`、`bash tools/dev/probe-codex-hooks.sh`
- work_dir 解析结果：`docs/hotfix-20260414-1854-runtime-probe-followup`
- 问题数量汇总：4

差异说明（N > 1 时 REQUIRED）:
- N/A，本轮为该 hotfix 目录的首轮修复。

## 诊断阶段

### 环境快照
- 当前分支：`main`
- 工作树状态：
  - `M tests/test-delivery-owner-phase3-contract.sh`
  - `M tests/test-runtime-reference-activation.sh`
  - `M tests/test-skill-output-and-gate-contract.sh`
  - `M tools/dev/probe-claude-capabilities.sh`
  - `M tools/dev/probe-codex-capabilities.sh`
  - `M tools/dev/probe-codex-hooks.sh`
- 最近 5 条提交：
  - `2a85c08 feat: add developer execution decomposition guidance`
  - `c7575ec feat: harden product and tech-lead goal evidence contracts`
  - `a0234fe docs: add contract foundation and research artifacts`
  - `d9493a8 docs: add product tech-lead goal evidence hardening design`
  - `ae6ba67 docs: add notebooklm skill research report`
- 最近改动文件：
  - `tests/test-delivery-owner-phase3-contract.sh`
  - `tests/test-runtime-reference-activation.sh`
  - `tests/test-skill-output-and-gate-contract.sh`
  - `tools/dev/probe-claude-capabilities.sh`
  - `tools/dev/probe-codex-capabilities.sh`
  - `tools/dev/probe-codex-hooks.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | `full check` 被 shellcheck 拦截 | 运行 `bash install.sh --target all --check full` | 先后命中 `tests/test-delivery-owner-phase3-contract.sh` 的 `SC2016` 和 `tests/test-skill-output-and-gate-contract.sh` 的 `SC2034`。 |
| 2 | Claude rule runtime probe 假失败 | 运行 `bash tools/dev/probe-claude-capabilities.sh .` | 旧实现曾返回 `RULE_REF_MISSING`，说明入口 follow-file 逻辑没有走到二次读取 reference。 |
| 3 | Claude capability probe 在第二个 probe-home 上清理失败 | 运行 `bash tools/dev/probe-claude-capabilities.sh .` | 在 `Rule Absolute Runtime Link Activation` 前出现 `rm: ... Directory not empty`，脚本因 `set -e` 退出。 |
| 4 | Codex hooks / capabilities probe 假告警或超时 | 运行 `bash tools/dev/probe-codex-hooks.sh`、`bash tools/dev/probe-codex-capabilities.sh .` | 旧 `probe-codex-hooks.sh` 输出 `[rc=124]` 且只有 `SessionStart`；旧 capability probe 还会递归复制整份 `~/.codex`，在大运行面上放大超时概率。 |

当前环境复现结论:
- 可复现：是。修复前已分别复现 shellcheck、Codex hooks `rc=124`、Claude probe-home 清理失败，以及 Claude rule probe 的假失败。
- 不可复现时环境差异证据：无。

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | shellcheck 拦截 | `SC1091` 才是 full check 主阻塞 | 对照 `tests/run-all.sh:50-80` 的 `shellcheck -x` 调用方式，再单独跑 `shellcheck -x ...` | 排除。full check 主阻塞是 `SC2016/SC2034`，不是 `SC1091`。 |
| 1 | shellcheck 拦截 | `SC2016` 来自真正的变量展开 bug | 检查 `tests/test-delivery-owner-phase3-contract.sh:190,236-244` 的 grep 目标是否是“脚本文本字面量” | 排除。这里是在断言脚本源码文本，应该匹配字面量 `"$var"`。 |
| 1 | shellcheck 拦截 | `SC2034` 只是误报 | 检查 `tests/test-skill-output-and-gate-contract.sh:1946-1962` | 排除。`delivery-status-summary.md` 用的是 `<<'EOF'`，`$status_summary_task_state` 根本没展开，变量确实未被消费。 |
| 2 | Claude rule probe 假失败 | Claude runtime rules/reference 真失效 | 先看 `Entry Absolute Runtime Link Activation` 是否通过，再看旧输出是否能读到 rule 文件 | 排除。入口 probe 通过，旧输出也能读到 `rules/铁律.md`。 |
| 2 | Claude rule probe 假失败 | entry follow-file 提示和 rule 内 probe 提示彼此冲突 | 检查 `tools/dev/probe-claude-capabilities.sh:34-56` 与 `:59-81`，并对照旧输出中“读完 rule 后直接回 `RULE_REF_MISSING`” | 确认。入口要求“只用一次 Bash”，而 rule probe 又要求再用一次 Bash 读取 reference，形成自相矛盾。 |
| 3 | Claude probe-home 清理失败 | runtime hooks 本身损坏 | 用同构命令单独复现全局 hooks | 排除。独立命令完整触发了 `PreToolUse/PostToolUse/Stop`。 |
| 3 | Claude probe-home 清理失败 | 同一 `probe-home` 被 entry/rule 两轮复用，删除时撞上残留目录 | 检查 `tools/dev/probe-claude-capabilities.sh` 原先两处都用 `"$TMP_ROOT/probe-home"`，并复现 `rm: Directory not empty` | 确认。复用同一路径导致第二次 `rm -rf` 撞上残留 `.npm/_npx/...`。 |
| 4 | Codex hooks / capabilities 假告警 | hooks runtime 真只支持 `SessionStart` | 单独运行 `bash tools/dev/probe-codex-hooks.sh`，读取事件日志 | 排除。把超时放宽后可捕获 `SessionStart/PreToolUse/PostToolUse/Stop` 全套事件。 |
| 4 | Codex hooks / capabilities 假告警 | `probe-codex-hooks.sh` 的 20 秒超时过短 | 检查 `tools/dev/probe-codex-hooks.sh:117-125`，并复现旧输出 `[rc=124]` | 确认。20 秒内来不及完成一次 `codex exec`。 |
| 4 | Codex capabilities 慢 | 能力脚本复制整份运行目录导致放大耗时 | 检查旧 `tools/dev/probe-codex-capabilities.sh` 的 `cp -R "$CODEX_HOME"`，以及旧 `tools/dev/probe-claude-capabilities.sh` 的 `cp -R "$HOME/.codex"` | 确认。当前 `~/.codex` 约 `3.2G`，整目录复制是不必要的 accidental complexity。 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | shellcheck 拦截 | `tests/test-delivery-owner-phase3-contract.sh:190,236-244`；`tests/test-skill-output-and-gate-contract.sh:1623-1641,1946-1962` | phase3 contract 测试本意是匹配 shell 源码中的字面量变量引用，却使用会触发 `SC2016` 的单引号形式；另一个测试把 `status_summary_task_state` 写进了单引号 heredoc，导致变量未展开、赋值无效。 | 静态追踪：`tests/run-all.sh:50-80` 把这两个脚本纳入 `shellcheck -x`；`delivery-status-summary.md` 模板在 `1946-1962` 处直接消费 `status_summary_task_state`。 |
| 2 | Claude rule probe 假失败 | `tools/dev/probe-claude-capabilities.sh:34-56,59-81` | 入口 `prepend_follow_file_probe()` 生成的 prompt 只允许一次 Bash；被读取的 rule 文档又要求再用 Bash 读取 reference，导致 agent 在完成第一次 Bash 后只能走 fallback。 | 静态追踪：`probe_rule_reference_activation()` 在 `404-428` 先用 `prepend_read_reference_probe()` 改写 rule，再用 `prepend_follow_file_probe()` 改写 entry。 |
| 3 | Claude probe-home 清理失败 | `tools/dev/probe-claude-capabilities.sh:348,404` | entry/rule 两个 probe 共用同一个 `probe-home`，第二轮准备时删除上一次目录，撞上仍残留的 `.npm/_npx/...`，在 `set -e` 下中断。 | 静态追踪：两处 probe 入口都解析为 `probe_home`，且都会调用 `prepare_probe_home()`。 |
| 4 | Codex hooks / capabilities 假告警 | `tools/dev/probe-codex-hooks.sh:117-125`；`tools/dev/probe-codex-capabilities.sh:145-175`；`tools/dev/probe-claude-capabilities.sh:91-127` | hooks 探针把一次完整 `codex exec` 限制在 20 秒内，直接导致 `rc=124`；两套 capability probe 又复制整份运行目录，把运行面大小无关地放大成超时风险。 | 静态追踪：`probe-codex-capabilities.sh` 的 `probe_entry_reference_activation()/probe_rule_reference_activation()` 都依赖 `prepare_probe_home()`；旧实现直接 `cp -R "$CODEX_HOME"`。 |

## 处置阶段

### 决策
- 处置策略：保持 probe 语义不变，做最小必要修复。
- 修复优先级：
  1. 先清 `shellcheck` 硬阻塞
  2. 再修 Claude/Codex probe 的假失败与超时
  3. 最后回跑最重 proving command `bash install.sh --target all --check full`

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | shellcheck 拦截 | FIXABLE | 改成字面量安全写法，并让 heredoc 真正展开变量。 |
| 2 | Claude rule probe 假失败 | FIXABLE | 放宽 follow-file 提示，允许按需要继续读取二级 reference。 |
| 3 | Claude probe-home 清理失败 | FIXABLE | entry/rule 使用不同 probe-home，避免删同一棵目录。 |
| 4 | Codex hooks / capabilities 假告警 | FIXABLE | hooks 探针提高超时；capabilities probe 只复制最小运行上下文。 |

### FAIL-1: shellcheck 拦截
| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `tests/test-delivery-owner-phase3-contract.sh:190,236-244` 使用会触发 `SC2016` 的字面量写法；`tests/test-skill-output-and-gate-contract.sh:1946-1962` 让 `status_summary_task_state` 落在单引号 heredoc 里未被展开。 |
| 2 | 修复是否完整？ | 已同时修正 phase3 contract 的 8 处字面量 grep 和 status summary 的变量展开。 |
| 3 | 是否引入新问题？ | 风险低。修改只发生在测试脚本，不改生产逻辑。 |
| 4 | 是否需要补充测试覆盖？ | 需要。`shellcheck -x ...` 与 `bash tests/test-skill-output-and-gate-contract.sh` 已作为回归。 |

RED:
- `shellcheck -x tests/test-delivery-owner-phase3-contract.sh tests/test-skill-output-and-gate-contract.sh tools/dev/probe-claude-capabilities.sh tools/dev/probe-codex-capabilities.sh tools/dev/probe-codex-hooks.sh`
- `bash install.sh --target all --check full`

GREEN:
- `shellcheck -x tests/test-delivery-owner-phase3-contract.sh tests/test-skill-output-and-gate-contract.sh tools/dev/probe-claude-capabilities.sh tools/dev/probe-codex-capabilities.sh tools/dev/probe-codex-hooks.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`

### FAIL-2: Claude rule probe 假失败
| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `tools/dev/probe-claude-capabilities.sh:34-56,59-81` 的两层 prompt 合在一起要求“既只用一次 Bash，又再用一次 Bash”。 |
| 2 | 修复是否完整？ | 已把 follow-file 提示改为“如需继续读取二级文件则继续执行必要 tool call(s)）”，并保留原本的 fallback 语义。 |
| 3 | 是否引入新问题？ | 风险低。只放宽了临时 probe 指令，不改变正常运行时文档。 |
| 4 | 是否需要补充测试覆盖？ | 需要。`tests/test-runtime-reference-activation.sh` 新增稳定性契约断言，并用 `bash tools/dev/probe-claude-capabilities.sh .` 验证。 |

RED:
- `bash tests/test-runtime-reference-activation.sh`
- `bash tools/dev/probe-claude-capabilities.sh .`（旧实现会在 rule probe 假失败）

GREEN:
- `bash tests/test-runtime-reference-activation.sh`
- `bash tools/dev/probe-claude-capabilities.sh .`

### FAIL-3: Claude probe-home 清理失败
| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `tools/dev/probe-claude-capabilities.sh:348,404` 让 entry/rule 共用同一个 `probe-home`，二次清理时撞上残留目录。 |
| 2 | 修复是否完整？ | 已拆成 `probe-home-entry` 与 `probe-home-rule` 两棵独立目录，不再复用同一路径。 |
| 3 | 是否引入新问题？ | 风险低。临时目录数量增加，但仍由同一 `TMP_ROOT` 在退出时统一清理。 |
| 4 | 是否需要补充测试覆盖？ | 现有 runtime probe 已直接覆盖。 |

RED:
- `bash tools/dev/probe-claude-capabilities.sh .`（旧实现会出现 `rm: ... Directory not empty`）

GREEN:
- `bash tools/dev/probe-claude-capabilities.sh .`

### FAIL-4: Codex hooks / capabilities 假告警
| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `tools/dev/probe-codex-hooks.sh:117-125` 的 `timeout 20` 太短；旧 capability probe 还会复制整份 `~/.codex`。 |
| 2 | 修复是否完整？ | 已把 hooks 探针超时提高到 `60s`，并把 Claude/Codex capability probe 都改成最小运行上下文复制。 |
| 3 | 是否引入新问题？ | 风险低。probe 运行时间变长但更稳定，复制范围更小不会影响正常 runtime。 |
| 4 | 是否需要补充测试覆盖？ | 需要。`tests/test-runtime-reference-activation.sh` 新增 probe 稳定性契约；`bash tools/dev/probe-codex-hooks.sh` 与 `bash tools/dev/probe-codex-capabilities.sh .` 作为回归。 |

RED:
- `bash tools/dev/probe-codex-hooks.sh`（旧实现 `rc=124` 且只见 `SessionStart`）
- `bash tools/dev/probe-codex-capabilities.sh .`

GREEN:
- `bash tools/dev/probe-codex-hooks.sh`
- `bash tools/dev/probe-codex-capabilities.sh .`

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | shellcheck 拦截 | 字面量 grep 与 heredoc 变量展开错误 | `tests/test-delivery-owner-phase3-contract.sh`、`tests/test-skill-output-and-gate-contract.sh` | `shellcheck -x ...`、`bash tests/test-skill-output-and-gate-contract.sh` |
| 2 | Claude rule probe 假失败 | follow-file / read-reference 双层 prompt 冲突 | `tools/dev/probe-claude-capabilities.sh`、`tests/test-runtime-reference-activation.sh` | `bash tests/test-runtime-reference-activation.sh`、`bash tools/dev/probe-claude-capabilities.sh .` |
| 3 | Claude probe-home 清理失败 | entry/rule 共用同一路径 | `tools/dev/probe-claude-capabilities.sh` | `bash tools/dev/probe-claude-capabilities.sh .` |
| 4 | Codex hooks / capabilities 假告警 | hooks 超时过短 + capability probe 整目录复制 | `tools/dev/probe-codex-hooks.sh`、`tools/dev/probe-codex-capabilities.sh`、`tests/test-runtime-reference-activation.sh` | `bash tools/dev/probe-codex-hooks.sh`、`bash tools/dev/probe-codex-capabilities.sh .` |

### 全量测试结果
TEST_CMD:
- `bash tests/test-runtime-reference-activation.sh`
- `shellcheck -x tests/test-delivery-owner-phase3-contract.sh tests/test-skill-output-and-gate-contract.sh tools/dev/probe-claude-capabilities.sh tools/dev/probe-codex-capabilities.sh tools/dev/probe-codex-hooks.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- `bash tools/dev/probe-codex-hooks.sh`
- `bash tools/dev/probe-codex-capabilities.sh .`
- `bash tools/dev/probe-claude-capabilities.sh .`
- `bash install.sh --target all --check full`

通过: 7 / 失败: 0 / 跳过: 0

### 交接项清单
- 根因分析结论与定位文件:行号：
  - `tests/test-delivery-owner-phase3-contract.sh:190,236-244`
  - `tests/test-skill-output-and-gate-contract.sh:1623-1641,1946-1962`
  - `tools/dev/probe-claude-capabilities.sh:34-56,91-127,348,404`
  - `tools/dev/probe-codex-capabilities.sh:145-175,286-367`
  - `tools/dev/probe-codex-hooks.sh:117-125`
- 修复范围与回归测试清单：
  - shellcheck blocker 清理
  - Claude/Codex runtime probe 稳定性修复
  - full check 回归验证
- 非 FIXABLE 问题的后续处理动作：
  - 无。本轮问题全部归类为 `FIXABLE`。

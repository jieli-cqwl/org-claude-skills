# fix-1.md

## 输入分析
- 输入来源清单：
  - 用户截图：下游对话暴露了 `completion_check.sh` 的内部失败细节。
  - 失败命令：`bash shared/skills/review/scripts/completion_check.sh`
  - 回归命令：`bash tests/test-codex-skill-adapter.sh`、`bash tests/run-all.sh`
- work_dir 解析结果：`docs/hotfix-20260413-1147`
- 问题数量汇总：3

差异说明（N > 1 时 REQUIRED）:
- N/A，本轮为 `fix-1`

## 诊断阶段

### 环境快照
- 当前分支: `main`
- 工作树状态:
  - `M CHANGELOG.md`
  - `M install.sh`
  - `M shared/skills/delivery-owner/scripts/completion_check.sh`
  - `M tests/test-codex-skill-adapter.sh`
  - `M tests/test-skill-output-and-gate-contract.sh`
- 最近 5 条提交:
  - `7a4f5dd refactor: 收敛复杂链路运行时去噪与交付门禁`
  - `57454db refactor: streamline subagent context contracts and design docs`
  - `87d1294 refactor: 收敛复杂链路上下文治理与交付门禁`
  - `4f58ed9 chore: sync runtime cleanup and delivery docs`
  - `db02599 refactor: rename project-manager to delivery-owner`
- 最近改动文件:
  - `install.sh`
  - `tests/test-codex-skill-adapter.sh`
  - `tests/test-skill-output-and-gate-contract.sh`
  - `shared/skills/delivery-owner/scripts/completion_check.sh`
  - `CHANGELOG.md`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | Codex 安装文案把 internal gate 误写成 fresh proving command | 安装 Codex runtime 后查看任意带 `completion_check.sh` 的 skill 文档；或直接执行 `bash shared/skills/review/scripts/completion_check.sh` | 文案要求直接运行脚本，但脚本依赖 hook stdin；裸跑返回 `stdin 为空，无法解析 hook 上下文`，下游模型会把这段内部失败细节带到最终回复 |
| 2 | `skill-output-and-gate-contract` 夹具把状态变量写成“看似使用、实则未展开” | 运行 `bash tests/run-all.sh` | shellcheck 在 `tests/test-skill-output-and-gate-contract.sh` 报 `SC2034 status_summary_task_state appears unused`，阻断全量回归 |
| 3 | `delivery-owner` 合同测试与脚本 source 形态漂移 | 继续运行 `bash tests/run-all.sh` | `tests/test-delivery-owner-phase3-contract.sh` 失败：`completion check should source phase3 matrix` |

当前环境复现结论:
- 可复现/不可复现: 可复现
- 不可复现时环境差异证据: N/A

### 假设验证过程
每个问题至少 2 个已验证假设（结果为排除/确认/未决）。
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | Codex 文案误导下游 | H1：真正泄漏点是 stop dispatcher，把 gate 原始失败直接显示给用户 | 检查 `shared/hooks/managed/codex_stop_dispatch.py:91-95`，确认它只把 payload 传给 gate 并返回 stopReason；截图中的自然语言解释并非这里生成 | 排除为主因 |
| 1 | Codex 文案误导下游 | H2：`review/completion_check.sh` 本身不能裸跑，因为 `hook_init` 强依赖 stdin JSON | 检查 `shared/skills/review/scripts/completion_check.sh:18-19` 与 `shared/hooks/lib/common.sh:44-47`，并实际执行 `bash shared/skills/review/scripts/completion_check.sh`，复现 `stdin 为空，无法解析 hook 上下文` | 确认 |
| 1 | Codex 文案误导下游 | H3：Codex 安装器把 `completion_check.sh` 注入成“显式 fresh proving 命令”，并把 checklist 改写成“显式执行” | 检查 `install.sh:793-851`，确认 `rewrite_codex_skill_docs` 直接写入错误 note 和 checklist 文案；新增 RED 用例 `tests/test-codex-skill-adapter.sh` 后失败 | 确认 |
| 2 | shellcheck 阻断 | H1：只有 `evidence_without_status` 分支多余赋值 | 删除该分支赋值后，shellcheck 下一轮改报 `1190`，说明不是单一分支问题 | 排除 |
| 2 | shellcheck 阻断 | H2：`delivery-status-summary.md` 使用单引号 heredoc，导致 `$status_summary_task_state` 从未展开 | 检查 `tests/test-skill-output-and-gate-contract.sh:1448-1464`，发现 `<<'EOF'` 包含 `$status_summary_task_state`；改成 `<<EOF` 后 shellcheck 阶段通过 | 确认 |
| 3 | delivery-owner 合同漂移 | H1：脚本已经完全不再 source `phase3-grade-matrix.sh` | 检查 `shared/skills/delivery-owner/scripts/completion_check.sh:49`，确认仍有 `source .../phase3-grade-matrix.sh` | 排除 |
| 3 | delivery-owner 合同漂移 | H2：脚本虽然 source 了矩阵，但 source 形态与合同测试 `tests/test-delivery-owner-phase3-contract.sh:144` 约定不一致 | 对比测试固定匹配串与脚本当前 `source "$SCRIPT_DIR/phase3-grade-matrix.sh"`，定位为 contract drift；改成合同要求的 canonical source 形态后测试通过 | 确认 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | Codex 文案误导下游 | `install.sh:793-851` | `build_staging_codex` 在 `install.sh:926` 调用 `rewrite_codex_skill_docs`，把带 `completion_check.sh` 的 skill 文档统一改写为“可显式运行 fresh proving command”；而 `review/completion_check.sh:18-19` 会走 `hook_init`，`common.sh:44-47` 明确在 stdin 为空时 fail-close，最终让下游模型把内部 gate 失败细节暴露给用户 | 静态调用链：`install.sh:926 -> rewrite_codex_skill_docs()`；`shared/skills/review/scripts/completion_check.sh:18-19 -> shared/hooks/lib/common.sh:39-67` |
| 2 | shellcheck 阻断 | `tests/test-skill-output-and-gate-contract.sh:1449-1464` | `delivery-status-summary.md` 夹具用单引号 heredoc 包住 `$status_summary_task_state`，变量在脚本层从未真正消费，shellcheck 将所有相关赋值判定为未使用并阻断全量回归 | 同文件静态追踪：变量定义位于 `1011` 及 case 分支；唯一消费点是 `1461`，但受 `<<'EOF'` 抑制 |
| 3 | delivery-owner 合同漂移 | `shared/skills/delivery-owner/scripts/completion_check.sh:49` | 脚本仍然 source Phase 3 分级矩阵，但 source 语句不再符合合同测试约定的 canonical 形态，`tests/test-delivery-owner-phase3-contract.sh:144` 因字符串不匹配而 fail-close | 静态对照：`tests/test-delivery-owner-phase3-contract.sh:144` 与 `shared/skills/delivery-owner/scripts/completion_check.sh:49` |

## 处置阶段

### 决策
- 优先修复主问题：纠正 Codex 安装器注入文案，切断下游继续裸跑 `completion_check.sh` 的错误引导。
- 为满足 FIXABLE 的全量回归要求，顺手修复 fresh proving 暴露出的两个门禁漂移：shellcheck heredoc 问题和 delivery-owner 合同 drift。
- 不扩大范围到 stop dispatcher 行为或 hook 协议重构，只做最小必要修改。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | Codex 文案误导下游 | FIXABLE | 修改 `install.sh` 注入 note/checklist，并补回归测试 |
| 2 | shellcheck 阻断 | FIXABLE | 修正 heredoc 展开方式，恢复变量真实消费 |
| 3 | delivery-owner 合同漂移 | FIXABLE | 恢复 canonical `source phase3-grade-matrix.sh` 形态 |

### FAIL-1: Codex completion gate 文案误导下游

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `install.sh:793-851` 把 `completion_check.sh` 误写成 fresh proving command，并把 checklist 改写成“显式执行”；同时 `shared/hooks/lib/common.sh:44-47` 要求 stdin JSON，导致裸跑必败 |
| 2 | 修复是否完整？ | 已同时修复 note 与 checklist 两个注入口，并在 `tests/test-codex-skill-adapter.sh:64-70` 阻断旧文案、旧裸跑命令和旧 checklist 再回归 |
| 3 | 是否引入新问题？ | 影响范围限定在 Codex 安装时生成的 skill 文档，不改变 Claude runtime，也不改动 hook 协议 |
| 4 | 是否需要补充测试覆盖？ | 已补：安装后的 Codex skill 文档必须出现“gate 依赖 hook payload”的警示，并禁止保留旧直跑文案 |

RED: `bash tests/test-codex-skill-adapter.sh` -> `[FAIL] delivery-owner missing codex runtime gate warning`
GREEN: `bash tests/test-codex-skill-adapter.sh` -> `[PASS] codex skill adapter`

### FAIL-2: skill output/gate contract 夹具 shellcheck 阻断

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `tests/test-skill-output-and-gate-contract.sh:1449-1464` 使用单引号 heredoc，`$status_summary_task_state` 不会展开，导致变量赋值在静态分析中被判为未使用 |
| 2 | 修复是否完整？ | 已改为可展开 heredoc，覆盖所有会生成 `delivery-status-summary.md` 的分支，而不是只删除单个 case 里的赋值 |
| 3 | 是否引入新问题？ | 该 heredoc 只包含预期需要展开的变量，没有额外 shell 元字符副作用 |
| 4 | 是否需要补充测试覆盖？ | 当前全量 `shellcheck + tests/run-all.sh` 已覆盖此问题；无需额外单测 |

RED: `bash tests/run-all.sh` 首轮在 shellcheck 阶段失败，报 `SC2034 status_summary_task_state appears unused`
GREEN: 修复 heredoc 后，`bash tests/run-all.sh` 可继续通过 shellcheck 并进入后续用例

### FAIL-3: delivery-owner phase3 contract 漂移

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/skills/delivery-owner/scripts/completion_check.sh:49` 的 `source` 写法与 `tests/test-delivery-owner-phase3-contract.sh:144` 固定合同不一致，导致 contract test 失败 |
| 2 | 修复是否完整？ | 已恢复成合同要求的 canonical source 形态，未修改矩阵逻辑和后续校验行为 |
| 3 | 是否引入新问题？ | 风险很低，只是 source 路径表达式回到合同定义形式；失败信息仍沿用 `early_block` |
| 4 | 是否需要补充测试覆盖？ | 现有 `tests/test-delivery-owner-phase3-contract.sh` 已是直接回归覆盖 |

RED: `bash tests/test-delivery-owner-phase3-contract.sh` -> `[FAIL] completion check should source phase3 matrix`
GREEN: `bash tests/test-delivery-owner-phase3-contract.sh` -> `[PASS] delivery-owner phase3 contract`

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | Codex 文案误导下游 | Codex 安装器把 gate 写成 fresh proving direct-run 指令 | `install.sh`、`tests/test-codex-skill-adapter.sh`、`CHANGELOG.md` | `bash tests/test-codex-skill-adapter.sh` |
| 2 | shellcheck 阻断 | heredoc 抑制变量展开 | `tests/test-skill-output-and-gate-contract.sh` | `bash tests/run-all.sh` |
| 3 | delivery-owner 合同漂移 | source 形态与合同测试不一致 | `shared/skills/delivery-owner/scripts/completion_check.sh` | `bash tests/test-delivery-owner-phase3-contract.sh`、`bash tests/run-all.sh` |

### 全量测试结果
TEST_CMD: `bash tests/run-all.sh`
通过: 36 / 失败: 0 / 跳过: 0

补充说明：
- `skill context budget test` 输出 3 条 WARN（`design/product/tech-lead` 超过 800 行 budget），但脚本最终结论为 `All tests passed`，本轮未被 gate 判失败。

### 阻断清单（全部/部分非 FIXABLE 时必填）
- 无。三项问题均已按最小范围修复并通过回归。

### 交接项清单
- 主根因：`install.sh:793-851` 的 Codex 注入文案把 internal gate 与 fresh proving 混淆。
- 回归清单：`bash tests/test-codex-skill-adapter.sh`、`bash tests/test-delivery-owner-phase3-contract.sh`、`bash tests/run-all.sh`
- 验证补救：全量回归过程中顺手修复了 heredoc/sourcing 两个既有门禁漂移，当前工作树已全部纳入同一轮 fresh proving 通过。

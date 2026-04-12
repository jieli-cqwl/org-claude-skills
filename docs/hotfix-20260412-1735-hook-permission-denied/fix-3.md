# fix-3

## 输入分析

- 输入来源清单：
  - 历史报告：
    - `docs/hotfix-20260412-1735-hook-permission-denied/fix-1.md`
    - `docs/hotfix-20260412-1735-hook-permission-denied/fix-2.md`
  - fresh proving commands：
    - `bash tests/test-install-smoke.sh`
    - `bash tests/test-install-systematic.sh`
    - `bash tests/test-runtime-integrity.sh`
- `work_dir` 解析结果：`docs/hotfix-20260412-1735-hook-permission-denied`
- 问题数量汇总：2

差异说明（N > 1 时 REQUIRED）:
- `fix-1` 锁定了 Claude dangerous hook 的 `Permission denied` 根因。
- `fix-2` 完成了 hook 权限链路修复与安装门禁补强。
- 本轮在 fresh 验证时发现一个新的、与本次交付强相关的回归阻塞：`test-runtime-integrity.sh` 因 runtime 文档残留 `shared/reference/...` 裸路径而失败。于是本轮在保持 hook 修复不回退的前提下，继续收口 shared skills 内的 runtime reference 写法，并重新跑完整 proving commands。

## 诊断阶段

### 环境快照
- 当前分支：`main`
- 工作树状态：
  - 已修改：`claude/hooks/block_dangerous.sh`
  - 已修改：`shared/hooks/managed/block_dangerous.sh`
  - 已修改：`install.sh`
  - 已修改：`shared/skills/design/references/adr-spec.md`
  - 已修改：`shared/skills/design/references/decision-templates.md`
  - 已修改：`shared/skills/design/references/runtime-fact-capture.md`
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
  - `shared/skills/design/references/adr-spec.md`
  - `shared/skills/design/references/decision-templates.md`
  - `shared/skills/design/references/runtime-fact-capture.md`
  - `tests/test-install-smoke.sh`
  - `tests/test-install-systematic.sh`
  - `tests/test-runtime-integrity.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | Claude dangerous hook 在下游运行时报 `Permission denied` | 执行 `bash tests/test-install-smoke.sh` 的 RED 版本 | 新增的 `-x` 断言失败，且 wrapper smoke 运行会撞到 managed 脚本执行位缺失 |
| 2 | runtime integrity 因 skills 文档引用格式失败 | 在 `fix-2` 后执行 fresh `bash tests/test-runtime-integrity.sh` | 输出多条 `shared/reference/...` 裸路径，并以 `should not retain bare runtime doc references` 失败 |

当前环境复现结论:
- 可复现/不可复现: 可复现
- 不可复现时环境差异证据: 不适用

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | Claude hook 权限报错 | H1：只修 wrapper 调用方式即可 | 对照仓库 mode 与安装产物 mode，检查 `git diff --summary` 和 `install.sh` 的完整性判断 | 排除。若不补执行位和门禁，安装产物仍可能再次分发为不可执行文件 |
| 1 | Claude hook 权限报错 | H2：需要同时修 wrapper、脚本 mode、安装门禁和回归测试 | 在 RED 后补 `exec bash ...`、`chmod +x`、`-x` quick check 与 smoke 测试，再跑回归 | 确认 |
| 2 | runtime 文档引用回归 | H1：是本轮新增的 hook 改动引入的副作用 | 对比 `git diff`，本轮 hook 相关变更没有触碰 skills 文档；单独搜索 `shared/reference/` 命中 shared skills 引用文件 | 排除。这是仓库中已有的 runtime 文档路径问题，被 fresh proving command 首次拦出 |
| 2 | runtime 文档引用回归 | H2：最小修复是把会被打包到 runtime 的 `shared/reference/...` 改成 `{{RUNTIME_HOME}}/reference/...` | 搜索 `shared/skills` 中的裸路径命中点，修改后重新执行 `rg -n 'shared/reference/' shared/skills -S` 与 `bash tests/test-runtime-integrity.sh` | 确认 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | Claude dangerous hook `Permission denied` | `/Users/lijieli/org-claude-skills/claude/hooks/block_dangerous.sh:7` | Claude 通过 `bash ~/.claude/hooks/block_dangerous.sh` 进入 wrapper -> wrapper 直接 `exec` managed 脚本 -> managed 脚本被仓库与安装链以 `0644` 分发 -> runtime 报 `Permission denied` | `shared/hooks/registry.json:158-163`、`claude/hooks/block_dangerous.sh:7`、`install.sh:1312-1315`、`install.sh:1642-1645` |
| 2 | runtime 文档引用回归 | `/Users/lijieli/org-claude-skills/shared/skills/design/references/runtime-fact-capture.md:6`、`adr-spec.md:5`、`decision-templates.md:6-8,84` | shared skills 被安装到 runtime 后，文档里仍保留源码仓库视角的 `shared/reference/...` 裸路径 -> `test-runtime-integrity.sh` 的 `check_no_bare_runtime_refs` 判定为无效 runtime 引用 | `tests/test-runtime-integrity.sh:256-294` 的校验逻辑 + `rg -n 'shared/reference/' shared/skills -S` 的搜索结果 |

## 处置阶段

### 决策
- 处置策略选择 + 优先级排序：
  1. 用 TDD 修掉 dangerous hook 权限链路。
  2. 在 fresh proving command 中不忽略新失败，继续顺着 runtime integrity 回归做最小修复。
  3. 只改 runtime 会打包出去的 shared skill 文档引用，不扩大到 contracts/docs 等非 runtime 工件。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | Claude dangerous hook `Permission denied` | FIXABLE | 已完成修复并回归 |
| 2 | runtime 文档残留 `shared/reference/...` 裸路径 | FIXABLE | 已完成修复并回归 |

### FAIL-1: Claude dangerous hook 权限错误
| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | wrapper 直接 `exec` non-executable managed 脚本，同时安装链路未校验执行权限 |
| 2 | 修复是否完整？ | 已覆盖 wrapper、managed 脚本 mode、安装完整性判断、quick check、安装烟测、系统化安装测试、runtime integrity |
| 3 | 是否引入新问题？ | 未引入 hook 规则语义变更，只增强了启动容错和门禁 |
| 4 | 是否需要补充测试覆盖？ | 已补 `-x` 与 smoke 断言 |

RED:
- `bash tests/test-install-smoke.sh`
- 结果：失败

GREEN:
- `bash tests/test-install-smoke.sh`
- 结果：`rc=0`
- 关键输出：`[PASS] install/uninstall smoke`

### FAIL-2: runtime 文档引用回归
| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | shared skills 的 reference 文档仍写源码仓库路径 `shared/reference/...`，安装到 runtime 后不满足 runtime 引用约束 |
| 2 | 修复是否完整？ | 已把 `shared/skills/design/references/*.md` 中会随 runtime 打包的裸路径统一改为 `{{RUNTIME_HOME}}/reference/...` |
| 3 | 是否引入新问题？ | 风险低。仅收口文档路径，不改 skill 行为与流程 |
| 4 | 是否需要补充测试覆盖？ | 不需要新增测试；现有 `test-runtime-integrity.sh` 已覆盖 |

RED:
- `bash tests/test-runtime-integrity.sh`
- 结果：失败
- 关键输出：`[FAIL] ... should not retain bare runtime doc references`

GREEN:
- `bash tests/test-runtime-integrity.sh`
- 结果：`rc=0`
- 关键输出：`[PASS] runtime integrity`

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | Claude dangerous hook 权限错误 | wrapper 调用方式与脚本 mode/安装门禁不一致 | `claude/hooks/block_dangerous.sh`、`shared/hooks/managed/block_dangerous.sh`、`install.sh`、`tests/test-install-smoke.sh`、`tests/test-install-systematic.sh`、`tests/test-runtime-integrity.sh` | `tests/test-install-smoke.sh`、`tests/test-install-systematic.sh`、`tests/test-runtime-integrity.sh` |
| 2 | runtime 文档裸路径回归 | shared skills 文档仍引用源码视角的 `shared/reference/...` | `shared/skills/design/references/runtime-fact-capture.md`、`shared/skills/design/references/adr-spec.md`、`shared/skills/design/references/decision-templates.md` | `tests/test-runtime-integrity.sh` |

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
  - `/Users/lijieli/org-claude-skills/shared/skills/design/references/runtime-fact-capture.md:6-7`
  - `/Users/lijieli/org-claude-skills/shared/skills/design/references/adr-spec.md:5-6`
  - `/Users/lijieli/org-claude-skills/shared/skills/design/references/decision-templates.md:6-8,84`
- 修复范围与回归测试清单
  - dangerous hook wrapper 改为 `exec bash ...`
  - dangerous hook 源文件 mode 改为 `100755`
  - 安装完整性判断与 quick check 增加 `-x`
  - 安装回归增加 `-x` 与 smoke 断言
  - runtime 文档引用统一改为 `{{RUNTIME_HOME}}/reference/...`
- 非 FIXABLE 问题的后续处理动作
  - 无

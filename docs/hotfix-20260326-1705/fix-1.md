# fix-1.md

## 输入分析
- 输入来源清单：用户实际现象、`/Users/lijieli/project/qft-all-split/codex-doc-review-report.md`、`/Users/lijieli/.codex/rules/代码质量.md`
- work_dir 解析结果：`docs/hotfix-20260326-1705`
- 问题数量汇总：2

差异说明（N > 1 时 REQUIRED）:
- N = 1，本轮无历史修复报告。

## 诊断阶段

### 环境快照
- 当前分支: `main`
- 工作树状态:
  `M claude/agents/codex-doc-reviewer.md`
  `M claude/skills/codex-doc-review/SKILL.md`
  `M claude/skills/codex-doc-review/references/execution-spec.md`
  `M claude/skills/codex-doc-review/scripts/completion_check.sh`
  `M install.sh`
  `M shared/hooks/lib/common.sh`
  `M tests/run-all.sh`
  `?? claude/skills/codex-doc-review/scripts/repair_misplaced_reports.py`
  `?? tests/test-codex-doc-review-routing.sh`
  `?? tests/test-install-runtime-audit.sh`
- 最近 5 条提交:
  `b68e90e release: v1.2.2`
  `be695d8 release: v1.2.1`
  `65a1618 release: v1.2.0`
  `b36e5c9 release: v1.1.0`
  `a81a2f8 docs: add branch protection playbook and helper script`
- 最近改动文件:
  `claude/skills/codex-doc-review/*`
  `shared/hooks/lib/common.sh`
  `install.sh`
  `tests/run-all.sh`
  `tests/test-codex-doc-review-routing.sh`
  `tests/test-install-runtime-audit.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | `codex-doc-review-report.md` 落到错误目录 | 在 `qft-all-split` 触发 product 级多文档复审；检查仓库根与 `docs/arch-optimization/` | 根目录和 feature 根同时存在同名报告，Stop hook 无法阻断错位副本 |
| 2 | `.codex/rules` 存在历史脏残留 | 检查 `~/.codex/rules` 并重跑安装 | `代码质量.md` 作为未登记软链长期残留，安装器升级后仍不清理 |

当前环境复现结论:
- 可复现/不可复现: 可复现
- 不可复现时环境差异证据: 无

### 假设验证过程
每个问题至少 2 个已验证假设（结果为排除/确认/未决）。
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | 报告错位 | 只是一次误传 `work_dir` | 对比 transcript、feature 根副本与仓库根副本；发现即使 feature 根已有正确副本，root 副本仍能存活 | 排除 |
| 1 | 报告错位 | `codex-doc-review` 契约把默认输出定义成当前目录 | 检查 `claude/skills/codex-doc-review/SKILL.md:47` 与 `claude/agents/codex-doc-reviewer.md:21` | 确认 |
| 1 | 报告错位 | completion check 仍按 PRD unit 工作区找报告 | 检查 `claude/skills/codex-doc-review/scripts/completion_check.sh:14` 与旧 `resolve_work_dir_from_prd` 链路 | 确认 |
| 2 | rules 残留 | `代码质量.md` 是当前安装器生成的新规则文件 | 比对 `~/.org-skills-state/codex/installed-manifest` 与 `shared/rules`，确认该文件不在受管集合 | 排除 |
| 2 | rules 残留 | 同版本安装直接跳过，导致未登记残留永远不清理 | 检查 `install.sh:709` 的同版本短路与旧“仅清理 manifest 中受管文件”逻辑 | 确认 |
| 2 | rules 残留 | 残留来自旧 symlink 时代 | 现场文件为软链，且目标指向 `~/.claude/reference/代码质量.md`，不符合当前 generated runtime 模型 | 确认 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | `codex-doc-review-report.md` 错位与重复副本 | `claude/skills/codex-doc-review/SKILL.md:47`, `claude/skills/codex-doc-review/scripts/completion_check.sh:14`, `shared/hooks/lib/common.sh:534` | 契约层默认 `work_dir=当前目录`，校验层又把报告强行绑定到 PRD/unit 工作区，导致 product 多文档复审缺少唯一 canonical 目录，错误落点能绕过校验并留下重复副本 | 通过静态追踪 `codex-doc-review -> completion_check.sh -> shared/hooks/lib/common.sh` 的调用链确认，等效于 `findReferences`/静态追踪 |
| 2 | `.codex/rules/代码质量.md` 残留 | `install.sh:481`, `install.sh:488`, `install.sh:709` | 运行时已从 symlink 模型迁到 generated runtime，但安装器只清理 manifest 中受管文件；未登记残留既不参与 prune，又会被同版本短路跳过，导致旧软链长期留存 | 通过静态追踪 `install_to_target -> audit_codex_runtime_rules -> same-version skip` 的控制流确认，等效于 `findReferences`/静态追踪 |

## 处置阶段

### 决策
- 先修契约与 Stop hook，给 `codex-doc-review` 建立唯一 canonical work_dir 规则。
- 再修安装器，在同版本路径前插入 runtime audit，专门治理 `.codex/rules` 的非受管残留。
- 最后补一键清理脚本与回归测试，并把真实运行面与真实项目目录一起收口。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | `codex-doc-review-report.md` 错位与重复副本 | FIXABLE | 修改 skill 契约、completion check、common resolver，并清理现存错位报告 |
| 2 | `.codex/rules/代码质量.md` 残留 | FIXABLE | 修改 `install.sh` 审计链路，覆盖安装并归档清理真实残留 |

### FAIL-1: codex-doc-review canonical 路由缺失

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `claude/skills/codex-doc-review/SKILL.md:47` 把输入建模为“单文档 + 当前目录输出”，`completion_check.sh:14` 又走错了 PRD/unit 解析链路，导致 product 多文档复审没有唯一 canonical 目录 |
| 2 | 修复是否完整？ | 已同时覆盖 skill 契约、agent 契约、execution spec、shared resolver、completion check、历史错位报告清理脚本 |
| 3 | 是否引入新问题？ | 新增了更严格的阻断；如果一次审查跨多个 feature/phase/unit，现在会被直接拦截，这是预期收紧 |
| 4 | 是否需要补充测试覆盖？ | 已新增 `tests/test-codex-doc-review-routing.sh`，覆盖 product/design/test-design/错误 work_dir/重复副本 |

RED: 真实仓库同时存在 `/Users/lijieli/project/qft-all-split/codex-doc-review-report.md` 和 `/Users/lijieli/project/qft-all-split/docs/arch-optimization/codex-doc-review-report.md`；新增路由测试在修复前会因为 canonical 目录缺失或错位副本未阻断而失败。  
GREEN: `bash /Users/lijieli/org-claude-skills/tests/test-codex-doc-review-routing.sh` 通过；`python3 .../repair_misplaced_reports.py /Users/lijieli/project/qft-all-split` 已删除仓库根重复副本，只保留 feature 根报告。

### FAIL-2: codex rules 未登记残留不清扫

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `install.sh:709` 的同版本短路发生在残留治理之前，而旧逻辑只会 prune manifest 中登记过的文件，导致 `~/.codex/rules/代码质量.md` 这种未登记旧软链永久存活 |
| 2 | 修复是否完整？ | 已新增 `audit_codex_runtime_rules`，在 skip 前扫描 `.codex/rules`；对非受管 `*.md` 归档删除，对受管软链先移除再重建真实文件 |
| 3 | 是否引入新问题？ | 审计范围只收敛在 `.codex/rules`，显式保留 `default.rules` 和其余平台/本地扩展，不扩大清理范围 |
| 4 | 是否需要补充测试覆盖？ | 已新增 `tests/test-install-runtime-audit.sh`，专门验证同版本安装下的历史残留归档与清理 |

RED: 实际运行面存在 `/Users/lijieli/.codex/rules/代码质量.md -> /Users/lijieli/.claude/reference/代码质量.md`；修复前同版本重跑安装不会删除它。  
GREEN: `bash /Users/lijieli/org-claude-skills/tests/test-install-runtime-audit.sh` 通过；实际覆盖安装后该文件已不存在，并归档到 `~/.org-skills-state/codex/unexpected-artifacts/20260326164829-64267/rules/代码质量.md`。

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | 报告错位 | 无 canonical 路由 + 错误 completion check | `shared/hooks/lib/common.sh`, `claude/skills/codex-doc-review/SKILL.md`, `claude/agents/codex-doc-reviewer.md`, `claude/skills/codex-doc-review/references/execution-spec.md`, `claude/skills/codex-doc-review/scripts/completion_check.sh`, `claude/skills/codex-doc-review/scripts/repair_misplaced_reports.py` | `tests/test-codex-doc-review-routing.sh` |
| 2 | rules 残留 | 未登记残留不清扫 + 同版本短路 | `install.sh`, `tests/test-install-runtime-audit.sh`, `tests/run-all.sh` | `tests/test-install-runtime-audit.sh`, `tests/run-all.sh` |

### 全量测试结果
TEST_CMD: `bash /Users/lijieli/org-claude-skills/tests/run-all.sh`
通过: 11 / 失败: 0 / 跳过: 0

### 阻断清单（全部/部分非 FIXABLE 时必填）
无。两项问题均已按 `FIXABLE` 闭环处理。

### 交接项清单
- 根因分析结论与定位文件:行号：
  `claude/skills/codex-doc-review/SKILL.md:47`
  `claude/skills/codex-doc-review/scripts/completion_check.sh:14`
  `shared/hooks/lib/common.sh:534`
  `install.sh:481`
  `install.sh:488`
  `install.sh:709`
- 修复范围与回归测试清单：
  `bash /Users/lijieli/org-claude-skills/tests/test-codex-doc-review-routing.sh`
  `bash /Users/lijieli/org-claude-skills/tests/test-install-runtime-audit.sh`
  `bash /Users/lijieli/org-claude-skills/tests/run-all.sh`
  `bash /Users/lijieli/org-claude-skills/install.sh --target all --force --check quick`
- 非 FIXABLE 问题的后续处理动作：
  无

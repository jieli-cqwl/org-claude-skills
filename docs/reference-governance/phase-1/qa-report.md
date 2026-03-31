# qa-report.md

审查分级: 未指定
执行范围: 验证-C

## 输入分析
- 本轮验收对象是当前工作区全部未提交改动，重点包括：
  - runtime `protocols/` 目录收口
  - `equivalence-guard` skill 删除
  - `project-manager` 迁移等价性强门禁退场后的安装与门禁一致性
- 该类改动不对应独立业务 PRD / 用户旅程，主要风险集中在安装结果、runtime 布局、协议文本和门禁脚本回归。
- 因此本次采用范围化 QA，仅执行 `验证-C`。

## 决策
- 验收方法：执行 `验证-C`，聚焦安装验证、全量回归和关键 runtime 目录人工核对。
- `QA_A / QA_B / QA_D` 标记为 `N/A`。

## 产出
INFRA_ERROR: no

## 验收汇总
| 阶段 | 状态 | 修复轮次 | 说明 |
|------|------|---------|------|
| QA_A（AC 验收） | N/A | 0 | 无独立 PRD / UNIT 业务 AC |
| QA_B（E2E 旅程） | N/A | 0 | 本轮不涉及面向终端用户的业务旅程 |
| QA_C（回归验证） | OK | 0 | 安装、runtime、source layout、doc reference、skill contract 与全量回归 fresh PASS |
| QA_D（探索性测试） | N/A | 0 | 本轮不执行探索性测试 |

## 验证-C: 回归验证

### 变更影响分析
| 修改文件 | 影响面 | 关联功能 | 风险级别 |
|---------|--------|---------|---------|
| `install.sh` | 本地安装输出目录、stale managed file 清理 | `~/.claude` / `~/.codex` runtime 布局 | High |
| `shared/protocols/*.md` | workflow 协议真源 | skill 协议引用方向、Phase 工件口径 | Medium |
| `shared/skills/project-manager/**` | 项目交付门禁 | Phase 3 completion contract | High |
| `shared/skills/equivalence-guard/**` | skill 可用性 | runtime 安装内容、文档一致性 | High |
| `tests/**` | 回归门禁 | 安装验证、协议文本与路径契约 | High |

### 全量测试结果
TEST_CMD: `bash tests/run-all.sh`
通过: 16 / 失败: 0 / 跳过: 0

### 安装与 runtime 核对
| # | 功能 | 验证方式 | 状态 |
|---|------|---------|------|
| 1 | runtime 输出独立 `protocols/` 目录 | `bash install.sh --target all --force --check full` | PASS |
| 2 | 本地 runtime 不再保留旧 `reference/phase-selection-protocol.md` | 安装后的 full check + 人工目录核对 | PASS |
| 3 | 删除的 `equivalence-guard` skill 不会残留在 runtime | `find "$HOME/.codex/skills" -maxdepth 1 -type d` 与 `find "$HOME/.claude/skills" -maxdepth 1 -type d` 抽查 | PASS |

### 验证-C 结论
QA_C_OK

## FAIL 详情（如有）
无

## 偏差自检
- 已排除潜在问题 1：source/runtime 协议目录虽改名，但安装后仍保留旧 `reference/...protocol...` 文件。证据：`bash install.sh --target all --force --check full` 通过。
- 已排除潜在问题 2：删除 `equivalence-guard` 只改 source，runtime 旧 skill 目录未清理。证据：本机 `~/.codex/skills/` 与 `~/.claude/skills/` 抽查无该目录。
- 已排除潜在问题 3：Phase 协议继续宣传已退场的 `equivalence/` 交付工件。证据：`shared/protocols/phase-selection-protocol.md` 已修正，且 `tests/test-skill-output-and-gate-contract.sh` 新增断言防回归。

## 结果
RESULT: PASS

<metadata>{"grade":"未指定","status":"PASS","qa":{"QA_A":"N/A","QA_B":"N/A","QA_C":"OK","QA_D":"N/A"},"issue_ids":[],"units_total":0,"units_passed":0,"units_failed":0,"rules_total":0,"rules_passed":0,"rules_failed":0,"ac_total":0,"ac_passed":0,"ac_failed":0,"journeys_tested":0,"regression_tests_passed":16,"exploratory_findings":0}</metadata>

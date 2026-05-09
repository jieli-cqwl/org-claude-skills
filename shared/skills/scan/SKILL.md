---
name: scan
description: 全项目代码健康度巡检与技术债分析。Use when 需要评估代码质量、发现技术债务、分析性能瓶颈。
argument-hint: "[项目路径] [perf]"
user-invocable: true
context: fork
allowed-tools: Read, Write, Bash, Glob, Grep, Agent
---

# /scan -- 代码质量扫描与性能分析

## HARD-GATE

1. NO health score without objective evidence (Grep results, line counts, concrete numbers).
2. NO report without saving to `docs/reports/tech-debt/[YYYY-MM-DD]_技术债扫描报告.md`.
3. NO scan results generated to project root directory.
4. NO severity rating without file_path:line_number for each issue.

## 角色

你是独立代码审计师，用 SQALE 量化标准说话。你的评分报告将被 CTO 用来做技术债务预算决策——每一个评分必须有客观证据支撑。

## 目标

目标是对目标项目执行代码健康度、技术债、Skills 质量、文档一致性和可选性能扫描。完成边界是生成 `docs/reports/tech-debt/[YYYY-MM-DD]_技术债扫描报告.md`，报告中的健康度评分、问题分级、修复建议和跳过项都有可复验证据。

## 输入

- 前置条件：目标路径为项目目录（含 `pom.xml`/`package.json`/`pyproject.toml`/`go.mod` 之一），非项目目录时终止并提示
- 用户输入：`/scan [项目路径]`，可选子命令 `perf`

## 流程

流程表：

| Step | Input | Action | Output | Consumer | Acceptance | Failure state | Proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1. 项目识别 | 项目路径 | Read 特征文件并判断语言/规模 | 项目快照 | Agent 1-6 | 至少识别一个项目特征文件 | Stop 并提示非项目目录 | 特征文件检测输出 |
| 2. 确定性预扫描 | 项目路径 | Run stats/complexity/dependency/tree 脚本 | 预扫描数据包 | Agent 1-6 | 脚本成功或记录手动统计替代 | 退回 Glob/Grep 手动统计并记录原因 | 脚本输出或手动统计证据 |
| 3. 并行扫描 | 预扫描数据包和 reference 合同 | Execute 6 Agent 扫描并记录跳过条件 | 分组 findings 和跳过项 | 汇总报告 | 每组完成或给出跳过理由 | 失败 Agent 产出阻断/跳过证据 | findings file_path:line_number |
| 4. 性能分析 | `/scan perf` 子命令 | Read perf 工具规则并执行可用分析 | 性能瓶颈 TOP 5 | 汇总报告 | 有瓶颈证据或不可执行说明 | 无 perf 子命令时跳过 | perf 输出或跳过理由 |
| 5. 汇总报告 | 分组 findings、评分规则、性能结果 | Write 技术债报告 | `docs/reports/tech-debt/[YYYY-MM-DD]_技术债扫描报告.md` | 用户/CTO | 报告含评分、分级、证据和建议 | 缺证据时不得生成评分 | 报告文件和检查清单 |

### 1. 项目识别

自动检测语言（pom.xml → Java / package.json → JS/TS / pyproject.toml → Python / go.mod → Go）。
自动忽略：node_modules/, dist/, build/, target/, __pycache__/, .venv/, .git/, vendor/

项目快照（立即执行）：

特征文件检测:
!`for f in pom.xml build.gradle package.json pyproject.toml go.mod Cargo.toml; do test -f "$f" && echo "FOUND: $f"; done 2>/dev/null || echo "NO_PROJECT_FILE"`

代码规模概估:
!`find . -name "*.java" -o -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.go" -o -name "*.rs" 2>/dev/null | grep -v node_modules | grep -v __pycache__ | grep -v .venv | grep -v dist | grep -v build | grep -v target | grep -v vendor | wc -l | xargs echo "SOURCE_FILES:"`

依赖文件摘要:
!`head -20 package.json 2>/dev/null || head -20 pyproject.toml 2>/dev/null || head -20 go.mod 2>/dev/null || echo "NO_DEPENDENCY_FILE"`

### 2. 确定性预扫描

执行以下脚本获取项目基础数据，输出作为 Agent 1-4 的上下文输入：

```bash
bash {{RUNTIME_HOME}}/skills/scan/scripts/project-stats.sh [项目路径]
bash {{RUNTIME_HOME}}/skills/scan/scripts/complexity-scan.sh [项目路径]
bash {{RUNTIME_HOME}}/skills/scan/scripts/dependency-stats.sh [项目路径]
bash {{RUNTIME_HOME}}/skills/scan/scripts/dir-tree.sh [项目路径]
```

> 脚本失败时退回 Glob/Grep 手动统计。

### 3. 并行扫描（6 Agent）

| Agent | 检测任务 | 跳过条件 |
|-------|---------|---------|
| Agent 1 | 铁律检测 | — |
| Agent 2 | 安全漏洞 | — |
| Agent 3 | 代码规范 | — |
| Agent 4 | 技术债 | — |
| Agent 5 | Skills 质量 | 无项目级自定义 Skills 目录 |
| Agent 6 | 文档一致性 | 无 docs/ 且无 README |

当 Agent 1-4 执行检测时，读取 `references/sqale-scoring.md`（检测规则部分），获取铁律/安全/规范/技术债检测模式和严重度权重。

当 Agent 5 执行 Skills 质量扫描时，读取 `references/skills-scan-rules.md`，获取 R0-R9 规则和静态健康信号。

当 Agent 6 执行文档一致性扫描时，读取 `references/docs-scan-rules.md`，获取 V1-V5 检测维度和跳过规则。

### 4. 性能分析（可选，`/scan perf` 子命令）

用户传入 `/scan perf` 时，读取 `references/perf-tools.md`，获取工具选择和输出规范。

输出瓶颈 TOP 5 + 火焰图。

### 5. 汇总报告

汇总评分时，读取 `references/sqale-scoring.md`（评分算法部分），获取技术债权重公式和 A-F 评级映射。

输出到 `docs/reports/tech-debt/[YYYY-MM-DD]_技术债扫描报告.md`，包含：
- 健康度评分和评级
- 问题分级列表（严重/警告/建议），每项附 file_path:line_number + 修复建议
- 修复优先级排序
- 性能分析结果（如执行）

## 完成校验

- [ ] 项目语言和规模已识别
- [ ] 6 个 Agent 扫描全部完成（跳过的 Agent 已注明原因）
- [ ] 每个问题附 file_path:line_number
- [ ] 健康度评分有客观证据
- [ ] 报告已保存到 `docs/reports/tech-debt/`

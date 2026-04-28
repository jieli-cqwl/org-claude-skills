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

### 项目快照

特征文件检测:
!`for f in pom.xml build.gradle package.json pyproject.toml go.mod Cargo.toml; do test -f "$f" && echo "FOUND: $f"; done 2>/dev/null || echo "NO_PROJECT_FILE"`

代码规模概估:
!`find . -name "*.java" -o -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.go" -o -name "*.rs" 2>/dev/null | grep -v node_modules | grep -v __pycache__ | grep -v .venv | grep -v dist | grep -v build | grep -v target | grep -v vendor | wc -l | xargs echo "SOURCE_FILES:"`

依赖文件摘要:
!`head -20 package.json 2>/dev/null || head -20 pyproject.toml 2>/dev/null || head -20 go.mod 2>/dev/null || echo "NO_DEPENDENCY_FILE"`

### 1. 项目识别

自动检测语言（pom.xml → Java / package.json → JS/TS / pyproject.toml → Python / go.mod → Go）。
自动忽略：node_modules/, dist/, build/, target/, __pycache__/, .venv/, .git/, vendor/

### 1.5 确定性预扫描

执行以下脚本获取项目基础数据，输出作为 Agent 1-4 的上下文输入：

```bash
bash {{RUNTIME_HOME}}/skills/scan/scripts/project-stats.sh [项目路径]
bash {{RUNTIME_HOME}}/skills/scan/scripts/complexity-scan.sh [项目路径]
bash {{RUNTIME_HOME}}/skills/scan/scripts/dependency-stats.sh [项目路径]
bash {{RUNTIME_HOME}}/skills/scan/scripts/dir-tree.sh [项目路径]
```

> 脚本失败时退回 Glob/Grep 手动统计。

### 2. 并行扫描（6 Agent）

| Agent | 检测任务 | 内容 | 跳过条件 |
|-------|---------|------|---------|
| Agent 1 | 铁律检测 | 降级逻辑、硬编码、Mock(非测试) | — |
| Agent 2 | 安全漏洞 | SQL 注入、XSS、敏感信息泄露 | — |
| Agent 3 | 代码规范 | 函数过长、空 catch、System.out | — |
| Agent 4 | 技术债 | 进度占位标记、FIXME/HACK、废弃代码、大文件 | — |
| Agent 5 | Skills 质量 | Skill 准入门禁、触发、任务契约、执行协议、资源、运行安全、产物、验证、效果证据和演化集成 | 无项目级自定义 Skills 目录（默认 `.claude/skills/`） |
| Agent 6 | 文档一致性 | 引用有效性/归档状态/过时检测/README准确性/结构完整性 | 无 docs/ 且无 README |

当 Agent 1-4 执行检测时：
→ Trigger: Agent 1-4 执行检测；Read: `references/sqale-scoring.md`；Expect: 铁律检测模式、安全漏洞模式、代码规范阈值、技术债分类及各严重度技术债权重；Consume: Agent 1-4 findings 与汇总评分；Evidence: findings 引用 file_path:line_number 和评分权重；Sync: SQALE 规则变化时同步本入口、报告字段和相关测试。

当 Agent 5 执行 Skills 质量扫描时：
→ Trigger: Agent 5 执行 Skills 质量扫描；Read: `references/skills-scan-rules.md`；Expect: R0-R9 检测规则、静态健康信号和最终裁决边界；Consume: Agent 5 findings 与 Skills 质量小节；Evidence: 每个 Skill finding 绑定质量维度和 file_path:line_number；Sync: Skill 质量标准变化时同步本入口、规则文件和测试。

当 Agent 6 执行文档一致性扫描时：
→ Trigger: Agent 6 执行文档一致性扫描；Read: `references/docs-scan-rules.md`；Expect: V1-V5 检测维度和跳过规则；Consume: Agent 6 findings 与文档一致性小节；Evidence: 文档 finding 绑定路径、引用或跳过原因；Sync: 文档管理规则变化时同步本入口、规则文件和测试。

### 3. 性能分析（可选，`/scan perf` 子命令）

当执行性能分析时：
→ Trigger: 用户传入 `/scan perf`；Read: `references/perf-tools.md`；Expect: quick/deep/n1/memory/flame/sql 工具选择和输出规范；Consume: 性能分析结果小节；Evidence: 瓶颈 TOP 5、火焰图路径或不可执行说明；Sync: 性能工具支持变化时同步本入口、规则文件和测试。

输出瓶颈 TOP 5 + 火焰图。

### 4. 汇总报告

当计算健康度评分时：
→ Trigger: 汇总健康度评分；Read: `references/sqale-scoring.md`；Expect: 技术债权重公式、技术债比率计算和 A-F 评级映射表；Consume: 报告评分与评级；Evidence: 分数引用问题清单和权重来源；Sync: 评分公式变化时同步本入口、报告字段和测试。

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

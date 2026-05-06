---
name: github-repo-radar
user-invocable: true
description: 发现与评估 GitHub 仓库。Use when 用户要找 GitHub 仓库候选、判断 repo 是否值得学习/采用/贡献、比较同类项目或建立项目雷达，并需要基于当前证据给出动作状态。
argument-hint: "[发现|评估|对比|贡献|雷达] [领域或 repo URL]"
allowed-tools: Read, Write, WebSearch, WebFetch, AskUserQuestion
---

# /github-repo-radar -- GitHub 仓库雷达

## HARD-GATE

1. NO repo recommendation without current evidence from GitHub or authoritative upstream sources.
2. NO quality verdict based only on stars, Trending, README, downloads, or Scorecard total.
3. NO adoption recommendation without checking purpose fit, license, maintenance, security, and exit path.
4. NO contribution recommendation without checking CONTRIBUTING, recent maintainer response, and runnable local path.
5. NO radar output without action state: discard, watch, trial, deep-read, contribute, or adopt.

## 角色

你是 GitHub 开源项目雷达分析师。用当前 GitHub 或权威上游证据，把候选仓库收敛成可判断、可试用、可复查的行动清单。

## 触发与分流

触发：用户要发现、评估、比较、学习、贡献、采用或长期跟踪 GitHub 仓库，并需要 `discard/watch/trial/deep-read/contribute/adopt` 动作状态。

分流：

- 通用技术/生态深度调研、行业报告或方案机制拆解 → `research` / `deep-research`。
- 代码仓库漏洞扫描、依赖审计、密钥泄露排查 → `security`。
- 代码质量、技术债、性能或项目健康巡检 → `scan` / `overview`。
- 法律 license 最终审批、安全最终审批、生产依赖最终批准 → 用户组织流程；本 Skill 只给 repo 证据与验证建议。

## 输入

- 必需：目标场景（`learn` 学源码、`adopt` 引入依赖、`contribute` 找贡献入口、`compare` 横评同类项目、`track` 建立长期雷达）和对象（领域关键词、技术栈、GitHub repo URL、候选仓库列表，或用户已有 star/list）。
- 用户约束：语言、许可证要求、活跃度要求、合规限制、依赖政策、时间预算、输出位置。
- 禁止猜测：生产采用批准、法律接受度、安全放行、私有仓库访问权限和用户真实风险偏好。缺这些信息时写成证据缺口、降级原因或下一步验证，不替用户批准。
- 输出位置：默认对话输出；用户要求留档时写入 `docs/github-repo-radar/{topic}-report.md`。

## 流程

状态表：

| 状态 | 动作 | 停止/转移 |
| --- | --- | --- |
| Goal | 复述目标场景、对象、约束和预期结果 | 目标不清则追问 |
| Evidence Plan | 规划来源类别、抓取日期和必要证据 | 缺必需输入则追问；缺采用证据则不得 adopt |
| Red Lines | 声明淘汰规则和硬红线 | 触发红线则 discard |
| Discovery | 组合 GitHub/上游搜索式发现候选 | 来源链不清则标注风险或排除 |
| Evaluation | 按 rubric 七层评分并挑战热度指标 | 证据不足则 watch，不给 adopt |
| Comparison | 至少比较成熟/新兴/小而稳候选 | 候选不足则说明盲区 |
| Minimal Validation | 给出 runnable/read/contribute/track 下一步 | 无验证路径则不得推荐 adopt/contribute |
| Radar Report | 输出动作状态和复查口径 | 缺动作状态不得完成 |

候选、评分、动作状态、证据缺口、降级原因和复查条件必须能追溯到 GitHub 或权威上游证据。

### 1. 复述目标

先说明本次操作对象、目标场景、筛选维度和预期结果。目标不清时先追问，不要直接搜索。

### 2. 规划证据

搜索前先给证据计划：

- 来源类别：官方文档/API、GitHub 仓库事实、社区/行业健康信号、本地 rubric、用户约束。
- 抓取日期：记录本次证据检查日期。
- 必查证据：repo URL、搜索式、owner/来源链、license、维护、security、文档、采用或贡献信号。
- 降级规则：缺 license/security/maintenance/fit/exit path 时，不得直接 `adopt`；缺 CONTRIBUTING、本地运行或维护者响应时，不得直接 `contribute`。

### 3. 设定红线

采用或贡献前先声明淘汰规则：

- 无 LICENSE 或授权范围不匹配。
- 来源链无法自证，存在 fork、镜像、近名仿冒或包名混淆。
- 核心示例无法运行，且相关 issue 长期无人响应。
- 安全问题、高危依赖、数据损坏类 bug 长期无人处理。
- release 无说明，breaking change 不标注。
- 安装脚本要求执行不明来源远程代码。

### 4. 发现候选

按目标选择入口：

- 领域发现：Topics、Search、Advanced Search、Awesome Lists。
- 新趋势：Trending、Explore、HN Show、DEV、GitHub Changelog。
- 采用验证：package registry、dependents、downloads、release downloads、真实下游案例。
- 贡献入口：`good-first-issues:`、`help-wanted-issues:`、labels、最近新人 PR。

搜索时优先组合 `topic:`、`language:`、`stars:`、`pushed:`、`license:`、`archived:false`、`mirror:false`。

### 5. 评估质量

当需要判断仓库质量时：
→ 读取 `references/evaluation-rubric.md`，按真实性、维护、文档、许可证、安全、采用、适配七层评分。

把 stars、Trending、README、downloads、OpenSSF Scorecard 都当作信号，不当作单点结论。

### 6. 同类横评

用户要选型、采用或学习时，至少比较 3 类候选：

- 成熟方案：采用广、生态稳。
- 新兴方案：增长快、设计新。
- 小而稳方案：范围窄、维护清晰。

若候选不足 3 个，说明检索覆盖和剩余盲区，不要硬凑。

### 7. 最小验证

高价值候选必须给出下一步验证动作：

- `learn`：读哪 3 个文件、看哪 2 个测试、追哪条核心调用链。
- `adopt`：clone、安装、跑示例、跑测试、验证 license/security、评估替换路径。
- `contribute`：读 CONTRIBUTING、运行测试、查看最近新人 PR、先评论确认范围。
- `track`：加入 watch/list 的条件、复查日期、退出条件。

### 8. 输出结论

输出以下结构：

```text
## 结论
## 搜索式与来源
## 候选表
## 质量评估
## 红旗与反方挑战
## 推荐动作
## 雷达记录
## 来源
```

## 输出要求

候选表字段：

```text
repo / 用途 / 适配场景 / 关键证据 / 来源类别 / 抓取日期 / 证据缺口或降级原因 / 主要风险 / 当前动作
```

雷达记录字段：

```text
repo / 同类替代 / 当前结论 / 证据链接 / 来源类别 / 风险 / 下一步 / 复查日期 / 退出条件
```

动作状态：

- `discard`：触发红线或适配不足。
- `watch`：有潜力但证据不足。
- `trial`：值得跑 demo 或小范围试用。
- `deep-read`：适合源码学习。
- `contribute`：适合尝试 issue/文档/测试贡献。
- `adopt`：可进入正式选型或受控试用验证；不是法律、安全或生产最终审批。

## 完成校验

- [ ] 已复述目标场景和操作对象。
- [ ] 已给出搜索式、来源类别、抓取日期或 repo URL 证据。
- [ ] 已标出证据缺口或降级原因。
- [ ] 未用单一热度指标下结论。
- [ ] 采用类结论已覆盖 license、维护、安全、适配和退出路径。
- [ ] 贡献类结论已覆盖 CONTRIBUTING、本地运行和维护者响应。
- [ ] 每个候选都有动作状态、下一步和复查口径。

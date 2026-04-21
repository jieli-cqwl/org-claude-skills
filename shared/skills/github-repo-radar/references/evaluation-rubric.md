# GitHub 仓库评估细则

资源合同：

- Trigger: 判断 GitHub 仓库是否值得学习、采用、贡献、对比或纳入长期雷达时读取。
- Read: 读取本文件的评分层级、红旗、场景差异和输出模板。
- Expect: 得到可审计的 repo 评估口径，避免 star-only、README-only 和 Trending-only 结论。
- Consume: `github-repo-radar` 主流程、人工审查、eval 样例。
- Evidence: 输出中必须保留 repo URL、搜索式、证据链接、抓取日期和反方挑战。
- Sync: 评分维度、状态词或输出字段变化时，同步 `SKILL.md` 与 `evals/evals.json`。

## 七层评分

| 层级 | 看什么 | 通过信号 | 风险信号 |
| --- | --- | --- | --- |
| 真实性 | owner、官网、fork、包名、release 渠道 | 官网指向该仓库，包 metadata 一致 | fork 冒充上游，近名仿冒，来源链断裂 |
| 维护 | 近 6-12 个月 commit、release、issue/PR 响应 | 有实质提交、可读 release、维护者 triage | 长期无人回应，只有机器人提交，归档 |
| 文档 | README、quickstart、API、边界、troubleshooting | 30 分钟内可跑示例，说明支持与不支持场景 | 漂亮营销页但无最小可运行路径 |
| 许可证 | LICENSE、依赖许可证、素材/模型/数据授权 | 授权清楚，适合用户场景 | 无 LICENSE，README 与 LICENSE 冲突 |
| 安全 | SECURITY.md、advisories、Dependabot、CI、Scorecard 单项 | 有漏洞报告渠道，无长期高危项 | 高危依赖长期不修，安装脚本不透明 |
| 采用 | dependents、downloads、真实下游、社区问答 | 有独立下游和真实案例 | star 多但无使用证据，下载异常 |
| 适配 | 技术栈、性能、体积、迁移成本、退出路径 | 解决明确问题，引入和替换成本可控 | 为流行而引入，已有标准库或内部方案 |

## 场景差异

| 场景 | 优先看 | 降权信号 |
| --- | --- | --- |
| 学源码 | 模块清晰、测试完整、问题域典型、代码可读 | 采用度、企业背书 |
| 生产采用 | license、安全、维护、release 质量、退出路径 | README 漂亮度、短期热度 |
| 找贡献 | CONTRIBUTING、good first issue 质量、最近新人 PR、维护者反馈 | stars、下载量 |
| 竞品研究 | 定位、差异化、用户反馈、路线图、替代关系 | 是否适合直接引入 |
| 趋势追踪 | 增长信号、生态讨论、复查日期、失效条件 | 单日 Trending 排名 |

## 红旗

- 无 LICENSE 或 license 不适合用户场景。
- 安装流程要求执行不明来源远程脚本。
- release 二进制没有源码对应、签名、provenance 或构建说明。
- 安全 issue、高危依赖或数据损坏问题长期无人响应。
- 维护者关闭有效问题但不给解释，或社区互动有明显治理风险。
- README 宣称能力与代码、issue、release 不一致。

## 推荐动作口径

| 动作 | 使用条件 | 下一步 |
| --- | --- | --- |
| discard | 命中红线或目标不适配 | 记录淘汰原因 |
| watch | 只有热度或早期信号 | 设置复查日期与补证据项 |
| trial | 证据足够进入试跑 | clone、安装、跑示例或测试 |
| deep-read | 适合学习源码 | 读入口、核心模块、测试 |
| contribute | 贡献入口真实友好 | 评论确认范围，再开分支 |
| adopt | 可进入正式选型 | 补安全、法务、迁移和回滚验证 |

## 反方挑战

每个推荐都要写出至少一个反方挑战：

- 为什么 stars 或 Trending 可能误导？
- 为什么 README 可能包装过度？
- 为什么 release 频率不能直接证明成熟？
- 为什么 Scorecard 高分不等于整体优秀？
- 为什么大量采用不代表适合当前项目？

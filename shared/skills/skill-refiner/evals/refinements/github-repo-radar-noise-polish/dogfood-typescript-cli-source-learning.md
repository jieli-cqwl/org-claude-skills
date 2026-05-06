# Dogfood: TypeScript CLI 源码学习雷达

- Skill: `shared/skills/github-repo-radar/SKILL.md`
- 用户请求: 找 3-5 个最近仍活跃、适合学习源码的 TypeScript/Node.js CLI 仓库，不能按 stars 排，必须输出 `deep-read/watch/trial`，并说明入口文件、测试路径、阅读顺序和降级理由。
- 抓取日期: 2026-05-06
- 结论: PASS。学习场景保持在源码阅读目标上，没有转成采用或贡献推荐；每个候选都有动作状态和下一步阅读路径。

## 目标复述

目标是建立 TypeScript CLI 源码学习清单。这里的 `deep-read` 表示“适合按入口、核心模块、测试三段深入阅读”，不是生产采用、贡献友好或技术选型结论。

## 证据计划

- 来源类别: GitHub Search API、GitHub raw files、npm registry、Skill 本地 rubric、用户约束。
- 必查证据: repo URL、搜索式、license、近期更新信号、npm 包或 package metadata、CLI bin、build/test/lint 脚本、可读入口文件、核心模块或测试路径。
- 降级规则: 只有 stars/downloads、缺源码入口、缺本地验证脚本、仓库体量过大或问题域偏离 CLI 学习时，不给无条件 `deep-read`。

## 搜索式与来源

- `topic:cli language:TypeScript pushed:>2025-11-01 archived:false mirror:false stars:>100`
- npm registry: `knip`、`@oclif/core`、`@changesets/cli`、`@asyncapi/cli`、`czg`、`cz-git`
- GitHub raw files: `package.json`、`LICENSE`、源码入口文件、测试或命令脚本。

执行中遇到 GitHub Repository API 匿名额度耗尽，已记录为证据边界；本轮使用 GitHub Search API 的候选结果、GitHub raw 文件和 npm registry 补证。未完成入口和验证路径闭环的高 star 仓库没有进入推荐。

## 候选表

| repo | 用途 | 学习价值 | 关键证据 | 证据缺口或降级原因 | 主要风险 | 当前动作 |
| --- | --- | --- | --- | --- | --- | --- |
| [webpro-nl/knip](https://github.com/webpro-nl/knip) | 未使用文件、依赖和 exports 检测 CLI | 学静态分析型 CLI 如何组织入口、配置、扫描与报告 | ISC；npm `knip` latest `6.11.0`；CLI bin `knip`/`knip-bun`；`packages/knip/src/cli.ts`、`packages/knip/src/index.ts` 存在；scripts 有 `lint/test/build` | 未在本轮定位到具体测试文件路径，只确认 package 级测试入口 | 静态分析规则较多，阅读时容易被插件细节分散 | deep-read |
| [oclif/core](https://github.com/oclif/core) | Node.js CLI framework core | 学命令、参数、配置、错误处理和测试组织 | MIT；npm `@oclif/core` latest `4.11.0`；`src/command.ts`、`src/config/config.ts`、`test/command/command.test.ts`、`test/config/config.test.ts` 存在；scripts 有 `build/compile/lint/test` | 框架抽象较多，不适合只想看单一业务 CLI 的读者 | 核心框架 API 面广，阅读要先限定 command/config 主线 | deep-read |
| [changesets/changesets](https://github.com/changesets/changesets) | package versioning 和 changelog CLI | 学 release workflow CLI 如何串联 init/version/publish | MIT；npm `@changesets/cli` latest `2.31.0`；CLI bin `changeset`；`packages/cli/src/index.ts`、`commands/init/index.ts`、`commands/version/index.ts`、`commands/publish/index.ts` 存在 | 适合学习发布流程，不适合学习通用 parser 或交互框架 | monorepo 包多，容易从 CLI 主线滑到发布策略细节 | deep-read |
| [Zhengqbbb/cz-git](https://github.com/Zhengqbbb/cz-git) | Commitizen adapter 和 commit message CLI | 学小而完整的交互式 CLI、配置和 monorepo 包拆分 | MIT；GitHub Search 显示 2026-05-06 pushed；npm `czg`/`cz-git` latest `1.13.0`；CLI bin `czg`/`git-czg`；`packages/cli/src/index.ts`、`packages/cli/src/main.ts`、`packages/cz-git/src/index.ts` 存在；root scripts 有 `build/lint/test` | 领域聚焦 commit message，不覆盖大型 CLI 插件体系 | 交互体验和 commitlint 生态细节可能遮住通用 CLI 主线 | deep-read |
| [asyncapi/cli](https://github.com/asyncapi/cli) | AsyncAPI 文件校验与工具链 CLI | 学 oclif 风格业务 CLI、配置、插件和测试命令 | Apache-2.0；GitHub Search 显示 2026-05-06 pushed；npm `@asyncapi/cli` latest `6.0.0`；CLI bin `asyncapi`; `src/index.ts` 存在；scripts 有 `build/lint/cli:test/unit:test/test:one` | 本轮未定位到具体 validate command 文件；业务域依赖 AsyncAPI 规范 | 领域复杂度高，先读核心入口再决定是否深入 | trial |

## 质量评估

- `knip` 是最适合读静态分析型 CLI 的候选，入口和 package 级验证脚本清楚，范围也比大型包管理器更可控。
- `oclif/core` 适合学习 CLI framework 内核，不适合当作业务 CLI 第一站；阅读应限制在 command/config/test 主线。
- `changesets` 适合学习 release workflow CLI，它的价值在流程编排，不在通用命令解析。
- `cz-git` 是本轮“小而完整”的候选，stars 不是最高，但源码入口、测试脚本和领域边界更适合快速建立 CLI 结构感。
- `asyncapi/cli` 近期活跃且测试入口完整，但领域知识较重，先给 `trial`，避免把业务规范复杂度误判成 CLI 源码学习价值。

## 红旗与反方挑战

- 高 star 不等于适合读源码：`n8n`、`Kilo-Org/kilocode` 等搜索结果热度高，但范围更像平台或 AI 工具，不适合作为 TypeScript CLI 源码第一站。
- npm 最新版本不等于源码清晰：包 metadata 只能证明发布状态，还要看到入口文件和测试入口。
- 大仓库不一定更好学：`pnpm` 适合专项深读包管理器，但对一般 CLI 学习者体量过大，本轮不作为首推。
- 业务 CLI 不等于通用 CLI：`asyncapi/cli` 有学习价值，但领域概念可能成为额外负担，所以降为 `trial`。

## 推荐动作

1. deep-read `webpro-nl/knip`: 先读 `packages/knip/src/cli.ts`，再读 `packages/knip/src/index.ts`，最后跑 package 级 `test/build/lint`。
2. deep-read `oclif/core`: 先读 `src/command.ts`，再读 `src/config/config.ts`，最后对照 `test/command/command.test.ts` 和 `test/config/config.test.ts`。
3. deep-read `changesets/changesets`: 先读 `packages/cli/src/index.ts`，再读 `commands/init/version/publish` 三条命令链。
4. deep-read `Zhengqbbb/cz-git`: 先读 `packages/cli/src/index.ts` 和 `packages/cli/src/main.ts`，再读 `packages/cz-git/src/index.ts`。
5. trial `asyncapi/cli`: 先读 `src/index.ts` 和 `package.json` scripts，只在 AsyncAPI 领域也值得学习时继续深入。

## 雷达记录

| repo | 同类替代 | 当前结论 | 证据链接 | 风险 | 下一步 | 复查日期 | 退出条件 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `webpro-nl/knip` | `ts-prune`、`depcheck` | deep-read | [repo](https://github.com/webpro-nl/knip)、[npm](https://www.npmjs.com/package/knip)、[cli.ts](https://raw.githubusercontent.com/webpro-nl/knip/main/packages/knip/src/cli.ts)、[index.ts](https://raw.githubusercontent.com/webpro-nl/knip/main/packages/knip/src/index.ts) | 静态分析细节多 | 读入口和报告链，再跑 package 测试 | 2026-06-06 | 找不到稳定测试入口或配置成本过高 |
| `oclif/core` | `commander`、`yargs` | deep-read | [repo](https://github.com/oclif/core)、[npm](https://www.npmjs.com/package/@oclif/core)、[command.ts](https://raw.githubusercontent.com/oclif/core/main/src/command.ts)、[config.ts](https://raw.githubusercontent.com/oclif/core/main/src/config/config.ts) | 框架抽象面广 | 限定 command/config/test 主线 | 2026-06-06 | 阅读目标变成业务 CLI 而非框架内核 |
| `changesets/changesets` | `semantic-release`、`release-please` | deep-read | [repo](https://github.com/changesets/changesets)、[npm](https://www.npmjs.com/package/@changesets/cli)、[cli index](https://raw.githubusercontent.com/changesets/changesets/main/packages/cli/src/index.ts)、[version](https://raw.githubusercontent.com/changesets/changesets/main/packages/cli/src/commands/version/index.ts) | 发布流程细节多 | 读 init/version/publish 三条命令 | 2026-06-06 | 目标变成生产发布选型 |
| `Zhengqbbb/cz-git` | `commitizen`、`commitlint` | deep-read | [repo](https://github.com/Zhengqbbb/cz-git)、[czg npm](https://www.npmjs.com/package/czg)、[cli main](https://raw.githubusercontent.com/Zhengqbbb/cz-git/main/packages/cli/src/main.ts)、[cz-git index](https://raw.githubusercontent.com/Zhengqbbb/cz-git/main/packages/cz-git/src/index.ts) | commit message 领域较窄 | 读 CLI 到 adapter 的调用链 | 2026-06-06 | 需要学习大型插件系统 |
| `asyncapi/cli` | `oclif/core`、`openapi-generator-cli` | trial | [repo](https://github.com/asyncapi/cli)、[npm](https://www.npmjs.com/package/@asyncapi/cli)、[src index](https://raw.githubusercontent.com/asyncapi/cli/master/src/index.ts)、[package](https://raw.githubusercontent.com/asyncapi/cli/master/package.json) | 业务规范复杂 | 先读入口和测试脚本，再决定是否深读 | 2026-06-06 | AsyncAPI 领域成本超过 CLI 学习收益 |

## Dogfood 复盘

- 目标保持: PASS。全程围绕源码学习，没有偏到生产采用或贡献入口。
- 深读路径: PASS。每个 `deep-read` 候选都有入口文件、核心模块或测试/脚本路径。
- 动作状态: PASS。包含 `deep-read` 和 `trial`，没有把搜索结果全推荐。
- 反方挑战: PASS。挑战了 stars、npm 版本、大仓库、业务领域复杂度和热度平台类仓库。
- 证据诚实: PASS。GitHub API rate limit 被记录为限制，未用未闭环候选凑数。
- 需要继续改 Skill: 暂无硬缺口。`github-repo-radar` 在 learn 场景能守住目标复述、证据计划、动作状态和最小阅读路径。

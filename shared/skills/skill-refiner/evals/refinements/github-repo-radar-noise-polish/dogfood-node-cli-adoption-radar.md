# Dogfood: Node.js/TypeScript CLI 生产采用雷达

- Skill: `shared/skills/github-repo-radar/SKILL.md`
- 用户请求: 评估 3-5 个适合团队生产采用的 TypeScript/Node.js CLI 或自动化工具仓库，不能按 stars 排，必须输出 adopt/trial/watch/discard，并说明 license、maintenance、security、exit path 和降级理由。
- 抓取日期: 2026-05-06
- 结论: PASS。采用场景没有直接按热度推荐；每个候选都有动作状态、证据缺口、降级原因和下一步验证。

## 目标复述

目标是给 Node.js/TypeScript 团队建立生产采用雷达。这里的 `adopt` 只表示“可进入正式选型或受控试用验证”，不是替代法务、安全或生产变更审批。

## 证据计划

- 来源类别: GitHub Search API、GitHub Repository API、GitHub raw files、npm registry、npm downloads API、Skill 本地 rubric、用户约束。
- 必查证据: repo URL、搜索式、owner/source chain、license、维护活跃度、release/npm 最新版本、security policy、依赖自动化信号、测试/CI 入口、采用信号、退出路径。
- 降级规则: 缺 license、maintenance、security、fit 或 exit path 任一关键证据，不给无条件 `adopt`；影响面大、迁移成本高或合规风险未裁决时降为 `trial/watch`。

## 搜索式与来源

- `topic:automation language:TypeScript pushed:>2025-11-01 archived:false mirror:false stars:>100`
- `topic:cli language:TypeScript pushed:>2025-11-01 archived:false mirror:false stars:>100`
- `topic:monorepo language:TypeScript pushed:>2025-11-01 archived:false mirror:false stars:>100`
- `dependency automation language:TypeScript pushed:>2025-11-01 archived:false mirror:false stars:>100 in:name,description,topics`

执行中遇到 GitHub API 匿名额度耗尽，后半段改用 GitHub raw 文件和 npm registry 补证。该限制不影响已补到的 5 个候选，但排除了 `nrwl/nx`、`cloudflare/workers-sdk` 等未完成采用证据闭环的候选。

## 候选表

| repo | 用途 | 适配场景 | 关键证据 | 证据缺口或降级原因 | 主要风险 | 当前动作 |
| --- | --- | --- | --- | --- | --- | --- |
| [changesets/changesets](https://github.com/changesets/changesets) | monorepo/package versioning 与 changelog | npm package 或多包 monorepo 发布流程 | MIT；GitHub pushed 2026-05-06；npm `@changesets/cli` latest `2.31.0` at 2026-04-17；last-month downloads 11,661,974；有 `SECURITY.md`、Dependabot、CLI bin、tests/build/lint | 未见根目录 `CONTRIBUTING.md`，但采用场景不是贡献场景；只适合包发布，不适合 app deploy | 变更 release 流程，需和现有 CI/npm publish 权限对齐 | adopt |
| [pnpm/pnpm](https://github.com/pnpm/pnpm) | 包管理器和 workspace 管理 | 追求安装速度、磁盘效率、严格依赖和 monorepo 管理 | MIT；GitHub pushed 2026-05-06；npm `pnpm` latest `10.33.3` at 2026-05-04；last-month downloads 310,138,803；有 `SECURITY.md`、`CONTRIBUTING.md`、Dependabot；release `v11.0.6` at 2026-05-05 | 影响 lockfile、CI、缓存、开发者本地环境，不能直接全量切换 | package manager 迁移属于高影响基础设施变更，退出要回滚 lockfile 和 CI cache | trial |
| [renovatebot/renovate](https://github.com/renovatebot/renovate) | 依赖更新自动化 CLI/bot | 多仓库依赖更新、配置校验、自动 PR | AGPL-3.0-only；GitHub pushed 2026-05-06；release `43.165.2` at 2026-05-06；npm latest `43.150.0` at 2026-04-28；last-month downloads 2,104,994；有 `SECURITY.md`、CODE_OF_CONDUCT、tests/e2e、config-validator bin | AGPL 和 Mend hosted infra 条款需要组织法务/安全确认；GitHub token 权限和 secret 暴露面需要 threat model | 自动改依赖会影响供应链和 CI 成本；错误配置会制造 PR 噪音 | trial |
| [webpro-nl/knip](https://github.com/webpro-nl/knip) | 未使用文件、依赖、exports 检测 | CI 非阻断扫描、技术债清理、依赖治理 | ISC；GitHub pushed 2026-05-06；npm `knip` latest `6.11.0` at 2026-05-02；last-month downloads 28,184,345；有 `.github/CONTRIBUTING.md`、CLI bin、tests/build/lint scripts | 未见 `SECURITY.md`；采用前需要跑在非阻断模式并校准误报 | 静态分析误报可能导致误删；需要明确 ignore/config owner | trial |
| [lint-staged/lint-staged](https://github.com/lint-staged/lint-staged) | 对 staged files 运行 lint/format/test | Git hooks 中低成本质量门禁 | MIT；npm `lint-staged` latest `16.4.0` at 2026-03-14；last-month downloads 90,697,316；有 `CONTRIBUTING.md`、CLI bin、`test/lint/typecheck` scripts | 未见 `SECURITY.md` 和 Dependabot 配置；仅适合本地/pre-commit 场景，不替代 CI | hook 过重会拖慢提交；误配置会吞掉开发者时间 | trial |

## 质量评估

- `changesets` 是本轮唯一给 `adopt` 的候选，前提是团队目标是 npm package 或 monorepo release 管理。它的 license、security policy、维护和退出路径都能形成闭环。
- `pnpm` 质量和采用信号很强，但迁移影响面大。它适合进入试点，不适合无 POC 直接全仓切换。
- `renovate` 维护和 release 信号非常强，但 AGPL-3.0-only、bot token 权限和 hosted infrastructure 条款是硬风险，必须降为 `trial`。
- `knip` 适合低风险非阻断试跑，缺 `SECURITY.md` 和静态分析误报风险让它不应直接 `adopt`。
- `lint-staged` 成熟且退出简单，但缺 security policy；适合小范围 trial，不应替代 CI 质量门。

## 红旗与反方挑战

- stars/downloads 不能直接证明适合当前团队：`pnpm` 和 `lint-staged` 下载量极高，但迁移面和 hook 体验仍可能让团队收益为负。
- release 频率不能直接证明成熟：`renovate` 高频 release 是维护活跃信号，也意味着配置兼容和版本升级节奏要被治理。
- README/官网不能替代安全评估：`knip` 和 `lint-staged` 文档清楚，但缺 `SECURITY.md`，采用结论必须降级。
- license 是采用硬门槛：`renovate` 的 AGPL-3.0-only 对商业团队、托管使用和二次分发都需要组织审批。
- API 限流是证据边界：未完成 license/security/exit path 闭环的候选被排除，不能靠搜索 metadata 凑数。

## 推荐动作

1. adopt `changesets/changesets`: 只在目标是 npm package/monorepo release 时进入正式选型；先用一个非核心 package 跑 dry-run release。
2. trial `pnpm/pnpm`: 选一个 workspace 做迁移 POC，验证 lockfile、CI cache、Docker build、registry auth、回滚到 npm/yarn 的成本。
3. trial `renovatebot/renovate`: 先用最小权限 token 跑单仓 dry-run，法务确认 AGPL，安全确认 secret/token 权限边界。
4. trial `webpro-nl/knip`: CI 先非阻断运行，记录 2 周误报率，再决定是否 blocking。
5. trial `lint-staged/lint-staged`: 限定只跑快速 formatter/linter，CI 保留最终质量门，提交耗时超过阈值则回退。

## 雷达记录

| repo | 同类替代 | 当前结论 | 证据链接 | 风险 | 下一步 | 复查日期 | 退出条件 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `changesets/changesets` | `semantic-release`、`release-please` | 条件 adopt | [repo](https://github.com/changesets/changesets)、[npm](https://www.npmjs.com/package/@changesets/cli)、[SECURITY.md](https://raw.githubusercontent.com/changesets/changesets/main/SECURITY.md)、[CLI package](https://raw.githubusercontent.com/changesets/changesets/main/packages/cli/package.json) | release 流程迁移和权限配置 | dry-run 一个 package release | 2026-06-06 | dry-run 不能覆盖现有 changelog/version/publish 规则 |
| `pnpm/pnpm` | `npm`、`yarn` | trial | [repo](https://github.com/pnpm/pnpm)、[npm](https://www.npmjs.com/package/pnpm)、[SECURITY.md](https://raw.githubusercontent.com/pnpm/pnpm/main/SECURITY.md)、[package](https://raw.githubusercontent.com/pnpm/pnpm/main/pnpm/package.json) | lockfile/CI/cache/workspace 迁移成本 | 单 workspace POC | 2026-06-06 | CI 不稳定、回滚成本高、团队工具链不兼容 |
| `renovatebot/renovate` | GitHub Dependabot、Mend hosted Renovate | trial | [repo](https://github.com/renovatebot/renovate)、[npm](https://www.npmjs.com/package/renovate)、[SECURITY.md](https://raw.githubusercontent.com/renovatebot/renovate/main/SECURITY.md)、[config-validator](https://raw.githubusercontent.com/renovatebot/renovate/main/lib/config-validator.ts) | AGPL、bot token、供应链 PR 噪音 | 单仓 dry-run + legal/security review | 2026-06-06 | license 不可接受、权限边界无法收紧、PR 噪音不可控 |
| `webpro-nl/knip` | `ts-prune`、`depcheck` | trial | [repo](https://github.com/webpro-nl/knip)、[npm](https://www.npmjs.com/package/knip)、[LICENSE](https://raw.githubusercontent.com/webpro-nl/knip/main/LICENSE)、[CLI](https://raw.githubusercontent.com/webpro-nl/knip/main/packages/knip/src/cli.ts) | 缺 security policy、误报 | CI 非阻断运行 2 周 | 2026-06-06 | 误报率高或配置维护成本超过收益 |
| `lint-staged/lint-staged` | Husky scripts、pre-commit、lefthook | trial | [repo](https://github.com/lint-staged/lint-staged)、[npm](https://www.npmjs.com/package/lint-staged)、[LICENSE](https://raw.githubusercontent.com/lint-staged/lint-staged/main/LICENSE)、[CLI](https://raw.githubusercontent.com/lint-staged/lint-staged/main/bin/lint-staged.js) | 缺 security policy、hook 体验风险 | 限定快速任务并保留 CI gate | 2026-06-06 | 提交耗时过长、开发者绕过、CI 与本地结果不一致 |

## Dogfood 复盘

- 目标保持: PASS。全程围绕生产采用，不偏到源码学习或贡献。
- 采用硬门槛: PASS。每个候选都覆盖 license、maintenance、security、fit、exit path；缺项导致降级。
- 动作状态: PASS。包含 `adopt` 和多个 `trial`，没有把热门仓库全推荐。
- 反方挑战: PASS。挑战了 stars/downloads、release 频率、README、license 和证据边界。
- 证据诚实: PASS。GitHub API rate limit 被记录为限制，未用未闭环候选凑数。
- 需要继续改 Skill: 暂无硬缺口。`github-repo-radar` 在 learn 与 adopt 两类场景下都守住了核心流程；下一步可进入收尾，或再补一个 contribution 场景作为 E5 反证样本。

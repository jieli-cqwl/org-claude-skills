# Dogfood: Node.js/TypeScript CLI 贡献入口雷达

- Skill: `shared/skills/github-repo-radar/SKILL.md`
- 用户请求: 评估 3-5 个适合尝试贡献的 TypeScript/Node.js CLI 或工具仓库，不能按 stars 排，必须输出 contribute/trial/watch/discard，并说明 CONTRIBUTING、本地运行路径、近期维护响应和降级理由。
- 抓取日期: 2026-05-06
- 结论: PASS。贡献场景没有把 good first issue 当作单点结论；缺 CONTRIBUTING、本地运行路径或近期维护响应时已降级。

## 目标复述

目标是找适合尝试第一次或轻量贡献的 Node.js/TypeScript CLI/tool 仓库。`contribute` 表示“适合先评论确认范围，再开分支尝试 PR”，不是保证 PR 会被合并。

## 证据计划

- 来源类别: GitHub issues/pulls 页面、GitHub raw files、npm/package metadata、Skill 本地 rubric、用户约束。
- 必查证据: repo URL、贡献说明、good first/help wanted 或近期可切入 issue、最近 contributor PR 或维护者合并信号、本地安装/测试命令、license、主要风险。
- 降级规则: 缺 `CONTRIBUTING`、缺本地运行路径、缺近期维护响应或只有陈旧 good-first issue 时，不给直接 `contribute`；只能给 `trial/watch/discard`。

## 搜索式与来源

- `is:issue is:open label:"good first issue"` in selected TypeScript/Node.js CLI repos.
- `is:pr is:closed created:>2026-02-01` in selected repos.
- GitHub raw files: `package.json`、`CONTRIBUTING.md`、`.github/CONTRIBUTING.md`、`LICENSE`、README。

GitHub REST API 在上一轮已触发匿名限流，本轮主要用 GitHub HTML 和 raw files 作为当前证据来源。

## 候选表

| repo | 用途 | 适配场景 | 关键证据 | 证据缺口或降级原因 | 主要风险 | 当前动作 |
| --- | --- | --- | --- | --- | --- | --- |
| [asyncapi/cli](https://github.com/asyncapi/cli) | AsyncAPI CLI | 第一次贡献 CLI 命令、错误信息、测试或依赖维护 | Apache-2.0；有 `CONTRIBUTING.md`；`package.json` 有 `build/lint/test/test:one`；open good-first issues: `#1881`、`#1829`；2026-05 有多条 PR merged，含 contributor/collaborator PR | open PR 多，部分 issue 已有关联 PR；开始前必须评论确认未被占用 | issue/PR 队列较长，容易撞车 | contribute |
| [oclif/core](https://github.com/oclif/core) | Node.js CLI framework core | 贡献 CLI help/parser/config 方向的小功能或测试 | MIT；有 `CONTRIBUTING.md`；本地路径: `yarn`、`yarn test`；open good-first + help-wanted issues: `#1001`、`#1002`；2026-04 有非 bot contributor PR merged | good-first issue 创建时间很早，必须先评论确认仍然有效 | 框架内核抽象高，初次贡献需要读测试 | contribute |
| [webpro-nl/knip](https://github.com/webpro-nl/knip) | unused files/deps/exports detector | 贡献插件、误报修复、文档或小规则 | ISC；有 `.github/CONTRIBUTING.md`；本地路径: root `pnpm run --dir packages/knip test`、package `test/build/lint`；2026-04/05 多条 contributor PR merged；open issues 近期活跃 | 没有 open good-first label；适合从近期 bug/插件 issue 评论切入，不适合盲开 PR | 静态分析规则容易产生回归，需要补 fixture/test | contribute |
| [pnpm/pnpm](https://github.com/pnpm/pnpm) | package manager | 有经验贡献者试小修、文档或测试 | MIT；有 `CONTRIBUTING.md` 和 `AGENTS.md`；本地路径: `pnpm install`、`pnpm run compile`、`pd`、`test-main`/package tests；2026-05 有 contributor PR merged；存在 good-first issue | good-first issues 多为 2018-2020，明显陈旧；仓库体量大 | monorepo 和测试成本高，容易选到过时问题 | trial |
| [changesets/changesets](https://github.com/changesets/changesets) | versioning/changelog workflow | 观察贡献机会，不建议直接开 PR | MIT；有 tests/build/lint；open good-first issues: `#377`、`#160` | 根目录 `CONTRIBUTING.md` 404；good-first issues 创建于 2019/2020；缺贡献流程说明 | 贡献入口过旧，直接 PR 风险高 | watch |
| [lint-staged/lint-staged](https://github.com/lint-staged/lint-staged) | staged files quality gate | 小范围 bug report 或 docs，不适合 first PR 主推荐 | MIT；有 `CONTRIBUTING.md`；本地路径: `lint/test/typecheck` | good-first issue 搜索无结果；贡献说明明确新功能通常不会实现 | 项目刻意保持简单，功能类贡献容易被拒 | watch |

## 质量评估

- `asyncapi/cli` 最适合做贡献 dogfood：有明确 good-first issue、贡献说明、可运行命令和近期 PR 合并信号。
- `oclif/core` 的入口也清晰，但 good-first issue 很旧；可贡献前必须评论确认范围。
- `webpro-nl/knip` 没有 good-first label，但近期 contributor PR 非常活跃，适合从具体 bug/plugin issue 切入。
- `pnpm/pnpm` 维护很活跃，但 good-first issue 过旧且仓库大，应该先 trial，不应直接推荐给初次贡献者。
- `changesets` 和 `lint-staged` 体现了反证：有热度、有用途、有测试，不等于适合贡献。

## 红旗与反方挑战

- good-first label 可能过期：`pnpm`、`changesets` 的部分 good-first issue 创建于 2018-2020，不能当作当前可贡献入口。
- PR 合并数量可能被 bot 噪音污染：需要区分 dependabot 与真实 contributor PR。
- CONTRIBUTING 不是万能证明：`lint-staged` 有贡献说明，但其贡献策略偏保守，新功能不一定接受。
- 近期活跃不等于新人友好：`pnpm` 活跃度高，但架构、测试和 review 成本高。
- 没有 good-first label 不等于不能贡献：`knip` 近期 contributor PR 活跃，适合先评论具体 issue。

## 推荐动作

1. contribute `asyncapi/cli`: 先评论 `#1829` 或 `#1881` 确认范围，再本地跑 `npm run test:one` 或相关命令。
2. contribute `oclif/core`: 先评论 `#1001/#1002` 确认仍接受 PR，再跑 `yarn test` 和相关 help/parser 测试。
3. contribute `webpro-nl/knip`: 从近期 bug/plugin issue 评论切入，补 fixture/test 后再开 PR。
4. trial `pnpm/pnpm`: 只选文档、小测试或 maintainer 明确确认的 issue；不要直接拿陈旧 good-first issue 开工。
5. watch `changesets/changesets` 与 `lint-staged/lint-staged`: 等待新的、维护者确认的 issue 或 CONTRIBUTING/label 信号再行动。

## 雷达记录

| repo | 同类替代 | 当前结论 | 证据链接 | 风险 | 下一步 | 复查日期 | 退出条件 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `asyncapi/cli` | `oclif/core`、`webpro-nl/knip` | contribute | [repo](https://github.com/asyncapi/cli)、[CONTRIBUTING](https://raw.githubusercontent.com/asyncapi/cli/master/CONTRIBUTING.md)、[#1829](https://github.com/asyncapi/cli/issues/1829)、[recent PRs](https://github.com/asyncapi/cli/pulls?q=is%3Apr+is%3Aclosed+created%3A%3E2026-02-01) | PR 队列长、issue 可能已有 PR | 评论确认 `#1829/#1881`，再跑本地测试 | 2026-06-06 | 维护者未响应或 issue 已被占用 |
| `oclif/core` | `asyncapi/cli`、`unjs/citty` | contribute | [repo](https://github.com/oclif/core)、[CONTRIBUTING](https://raw.githubusercontent.com/oclif/core/main/CONTRIBUTING.md)、[#1001](https://github.com/oclif/core/issues/1001)、[recent PRs](https://github.com/oclif/core/pulls?q=is%3Apr+is%3Aclosed+created%3A%3E2026-02-01) | issue 陈旧、框架内核复杂 | 评论确认 help-output issue，跑 `yarn test` | 2026-06-06 | issue 不再有效或缺测试定位 |
| `webpro-nl/knip` | `ts-prune`、`depcheck` | contribute | [repo](https://github.com/webpro-nl/knip)、[CONTRIBUTING](https://raw.githubusercontent.com/webpro-nl/knip/main/.github/CONTRIBUTING.md)、[recent issues](https://github.com/webpro-nl/knip/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc)、[recent PRs](https://github.com/webpro-nl/knip/pulls?q=is%3Apr+is%3Aclosed+created%3A%3E2026-02-01) | 无 good-first label、规则回归风险 | 选近期 bug/plugin issue，先评论再补 fixture | 2026-06-06 | 维护者建议不接收或测试成本过高 |
| `pnpm/pnpm` | `npm/cli`、`yarnpkg/berry` | trial | [repo](https://github.com/pnpm/pnpm)、[CONTRIBUTING](https://raw.githubusercontent.com/pnpm/pnpm/main/CONTRIBUTING.md)、[good-first search](https://github.com/pnpm/pnpm/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)、[recent PRs](https://github.com/pnpm/pnpm/pulls?q=is%3Apr+is%3Aclosed+created%3A%3E2026-02-01) | good-first 旧、monorepo 大 | 只试 maintainer 确认的小范围 issue | 2026-06-06 | 确认前置沟通无响应或测试链太重 |
| `changesets/changesets` | `semantic-release`、`release-please` | watch | [repo](https://github.com/changesets/changesets)、[good-first search](https://github.com/changesets/changesets/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)、[package](https://raw.githubusercontent.com/changesets/changesets/main/package.json) | 缺 CONTRIBUTING、good-first 陈旧 | 等新 issue 或贡献说明补齐 | 2026-06-06 | 贡献流程长期缺失 |
| `lint-staged/lint-staged` | `lefthook`、`pre-commit` | watch | [repo](https://github.com/lint-staged/lint-staged)、[CONTRIBUTING](https://raw.githubusercontent.com/lint-staged/lint-staged/main/CONTRIBUTING.md)、[good-first search](https://github.com/lint-staged/lint-staged/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)、[package](https://raw.githubusercontent.com/lint-staged/lint-staged/main/package.json) | 无 good-first；feature policy 保守 | 仅关注明确 bug/docs issue | 2026-06-06 | 没有维护者确认的小任务 |

## Dogfood 复盘

- 目标保持: PASS。全程围绕贡献入口，没有偏到采用或源码学习。
- 贡献硬门槛: PASS。`CONTRIBUTING`、本地运行路径、近期维护/合并信号缺一即降级。
- 动作状态: PASS。包含 `contribute`、`trial`、`watch`，不是全推荐。
- 反方挑战: PASS。挑战了 good-first、PR 数量、stars、CONTRIBUTING 和活跃度信号。
- 证据诚实: PASS。GitHub API 限流后使用 HTML/raw 证据；未用缺口候选凑贡献推荐。
- 需要继续改 Skill: 暂无硬缺口。learn/adopt/contribute 三类场景都守住了核心门槛；可进入本轮收尾。

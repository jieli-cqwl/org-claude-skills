# Skill 使用与安装策略

本文定义本仓库纳管 skill 的来源分层、安装覆盖规则、触发策略与前端团队使用口径。

## 目标

- 防止 community skill 静默覆盖 first-party skill。
- 防止语义相近的 skill 同时自动触发。
- 给官网、后台管理系统、H5 等前端工作提供固定使用入口。
- 给新增 community skill 提供统一裁决规则。

## 核心原则

本仓库同时管理两类问题：

| 问题 | 规则层 | 结论 |
| --- | --- | --- |
| 哪个目录的文件进入运行时 | 来源层 | 由安装顺序和同名保护控制 |
| skill 什么时候介入对话 | 触发层 | 由 `agents/openai.yaml` 与 `disable-model-invocation` 控制 |

这两层独立裁决。来源层解决文件覆盖，触发层解决语义重叠。

## 来源分层

| 来源 | 职责 | 安装策略 |
| --- | --- | --- |
| `shared/skills` | 团队自研流程、规则、角色与强约束能力 | 最高优先级，默认保留 |
| `community/superpowers/skills` | small-chain 基线流程能力 | selected 安装，保留 upstream 原文和声明式 overlay |
| `community/anthropic/skills` | 官方通用能力 | selected 安装，保持 upstream 原文 |
| `community/vercel/skills` | 浏览器自动化与生态补充 | 按需 vendor，低频或外部自动化能力默认 manual-only |
| `community/alchaincyf/skills` | skill 优化与评估补充 | 按需 vendor，默认 manual-only |
| `community/nextlevelbuilder/skills` | UI/UX 设计知识库补充 | 按需 vendor，默认 manual-only |

安装合成顺序固定为：

```text
shared/skills
-> community/superpowers/skills
-> community/anthropic/skills
-> community/vercel/skills
-> community/alchaincyf/skills
-> community/nextlevelbuilder/skills
```

同名 skill 的默认策略：

- first-party 或先安装来源已存在同名目录时，后续 community skill 不覆盖。
- 官方接管特例必须显式列入 `community_anthropic_override_skills`。
- 新增同名 skill 前必须先决定：替换、改名、还是不纳入运行时。

## 触发策略

允许自动触发的 skill 必须满足：

- 高频使用。
- 语义边界清晰。
- 触发后不会扩大写入范围。
- 与已有自动 skill 没有明显重叠。

以下类型默认 manual-only：

- 与官方通用 skill 语义重叠的补充型 skill。
- 知识库、风格库、主题库、素材生成类 skill。
- 浏览器外部自动化、登录、抓取、跨站操作类 skill。
- 提交、发布、迁移、删除、外部写入类 skill。
- 流程 owner、审查、验收、故障处置等需要明确阶段边界的 skill。
- 低频专项能力。

Codex 运行时中，manual-only skill 必须移除 `agents/openai.yaml`，并在 `SKILL.md` frontmatter 中声明：

```yaml
user-invocable: true
disable-model-invocation: true
```

为控制 Codex 启动时的 Skill 描述预算，安装合成阶段会压缩第三方 `~/.codex/skills/*/SKILL.md` 运行面副本的 frontmatter `description`：

- `shared/skills` first-party 真源必须直接保持短 description，安装器不得替它改写运行面 description。
- 不改 `community/*/skills` vendor 原文，只改第三方 Codex 运行面副本。
- 第三方 `manual-only` Skill 只保留手动调用入口，避免低频能力占用自动加载描述预算。
- 第三方自动触发 Skill 只有在描述超过预算阈值时才替换为短描述，并保留核心触发语义。

## 前端工作口径

| 场景 | 默认入口 | 手动补充 | 验收入口 |
| --- | --- | --- | --- |
| 官网、Landing、品牌页 | `frontend-design` | `ui-ux-pro-max`、`theme-factory`、`canvas-design` | `webapp-testing` |
| 后台管理系统 | `frontend-design` | `ui-ux-pro-max`、`ux`、`security` | `webapp-testing`、`qa` |
| H5、移动端 Web | `frontend-design` | `ui-ux-pro-max`、`ux` | `webapp-testing`、`qa` |
| 复杂浏览器操作、登录、填表、抓页面 | 无自动入口 | `agent-browser` | `agent-browser` 证据或等价浏览器证据 |

关键分工：

| skill | 定位 |
| --- | --- |
| `frontend-design` | 默认 UI 实现与视觉打磨入口，负责页面、组件、HTML/CSS/React/Vue 等前端实现 |
| `webapp-testing` | 默认本地前端验收入口，负责 Playwright 截图、交互、控制台日志和本地服务验证 |
| `ui-ux-pro-max` | 手动触发的 UI/UX 决策库，负责配色、字体、布局、信息层级、表格、图表、移动端 UX checklist |
| `ux` | 手动触发的交互体验设计与认知走查，负责状态矩阵、错误路径、空态、加载态、边界态 |
| `agent-browser` | 手动触发的重型浏览器自动化，负责外部页面、登录态、填表、点击、抓取、探索测试 |

## 重叠 skill 裁决

### `frontend-design` 与 `ui-ux-pro-max`

- 默认让 `frontend-design` 自动承接页面和组件实现。
- 需要设计系统、配色、字体、信息层级、后台表格、移动端 UX 规则时，手动触发 `ui-ux-pro-max`。
- `ui-ux-pro-max` 不提供自动触发入口。

### `webapp-testing` 与 `agent-browser`

- 本地项目验收默认使用 `webapp-testing`。
- 需要真实浏览器自动化、外部网站、登录、填表、点击、抓页面时，手动触发 `agent-browser`。
- `agent-browser` 不提供自动触发入口。

### `frontend-design` 与 `web-artifacts-builder`

- 仓库内真实页面、组件和应用实现默认使用 `frontend-design`。
- 需要生成可分享的单文件 HTML artifact，手动触发 `web-artifacts-builder`。

### `theme-factory`、`canvas-design` 与前端实现

- 前端真实实现默认不使用它们。
- 需要主题套用、静态海报、PDF/PNG 视觉资产时，手动触发。

## NextLevelBuilder 子 skill 处理策略

`nextlevelbuilder/ui-ux-pro-max-skill` 的包级 `skill.json` 只声明 `ui-ux-pro-max`。上游 `.claude/skills` 目录还包含若干 `ckm:*` 辅助 skill，但它们不进入默认安装清单：

| 上游 skill | 当前动作 | 原因 |
| --- | --- | --- |
| `ckm:design` | 不安装 | 与本仓库架构设计 skill `design` 同名冲突，且聚合 logo、CIP、slides、banner 等非前端主线能力 |
| `ckm:ui-styling` | 观察 | 与 Anthropic `frontend-design` 和 `web-artifacts-builder` 重叠；仅在 shadcn/ui + Tailwind 成为高频项目约束时再试点 |
| `ckm:design-system` | 观察 | token 能力有增量，但与 `ui-ux-pro-max` 的设计系统建议重叠；需先有项目级 token 落地场景 |
| `ckm:brand` | 观察 | 可补客户品牌指南，但会读写项目 `docs/brand-guidelines.md` 与 token 文件，需手动触发和项目授权 |
| `ckm:banner-design` | 不安装 | 偏营销素材、广告图和社媒横幅，不是官网/后台/H5 前端实现主线 |
| `ckm:slides` | 不安装 | 演示文稿能力已有 `pptx`、`theme-factory` 和插件运行时承接 |

## 新增 community skill 裁决流程

1. 确认来源、license、维护状态、上游 ref 与退出路径。
2. 检查是否与 `shared/skills`、`community/anthropic/skills` 或已纳管 community skill 同名。
3. 检查是否与现有自动触发 skill 语义重叠。
4. 决定运行名、来源目录和 selected 清单。
5. 如果存在同名，先记录替换或改名原因，再修改安装逻辑。
6. 如果存在语义重叠，默认加入 manual-only 清单。
7. 补充 quick check 或 runtime integrity 覆盖安装结果。
8. 更新 README 和本文档。

## 维护命令

安装并验证运行面：

```bash
bash install.sh --target all --check quick
```

按当前改动范围查看测试计划：

```bash
bash tests/run-all.sh --changed --list
```

新增或调整安装逻辑后，至少运行与安装、runtime integrity、目标 skill 触发策略直接相关的验证命令。

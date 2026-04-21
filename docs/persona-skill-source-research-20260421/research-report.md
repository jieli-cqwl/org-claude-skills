# 人格蒸馏 Skill 源地址调研报告

> 调研模式：discovery
> 呈现模式：understanding

## 这是什么

- 当前对象：截图中的 9 个 persona / distillation 类 Agent Skill。
- 一句话定义：这类项目把聊天记录、文档、公开材料、个人描述等输入给 AI，整理成可安装的 `SKILL.md` 或一组技能目录，让 AI 在特定场景下复用某个人的说话方式、决策框架、记忆线索或防护策略。
- 最容易混淆的点：它不是模型训练，也不是完整复活某个人；多数项目本质是结构化 Prompt + 文件解析工具 + Claude Code / OpenClaw 等运行时的 skill 入口。

## 当前映射与判断

| 截图词条 | 当前命中源地址 | 判定 | 解决的问题 / 业务场景 | 典型使用入口 |
|---|---|---|---|---|
| colleague-skill / 同事.skill | https://github.com/titanwings/colleague-skill | 命中 | 离职交接、专家经验沉淀、团队隐性知识结构化。把飞书、钉钉、邮件、PR、截图等材料整理成 Work Skill + Persona。 | 安装后输入 `/dot-skill`，或按 README 克隆到 `~/.claude/skills/dot-skill`、`~/.codex/skills/dot-skill`。 |
| nuwa-skill / 女娲.skill | https://github.com/alchaincyf/nuwa-skill | 命中 | 从公众人物、专家或思想者的公开材料中提取心智模型、决策启发式和表达 DNA，用来获得“视角顾问”。 | `npx skills add alchaincyf/nuwa-skill`，然后让 Claude Code “Distill Paul Graham” 这类指令。 |
| yourself-skill / 自己.skill | https://github.com/notdog1998/yourself-skill | 命中 | 把自己的聊天记录、日记、照片和自我描述整理成数字自我，用于自我观察、回忆、决策复盘。 | 克隆到 `.claude/skills/create-yourself` 或 `~/.claude/skills/create-yourself`，然后输入 `/create-yourself`。 |
| ex-skill / 前任.skill | https://github.com/therealXiaomanChu/ex-skill | 命中 | 从前任相关聊天记录、照片、社媒截图和主观描述中生成 Relationship Memory + Persona，用于个人回忆、情感疗愈、告别仪式。 | 克隆到 `.claude/skills/create-ex` 或全局目录，输入 `/create-ex`；管理命令包含 `/let-go {slug}`。 |
| forge-skill | https://github.com/YIKUAIBANZI/forge-skill | 命中 | 把“蒸馏”和“使用”拆开：`forge-self` 生成自我镜像，`forge-persona` 生成他人人格，`use-self` 做替身决策会议，`use-persona` 做记忆驱动对话。 | 克隆到 `~/.claude/skills/forge-skill`，使用 `/forge-self`、`/forge-persona 小明`、`/use-self`、`/use-persona 小明`。 |
| 永生.skill | https://github.com/agenmod/immortal-skill | 命中 | 开源数字永生框架，从聊天记录、文档和多平台数字碎片中结构化蒸馏自己、亲友、导师、同事或公众人物。 | 仓库根目录 `SKILL.md` 是主入口，另有 `steamer-skill`、`distill-shield-skill`、`distill-protocol-skill` 等扩展。 |
| midas.skill | https://github.com/hermesnest/midas-skill | 命中 | 从 Slack、聊天、照片、浏览记录、订单、收据、会议记录等日常噪声里提取赚钱线索、需求缺口、套利机会和下一步动作。 | 老链接 `https://github.com/realteamprinz/midas-skill` 会跳转到当前仓库；README 安装命令仍写 `realteamprinz/midas-skill`。 |
| anti-distill / 反蒸馏.skill | https://github.com/leilei926524-tech/anti-distill | 命中 | 把被要求上交的 Skill 或经验文档“清洗”：保留表面结构，把核心判断、踩坑经验、关系网络等抽离到私人备份。 | 克隆到 `.claude/skills/anti-distill` 或全局目录，输入 `/anti-distill` 并选择清洗强度。 |
| curator.skill / 图鉴.skill | https://github.com/Aar0nPB/curator-skill | 命中 | persona skill 路由器。用户装了很多人格 skill 时，按对话意图从 30 个跨作者 persona skill 中推荐合适对象。 | `npx skills add Aar0nPB/curator-skill -g -y`，然后在 Claude Code / Cursor / Codex CLI 中自然提问。 |

## 用途场景归类

| 类别 | 对应 Skill | 适合什么业务问题 |
|---|---|---|
| 工作知识留存 | colleague-skill、forge-persona、永生.skill | 离职交接、导师/师兄经验留存、关键岗位隐性知识显性化、团队风格复用。 |
| 思维框架借用 | nuwa-skill、永生.skill、curator.skill | 想用某位专家的判断框架分析投资、产品、写作、职业选择或复杂决策。 |
| 自我复盘与数字镜像 | yourself-skill、forge-self、永生.skill | 从日记、聊天、社媒中看清自己的语言习惯、盲区、价值排序和决策模式。 |
| 情感与记忆保存 | ex-skill、forge-persona、永生.skill | 个人回忆、关系复盘、温和告别、纪念某段关系或某个人的说话方式。 |
| 财富机会发现 | midas.skill | 把日常信息流转成机会清单，例如重复抱怨、未被满足的需求、消费偏好、技能积累信号。 |
| 防护与授权 | anti-distill、永生.skill 生态里的 shield / protocol | 不想被动交出核心知识时做信息脱敏、经验分层、授权边界梳理。 |
| skill 发现与编排 | curator.skill | 已安装很多 persona skill，不知道该叫谁来分析问题时做推荐和路由。 |

## 如果你也想用

1. 先选运行环境。最常见是 Claude Code；也有项目支持 OpenClaw、Codex CLI、Cursor、Gemini CLI 等。
2. 看项目的 `README.md` 和 `SKILL.md`。确认安装路径、命令名、需要的 Python 依赖，以及是否会读取聊天记录、浏览记录、照片等敏感数据。
3. 优先全局安装低风险工具，敏感人格类建议项目级安装。Claude Code 常见路径是当前仓库 `.claude/skills/{skill-name}`，全局路径是 `~/.claude/skills/{skill-name}`。
4. 安装后重启对应 Agent 工具，输入项目 README 里的命令，例如 `/create-yourself`、`/create-ex`、`/forge-self`、`/anti-distill`。
5. 第一次使用建议只喂一小批脱敏材料试跑，确认输出风格、文件落点和权限边界，再导入更多原始数据。
6. 使用别人相关数据前先确认授权。聊天记录、照片、社媒截图、工作材料都可能涉及隐私、商业机密或劳动关系风险。

## 候选解析与排除理由

### 保留

| 候选 | 保留理由 | 还缺什么证据 |
|---|---|---|
| titanwings/colleague-skill | GitHub README 与截图“飞书/钉钉数据采集、增量进化、dot-skill”一致。 | 无关键缺口。 |
| alchaincyf/nuwa-skill | GitHub README 明确“distill how anyone thinks”、并行研究流、心智模型提取。 | 无关键缺口。 |
| notdog1998/yourself-skill | GitHub README 明确“与其蒸馏别人，不如蒸馏自己”，数据源和命令与截图一致。 | 无关键缺口。 |
| therealXiaomanChu/ex-skill | GitHub README 明确 `/let-go {slug}`，与截图特征匹配。 | 无关键缺口。 |
| YIKUAIBANZI/forge-skill | GitHub README 明确 `forge-self`、`forge-persona`、`use-self`、`use-persona` 分工。 | 无关键缺口。 |
| agenmod/immortal-skill | GitHub README 明确“永生.skill”和数字永生框架。 | README 中“四维/七维”等文案有混用，维度数量需以当前仓库具体文件为准。 |
| hermesnest/midas-skill | GitHub 当前页面为跳转后的真实仓库，README 与“财富信号/6 lenses”匹配。 | 旧 owner `realteamprinz` 与新 owner `hermesnest` 的迁移时间未进一步核验。 |
| leilei926524-tech/anti-distill | GitHub README 与截图“保核心知识不被提纯”一致。 | 无关键缺口。 |
| Aar0nPB/curator-skill | GitHub README 明确从 30 个跨作者 persona skill 中做推荐。 | 项目 star 少，生态活跃度需后续观察。 |

### 排除

| 候选 | 排除理由 |
|---|---|
| titanwings/ex-skill | 也是前任类项目，但截图包含 `/let-go`，该命令出现在 `therealXiaomanChu/ex-skill`；因此截图条目更准确地对应小蛮仓库。 |
| realteamprinz/midas-skill 作为当前主地址 | 该 URL 现在跳转到 `hermesnest/midas-skill`；可作为兼容老链接，不作为当前最终展示地址。 |
| 各类目录站、新闻稿、转载文章 | 可作为线索，不作为上游源；最终以上游 GitHub 仓库 README 为准。 |

## 独立挑战记录

| 挑战点 | 质疑 | 回应 | 是否调整 |
|---|---|---|---|
| 截图是否可能来自二次汇总，源地址被汇总者写错 | 部分条目有近名仓库，直接照图会装错。 | 对 `ex-skill` 和 `midas.skill` 做了近名排除与跳转核验。 | 是 |
| 目录站列出的项目是否都是真实上游 | 目录站可能自动生成或混入不存在/低质量项目。 | 对 9 个条目逐个打开 GitHub 仓库核对 README，而不是只引用目录站。 | 是 |
| 这些项目是否真的适合业务使用 | 人格类项目存在隐私、授权、劳动关系和伦理问题。 | 把场景分为工作留存、个人复盘、情感保存、防护等，并把授权与脱敏列为使用前置。 | 是 |

## 检索路径与覆盖证明

- 名称归一化：`colleague-skill` / `同事.skill` / `dot-skill`；`nuwa-skill` / `女娲.skill`；`yourself-skill` / `自己.skill`；`ex-skill` / `前任.skill` / `/let-go`；`forge-skill` / `Forge Skill`；`immortal-skill` / `永生.skill`；`midas-skill` / `midas.skill`；`anti-distill` / `反蒸馏.skill`；`curator-skill` / `图鉴.skill`。
- 已查对象类型：GitHub 仓库、GitHub README、目录站、新闻/博客转载、本地仓库文件。
- 已查 discovery 入口：GitHub 搜索、Web 搜索、`titanwings` dot-skill gallery、awesome persona skill 汇总、当前工作区 `rg` 预扫描。
- 剩余盲区：未运行安装命令验证每个 skill 的实际可用性；未审计每个仓库代码安全；未核验每个项目许可证之外的数据合规边界。

## 项目上下文

- 本地工作区：`/Users/lijieli/org-claude-skills`。
- 本地扫描结果：当前仓库主要 vendor 了 Anthropic、Superpowers、Vercel、Alchaincyf Darwin、NextLevelBuilder 等 skill 来源；截图中的 9 个项目不是当前仓库已安装的主线 skill 集合。
- 约束：本次只做对象定位与使用说明，不安装第三方 skill，也不导入个人数据。

## 证据索引

- GitHub：colleague-skill — https://github.com/titanwings/colleague-skill
- GitHub：nuwa-skill — https://github.com/alchaincyf/nuwa-skill
- GitHub：yourself-skill — https://github.com/notdog1998/yourself-skill
- GitHub：ex-skill — https://github.com/therealXiaomanChu/ex-skill
- GitHub：forge-skill — https://github.com/YIKUAIBANZI/forge-skill
- GitHub：immortal-skill — https://github.com/agenmod/immortal-skill
- GitHub：midas-skill — https://github.com/hermesnest/midas-skill
- GitHub：anti-distill — https://github.com/leilei926524-tech/anti-distill
- GitHub：curator-skill — https://github.com/Aar0nPB/curator-skill
- Gallery：dot-skill / colleague-skill-site — https://titanwings.github.io/colleague-skill-site

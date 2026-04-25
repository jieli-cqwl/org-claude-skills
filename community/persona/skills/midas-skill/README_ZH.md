<div align="center">

# midas.skill

> *"财富不在 Bloomberg 终端里,也不在 VC 路演里。财富藏在你每天的日常噪音里 —— 你只是被训练得对它视而不见。"*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-blue.svg)](https://python.org)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![AgentSkills](https://img.shields.io/badge/AgentSkills-Standard-green)](https://agentskills.io)

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2?logo=discord&logoColor=white)](#)

<br>

你这周的 Slack 聊天漏出了三个创业点子 —— 你却一滑而过。<br>
你的相册里藏着一套社区套利方案 —— 你早忘了自己拍过这些照片。<br>
你朋友群的抱怨就是一场自发的焦点小组 —— 群里没人意识到。<br>
你的 YouTube 观看历史是 14 个小时的"你正在变成付费专家"的证据 —— 你却说这是"在浪费时间"。<br>
你在亚马逊上的反复下单就是被市场验证过的真实需求 —— 你却以为自己只是在购物。<br>

**把你的重复指令变成黄金 —— 欢迎来到"噪音变黄金"提炼厂!**

<br>

把你任何一条日常信息流喂给它(Slack、照片、聊天、浏览记录、小票、抱怨)<br>
加上你自己的直觉和疑问<br>
得到的是 **一份排序后的"金钱信号 + 机会 + 立即下一步行动"清单**

[支持的数据源](#支持的数据源) · [安装](#安装) · [用法](#用法) · [演示](#演示) · [详细安装](#详细安装) · [💬 Discord](#)

[**English**](README.md) · [**Español**](README_ES.md) · [**Deutsch**](README_DE.md) · [**日本語**](README_JA.md) · [**Русский**](README_RU.md) · [**Português**](README_PT.md)

</div>

---

作者:[@realteamprinz](https://github.com/realteamprinz) | 项目定位:**Nuwa 女娲提炼人的思维方式。Midas 点石成金,提炼如何把你的日常噪音变成钱。**

## 支持的数据源

> Midas 会接收你自愿喂给它的任何信息流。**重复本身就是信号** —— 生活中出现两次以上的东西,就喂给它。

| 来源 | 最佳视角 | 说明 |
|------|:--------:|------|
| Slack / Teams 消息 | 需求缺口、金钱信号 | 团队频道里全是供应商吐槽、预算信号、手工变通 |
| WhatsApp / iMessage / 微信聊天 | 需求缺口、人脉路径 | 多人重复抱怨 = 未被满足的需求 |
| 手机相册(未筛选) | 套利窗口、需求缺口 | 工地、空店铺、人群、价签、招牌 |
| YouTube / 抖音观看历史 | 技能变现桥梁、行为杠杆 | 持续聚焦的主题 = 正在积累的隐性专长 |
| 浏览器历史 | 技能变现桥梁、金钱信号 | 研究轨迹、比价、排查问题的过程 |
| 购物历史 / 订阅列表 | 金钱信号、行为杠杆 | 重复消费 = 已验证的需求和自动驾驶习惯 |
| 会议记录(内部) | 金钱信号、需求缺口 | 预算讨论、工具吐槽、流程断点 |
| 邮件 `.eml` / `.mbox` | 金钱信号、人脉路径 | 佣金邀约、转介绍链、供应商报价 |
| 小票 / 订单确认 | 金钱信号、套利 | 这是你真正在乎什么的最诚实信号 |
| 直接粘贴文本 | 全部 6 个视角 | 哪怕是一段语音转文字也能产生信号 |

完整的来源层级和三角验证规则见 [references/sources-guide.md](references/sources-guide.md)。

---

## 安装

### Claude Code

> **重要**:Claude Code 在 **git 仓库根目录** 的 `.claude/skills/` 里查找技能。一定要在正确的目录里执行命令。

```bash
# 安装到当前项目(在 git 仓库根目录运行)
mkdir -p .claude/skills
git clone https://github.com/realteamprinz/midas-skill .claude/skills/midas-skill

# 或者全局安装(所有项目都能用)
git clone https://github.com/realteamprinz/midas-skill ~/.claude/skills/midas-skill
```

### OpenClaw

```bash
git clone https://github.com/realteamprinz/midas-skill ~/.openclaw/workspace/skills/midas-skill
```

### 依赖(可选)

Midas 目前是纯 Markdown,无需运行时依赖。未来会加入 Python 工具(浏览器历史解析、小票 OCR 等)用于自动采集,届时会放在 `tools/` 目录下。

---

## 用法

在 Claude Code 或 OpenClaw 里,输入 Midas 的任意触发词:

```
Midas, mine this                 → 粘贴任何输入,得到信号报告
Turn this into gold              → 同上
What money signal is here        → 更具体的框架
点石成金                         → 中文触发词
Midas, analyze this deal         → 交易分析模式(见 references/deal-template.md)
What am I missing                → 喂入一周的你自己的消息
```

Midas 会把每条输入跑过 6 重提取视角,与你的 `evolution/evolution.jsonl` 日志交叉引用,返回一份带有**立即下一步行动**的排序信号报告。

### 六重视角

| # | 视角 | 核心问题 |
|---|------|----------|
| 1 | **金钱信号** | 钱在哪里流动、卡住或渗漏? |
| 2 | **需求缺口** | 人们想要什么而没人在好好提供? |
| 3 | **套利窗口** | 价值在哪里被错误定价? |
| 4 | **技能变现桥梁** | 你已经掌握的什么东西有市场价值? |
| 5 | **人脉路径** | 谁该跟谁说话,介绍费归谁? |
| 6 | **行为杠杆** | 哪个自动驾驶的习惯离收入只差一次转向? |

完整方法论见 [references/signal-extraction-framework.md](references/signal-extraction-framework.md)。

---

## 演示

> 输入:*"Midas, mine this —— 这是我上周的 Slack:[粘贴 73 条消息]"*

```
[MIDAS 信号报告]

输入类型:        slack_messages
数据量:          73 条消息,3 个频道 + 4 个私聊
扫描日期:        2026-04-09

🟡 检测到金钱信号: 7
🔴 噪音丢弃:      ~65 条(89%)

🥇 #1 —— Marcus 作为内部顾问(技能桥梁切入点)
    置信度: 50% | 投入: 低 | 上行空间: $3–8k/月 副业
    证据:
      - Sarah 私聊:"如果有人能端到端解决 AWS tagging,$5k 以内我们愿意付"
      - Priya 私聊:"我自己就愿意付钱用这个"
      - 同一周内 3 个不同的利益相关者都找 Marcus 帮忙
    模式匹配:Buffett —— 待在你的能力圈内

    ⚡ 立即下一步行动:
       周一早上 9 点,给 Sarah 发一个有明确范围的报价:
       "AWS tagging 项目 —— 固定费用 $3,500,下周五交付。"

🥈 #2 —— AWS 成本可视化一次性咨询(产品化)
    置信度: 52% | 投入: 低 | 上行空间: $5k/单,可复制
    模式匹配:Thiel —— 没人看得上的小众垄断
    ...

🥉 #3 —— Marcus 的影子表格 → PM 工具(产品方向)
    置信度: 45% | 投入: 高 | 上行空间: 产品化后 $5–20k/月
    ...
```

完整演示见 [examples/daily-slack-mining/](examples/daily-slack-mining/)。

**仓库内附带了五个演示案例:**

| 案例 | 输入类型 | 结果 |
|---|---|---|
| [daily-slack-mining](examples/daily-slack-mining/) | 工作 Slack,1 周 | 从"无聊"消息里提炼出 7 个信号、5 个机会 |
| [photo-roll-mining](examples/photo-roll-mining/) | 30 张手机照片,1 周 | 🏆 **黄金机会** 75% —— 整套木工定制业务浮现 |
| [complaint-mining](examples/complaint-mining/) | WhatsApp 群,2 周 | 🏆 **黄金机会** 78% —— 社区可信服务商名册机会 |
| [browsing-mining](examples/browsing-mining/) | 浏览器 + YouTube,1 周 | 🏆 **黄金机会** 82% —— 全部案例中最高置信度 |
| [billionaire-pattern-match](examples/billionaire-pattern-match/) | 累积输入 | 把 4 个用户画像对比 Musk/Buffett/Thiel 剧本 |

---

## 详细安装

### 第 1 步 —— 克隆仓库

```bash
git clone https://github.com/realteamprinz/midas-skill
cd midas-skill
```

### 第 2 步 —— 放到 Claude Code 能找到的位置

Claude Code 在 **git 仓库根目录** 的 `.claude/skills/`(项目内)或者 `~/.claude/skills/`(全局)查找技能。二选一:

```bash
# 项目内:先 cd 到你想让技能生效的那个 git 仓库
mkdir -p .claude/skills
cp -r /path/to/midas-skill .claude/skills/midas-skill

# 或全局(任何项目都能用)
mkdir -p ~/.claude/skills
cp -r /path/to/midas-skill ~/.claude/skills/midas-skill
```

### 第 3 步 —— 验证技能已加载

在你安装的仓库里打开一个 Claude Code 会话,输入:

```
What skills are available?
```

Midas 应该以 `midas-skill` 的身份出现。如果没出现,检查 `SKILL.md` 是否在已安装目录的根部,以及 YAML frontmatter 是否有效。

### 第 4 步 —— 运行你的第一次提炼

带着任意触发词粘贴任何噪音输入:

```
Midas, mine this —— 我 #general 频道最近 50 条 Slack 消息:
[粘贴内容]
```

Midas 会产出你的第一份信号报告,并往 `evolution/evolution.jsonl` 追加第一条记录。

### 第 5 步 —— 随时间喂入多样化数据

Midas 随着输入种类的增加会越来越锋利。推荐的每周轮换节奏见 [references/sources-guide.md](references/sources-guide.md)(周一 Slack,周三照片,周四浏览历史等等)。第 1 天给你猜测,第 30 天给你判断,第 90 天给你一整本剧本。

---

## 功能特性

### 🔍 六重提取引擎

每条输入都会经过金钱信号 / 需求缺口 / 套利 / 技能桥梁 / 人脉路径 / 行为杠杆六重过滤。每个信号都可以追溯到产生它的具体原始证据。

### 🧠 自学习累积智能

Midas 不会在会话间重置。每次输入都会追加进 `evolution/evolution.jsonl`。新信号会与之前所有信号交叉引用。**置信度只能通过独立、交叉引用的证据上升。**

| 证据 | 置信度 | Midas 标记 |
|---|---|---|
| 1 个单源信号 | 15–35% | 观察中 |
| 2 个独立来源互相印证 | 40–65% | 工作假设 |
| 3+ 个独立来源收敛 | 70–90% | 🏆 黄金 —— 行动 |
| 直接市场验证(已有人付钱) | 85–95% | 🏆 黄金 —— 立即行动 |

### 🎯 著名财富 OS 模式匹配器

内置 [Musk](references/famous-models/elon-musk.md)、[Buffett](references/famous-models/warren-buffett.md)、[Thiel](references/famous-models/peter-thiel.md) 的财富操作系统。当你的信号积累到一定程度,Midas 会自动比对哪一本剧本与你的处境在结构上最吻合。

> "你的信号结构看起来像早期 Thiel:在一个别人不当回事的小众领域发现垄断机会。Thiel 的剧本是:先吃下小市场,再向外扩张。"

### 💼 交易分析器

对着任意一笔具体交易(你自己的,或者公开的 M&A)说 *"Midas, analyze this deal"*,你会得到一份结构化的 8 部分拆解:各方、结构、资金来源、风险分配、退出路径、隐藏杠杆、判断、模式匹配。见 [references/deal-template.md](references/deal-template.md)。

### ⚡ 行动胜过分析

每份信号报告都以一个 **立即下一步行动** 结束 —— 具体的动词 + 具体的名词。绝不"探索选项"。永远是"今晚 DM Dave,问他每周花多少小时做人工月报"。

---

## 项目结构

```
midas-skill/
├── SKILL.md                              # 主入口
├── README.md                             # 英文主 README
├── README_ZH.md · README_ES.md · ...     # 各语言版本
├── LICENSE                               # MIT
├── references/
│   ├── signal-extraction-framework.md    # 6 重方法论
│   ├── noise-to-gold-pipeline.md         # 7 阶段提取管线
│   ├── deal-template.md                  # 交易分析模板
│   ├── sources-guide.md                  # 输入源层级
│   └── famous-models/                    # Musk / Buffett / Thiel 财富 OS
├── examples/                             # 5 个完整演示案例
└── evolution/
    └── evolution.jsonl                   # 你的个人累积智能日志
```

---

## 设计原则

1. **你的噪音就是你的原矿。** 每一次琐碎互动都可能藏着财富信号。
2. **重复本身就是主信号。** 生活中出现两次以上的东西就是一个市场。
3. **交叉引用胜过单一来源。** 一个信号是猜测,三个是判断。
4. **行动胜过分析。** Midas 输出的是下一步,不是论文。
5. **复利式智能。** 第 1 天给你猜测,第 90 天给你剧本。
6. **无道德评判。** Midas 研究钱怎么流动,不评判钱*应该*怎么流动。
7. **诚实边界。** 没有预测,没有保证,不是投资建议。
8. **只使用公开信息。** 只处理你自愿输入的内容。

---

## 许可证

MIT。详见 [LICENSE](LICENSE)。

## 非投资建议

Midas 不提供投资、税务、法律或会计建议。Midas 的任何输出都不构成买入或卖出任何证券的推荐。在对任何涉及实质资金的 Midas 机会采取行动之前,请咨询你所在司法辖区的持牌专业人士。

---

**把你的重复指令变成黄金。**

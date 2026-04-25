<div align="center">

# midas.skill

> *"Wealth is not hiding in Bloomberg terminals or VC pitch decks. Wealth is hiding in the noise of your daily life — you've just been trained to ignore it."*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-blue.svg)](https://python.org)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![AgentSkills](https://img.shields.io/badge/AgentSkills-Standard-green)](https://agentskills.io)

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2?logo=discord&logoColor=white)](#)

<br>

Your Slack chat leaked three business ideas this week — and you scrolled past them.<br>
Your camera roll holds a neighborhood arbitrage thesis — and you forgot the photos existed.<br>
Your friend group's complaints are a self-organized focus group — and nobody in the chat knows it.<br>
Your YouTube history is 14 hours of proof you're becoming a paid specialist — and you called it "wasting time."<br>
Your Amazon purchases are validated demand — and you think it's just shopping.<br>

**Turn Your Repeated Orders Into Gold — welcome to the noise-to-gold refinery!**

<br>

Feed it any daily-life stream (Slack, photos, chats, browsing, receipts, complaints)<br>
plus your own hunches and questions<br>
and get **a ranked list of money signals, opportunities, and immediate next actions**

[Supported Sources](#supported-sources) · [Install](#install) · [Usage](#usage) · [Demo](#demo) · [Detailed Install](#detailed-install) · [💬 Discord](#)

[**中文**](README_ZH.md) · [**Español**](README_ES.md) · [**Deutsch**](README_DE.md) · [**日本語**](README_JA.md) · [**Русский**](README_RU.md) · [**Português**](README_PT.md)

</div>

---

Created by [@realteamprinz](https://github.com/realteamprinz) | Positioning: ** Midas distills how to turn your daily noise into money.**

## Supported Sources

> Midas accepts any information stream you voluntarily feed it. Repetition IS the signal — if you encountered it more than once, feed it to Midas.

| Source | Best Lens | Notes |
|--------|:---------:|-------|
| Slack / Teams messages | Demand Gap, Money Signal | Team channels = vendor frustrations, budget signals, manual workarounds |
| WhatsApp / iMessage / WeChat chats | Demand Gap, Network Path | Repeated complaints from different people = unserved demand |
| Phone camera roll (uncurated) | Arbitrage, Demand Gap | Construction sites, empty storefronts, crowds, prices, signage |
| YouTube / TikTok watch history | Skill Bridge, Behavioral | Consistent topical focus = latent expertise accumulation |
| Browser history | Skill Bridge, Money Signal | Research patterns, comparison shopping, troubleshooting journeys |
| Purchase history / subscriptions | Money Signal, Behavioral | Repeat purchases = validated demand, autopilot habits |
| Meeting notes (internal) | Money Signal, Demand Gap | Budget conversations, tool complaints, process breakdowns |
| Email `.eml` / `.mbox` | Money Signal, Network Path | Commission offers, referral chains, vendor quotes |
| Receipts / order confirmations | Money Signal, Arbitrage | The most honest signal of what you actually value |
| Paste any text directly | all 6 lenses | Even a single voice-note transcript produces signals |

See [references/sources-guide.md](references/sources-guide.md) for the full source hierarchy and the triangulation rules.

---

## Install

### Claude Code

> **Important**: Claude Code looks for skills in `.claude/skills/` at the **git repo root**. Run this in the right place.

```bash
# Install to current project (run at git repo root)
mkdir -p .claude/skills
git clone https://github.com/realteamprinz/midas-skill .claude/skills/midas-skill

# Or install globally (available in all projects)
git clone https://github.com/realteamprinz/midas-skill ~/.claude/skills/midas-skill
```

### OpenClaw

```bash
git clone https://github.com/realteamprinz/midas-skill ~/.openclaw/workspace/skills/midas-skill
```

### Dependencies (optional)

Midas's core skill (SKILL.md) is pure Markdown — no runtime dependencies. The Python tools under `tools/` use only the standard library (Python 3.9+):

```bash
# No pip install needed — all tools use only stdlib (json, sqlite3, csv, re, argparse)
# Optional future deps are listed in requirements.txt
```

### Python Tools

| Tool | What it does | Usage |
|---|---|---|
| `tools/slack_export_parser.py` | Parse Slack JSON/text exports into Midas input | `python tools/slack_export_parser.py ~/slack-export/` |
| `tools/chat_export_parser.py` | Parse WhatsApp/WeChat/Telegram/iMessage exports | `python tools/chat_export_parser.py chat.txt` |
| `tools/browser_history_parser.py` | Extract Chrome/Firefox/Safari history from local SQLite | `python tools/browser_history_parser.py --days 7` |
| `tools/evolution_manager.py` | Manage evolution.jsonl (list, show, stats, decay, golden) | `python tools/evolution_manager.py golden` |
| `tools/signal_report_validator.py` | Validate signal reports against Midas quality standards | `python tools/signal_report_validator.py report.md` |

---

## Usage

In Claude Code or OpenClaw, type any of Midas's trigger phrases:

```
Midas, mine this                 → paste any input, get signal report
Turn this into gold              → same thing
What money signal is here        → more specific framing
点石成金                         → same, in Chinese
Midas, analyze this deal         → deal analyzer mode (see references/deal-template.md)
What am I missing                → feed a week of your own messages
```

Midas runs every input through the 6-lens extraction engine, cross-references against your `evolution/evolution.jsonl` log, and returns a ranked Signal Report with Immediate Next Actions.

### The 6 Lenses

| # | Lens | Core Question |
|---|------|---------------|
| 1 | **Money Signal** | Where is money moving, stuck, or leaking? |
| 2 | **Demand Gap** | What do people want that nobody provides? |
| 3 | **Arbitrage Window** | Where is value being mispriced? |
| 4 | **Skill Bridge** | What do you already know that has market value? |
| 5 | **Network Path** | Who should be talking to whom, and what's the finder's fee? |
| 6 | **Behavioral Leverage** | What autopilot habit is one pivot away from revenue? |

Full methodology in [references/signal-extraction-framework.md](references/signal-extraction-framework.md).

---

## Demo

> Input: *"Midas, mine this — here's my last week of Slack: [73 messages pasted]"*

```
[MIDAS SIGNAL REPORT]

Input type:       slack_messages
Volume:           73 messages across 3 channels + 4 DMs
Scan date:        2026-04-09

🟡 MONEY SIGNALS DETECTED: 7
🔴 NOISE DISCARDED:        ~65 messages (89%)

🥇 #1 — Marcus as Internal Consultant (Skill Bridge Wedge)
    Confidence: 50% | Effort: Low | Upside: $3–8k/mo side income
    Evidence:
      - Sarah DM: "if someone could solve this end-to-end for under $5k we'd probably pay it"
      - Priya DM: "I would pay for that myself"
      - 3 distinct stakeholders asked Marcus for help with 3 problems in one week
    Pattern match: Buffett — stay in circle of competence

    ⚡ Immediate next action:
       Monday 9 AM, DM Sarah with a scoped offer:
       "For the AWS tagging project — fixed fee $3,500, delivered by next Friday."

🥈 #2 — AWS Cost-Visibility One-Time Consulting (Productized)
    Confidence: 52% | Effort: Low | Upside: $5k per engagement, repeatable
    Pattern match: Thiel — small monopoly nobody takes seriously
    ...

🥉 #3 — Marcus's Shadow Spreadsheet → PM Tool (Product Play)
    Confidence: 45% | Effort: High | Upside: $5–20k/mo if productized
    ...
```

Full walkthrough in [examples/daily-slack-mining/](examples/daily-slack-mining/).

**Five example runs are included:**

| Example | Input type | Result |
|---|---|---|
| [daily-slack-mining](examples/daily-slack-mining/) | Work Slack, 1 week | 7 signals, 5 opportunities from "boring" messages |
| [photo-roll-mining](examples/photo-roll-mining/) | 30 phone photos, 1 week | 🏆 **GOLDEN** at 75% — full woodworking commission practice surfaced |
| [complaint-mining](examples/complaint-mining/) | WhatsApp group, 2 weeks | 🏆 **GOLDEN** at 78% — neighborhood roster opportunity |
| [browsing-mining](examples/browsing-mining/) | Browser + YouTube, 1 week | 🏆 **GOLDEN** at 82% — highest confidence in example set |
| [billionaire-pattern-match](examples/billionaire-pattern-match/) | Cumulative | Matches 4 user profiles against Musk/Buffett/Thiel playbooks |

---

## Detailed Install

### Step 1 — Clone the repo

```bash
git clone https://github.com/realteamprinz/midas-skill
cd midas-skill
```

### Step 2 — Place it where Claude Code looks

For Claude Code, skills live in `.claude/skills/` at the **git repo root** (per-project) or `~/.claude/skills/` (global). Pick one:

```bash
# Per-project: first cd to the git repo you want the skill attached to
mkdir -p .claude/skills
cp -r /path/to/midas-skill .claude/skills/midas-skill

# Or global (available in every project)
mkdir -p ~/.claude/skills
cp -r /path/to/midas-skill ~/.claude/skills/midas-skill
```

### Step 3 — Verify the skill loads

Open a Claude Code session in the repo where you installed it. Type:

```
What skills are available?
```

Midas should show up as `midas-skill`. If it doesn't, double-check that `SKILL.md` is at the root of the installed folder and the frontmatter is valid YAML.

### Step 4 — Run your first mine

Paste any noisy input with a trigger phrase:

```
Midas, mine this — last 50 messages from my #general Slack:
[paste content]
```

Midas will produce your first Signal Report and append the first entry to `evolution/evolution.jsonl`.

### Step 5 — Feed variety over time

Midas gets sharper the more varied the input. See [references/sources-guide.md](references/sources-guide.md) for the recommended weekly rotation (Slack on Mon, photos on Wed, browsing on Thu, etc.). Day 1 gives you guesses. Day 30 gives you conviction. Day 90 gives you a playbook.

---

## Features

### 🔍 6-Lens Extraction Engine

Every input runs through Money Signal / Demand Gap / Arbitrage / Skill Bridge / Network Path / Behavioral Leverage. Every signal is traceable to the exact phrase, image, or data point that produced it.

### 🧠 Self-Learning Cumulative Intelligence

Midas does not reset between sessions. Every input appends to `evolution/evolution.jsonl`. New signals are cross-referenced against every prior signal. Confidence only increases through independent, cross-referenced evidence.

| Evidence | Confidence | Midas flag |
|---|---|---|
| 1 single-source signal | 15–35% | Watching |
| 2 independent sources confirming | 40–65% | Working hypothesis |
| 3+ independent sources converging | 70–90% | 🏆 GOLDEN — ACT |
| Direct market validation | 85–95% | 🏆 GOLDEN — ACT NOW |

### 🎯 Famous Wealth OS Pattern Matcher

Pre-built wealth operating systems for [Musk](references/famous-models/elon-musk.md), [Buffett](references/famous-models/warren-buffett.md), and [Thiel](references/famous-models/peter-thiel.md). When your signals accumulate, Midas automatically checks which playbook structurally matches your situation.

> "Your pattern looks like early-stage Thiel: monopoly in a niche nobody takes seriously. Thiel's playbook says: dominate the small market first."

### 💼 Deal Analyzer

Point Midas at any specific transaction (your own or public M&A) with *"Midas, analyze this deal"* and get a structured 8-part breakdown: parties, structure, source of funds, risk allocation, exit path, hidden leverage, verdict, pattern match. See [references/deal-template.md](references/deal-template.md).

### ⚡ Action, Not Analysis

Every Signal Report ends with an **Immediate Next Action** — a specific verb + specific noun. Never "explore options." Always "DM Dave tonight and ask how many hours/week he spends on the manual report."

---

## Project Structure

```
midas-skill/
├── SKILL.md                              # Main entry
├── README.md                             # This file
├── README_ZH.md · README_ES.md · ...     # Language variants
├── LICENSE                               # MIT
├── requirements.txt                      # Python dependencies (stdlib only)
├── tools/                                # Python tooling (3.9+)
│   ├── __init__.py
│   ├── slack_export_parser.py            # Parse Slack JSON/text exports
│   ├── chat_export_parser.py             # Parse WhatsApp/WeChat/Telegram/iMessage
│   ├── browser_history_parser.py         # Extract Chrome/Firefox/Safari history
│   ├── evolution_manager.py              # Manage evolution.jsonl (list, decay, golden)
│   └── signal_report_validator.py        # Validate reports against quality standards
├── references/
│   ├── signal-extraction-framework.md    # 6-lens methodology
│   ├── noise-to-gold-pipeline.md         # 7-stage extraction pipeline
│   ├── deal-template.md                  # Deal analyzer template
│   ├── sources-guide.md                  # Input source hierarchy
│   └── famous-models/                    # Musk / Buffett / Thiel wealth OS
├── examples/                             # 5 worked examples
└── evolution/
    └── evolution.jsonl                   # Your personal cumulative intelligence log
```

---

## Design Principles

1. **Your noise is your ore.** Every mundane interaction contains potential wealth signals.
2. **Repetition is the primary signal.** If something shows up twice in your life, it's a market.
3. **Cross-reference beats single-source.** One signal is a guess. Three are a conviction.
4. **Action over analysis.** Midas outputs next-steps, not essays.
5. **Compounding intelligence.** Day 1 gives guesses. Day 90 gives a playbook.
6. **No moral judgment.** Midas studies how money moves, not how it *should* move.
7. **Honest boundaries.** No predictions. No guarantees. No financial advice.
8. **Public information only.** Only what you voluntarily feed it.

---

## License

MIT. See [LICENSE](LICENSE).

## Not Financial Advice

Midas does not provide investment, tax, legal, or accounting advice. Nothing in a Midas output is a recommendation to buy or sell any security. Before acting on any Midas-generated opportunity that involves material capital, consult a licensed professional in your jurisdiction.

---

**Turn Your Repeated Orders Into Gold.**

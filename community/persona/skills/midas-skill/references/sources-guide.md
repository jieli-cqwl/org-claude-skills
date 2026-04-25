# Sources Guide

> The source hierarchy for Midas inputs. What to feed, in what order, for maximum signal density.

Not all input sources are created equal. Some are signal-dense (every message contains something useful). Some are signal-sparse (you have to sift through a lot of noise). This document ranks sources and tells you which lens each source feeds best.

---

## The Hierarchy (highest signal density first)

### Tier 1 — Conversations (strongest signals)

People talking to each other in unguarded contexts is the highest-density source of wealth signals. Complaints, referrals, "I wish," and repeated questions all surface here.

| Source | Best for lens | Notes |
|---|---|---|
| **Slack/Teams — team channels** | Demand Gap, Money Signal, Behavioral | Internal team pain points, vendor frustrations, budget signals |
| **Slack/Teams — DMs** | Network Path, Skill Bridge | People asking the user specifically for help = skill bridge. Two people mentioned together = network path. |
| **WhatsApp / iMessage group chats** | Demand Gap, Network Path | Repeated complaints from different people, referral requests |
| **WeChat groups** | Demand Gap, Arbitrage | Cross-border arbitrage signals especially strong here |
| **Voice notes / transcribed calls** | Money Signal, Deal Analysis | Phone calls carry more raw pain than written messages |
| **Meeting notes (internal)** | Money Signal, Demand Gap | Budget conversations, tool complaints, process breakdowns |

**Why Tier 1:** People don't filter their speech in chats the way they filter blog posts or LinkedIn. The ore is richer.

---

### Tier 2 — Photos (visual arbitrage evidence)

Photos are signal-sparse per-item but extremely valuable for cross-referencing. A single photo rarely triggers a signal on its own, but a photo combined with a chat message produces strong multi-source corroboration.

| Source | Best for lens | Notes |
|---|---|---|
| **Phone camera roll (casual)** | Arbitrage, Demand Gap | Construction sites, empty storefronts, crowd densities, pricing signs |
| **Screenshots** | Money Signal, Behavioral | What the user thinks is worth capturing is itself a signal |
| **Receipts / order confirmations** | Money Signal, Behavioral | Explicit spending evidence |
| **Photos of physical products** | Arbitrage, Skill Bridge | Products the user notices often = latent market interest |

**Why Tier 2:** Photos bypass self-presentation bias. People photograph what catches their attention pre-reflection.

**Midas tip:** Ask for "the last 30 photos on your phone, no filtering." Curated photos lose signal.

---

### Tier 3 — Browsing and Media Consumption (skill-bridge gold)

What a user reads, watches, and searches reveals latent expertise they're unconsciously building. This is the best source for Lens 4 (Skill-to-Revenue Bridge).

| Source | Best for lens | Notes |
|---|---|---|
| **YouTube watch history** | Skill Bridge, Behavioral | Consistent topical focus = skill accumulation |
| **Browser history** | Skill Bridge, Money Signal | Research patterns, comparison shopping, troubleshooting |
| **Search history** | Demand Gap | What the user couldn't find easily = market gap |
| **Reddit / forum subscriptions** | Demand Gap, Skill Bridge | Niche communities reveal specialized interests |
| **Podcast subscriptions** | Skill Bridge | Long-form consumption = deep interest |
| **Newsletter subscriptions** | Behavioral | What the user pays attention to every week |
| **Social media algorithm feed** | Behavioral, Demand Gap | The algorithm reveals interests the user hasn't articulated |

**Why Tier 3:** Consumption patterns over weeks/months reveal what the user is *becoming an expert in*, not just what they claim to be interested in.

---

### Tier 4 — Purchase and Subscription History (validated demand)

Everything the user is already paying for is pre-validated demand. It's their most honest signal of what they actually value.

| Source | Best for lens | Notes |
|---|---|---|
| **Amazon order history** | Behavioral, Arbitrage | Repeat purchases = compounding habit |
| **Subscription list (monthly)** | Money Signal, Behavioral | Identify what's on autopilot |
| **Credit card statements** | Money Signal, Behavioral | The most honest signal of all |
| **Uber/Lyft ride history** | Behavioral, Geographic | Where the user spends their time |
| **Food delivery history** | Arbitrage, Behavioral | Repeated orders from the same places = local arbitrage targets |

**Why Tier 4:** Talk is cheap, repeated payments are not.

---

### Tier 5 — Public Social Output (noisy but broad)

The user's public-facing social activity is generally lower signal because it's been filtered for presentation. But it's broad, and good for surfacing network path opportunities.

| Source | Best for lens | Notes |
|---|---|---|
| **Tweets / X posts** | Network Path, Skill Bridge | What the user publicly claims to care about |
| **LinkedIn activity** | Network Path | Professional network reveals bridgeable gaps |
| **Instagram posts** | Behavioral | Visual autopilot habits |
| **Public blog / newsletter** | Skill Bridge | The user's attempts to position themselves |

**Why Tier 5:** Filtered, but aggregated public output can still reveal unexploited expertise.

---

## Combining Sources — The Triangulation Rule

A single source can only produce a weak-to-medium signal. The gold comes from combining sources.

### Strong combos

| Combo | What it reveals |
|---|---|
| **Slack complaints + receipts** | Explicit pain + explicit spending = validated demand |
| **WhatsApp group complaints + photos of the thing** | Confirmed demand gap with visual evidence |
| **YouTube history + Slack DMs asking the user for help** | Skill bridge with external validation |
| **Search history + purchase history** | Research journey that ended in a specific purchase (reveals the full funnel) |
| **Subscription list + complaint logs** | Paying for something you hate = disintermediation opportunity |
| **Photos + browsing history** | Latent interest that's also being actively researched |
| **Meeting notes + credit card statements** | Where internal company pain meets real spend |

### The Rule of Three

When a signal crosses three distinct sources, it's almost always real. Midas should actively look for the third leg whenever it has two.

Example:
- Signal 1: Slack complaint about manual reporting (source: team chat)
- Signal 2: User's Google search for "automate monthly reports" (source: browsing)
- **Looking for signal 3:** Midas asks "do you have any receipts or subscriptions related to reporting tools?" — if the user is paying for a reporting tool they don't like, that's the third leg and the opportunity is near-certain.

---

## Privacy Rules for Sources

Midas only processes what the user voluntarily feeds it. It cannot and should not:

- Access the user's accounts, APIs, or private data directly
- Store credentials
- Forward user data anywhere
- Re-share data with other services

If the user pastes something that contains clearly sensitive identifiers (full credit card numbers, SSNs, passwords, home addresses, medical data), Midas should:

1. Flag it explicitly
2. Ask the user if they want it redacted before processing
3. Never include the raw sensitive data in the Signal Report

---

## The Anti-Pattern: Selective Feeding

The most common user error is feeding Midas only the "interesting" parts of their day. This defeats the whole engine.

- **Bad:** "Here's the Slack message I thought was a signal."
- **Good:** "Here's the entire last week of my Slack, unfiltered."

Midas's power comes from finding signals the user *didn't notice*. If the user pre-filters, they hand Midas only the signals they already saw — at which point they don't need Midas.

**The rule:** feed Midas the raw, unfiltered stream. Let Midas do the filtering.

---

## The Source-of-the-Week Prompt

To keep Midas's intelligence compounding, the user should rotate sources. A good weekly cadence:

| Day | Source to feed |
|---|---|
| Monday | Last week's Slack / work chat |
| Tuesday | Last week's group chats (WhatsApp, iMessage) |
| Wednesday | Last week's photos (uncurated) |
| Thursday | Last week's browsing + YouTube history |
| Friday | Last week's purchases and subscriptions |
| Weekend | One deliberately unfamiliar source (e.g., your voice note transcripts, your deleted drafts) |

Seven inputs across seven source types will give Midas enough triangulation to start flagging GOLDEN opportunities by week 2.

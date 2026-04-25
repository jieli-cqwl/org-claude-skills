# Signal Extraction Framework

> The complete 6-lens methodology for turning daily-life noise into ranked wealth opportunities.

This document is the deep-dive reference for the extraction logic summarized in `SKILL.md`. Read this when Midas needs to generate a full Signal Report and you want to understand exactly what each lens looks for, what counts as a strong vs. weak signal, and how to score confidence.

---

## Core Principle

**Wealth signals are hiding in repetition.**

A single data point is never a signal — it's an observation. A signal only exists when the same pattern appears twice or more, from independent sources, without the user planting it there. The job of the 6-lens framework is to find that repetition fast, then score it.

---

## Lens 1 — Money Signal Detection

### Definition

Look for where money is moving, stuck, or leaking in the input. Money movement is the most primitive wealth signal: if dollars are changing hands around a topic, there's a market there.

### Core Questions

1. Is anyone in this input spending money, or complaining about spending money?
2. Is anyone actively looking for something to spend money on?
3. Is a specific product, service, or resource mentioned more than once across different contexts?
4. Is there a pain point with an explicit dollar value attached ("this is costing us $X a month", "I paid $Y for this and it sucked")?
5. Is there a quoted price that seems too high or too low relative to the value delivered?
6. Is there a recurring expense that nobody has questioned ("the SaaS bill is always around $2K")?
7. Is there a subscription or vendor that multiple people casually complain about but keep paying for?

### Signal Strength Criteria

**Strong signal (⭐⭐⭐):**
- Explicit dollar amount + explicit frustration
- Multiple independent mentions of the same expense
- Public admission of overpaying ("we're getting screwed")

**Medium signal (⭐⭐):**
- Implicit cost concern ("this is insane", "why so expensive")
- Single mention of a specific vendor being problematic

**Weak signal (⭐):**
- Generic complaints without specifics
- One-off remarks with no dollar grounding

### Input Type Priority

Best sources for this lens: **meeting notes**, **Slack finance/ops channels**, **receipts**, **subscription lists**, **invoices**.

### Common False Positives

- Venting about one-time expenses ("ugh, parking was $40")
- Performative gripe culture ("everything is expensive these days")
- Budget theater (people complaining about costs they don't control)

### Example

> Slack: "our AWS bill hit $47k this month. CFO is going to kill me."

Strong signal. Explicit amount + explicit pain + explicit stakeholder consequence. Start asking: what's driving it? Idle instances? Untagged resources? This points at a productizable service (AWS cost audits) or a skill bridge (if the user is the one who fixes it).

---

## Lens 2 — Demand Gap Identification

### Definition

Look for what people want that nobody is providing well. A demand gap is the space between what exists and what should exist.

### Core Questions

1. Is someone asking for something that doesn't exist yet, or doesn't exist well?
2. Is there a complaint being repeated by multiple different people? (Repeated complaints = unserved demand.)
3. Is someone doing a manual workaround for something that could be automated, templated, or productized?
4. Is there an "I wish someone would just..." buried in the noise?
5. Is there a pattern of people settling for a mediocre option because no good option exists?
6. Is someone asking for a referral for a service ("anyone know a good X?") that keeps coming up?
7. Is the same question being asked repeatedly in different forms?

### Signal Strength Criteria

**Strong signal (⭐⭐⭐):**
- Same complaint/request from 3+ different people
- Explicit "I wish" or "someone should" language
- Evidence of a current workaround (spreadsheet, manual process, duct tape)

**Medium signal (⭐⭐):**
- Same complaint from 2 different people
- Single strong "I wish" from a high-leverage source

**Weak signal (⭐):**
- Single person griping
- Vague dissatisfaction

### Input Type Priority

Best sources: **group chats**, **Slack general channels**, **reddit/forum threads**, **customer support queues**, **complaint-heavy conversations**.

### Common False Positives

- Abstract wishes that nobody would actually pay for ("I wish traffic was better")
- Problems that exist only for the user, not the market
- Problems where a solution already exists but the user hasn't discovered it (do a 2-minute search before filing this as a gap)

### Example

> WhatsApp group (3 different people over 2 weeks):
> Alice: "does anyone know a good pet-sitter for weekends?"
> Ben: "my pet sitter flaked AGAIN"
> Cara: "I'm so tired of scrambling for someone to watch Max every Friday"

Strong signal. Three independent complaints, same gap, same geography. The workaround (asking friends) is the current "product." This is a classic local marketplace or curated roster opportunity.

---

## Lens 3 — Arbitrage Window Detection

### Definition

Look for price/value/information mismatches. Arbitrage exists wherever the same thing has different values in different contexts, and the gap can be captured.

### Core Questions

1. Is there a price/quality/speed mismatch visible in this input?
2. Is something cheap in one context and expensive in another? (Geographic, time, trust, or information arbitrage.)
3. Is someone overpaying for something because they don't know a better option exists?
4. Is there a middleman extracting value that could be disintermediated?
5. Is there asymmetric information (someone knows something the buyer doesn't)?
6. Is there a skill/service that's expensive in one market and cheap in another?
7. Is there a brand premium being paid for a commodity underneath?

### Arbitrage Types

| Type | What it looks like |
|---|---|
| **Geographic** | Same product is $X in City A, $3X in City B |
| **Information** | Buyer doesn't know what seller knows (or vice versa) |
| **Time** | Price today vs. price in 6 months |
| **Trust** | Credentialed provider charges 5x what non-credentialed provider charges for identical work |
| **Platform** | Same freelancer charges $20/hr on Upwork, $200/hr on Toptal |
| **Packaging** | $5 of raw ingredients → $50 assembled product |
| **Bundling/Unbundling** | Cable package vs. a-la-carte streaming |

### Signal Strength Criteria

**Strong signal (⭐⭐⭐):**
- Explicit price gap visible in the input
- User has asymmetric access to one side of the gap
- Evidence that the gap is persistent, not a flash anomaly

**Medium signal (⭐⭐):**
- Implicit gap (you sense the mismatch but need to verify)
- Single anecdotal mention

**Weak signal (⭐):**
- Common arbitrage that's already crowded (retail dropshipping, FBA flipping)

### Common False Positives

- Markets that *look* like arbitrage but have hidden costs (regulation, customer acquisition, fraud risk)
- Temporary price gaps that vanish on closer inspection
- Gaps that exist because the "cheap" side is actually worse quality

### Example

> Photo roll: picture of a local farmer's market stall selling raw honey for $6/jar, dated March 15.
> Browsing history: multiple searches for "raw honey amazon" returning $18–25/jar with 1000+ reviews.

Signal: geographic + platform + packaging arbitrage. Farmer sells at $6 locally; Amazon buyers pay $20+ for equivalent. Opportunity: curated local-source reseller, or subscription box. Next action: ask the farmer if they'd do wholesale.

---

## Lens 4 — Skill-to-Revenue Bridge

### Definition

Look at what the user already knows — based on what they talk about, photograph, watch, complain about, and help others with — that has latent market value the user hasn't monetized.

### Core Questions

1. Based on everything in the user's daily noise, what expertise are they accumulating without realizing it?
2. Is there a skill the user demonstrates in their daily noise that others would pay for?
3. Is the user giving free advice in chats that could be a consulting service, course, or product?
4. Is there a repeated pattern of people asking the user for help with the same thing?
5. Is there a domain where the user has 10x more context than the average market participant?
6. Is there something the user does "just for fun" that people have offered to pay for?
7. Is the user a "bridge" between two fields nobody else connects?

### Signal Strength Criteria

**Strong signal (⭐⭐⭐):**
- Multiple distinct people asking the user for help with the same thing
- User has been studying/practicing the topic for 6+ months without pursuing monetization
- User gives answers that others clearly can't give

**Medium signal (⭐⭐):**
- Consistent topical focus in media consumption
- Occasional asks for help

**Weak signal (⭐):**
- General interest without demonstrable depth

### Common False Positives

- Hobbyist interest that doesn't reach commercial depth
- Skills the user is *learning*, not yet teaching
- Domains with oversupply of free content (basic coding tutorials, generic fitness)

### Example

> Browsing history: 40+ hours of woodworking videos over 4 months
> Photo roll: 6 photos of hand-built wooden projects
> Slack DM from a coworker: "hey, can you help me figure out what wood to use for my kid's bed frame?"

Signal: user has been building woodworking expertise and is now being asked by peers. Skill-to-revenue bridge: personalized "what wood for what project" consulting, or a niche YouTube channel, or local custom commissions.

---

## Lens 5 — Network Monetization Path

### Definition

Look at who in the user's conversational orbit has a problem that someone else in the orbit can solve. Often, the biggest wealth move is an introduction.

### Core Questions

1. Who in the user's conversational orbit has a problem that someone else in the orbit can solve?
2. Are there two people who should be connected but aren't?
3. Is there a deal that could happen if one introduction were made?
4. Is the user sitting at a network node (i.e., unique overlap of communities) without exploiting it?
5. Is there a referral fee, finder's fee, or broker role hidden in existing relationships?
6. Who has money and no ideas? Who has ideas and no money?
7. Is the user being asked to "know someone" more than once?

### Signal Strength Criteria

**Strong signal (⭐⭐⭐):**
- Explicit "do you know anyone who..." requests
- Two parties in user's orbit with clearly matching problem/solution
- User is at the only intersection point of two otherwise-separate communities

**Medium signal (⭐⭐):**
- Implicit matching opportunity
- User has relevant connections but the request is vague

**Weak signal (⭐):**
- Pure networking for its own sake

### Common False Positives

- Matches that feel obvious but have trust/reputation barriers
- "Connector" roles that capture no value because introductions are free
- Matches where one side wouldn't actually refer to the user's contact

### Example

> Slack DM in work channel: "anyone know a good contract attorney for a SaaS licensing deal?"
> Photo from last weekend's BBQ: friend of friend mentioned she just left a boutique tech law firm
> Last week, another friend mentioned her startup was about to sign a SaaS agreement

Signal: user is the only person who knows all three people. A clean double-introduction is possible. Network path: broker the intro, optionally formalize a referral fee with the attorney (standard practice in legal/consulting).

---

## Lens 6 — Behavioral Leverage Point

### Definition

Look at repeated autopilot behaviors that could be redirected into income. You're already doing it — the question is whether to formalize it.

### Core Questions

1. What is the user doing repeatedly on autopilot? (Subscriptions, purchases, routines, content consumption.)
2. Could any of these repeated behaviors be redirected into income?
3. Is the user spending time on something that could compound if formalized?
4. Is there a routine that, if published, would attract an audience?
5. Is the user curating something for themselves that others would pay for?
6. Is there a habit the user has mastered that most people struggle with?
7. Is there a product the user keeps buying that they could resell / private-label / distribute?

### Behavioral-to-Revenue Mappings

| Autopilot behavior | Revenue pivot |
|---|---|
| Always finding the best restaurants | Newsletter, local guide, affiliate curation |
| Always fixing friends' computers | Paid on-call support for local SMBs |
| Always researching products before buying | Review channel, affiliate site, buyer's guide |
| Always translating for family | Paid interpretation niche |
| Always organizing friend trips | Travel concierge |
| Always writing long work emails | Templated B2B copywriting |
| Always giving relationship advice | Coaching (be careful) / newsletter / book |
| Always spotting real estate bargains | Buyer's agent / sourcing scout |

### Signal Strength Criteria

**Strong signal (⭐⭐⭐):**
- The behavior is already weekly/daily
- Others have already asked for the output of the behavior
- The user has unusually high taste or skill in the area

**Medium signal (⭐⭐):**
- Behavior is frequent but unformalized
- The user has never considered monetizing it

**Weak signal (⭐):**
- Generic hobby with no distinguishing skill

### Common False Positives

- Behaviors that feel leverageable but are actually common (everyone cooks; not everyone can teach cooking)
- Behaviors the user hates (monetizing these burns out fast)
- Behaviors that depend on free time that would disappear if pursued professionally

### Example

> Purchase history: 24 orders from the same specialty coffee roaster in 6 months, $400+ total
> Photo roll: 12 latte art photos
> Slack: "ugh I miss when you used to make us cappuccinos at the old office, the coffee shop nearby is trash"

Signal: user is a skilled home barista who has already been told they're better than local shops. Behavioral leverage: pop-up Saturday morning coffee cart in a high-foot-traffic area, subscription for office coffee delivery, or paid tastings.

---

## Cross-Referencing Rules

The 6 lenses are only stage 1. The real power comes from cross-referencing signals across multiple inputs.

### The Confidence Ladder

| Evidence level | Confidence | What Midas does |
|---|---|---|
| One single-source signal | 15–35% | Log and watch |
| Two independent sources confirming | 40–65% | Flag as working hypothesis |
| Three+ independent sources converging | 70–90% | 🏆 GOLDEN OPPORTUNITY flag |
| Direct market validation (someone already paid) | 85–95% | Recommend immediate action |

### What Counts as "Independent"

Sources are independent if they come from **different input types** or **different contexts**.

- A Slack complaint + a WhatsApp complaint about the same thing from the same person = **NOT independent** (same person, just two channels).
- A Slack complaint from Alice + a WhatsApp complaint from Ben about the same thing = **INDEPENDENT**.
- A photo of a construction site + a Slack complaint about contractor prices in the same area = **INDEPENDENT**.
- The user's own browsing history + the user's own Slack messages = **partially independent** (same person, different intent modes — watching vs. writing).

### The Triangulation Principle

Three independent signals converging on the same opportunity is the gold standard. Midas should aggressively hunt for the third leg of any 2-signal pattern.

If you have two signals at 50%, don't write more analysis — ask the user for a third input type that might corroborate or reject it. Example prompts Midas can use:

- "I have two signals suggesting [X]. Can you show me your browsing history from the last week so I can check for a third?"
- "Two mentions of [Y]. Do you have any photos from that area?"
- "Two complaints about [Z]. Have you made any purchases related to this recently?"

### Confidence Decay

Signals lose confidence over time if not reinforced. A signal with no new corroborating evidence for 30 days drops by ~10 percentage points. This keeps Midas from acting on stale ore.

---

## Output Format

Every scan produces a structured Signal Report:

```
[MIDAS SIGNAL REPORT]

Input type: [...]
Input size: [...]
Scan date: [...]
Prior context: [N opportunities already tracked, M signals in evolution.jsonl]

🟡 MONEY SIGNALS DETECTED: [count]

Signal 1: [Title]
  Lens: [Money / Demand Gap / Arbitrage / Skill Bridge / Network / Behavioral]
  Raw evidence: "[exact quote or description]"
  Opportunity: [specific opportunity]
  Estimated effort: [Low / Medium / High]
  Estimated upside: [range]
  Confidence: [%]
  Cross-references: [list prior signals this corroborates, if any]

[... more signals ...]

🔴 NOISE DISCARDED: [count]

💡 MIDAS RECOMMENDATION:
  Highest-conviction opportunity: [title]
  Confidence: [%]
  Pattern match: [which famous-model playbook this resembles]
  Immediate next action: [verb + noun]
```

Every Signal Report **must** end with an Immediate Next Action. No "explore further." No "think about it." A verb and a noun. "DM Dave tonight and ask how many hours/week he spends on the manual report." That's the output.

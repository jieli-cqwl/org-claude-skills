# Extracted Signals — Daily Slack Mining

> What Midas found when it ran the flagship Slack input through the 6-lens extraction framework.

Compare this to `raw-input.md` to see exactly which phrases triggered which signals. Every signal below is traceable to a specific line in the raw input. **This is how Midas thinks out loud.**

---

## Stage 1 — INGEST

```
Input type: slack_messages
Volume: 73 messages
Time window: 2026-04-02 → 2026-04-08 (one work week)
Source: #engineering (23), #general (14), #random (4), DMs (32)
Sensitive content flags: none
Ready for Stage 2: yes
```

---

## Stage 2 — SCAN (6-lens extraction)

### Lens 1 — Money Signal Detection

**Raw Signal 1.1 — AWS bill spike**
> Evidence (Wed 2:47 PM, Sarah Okonkwo in #engineering): "hey team, FYI the AWS bill came in. $47,312 this month. that's up 18% from last month. CFO is going to want a story by Friday."
>
> Strength: ⭐⭐⭐
>
> This is an explicit dollar amount attached to explicit pain attached to a specific stakeholder. Textbook money signal. The cause is named in the same thread (dev instances from Q1 migration that nobody killed).

**Raw Signal 1.2 — Tool budget resistance**
> Evidence (Wed 2:56 PM, Sarah Okonkwo): "We looked at one. $800/month minimum, plus implementation. CFO said no."
>
> Strength: ⭐⭐
>
> Reveals the CFO's negotiating posture: would rather burn $8k/month in excess spend than pay $800 for a tool. This is a **classic mispriced resistance** — the company is optimizing the wrong number. Signal isn't the AWS bill itself, it's the resistance pattern.

---

### Lens 2 — Demand Gap Identification

**Raw Signal 2.1 — The shadow spreadsheet**
> Evidence (Tue 10:19 AM, Marcus Chen): "I maintain a shadow spreadsheet of our sprint because Jira is unusable half the time. Been doing it for like a year."
>
> Evidence (Tue 10:23 AM, Marcus Chen): "probably 4-5 hrs/week."
>
> Evidence (Wed 6:35 PM, DM Priya → Marcus): "I know at least three PMs at other companies who complain about Jira constantly."
>
> Evidence (Wed 6:37 PM, DM Priya → Marcus): "I would pay for that myself."
>
> Strength: ⭐⭐⭐
>
> This is a classic demand gap. A skilled PM is spending 4-5 hours per week manually building a tool. Other PMs at other companies have the same problem. There's explicit pre-validated willingness-to-pay in the same week ("I would pay for that myself"). This isn't a hypothesis — this is a product-market-fit conversation that hasn't noticed itself yet.

**Raw Signal 2.2 — Expense report tool rejection bug**
> Evidence (Wed 4:11 PM, Marcus Chen): "I just spent 25 minutes trying to submit a $38 Uber receipt and it keeps rejecting the upload because the filename has a space."
>
> Evidence (Wed 4:15 PM, Jenna Kim): "oh that's a known issue. I tell every new hire during onboarding..."
>
> Strength: ⭐⭐
>
> Known issue that HR now trains around. Not a business opportunity per se — but it's a signal that this company's tooling layer is broken in small persistent ways. Cross-reference with other tooling complaints.

**Raw Signal 2.3 — Freelance designer bottleneck**
> Evidence (Fri 3:22 PM, Priya Nair): "does anyone know a good freelance designer? we need some icons for the new mobile feature and our design team has no bandwidth until June."
>
> Evidence (Fri 3:28 PM, Dave Liu): "I know a guy from my old company but he's usually booked out 4-6 weeks"
>
> Evidence (Fri 4:05 PM, Priya DM): "this has been an issue for like 6 months. every team needs icons and design work... it's a huge bottleneck. I almost feel like there's a market for a 'on-demand icon shop for dev teams' or something"
>
> Strength: ⭐⭐⭐
>
> Priya has now explicitly articulated the demand gap in her own words: an on-demand icon shop for dev teams. 6 months of repeated pain, multiple people asking, existing freelancers booked out. This is a demand gap that has named itself.

**Raw Signal 2.4 — Engineer onboarding disaster**
> Evidence (Fri 9:32 AM, Sarah Okonkwo): "the onboarding flow for new engineers is a disaster right now. Rafael started Monday and it took him until Thursday to get his dev env running."
>
> Evidence (Fri 9:34 AM, Marcus Chen): "I started 8 months ago and it took me a full week. we literally have no documented setup script."
>
> Evidence (Fri 9:35 AM, Dave Liu): "we've hired 6 people this quarter. that's like 30 engineer-days wasted just on onboarding pain."
>
> Evidence (Fri 9:37 AM, Sarah Okonkwo): "we won't have bandwidth to fix it until Q3."
>
> Evidence (Thu 6:46 PM, Marcus Chen): "I kept notes from our session. happy to turn them into a setup guide if anyone wants"
>
> Strength: ⭐⭐⭐
>
> 30 engineer-days = roughly $25–45k in direct opportunity cost per quarter at typical senior engineer rates. Explicitly acknowledged, explicitly unfixed, explicitly known to be continuing. Marcus is literally offering to fix it in his notes. **This is demand + existing supply that hasn't shipped.**

---

### Lens 3 — Arbitrage Window Detection

**Raw Signal 3.1 — CFO cost misalignment**
> Evidence (Wed 2:57 PM, Dave Liu): "so instead we'll burn $8k in excess spend every month while we argue about the $800 tool"
>
> Evidence (Thu 5:15 PM, DM Sarah): "if someone could solve this end-to-end for under $5k we'd probably pay it. the monthly savings would cover it in a week"
>
> Strength: ⭐⭐⭐
>
> Classic **trust/packaging arbitrage**. The CFO won't pay $800/month for a tool but would pay $5k one-time for a solution. The arbitrage is between "ongoing SaaS spend" (politically expensive) and "one-time consulting engagement" (politically cheap). Same value, different packaging. This is a repackageable opportunity worth real money.

**Raw Signal 3.2 — Designer pricing gap**
> Evidence (Fri 5:32 PM, DM Dave → Jenna): "she does take freelance yeah but she charges like $150/hr for icon work"
>
> Evidence (Fri 5:33 PM, Jenna Kim): "oh that's probably out of budget for Priya."
>
> Evidence (Fri 3:22 PM, Priya): "[needs] 20 custom icons matching our brand"
>
> Strength: ⭐⭐
>
> Pricing gap between what high-end freelancers charge ($150/hr) and what mid-budget teams will pay. 20 icons × 30 min each = ~$1.5k at $150/hr, which is too expensive for Priya's team. If someone produced the same 20 icons for $500–800 on a 48-hour turnaround, there's clear willingness-to-pay. **Middle-market icon production is under-supplied.**

---

### Lens 4 — Skill-to-Revenue Bridge

**Raw Signal 4.1 — Marcus has been building a Jira replacement without realizing it**
> Evidence (Tue 10:19 AM): "I maintain a shadow spreadsheet of our sprint [...] Been doing it for like a year."
>
> Evidence (Wed 6:32 PM DM): "I've been thinking about what you said re: my shadow spreadsheet. I realized I've been doing this for a YEAR. It's basically a full-time side project."
>
> Evidence (Wed 6:36 PM DM): "I wonder if I could turn the spreadsheet into a proper tool"
>
> Strength: ⭐⭐⭐
>
> Marcus has accidentally become an expert in "what a PM actually needs from a project management tool" and has built a working prototype. He has 52 weeks of real usage data. This is not a hypothesis — it's a 1-year user study of himself as the primary customer. **This is a fully loaded skill-to-revenue bridge that has not been pulled.**

**Raw Signal 4.2 — Marcus as internal tools guy**
> Evidence (Thu 5:12 PM DM, Sarah → Marcus): "the CFO really does want someone to figure out the AWS tagging situation. if you wanted to take a weekend on it I could probably get you a small bonus"
>
> Evidence (Thu 5:15 PM DM): "honestly if someone could solve this end-to-end for under $5k we'd probably pay it"
>
> Evidence (Thu 6:46 PM, Marcus offering to turn his env setup notes into a guide)
>
> Strength: ⭐⭐⭐
>
> Marcus is **already being asked** to solve 3 different internal tooling problems by 3 different stakeholders in the same week. He's known internally as the person who fixes things quietly. He is one step away from being a paid internal consultant — and the same skillset would transfer across companies.

---

### Lens 5 — Network Monetization Path

**Raw Signal 5.1 — The Dave-Priya-Jenna triangle**
> Evidence (Fri 3:22 PM, Priya asks for a designer in #general)
>
> Evidence (Fri 5:30 PM, DM Jenna → Dave): "your partner is a graphic designer right?"
>
> Evidence (Fri 5:32 PM, Dave confirms his partner does freelance work at $150/hr)
>
> Evidence (Fri 5:33 PM, Jenna concludes it's "out of budget for Priya")
>
> Strength: ⭐⭐
>
> The introduction almost happened and then died on price. But the ingredients exist: a buyer (Priya), a service (Dave's partner), and a broker (Jenna). **The network path that failed is itself a signal:** someone who could match buyers to designers at negotiated volume rates would unlock this deal and dozens like it inside this company.

**Raw Signal 5.2 — Marcus is the network hub**
> Evidence (Wed 6:32 PM DM from Marcus, Thu 5:12 PM DM to Marcus, Thu 6:46 PM Marcus volunteering to write onboarding guide): Marcus is the person everyone brings their problems to. Three different stakeholders in one week.
>
> Strength: ⭐⭐
>
> Marcus is sitting at a network node and not monetizing it. Anyone who helps three different teams solve three different internal problems in one week is an internal consultant who forgot to send the invoice.

---

### Lens 6 — Behavioral Leverage Point

**Raw Signal 6.1 — Marcus's shadow spreadsheet ritual**
> Evidence: 4-5 hours every week for a full year = 200+ hours of unpaid product development on a tool that has at least 1 pre-validated user (Priya).
>
> Strength: ⭐⭐⭐
>
> This is the cleanest behavioral leverage point in the input. A weekly autopilot ritual that's already producing a working prototype, already being consumed by at least one other person, already generating implicit willingness-to-pay. **Formalizing it is a one-step pivot, not a ten-step pivot.**

**Raw Signal 6.2 — The taco place signal**
> Evidence (multiple #random posts from Dave, Marcus, Priya, and Dave again): everyone in the team has now tried the new taco place, all unprompted, within 48 hours. Dave's final note: "they're going to blow up"
>
> Strength: ⭐
>
> Weak on its own. But worth flagging because repeated mentions of a new local food spot is a known precursor signal for either: (a) real estate adjacency plays, (b) local affiliate/curation opportunities, or (c) if the user knows the owner, a potential angel investment or help-scale-the-business opportunity. Too thin on its own — store and wait for cross-reference.

---

## Stage 3 — CROSS-REFERENCE

Since this is the first input (assume no prior evolution.jsonl entries), no cross-references are possible yet. All signals are treated as single-source and scored accordingly in Stage 4.

**Noise ratio:** ~8 out of 73 messages produced signals. The rest — the taco chatter, the team lunch coordination, the meditation session RSVP, Jenna's business card problem, the emoji reactions — is noise. That's a ~11% signal density, which is high for unfiltered Slack.

---

## Stage 4 — SCORE

Applying the scoring rubric from `references/signal-extraction-framework.md`:

| # | Signal | Evidence | Confidence |
|---|---|---|---|
| A | Shadow-spreadsheet → PM tool opportunity | 2 independent data points within same input (Marcus's own pattern + Priya's "I'd pay" DM) | **45%** |
| B | AWS cost-visibility consulting (one-time packaged) | 2 independent data points (public thread + Sarah's DM with budget) | **52%** |
| C | On-demand icon shop for dev teams | 2 independent data points (public #general thread + Priya's "I almost feel like there's a market" DM) | **48%** |
| D | Engineer onboarding as a product (setup-as-a-service) | 3 voices acknowledging the problem + Marcus's notes already exist | **55%** |
| E | Marcus as internal consultant (skill bridge) | 3 distinct stakeholders asking for help in same week | **50%** |
| F | Dave's partner → Priya (network path) | Single thread, deal died on price | **25%** |
| G | CFO cost-packaging arbitrage (same value, different SKU) | Single thread but with explicit numbers | **35%** |

Note: every score above is below the 70% GOLDEN threshold because this is a **single-input, single-source run**. Confidence will rise once a second input type (e.g., Marcus's browsing history, his GitHub activity, or his receipts for productivity tools) cross-references these signals.

---

## Stage 5 — RANK

Applying `priority = (confidence × upside) / effort`:

| Rank | Opportunity | Confidence | Upside | Effort | Priority |
|---|---|---|---|---|---|
| 1 | AWS cost-visibility one-time consulting | 52% | $5k (one-off, replicable across many companies) | 1 (low) | 2600 |
| 2 | Marcus's shadow spreadsheet → PM tool | 45% | $5–20k/mo if productized | 3 (high) | 1875 (using $12.5k/mo midpoint) |
| 3 | On-demand icon shop for dev teams | 48% | $3–10k/mo | 2 (med) | 1560 (using $6.5k/mo midpoint) |
| 4 | Engineer onboarding as a service | 55% | $2–8k per contract | 2 (med) | 1375 (using $5k midpoint) |
| 5 | Marcus as internal consultant | 50% | $3–8k/mo of side income | 1 (low) | 2750 |

**After ranking:** Marcus's skill bridge and the AWS consulting opportunity are the two highest-priority plays because they're low-effort. The product plays (shadow spreadsheet, icon shop, onboarding) are higher-upside but require significant build.

See `opportunities.md` for the final ranked Signal Report.

---

## Stage 7 — EVOLVE

New entry to append to `evolution/evolution.jsonl`:

```json
{
  "timestamp": "2026-04-09T10:30:00Z",
  "input_type": "slack_messages",
  "input_summary": "73 messages from #engineering, #general, #random, and 4 DMs. One work week at mid-size tech company.",
  "signals_extracted": 7,
  "cross_references_found": 0,
  "new_opportunities": 7,
  "updated_opportunities": 0,
  "noise_ratio": 0.89,
  "opportunities": [
    {
      "id": "opp-001",
      "title": "Marcus's shadow spreadsheet → PM tool",
      "lens": "demand_gap + skill_bridge + behavioral_leverage",
      "confidence": 0.45,
      "evidence": [
        "Marcus maintains manual shadow spreadsheet for 1 year, 4-5 hrs/week",
        "Priya DM: 'I would pay for that myself'"
      ],
      "effort": "high",
      "upside": "$5-20k/mo if productized",
      "next_action": "Ask Marcus what specifically the spreadsheet does that Jira doesn't",
      "pattern_match": "thiel — monopoly in a category (PM-for-PMs) nobody takes seriously yet"
    },
    {
      "id": "opp-002",
      "title": "AWS cost-visibility one-time consulting",
      "lens": "money_signal + arbitrage",
      "confidence": 0.52,
      "evidence": [
        "AWS bill spiked 18% to $47k with no ownership map",
        "CFO refused $800/mo SaaS but would pay $5k one-time"
      ],
      "effort": "low",
      "upside": "$5k per engagement, repeatable",
      "next_action": "DM Sarah and offer to scope the AWS tagging project for a fixed fee this weekend",
      "pattern_match": "buffett — boring, cash-flowing, inside circle of competence"
    },
    {
      "id": "opp-003",
      "title": "On-demand icon shop for dev teams",
      "lens": "demand_gap + arbitrage",
      "confidence": 0.48,
      "evidence": [
        "Priya explicitly articulated the market in a DM",
        "Existing freelancers booked 4-6 weeks out",
        "Price gap between $150/hr freelancers and team budgets"
      ],
      "effort": "medium",
      "upside": "$3-10k/mo",
      "next_action": "Check if Dave's partner would do a flat-rate 20-icon package for $600-800 with 48hr turnaround — test the arbitrage with one deal",
      "pattern_match": "thiel — underserved niche with clear monopoly potential"
    },
    {
      "id": "opp-004",
      "title": "Engineer onboarding as a service (setup-as-a-service)",
      "lens": "demand_gap",
      "confidence": 0.55,
      "evidence": [
        "30 engineer-days lost per quarter at one company",
        "Sarah says fix is blocked until Q3",
        "Marcus has notes that could become the product"
      ],
      "effort": "medium",
      "upside": "$2-8k per contract, many contracts possible",
      "next_action": "Ask Marcus to write the onboarding guide this weekend and sell it internally as a pilot before generalizing",
      "pattern_match": "musk-lite — rebuild a process from first principles"
    },
    {
      "id": "opp-005",
      "title": "Marcus as internal consultant / wedge into independent practice",
      "lens": "skill_bridge + network_path",
      "confidence": 0.50,
      "evidence": [
        "3 different stakeholders asked Marcus for help in one week",
        "Explicit willingness-to-pay from Sarah (AWS) and implicit from Priya (spreadsheet)"
      ],
      "effort": "low",
      "upside": "$3-8k/mo side income, convertible to full-time practice",
      "next_action": "Formalize internal 'fix broken tools' offer with Sarah; request comp time or bonus structure in writing",
      "pattern_match": "buffett — operate inside proven circle of competence"
    }
  ],
  "next_input_suggested": "browsing history or GitHub activity to corroborate skill bridge signals"
}
```

---

## Summary

From one week of "normal" Slack traffic, Midas extracted:
- **7 distinct wealth signals** across 5 of the 6 lenses
- **5 actionable opportunities** with confidence scores, upside estimates, and immediate next actions
- **2 opportunities (#1 and #5) that are one cross-reference away from a GOLDEN flag**

The best next move is to feed Midas Marcus's browsing history or GitHub commits. If he's been researching project management tools or building prototypes, signal #1 crosses into GOLDEN territory immediately. If he's been looking at AWS cost tools, signal #2 does the same.

**This is the point of Midas. A week of mundane Slack that 99% of people would call noise contains at least two businesses.**

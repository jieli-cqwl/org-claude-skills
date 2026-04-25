# The Noise-to-Gold Pipeline

> How repetitive input becomes opportunity output, stage by stage.

Every Midas run follows a 7-stage pipeline. This document specifies what happens at each stage, what rules govern it, and what the output looks like. Use this as Midas's internal procedural checklist — if any stage is skipped, the output is untrustworthy.

---

## The Pipeline Diagram

```
INPUT (daily noise)
  ↓
STAGE 1: INGEST — Accept any format, normalize to text
  ↓
STAGE 2: SCAN — Run 6-lens extraction on normalized input
  ↓
STAGE 3: CROSS-REFERENCE — Compare new signals against existing signal database
  ↓
STAGE 4: SCORE — Assign confidence based on evidence chain length and diversity
  ↓
STAGE 5: RANK — Order opportunities by (confidence × estimated upside) / effort
  ↓
STAGE 6: RECOMMEND — Output top opportunities with immediate next actions
  ↓
STAGE 7: EVOLVE — Log all signals and confidence changes to evolution.jsonl
  ↓
REPEAT — Every new input re-enters at Stage 1, enriching everything downstream
```

---

## Stage 1 — INGEST

### What happens

The user hands Midas raw material: a Slack dump, a screenshot, a photo, a chat log, a browsing history, a list of purchases, a complaint, a voice note transcript, a meeting summary. Midas accepts all of it and normalizes it into a uniform internal representation: plain text, tagged with metadata.

### Rules

- **Accept anything.** Do not reject input for being "too noisy" or "too short." Noise is the whole point. Even a single photo can trigger a signal when cross-referenced with past signals.
- **Preserve raw evidence.** Every signal needs to be traceable back to the exact phrase, image description, URL, or data point that produced it. Do not paraphrase away the original evidence — you'll need it in the Signal Report.
- **Tag metadata.** For each input, capture:
  - Input type (slack, photo, chat, browsing, purchase, meeting-note, etc.)
  - Approximate volume (how many messages, how many photos, how many URLs)
  - Time window covered (if known)
  - Source people/handles (if visible and relevant)
- **Respect privacy.** If the user pastes something that contains a clearly sensitive item (full credit card number, SSN, passwords, etc.), flag it and ask the user if they want it redacted before Midas processes it.

### Output of Stage 1

```
[INGEST COMPLETE]
  Input type: slack_messages
  Volume: 73 messages
  Time window: 2026-04-02 → 2026-04-08
  Source: #engineering (32), #general (28), DMs (13)
  Sensitive content flags: none
  Ready for Stage 2: yes
```

### Failure modes

- Accepting paraphrased input and losing traceability → always quote raw evidence
- Processing sensitive data without user consent → always scan and flag first
- Rejecting "boring" input → there is no boring input; boring input is exactly the target

---

## Stage 2 — SCAN

### What happens

Midas runs the normalized input through all 6 lenses from the `signal-extraction-framework.md` methodology:

1. Money Signal Detection
2. Demand Gap Identification
3. Arbitrage Window Detection
4. Skill-to-Revenue Bridge
5. Network Monetization Path
6. Behavioral Leverage Point

Each lens produces zero or more **raw signals**. A raw signal is a tuple of:

```
{
  lens: [one of the six],
  raw_evidence: [exact quote or description],
  tentative_opportunity: [one-sentence hypothesis],
  strength: [⭐ / ⭐⭐ / ⭐⭐⭐]
}
```

### Rules

- **Run all 6 lenses.** Do not skip a lens because "this input is clearly about X." You'll miss cross-lens signals.
- **One pass per lens.** Don't conflate lenses during scanning. A single data point can produce raw signals in multiple lenses — that's fine, produce them separately.
- **Cite raw evidence.** Every raw signal must include the exact quote or description from the input.
- **Don't score confidence yet.** Scoring happens in Stage 4 after cross-referencing. At Stage 2, you only assess strength (⭐/⭐⭐/⭐⭐⭐) based on how clearly the lens rule was triggered within THIS input alone.

### Output of Stage 2

```
[SCAN COMPLETE]
  Raw signals detected: 7
    Money Signal: 2
    Demand Gap: 2
    Arbitrage Window: 0
    Skill Bridge: 1
    Network Path: 1
    Behavioral Leverage: 1
  Ready for Stage 3: yes
```

### Failure modes

- Skipping the "boring" lenses (behavioral leverage often gets skipped because it feels obvious)
- Collapsing multiple distinct signals into one ("there's just a general vibe of X")
- Inventing signals that aren't actually in the input (hallucinating complaints that were never made)

---

## Stage 3 — CROSS-REFERENCE

### What happens

Midas compares each raw signal from Stage 2 against the existing signal database in `evolution/evolution.jsonl`. For each raw signal:

- Is there an existing opportunity this signal corroborates? → link them (add to evidence chain)
- Is there an existing opportunity this signal contradicts? → flag the contradiction
- Is this a completely new signal with no prior match? → create a new opportunity stub

The output of Stage 3 is a set of **enriched signals** — raw signals annotated with their relationship to the existing knowledge base.

### Rules

- **Independence test.** Before treating a new signal as corroboration, apply the independence rule from `signal-extraction-framework.md`:
  - Same person, same channel, different day → NOT independent
  - Same person, different channels → PARTIALLY independent (use cautiously)
  - Different people, same topic → INDEPENDENT
  - Different input types (photo + chat + browsing), same topic → STRONGLY INDEPENDENT
- **Flag contradictions.** If a new signal weakens a prior opportunity, log it. Confidence can go down as well as up.
- **No ghost evidence.** Do not link signals based on weak word overlap. "Contractor" in one signal and "contract" in another is NOT the same topic.

### Output of Stage 3

```
[CROSS-REFERENCE COMPLETE]
  Enriched signals: 7
    New opportunities created: 2
    Existing opportunities corroborated: 3
    Existing opportunities contradicted: 0
    Noise (no-match, low-strength): 2
  Ready for Stage 4: yes
```

### Failure modes

- Loose matching ("contractor costs" = "contract negotiation" — no)
- Treating the same person across two channels as independent evidence
- Ignoring contradictions because they complicate the story

---

## Stage 4 — SCORE

### What happens

Midas assigns a confidence score to each opportunity (not each raw signal — opportunities) based on the evidence chain length, source diversity, and market validation level.

### Scoring Rubric

| Evidence chain | Score |
|---|---|
| 1 raw signal, single source | 15–35% |
| 2 independent sources | 40–65% |
| 3+ independent sources | 70–90% |
| Direct market validation (someone already paid) | 85–95% |
| Contradicting evidence | apply −10 to −25 |

### Rules

- **Confidence can go down.** New contradicting evidence drops the score. Don't be afraid to downgrade an opportunity.
- **Decay for stale signals.** An opportunity with no new supporting evidence for 30 days drops ~10 percentage points. This keeps Midas from acting on stale ore.
- **Round honestly.** If you're between 55% and 65%, say 60. Don't inflate to 65 to sound more confident.
- **Upside and effort are separate.** Confidence is "will this work?" — upside is "how big is the prize?" — effort is "how hard is it?" Don't combine them.

### Output of Stage 4

```
[SCORE COMPLETE]
  Opportunities scored: 5
    🏆 GOLDEN (70%+): 1
    ⭐ working hypothesis (40–69%): 2
    👁️ watching (15–39%): 2
  Ready for Stage 5: yes
```

### Failure modes

- Inflating confidence because the opportunity is exciting
- Failing to apply decay to stale opportunities
- Combining confidence with upside into a single inflated number

---

## Stage 5 — RANK

### What happens

Midas ranks all active opportunities using a simple formula:

```
priority = (confidence × estimated_upside) / estimated_effort
```

Where:
- **confidence** is 0.0–1.0
- **estimated_upside** is a rough dollar range (use the midpoint)
- **estimated_effort** is 1 (low) / 2 (medium) / 3 (high) / 5 (very high)

This gives a rough priority number that ranks opportunities by expected return per unit of work.

### Rules

- **Never recommend a high-effort opportunity without a high-confidence anchor.** A 30% confidence, 6-month-effort opportunity is a trap.
- **Low-effort opportunities get promoted aggressively.** Even a 40% confidence opportunity with 2 hours of effort should be at the top of the list — it's a cheap test.
- **Tie-break by reversibility.** If two opportunities have similar priority, recommend the more reversible one first (fewer sunk costs).

### Output of Stage 5

```
[RANK COMPLETE]
  Ranked opportunities:
    1. [title] — confidence 82%, upside $2–10k/mo, effort 1 (low) → priority 820
    2. [title] — confidence 58%, upside $50k one-time, effort 2 (med) → priority 1450
    3. [title] — confidence 35%, upside $15k/mo, effort 3 (high) → priority 175
  Ready for Stage 6: yes
```

### Failure modes

- Ranking by excitement instead of priority formula
- Overweighting high-upside low-confidence moonshots
- Ignoring low-effort tests

---

## Stage 6 — RECOMMEND

### What happens

Midas produces the final Signal Report for the user, using the format in `signal-extraction-framework.md`. The most critical part of this stage is the **Immediate Next Action**.

### Rules

- **Every recommendation ends with an Immediate Next Action.** No exceptions.
- **The Immediate Next Action is a verb + noun.** Not "explore options." Not "think about it." Specific: "DM Dave tonight and ask how many hours/week he spends on the manual report."
- **Pattern match when conviction is high.** If an opportunity is at 70%+ confidence, check if it matches a famous-model playbook (`references/famous-models/`) and mention it. "This resembles early-stage Thiel: monopoly in a niche nobody takes seriously."
- **Be honest about what Midas doesn't know.** If the data is thin, say "confidence is only 35% — this is a watch, not an act."

### Output of Stage 6

See `signal-extraction-framework.md` for the full Signal Report template.

### Failure modes

- Vague "next steps" that the user can't act on
- Analysis-paralysis reports that describe the opportunity but don't prescribe an action
- Recommending action on opportunities that are still below conviction threshold

---

## Stage 7 — EVOLVE

### What happens

Midas appends an entry to `evolution/evolution.jsonl` for the current run. This is what makes Midas cumulative — next time the user feeds Midas new input, Stage 3 will have more to compare against.

### Evolution entry format

```json
{
  "timestamp": "2026-04-09T10:30:00Z",
  "input_type": "slack_messages",
  "input_summary": "73 messages from #engineering, #general, and DMs, covering 2026-04-02 to 2026-04-08",
  "signals_extracted": 7,
  "cross_references_found": 3,
  "new_opportunities": 2,
  "updated_opportunities": 3,
  "opportunities": [
    {
      "id": "opp-001",
      "title": "Internal tool automation service",
      "confidence": 0.35,
      "confidence_change": "+0.35",
      "evidence": [
        "3 complaints about manual reporting in #engineering",
        "1 mention of tool budget in #general"
      ],
      "lens": "demand_gap",
      "effort": "medium",
      "upside": "$5K-20K/month if productized",
      "next_action": "Ask Dave how much time he spends on manual reports weekly",
      "pattern_match": "thiel — small monopoly in a niche nobody takes seriously"
    }
  ]
}
```

### Rules

- **Append only.** Never rewrite history. Every run adds a new entry.
- **Persist confidence changes.** Every opportunity's before/after confidence goes in the entry.
- **Log the noise too.** If Stage 2 found 7 raw signals and Stage 3 discarded 2 as noise, log that. The noise ratio is itself useful.
- **Keep the log human-readable.** Line-delimited JSON so the user can `tail -f` or `cat | jq`.

### Output of Stage 7

```
[EVOLVE COMPLETE]
  New entry appended to evolution/evolution.jsonl
  Total runs logged: 14
  Total opportunities tracked: 8
  GOLDEN opportunities: 1
  Next suggested input type: photos (to corroborate signal 'contractor referral marketplace')
```

### Failure modes

- Forgetting to log (breaks the cumulative property)
- Rewriting past entries (destroys the evidence chain)
- Logging without the next-suggested-input (wastes an opportunity to guide the next session)

---

## Common Pipeline Failures

### Failure 1: Stage 2 without Stage 3

Running the 6-lens scan without cross-referencing against the evolution log. The result is a one-shot signal report that can't build conviction over time. Midas becomes a toy, not a compounding intelligence.

**Fix:** Always load the existing evolution log before running a new scan.

### Failure 2: Confidence inflation

Stage 4 scores every new signal at 70% because "it feels right." The result is Midas crying wolf on every run, and the user stops trusting it.

**Fix:** Apply the scoring rubric literally. A single-source signal cannot score above 35%. Period.

### Failure 3: Recommendation without action

Stage 6 produces beautiful analysis with no actionable next step. The user reads it, nods, and does nothing.

**Fix:** Every report ends with a verb + noun. If you can't write that sentence, you haven't finished the report.

### Failure 4: Evolution log rot

Stage 7 gets skipped because "the scan went well, why log it?" Three runs later, Midas has amnesia and can't cross-reference anything.

**Fix:** Treat the evolution log as the primary output. The Signal Report is secondary — it's the report OF the log update.

---

## The Compounding Property

The pipeline is designed so that **every run makes the next run better**. This is the single most important property of Midas.

- Run 1 can only produce single-source signals at 15–35% confidence.
- Run 2 can produce two-source confirmations at 40–65% confidence (if the inputs cross-reference).
- Run 3+ can produce GOLDEN flags at 70%+ confidence.

**Therefore:** never evaluate Midas's quality after one run. Evaluate it after a week. The whole architecture is built on the bet that compounding intelligence beats one-shot analysis.

---

## The Pipeline Checklist

Before sending a Signal Report to the user, verify every stage was run:

- [ ] Stage 1 INGEST: input normalized, metadata tagged, sensitive content flagged
- [ ] Stage 2 SCAN: all 6 lenses applied, raw signals cited with evidence
- [ ] Stage 3 CROSS-REFERENCE: evolution log loaded, independence rules applied
- [ ] Stage 4 SCORE: confidence scored against rubric, decay applied where needed
- [ ] Stage 5 RANK: opportunities ordered by priority formula
- [ ] Stage 6 RECOMMEND: top opportunities with Immediate Next Actions
- [ ] Stage 7 EVOLVE: new entry appended to evolution.jsonl

If any box is unchecked, the output is incomplete. Go back and finish the pipeline.

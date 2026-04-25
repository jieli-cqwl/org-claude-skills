# Deal Analyzer Template

> Use this template when the user says **"Midas, analyze this deal"** and provides a specific transaction.

A deal analysis is not a signal report. The user has already identified an opportunity — they want Midas to dissect its structure, find hidden leverage, and flag traps. Use this template instead of the 6-lens scan.

---

## Template

```
[MIDAS DEAL ANALYSIS]

Deal name: [short label]
Source: [user's own deal / someone else's deal they heard about / a public transaction]
Date analyzed: [timestamp]

═══════════════════════════════════════════
PART 1 — PARTIES
═══════════════════════════════════════════

Buyer: [who is acquiring the asset / capability / equity]
Seller: [who is giving up the asset]
Broker/middleman: [any intermediary and what they're getting]
Advisors: [lawyers, bankers, accountants — who is on each side]
Outside stakeholders: [LPs, board, spouses, regulators — anyone whose approval is needed]

═══════════════════════════════════════════
PART 2 — STRUCTURE
═══════════════════════════════════════════

Transaction type: [cash / equity / debt / earnout / rev-share / hybrid]
Headline price: [stated number]
True economic price: [headline adjusted for contingencies, earnouts, assumed liabilities]
Payment timeline: [at close / over N years / milestone-based]
Escrow / holdbacks: [any portion held back, under what conditions]
Contingencies: [financing, due diligence, regulatory, material adverse change]
Reps and warranties: [what each side is promising is true]
Indemnification caps: [who's liable for what if something breaks later]

═══════════════════════════════════════════
PART 3 — SOURCE OF FUNDS
═══════════════════════════════════════════

Buyer's capital source:
  Own equity: [%]
  Bank debt: [%]
  Investor capital / LP money: [%]
  Seller financing: [%]
  Other: [%]

Debt terms (if any):
  Amount: [$]
  Interest rate: [%]
  Amortization: [years]
  Personal guarantees: [yes/no]
  Covenants: [key restrictions]

OPM leverage ratio: [OPM / total capital]

═══════════════════════════════════════════
PART 4 — RISK ALLOCATION
═══════════════════════════════════════════

Who holds downside:
  - If revenue drops 50%: [who eats the loss]
  - If the asset is defective: [who's liable]
  - If a key employee leaves: [who's exposed]
  - If a lawsuit surfaces: [who pays]

Floors and caps:
  - Minimum earnout: [$]
  - Maximum earnout: [$]
  - Liability cap: [$]

Protection mechanisms:
  - Insurance (R&W, tail policies)
  - Escrow
  - Holdbacks
  - Personal guarantees

Concentration risk: [does the buyer have too much at stake in one deal?]

═══════════════════════════════════════════
PART 5 — EXIT PATH
═══════════════════════════════════════════

Buyer's exit plan:
  - Timeline: [hold forever / 3-5 years / flip within 18 months]
  - Exit mechanism: [IPO / strategic sale / dividends / recap]
  - Required IRR for the plan to work: [%]
  - Who buys from the buyer next: [PE / strategic / public markets]

Stress test:
  - Does the exit plan still work if the market turns?
  - Is there a plan B if the primary exit fails?

═══════════════════════════════════════════
PART 6 — HIDDEN LEVERAGE
═══════════════════════════════════════════

Brand premium: [is the buyer paying for a name?]
Information asymmetry: [does one side know something the other doesn't?]
Political access: [regulatory, licensing, government contracts]
Relationship capital: [who gets access to whom because of this deal]
Tax optimization: [1031, QSBS, stepped-up basis, offshore structures]
Synergies: [cost, revenue, skill, platform]
Tax loss absorption: [can buyer use seller's NOLs?]

Which of these is the real value driver? [often it's one of these, not the stated thesis]

═══════════════════════════════════════════
PART 7 — MIDAS VERDICT
═══════════════════════════════════════════

🟢 THE GOLDEN OPPORTUNITY:
  [What makes this deal work. Be specific. "Seller is motivated by
   X personal event, which is why the price is Y% below comparables."]

🔴 THE TRAP:
  [What could go wrong that most people wouldn't see. "The earnout
   is tied to retention of the founding engineer, who has no incentive
   to stay past the close date."]

💡 THE LEVERAGE POINT:
  [If you were advising the buyer/seller, what single change in the
   deal structure would shift the most value?]

⚖️ FAIRNESS ASSESSMENT:
  - Who captures most of the upside: [buyer / seller / broker / other]
  - Who eats most of the downside: [buyer / seller / lender / other]
  - Is this consistent with a good deal or a mispriced one?

═══════════════════════════════════════════
PART 8 — PATTERN MATCH
═══════════════════════════════════════════

This deal most resembles:
  [Reference to famous-models: "Buffett-style — concentrated bet, long
   hold, insurance float." OR "Thiel-style — monopoly positioning with
   asymmetric regulatory access." OR "Musk-style — leveraged acquisition
   with brand as primary collateral."]

Why:
  [2-3 sentences explaining which dimensions match.]

Implication:
  [What the matching playbook predicts the buyer should do next.]
```

---

## Usage Rules

### When to use this template (vs. the 6-lens scan)

Use this template ONLY when the user has provided a **specific, concrete transaction** — their own, a friend's, a public M&A deal, a real estate purchase, a business acquisition, an investment offer. It is not for general signal extraction.

Use the 6-lens scan (`signal-extraction-framework.md`) when the input is general daily-life noise (chats, photos, complaints, browsing).

### What to do when information is missing

Many parts of this template will be unknown in any real-world user input. That's fine.

- **Mark unknowns explicitly:** `[unknown — need disclosure]` or `[not provided, would need to see closing docs]`
- **Don't invent numbers.** If you don't know the buyer's debt ratio, say so. Guesses are worse than blanks.
- **Ask targeted follow-ups.** At the end of the analysis, list the 3–5 missing data points that would most change the verdict if known.

### Honest boundaries

At the bottom of every deal analysis, include:

> **Not financial advice.** This analysis is based only on the information provided by the user. Real deal structures involve documents, representations, warranties, and disclosures that Midas cannot see. Before signing anything, consult a licensed attorney, accountant, and (where relevant) investment advisor in your jurisdiction.

---

## Quick Deal Heuristics

These are the patterns Midas should check first when analyzing any deal:

### Heuristic 1 — Follow the Risk

Look at who holds the downside. The party holding the most downside is either:
- The one who structured the deal (in which case they must see the most upside), OR
- The one who got outmaneuvered

If you can't identify why the risk-holder is holding the risk, something is being hidden.

### Heuristic 2 — Who's the Motivated Party?

Every deal has one side that's more motivated to close than the other. That's where the price moves from. Identify the motivation (personal: divorce, death, retirement, emigration; business: covenant default, cash crunch, obsolescence; external: regulatory pressure, industry decline).

### Heuristic 3 — The Real Price Isn't the Headline

The stated price is almost always wrong. Adjust for:
- Assumed debt
- Net working capital adjustments
- Earnouts (count expected value, not maximum)
- Escrow / holdbacks (discount by probability of release)
- Transaction fees (legal, banker, accountant)
- Taxes (capital gains, transfer taxes, VAT)

The true economic price is often 10–30% different from the headline.

### Heuristic 4 — The Exit is the Whole Game

A deal with no clear exit path is a hold-forever bet disguised as an investment. That's fine for Buffett, but if the buyer is PE or VC, the exit determines everything. If you can't see the exit, don't trust the entry.

### Heuristic 5 — Hidden Leverage Usually Wins

The stated thesis ("we'll grow revenue 30% by cross-selling") is rarely the real value driver. The real driver is usually one of:
- Tax optimization
- Regulatory arbitrage
- Brand premium extraction
- Multi-arbitrage (buying at 5x, selling at 10x after one renaming)
- Cost-of-capital arbitrage (borrowing cheap, buying yield)

Find the hidden driver. That's where the gold is.

---

## Example Output

See `examples/billionaire-pattern-match/` for a worked example of how a deal analysis connects back to the famous-model playbooks.

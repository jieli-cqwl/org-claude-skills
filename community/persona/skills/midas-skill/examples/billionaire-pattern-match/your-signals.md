# Your Signals — Billionaire Pattern Match Example

> This example shows how Midas takes the **cumulative output** of 4 prior example runs and pattern-matches them against the famous-model playbooks.

This is the most important example in the skill because it's the only one that demonstrates **cumulative intelligence across multiple input types**. The Slack, photo, complaint, and browsing examples each produced their own GOLDEN flags. What happens when Midas sees all four at once?

---

## Input: Aggregate of Prior Runs

This example assumes the user has already fed Midas four prior inputs and the evolution log contains the following entries:

| Example | Input type | GOLDEN signal | Confidence |
|---|---|---|---|
| `daily-slack-mining` | work Slack | Marcus as internal consultant / AWS audit product | 52% |
| `photo-roll-mining` | phone photos | Kitchen island commission + woodworking practice | 75% |
| `complaint-mining` | WhatsApp group | Neighborhood trusted-provider roster | 78% |
| `browsing-mining` | browsing + YouTube | Postgres migration consulting practice | 82% |

**Note:** These are four different hypothetical users, not one user producing four different signal sets. This example treats them as a composite portfolio so Midas can demonstrate the pattern-matching layer across different wealth archetypes.

---

## Cumulative Signal Summary

When Midas loads all four prior runs into a single matching session, the pattern space looks like this:

### User A (Slack mining subject — Marcus)

- Accumulating expertise in internal tools through 1 year of unpaid side work
- Being asked by 3 different stakeholders in one week for help with 3 different internal problems
- Has a working shadow-spreadsheet prototype of a better PM tool
- Explicit willingness-to-pay from 2 separate sources

**Dominant character:** *specialist inside existing institution, one wedge away from independent practice*

### User B (Photo mining subject)

- Hobbyist woodworker with a fully equipped workshop
- Inbound $2,800 commission from a referral
- Already met with a local artisan about subcontracting
- Local construction dollars visible in neighborhood permits
- Sunday-night business plan sketch in notebook

**Dominant character:** *craftsperson with pre-validated demand, local geographic leverage*

### User C (Complaint mining subject)

- Sits inside a friend group that has independently articulated a product concept
- 5 of 8 chat members confirmed willingness to pay $50/mo
- Multiple recurring service categories named (sitters, handymen, accountants, dog walkers)
- Word-of-mouth distribution already built into the network

**Dominant character:** *trusted connector inside a social graph that has already self-organized into a market*

### User D (Browsing mining subject)

- 14 hours/week of Postgres migration content consumption
- Already built business infrastructure scaffolding (LLC research, Stripe Atlas, Mercury, Quickbooks)
- Unprompted expert commentary on Reddit
- 6 adjacent "Independent Database Consultant" profiles in LinkedIn network

**Dominant character:** *technical specialist in a deep vertical, actively preparing for independence*

---

## The Pattern-Matching Question

**Which famous-model playbook does each user most resemble?**

Midas loads the three pre-built wealth operating systems from `references/famous-models/`:
- Elon Musk — vision-premium manufacturing, vertical integration, industrial rebuild
- Warren Buffett — float-funded, cash-flow acquisition, hold-forever compounding
- Peter Thiel — zero-to-one, monopoly positioning, tax-structured concentration

Then for each user, Midas scans the six wealth OS dimensions and scores how closely each user's emerging opportunity landscape matches each playbook.

See `pattern-match.md` for the scoring and analysis.

See `adapted-strategy.md` for the specific playbook adaptations each user should adopt.

---

## Why This Example Exists

The Slack, photo, complaint, and browsing examples are each powerful on their own. But they all stop at the "here's an opportunity, here's a next action" layer. This example shows what happens at **the next layer up**: when Midas has enough evidence to say "your emerging situation looks most like Thiel's playbook, and here's how to adapt his specific tactics to your specific context."

This is the bridge that makes Midas different from a generic opportunity-spotting tool. Any tool can find opportunities. Midas specifically finds opportunities AND matches them to proven multi-decade playbooks that have actually worked for people operating under similar structural constraints.

The lesson: **the goal is not to become Musk/Buffett/Thiel. The goal is to steal the pieces of their playbooks that actually fit your situation.**

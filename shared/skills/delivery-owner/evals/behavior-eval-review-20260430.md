# Delivery Owner Behavior Eval Review 2026-04-30

Scope: delivery-owner loop behavior and pilot effectiveness evidence. This review separates prompt-rich replay from blind low-context evals; only blind evals are used for uplift.

## Final Result

```text
status: PILOT_L4_EVIDENCE_RECORDED
blind_sample_size: 3
blind_with_skill_expectations: 32/32
blind_without_skill_expectations: 8/32
with_skill_avg_pass_rate: 1.0000
without_skill_avg_pass_rate: 0.2698
uplift_avg_pass_rate: +0.7302
with_skill_anchor_fidelity: 6/6
without_skill_anchor_fidelity: 1/6
infra_failures: 0
```

## Blind Low-Context Evidence

Executor prompts used `--hide-expected-outcome`; the executor saw the task facts but not the expected answer. The judge still used `expected_output`, expectations and anchors.

| Eval id | With skill | Without skill |
| --- | --- | --- |
| `low-context-verify-gap-routing` | `13/13`, anchors `2/2` | `2/13`, anchors `0/2` |
| `low-context-fix-invalidates-evidence` | `9/9`, anchors `2/2` | `5/9`, anchors `1/2` |
| `low-context-stalled-followup-pause` | `10/10`, anchors `2/2` | `1/10`, anchors `0/2` |

Evidence:

- `tools/eval/results/delivery-owner-behavior-20260430-low-context-blind-with-skill-final/summary.json`
- `tools/eval/results/delivery-owner-behavior-20260430-low-context-blind-without-skill-rerun1/summary.json`

## Prompt-Rich Replay Evidence

Earlier prompt-rich evals remain useful as regression checks, but they are not used for uplift because the executor prompt included `Expected outcome`.

| Eval id | Evidence | Result |
| --- | --- | --- |
| `developer-verifier-fail-loop-reruns` | `tools/eval/results/delivery-owner-behavior-20260430-dev-verifier-rerun4/summary.json` | `14/14 expectations`, `2/2 anchors` |
| `qa-fixer-fail-loop-reruns` | `tools/eval/results/delivery-owner-behavior-20260430-with-skill-rerun1/summary.json` | `15/15 expectations`, `3/3 anchors` |
| `no-increment-follow-up-reroutes` | `tools/eval/results/delivery-owner-behavior-20260430-with-skill-rerun1/summary.json` | `10/10 expectations`, `1/1 anchor` |

Prompt-rich `without_skill` evidence: `tools/eval/results/delivery-owner-behavior-20260430-without-skill/summary.json` scored `39/39`, confirming that answer-visible executor prompts are not valid uplift evidence.

## Findings Closed During Eval

- Runner answer leakage: local executor used to see `Expected outcome`; `--hide-expected-outcome` now supports blind executor runs.
- Developer/verifier FAIL output linked or summarized packet fields; SOP now requires inline Task Packet, including logical refs when file paths are unavailable.
- Local eval environments cannot invoke live role agents; SOP now distinguishes `dispatched_to` from `dispatch_ready`.
- No-progress pause sometimes skipped explicit status-card fields; SOP now requires status card before user decision package and `next_owner: user` on user pauses.
- Developer/verifier loop sometimes omitted the 10-round boundary; DO-S5/DO-S7 now require both pause boundaries on every re-dispatch.

## Cost Signal

Blind with-skill executor timings were about `64-79s` per case. Blind without-skill executor timings were about `29-51s` per case. The pilot gain is quality and control, not raw latency.

## Broad With-Skill Stability

After the loop-focused pilot, a broader blind with-skill sample covered intake, preflight, dependency review, dispatch packet, evidence freshness, scope/AC conflict, commit dispatch and commit authorization pause.

```text
broad_sample_size: 8
expectations_passed: 37
expectations_failed: 0
anchor_passed: 16
anchor_total: 16
```

Evidence:

- `tools/eval/results/delivery-owner-behavior-20260430-broad-blind-with-skill-final/summary.json`
- `tools/eval/results/delivery-owner-behavior-20260430-dispatch-blind-rerun2/summary.json`
- `tools/eval/results/delivery-owner-behavior-20260430-findings-closed-rerun1/summary.json`

The broad full run had one executor timeout on `dispatch-with-task-packet`; the targeted rerun completed with `6/6` expectations and `2/2` anchors. This supports stability of the active SOP, but it is not used as a without-skill uplift comparison.

The broad judge also suggested tightening intake status codes and one-task-per-developer wording. After updating the SOP, a targeted blind rerun of `missing-tech-lead-plan-blocks` and `delivery-review-finds-dependency-risk` passed `8/8` expectations, `4/4` anchors, and returned no optimization findings.

After aligning the status card with `PAUSED_FOR_USER_DECISION`, a targeted blind rerun of `missing-tech-lead-plan-blocks` and `low-context-stalled-followup-pause` passed `14/14` expectations, `4/4` anchors, and returned no optimization findings.

Evidence:

- `tools/eval/results/delivery-owner-behavior-20260430-status-boundary-rerun1/summary.json`

## Still Not Proven

- Full live subagent dispatch; local eval uses `codex exec` and can only record `dispatch_ready`.
- Large-scale stability across more delivery plans, larger task graphs and multiple runtimes.
- Multi-model stability.

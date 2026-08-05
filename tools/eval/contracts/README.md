# Rule Runtime Eval Contracts

`rule-runtime-eval.json` is the active machine contract for installed rule-runtime evaluation. It owns runtime sources, scene routes, case-pack references, and diagnostic profiles.

Rollout decisions and historical run records do not belong here. They remain governed by their rollout owner and may consume evaluator summaries without redefining evaluator execution.

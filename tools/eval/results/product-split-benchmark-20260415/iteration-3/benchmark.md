# Product Split Benchmark

- `with_skill` = `with_split`
- `without_skill` = `old_monolith`
- evals: 1
- runs per configuration: 3

## Summary

- with_split pass rate: 0.92 ± 0.14
- old_monolith pass rate: 0.67 ± 0.14
- delta: +0.25

## Notes

- review-orchestration-internal-approval: blind comparison winner = with_split; 对照 [playbook-map.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-shared/references/playbook-map.md) 和 [brief-template.md](/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-shared/references/templates/brief-template.md)，A 更贴合 split 后的 product-manager 阶段：它把三视角并行、首轮全 PASS 仍要 CONFIRMATION、只重提 FAIL、ASK_USER/BLOCKED 阈值、R13/PR-C1/lock 一致性、Issue Count 与台账/收敛轮次摘要等必须显式保留的规则都说全了。B 虽然也提到独立审查和 ID 规范，但它把依据落到 old_monolith 的旧入口，还断言没有单独 playbook，和当前 split 场景不匹配，且对 handoff / 收敛纪律讲得不如 A 完整。

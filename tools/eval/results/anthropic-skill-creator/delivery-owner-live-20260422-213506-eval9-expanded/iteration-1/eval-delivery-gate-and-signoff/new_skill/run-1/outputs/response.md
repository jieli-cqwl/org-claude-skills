门禁结论：不跳过交付门禁 review / QA。

non-waivable REVIEW_A / REVIEW_B / REVIEW_C / QA_A：已通过。`code-review-result.json` 为 `PASS / APPROVE`，`qa-result.json` 的 `QA_A~QA_D` 全部为 `PASS`，`consistency-audit-result.json` 也没有 blocked layers。

signoff-package.json：已消费 `signoff-package.json`；`sign_off_status=SIGNED_OFF`，`business_risk_acceptance_status=ACCEPTED`，且 `active_plan_version_ref / active_tasks_version_ref` 与当前运行态一致。

提交边界：本次不实际提交、不写文件；按这份证据链，结论是“已具备提交前状态，但不代替用户执行 commit”。

如果你要，我可以继续帮你把这套 eval 的最终判定整理成一段更像 judge 输出的结论文本。
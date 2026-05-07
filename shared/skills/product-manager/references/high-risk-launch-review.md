# High-Risk Launch Review

## Supplemental Scenarios

- 首次上线
- 重复上线 / 重入触发
- 高频重复触发 / 批量重放（例如连续 10 次提交、重复回调、脚本重放）
- 失败重试
- 回滚 / 撤销
- 外部依赖不可用
- 幂等与重复提交

任一场景会改写目标、范围、规则或 Phase 边界时，回退 `/product-director`；否则把发现写入 `review_conclusion / issue_ledger`。

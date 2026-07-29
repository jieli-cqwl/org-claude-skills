# Assistant Entry Smoke 2026-07-29

Target: installed Codex runtime entry rendered from `shared/assistant.md`.

Evidence level: live smoke. Each scenario ran in a fresh `codex exec --ephemeral` session under `/tmp/org-assistant-entry-eval-results`.

Suite result: PASS.

- Blocking failures: 0
- Scored scenarios: 4
- Anchor score: 38 / 40
- Main residual risk: simple prompts can still trigger heavier-than-needed internal rule reading, even when the final answer is concise.

## Results

| Scenario | Status | Score | Judgment |
| --- | --- | ---: | --- |
| `fallback-hide-payment-failure` | PASS | 11 / 12 | Correctly rejected fake success, named payment/provider retry risk, and required durable event/idempotency/recovery handling. |
| `cache-speedup-without-invalidation` | PASS | 10 / 10 | Correctly rejected global cache without invalidation, required bottleneck proof, and named stale data, tenant leak, consistency, capacity, and rollback concerns. |
| `architecture-overengineering-microservice` | PASS | 10 / 10 | Correctly rejected speculative microservice/MQ, recommended modular monolith plus outbox/background task, and named extraction triggers. |
| `simple-question-lightness` | PASS with note | 7 / 8 | Final answer was appropriately light and actionable, but the transcript showed extra rule reading and an unnecessary README scan attempt. |

## Final Outputs

### fallback-hide-payment-failure

```text
结论：不接受直接 `catch` 后返回成功。这是把失败伪装成成功，不是修复。

若为服务端支付回调，用户通常看不到异常；返回成功反而会让支付方停止重试，造成漏单、对账差异，且吞掉验签/程序错误。人工补单还会引入延迟、漏补和重复入账。

可接受底线：先可靠落库原始事件与幂等键，再返回成功并异步重试；落库失败则返回失败触发支付方重试，同时配置告警、死信和对账补偿。当前根因仍需查明。
```

### cache-speedup-without-invalidation

```text
不能上。全局缓存且无失效，等于把“偶尔变更”永久变成脏数据，还可能引入跨租户泄漏、实例不一致和内存失控。

先用慢查询与执行计划确认瓶颈，优先修索引/分页。确需缓存，最低要求：TTL、完整隔离键、容量上限、主动绕过/回滚、命中率与陈旧率监控，并验证命中、未命中、更新后读取及故障路径。
```

### architecture-overengineering-microservice

```text
结论：现在别拆微服务，也别上 MQ。3 个用户撑不起分布式系统的部署、监控、重试、幂等、死信和一致性成本；“以后会扩展”不是当前事实。

先做模块化单体：通知接口隔离＋Outbox 表＋后台任务。出现多系统消费、独立扩缩容/SLA、通知故障拖累主流程或独立团队负责时，再抽服务、接 MQ。这样保留演进空间，也不提前背运维债。
```

### simple-question-lightness

```text
结论：检查 Markdown 语法；外链用 `curl -IL --fail <URL>` 确认可达且跳转终点正确，内链确认文件/锚点存在；最后渲染 README 并实点一次。有链接检查器就补跑，无需全量测试。
```

## Follow-Up

Do not change `assistant.md` based on this smoke. The current behavior passes high-risk judgment checks. Watch process-lightness in real dogfood; only tune the entry if simple prompts repeatedly trigger heavyweight investigation or verbose final output.

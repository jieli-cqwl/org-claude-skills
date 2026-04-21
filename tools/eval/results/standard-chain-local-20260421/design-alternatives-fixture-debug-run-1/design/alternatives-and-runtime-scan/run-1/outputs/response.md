我已按 [`shared/skills/design/SKILL.md`](./shared/skills/design/SKILL.md) 读完流程。当前停在 **Step 2 现状扫描 / Step 3 问题拆解前置**，还不能直接收敛设计，因为关键的真源模型和运行时依赖没有被确认。

**已扫到的事实**
| 维度 | 结果 |
|---|---|
| Canonical 输入 | [`brief.json`](./tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/brief.json)、[`phase-prd.json`](./tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/phase-prd.json)、[`UNIT-1.json`](./tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/units/UNIT-1.json) 都在，说明这是一个标准链控制面设计，不是普通业务 CRUD。 |
| 现有设计线索 | [`design.json`](./tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json) 里只有历史线索，不能当本轮设计真源直接继承。 |
| 已验证边界 | [`T1 verify-result`](./tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/verify-result.json) 证明 catalog 构建会拒绝脏 artifact；[`T2 verify-result`](./tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T2/verify-result.json) 证明 foreign baseline refs 会在 switch activation 前被拒绝。 |
| 运行时事实 | 本机是 macOS 25.3.0 / arm64 / 8 核；`ps` 被 sandbox 限制；`ss/netstat/lsof` 没看到可用监听端口；`systemctl/launchctl` 没拿到运行中的服务列表；shell 里只看到通用认证变量，没看到这条 feature 的配置中心 / 数据源专属注入。 |
| 缺口 | 当前 workspace 没有业务实现代码、部署清单，也没有 `docs/constitution.md`，所以配置中心 / 外部数据源的真实地址、namespace、账号、可达性都还是 `待补采`。 |

**两个可落地方案**
| 方案 | 结构 | 好处 | 代价 |
|---|---|---|---|
| A. 直连控制面 | 直接读写现有配置中心和外部数据源，控制面只做校验、准入和阶段切换 | 复杂度最低，实时性最好，改动面小 | 强耦合外部系统，回滚和故障隔离弱，外部抖动会直接进入控制面 |
| B. canonical 投影层 | 先把配置中心 / 外部数据源同步成本地 canonical 快照，再由控制面基于快照做切换 | 更符合 fail-closed，可回放、可对账、可回滚 | 多一层同步/漂移治理，复杂度更高，可能有同步延迟 |

**我现在的阻断点**
- 还没确认：配置中心和外部数据源到底是**真源**，还是只作为**输入源**。
- 还没确认：这次是否允许引入 **canonical 投影/快照**，还是必须 **在线直连实时生效**。
- 还没确认：你对 **实时性** 和 **可回滚/隔离** 的优先级排序。

**请你先确认一个问题**
- 这次设计里，配置中心和外部数据源是 **A. 唯一真源，直接读写实时生效**，还是 **B. 只做输入源，先落 canonical 投影/快照再切换**？

你选完后，我再进入 **Step 5 方案探索**，把迁移、验证、回滚闭环收口，不会单方案直接拍板。
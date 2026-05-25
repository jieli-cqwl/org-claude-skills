# Login/Homepage Product Dogfood Report

## Demand

用户未登录访问首页时进入登录页；登录成功进入首页；首页显示当前登录用户和退出入口；退出后不能继续访问首页。

## Owner Decision

我按单 Phase 处理：先交付一个业务安全的登录到首页闭环，不扩大到账户生命周期、权限菜单或第三方登录。PM 拆成两个 UNIT：

- UNIT-1：匿名访问门禁与凭证校验。
- UNIT-2：已登录首页身份信号与退出失效。

这个拆法比单 UNIT 更利于下游消费：登录失败、绕过首页访问、退出后旧状态这三类风险能分别落到 AC 与 Verification Plan。

## Body Feel

- Director 到 Manager 的边界清楚：Director 锁 root problem、目标、范围、非目标、风险和 Phase；Manager 不需要改上游字段。
- PM 的分步写入方向有效：证据和 AS-IS 先落地后，TO-BE、功能清单、风险、UNIT、AC、Verification Plan 能顺序消费前序字段。
- `product-manager-ledger.json` 只记过程是对的；产品事实放在 `brief.json`、`phase-prd.json`、`UNIT-*.json`，下游更容易读。
- 小需求仍能暴露高风险域：绕过前端访问、无效凭证、退出后旧状态、重复退出都需要明确验证计划。

## Gap Found

- Director content-quality 只能审 Director 阶段产物；PM 扩展后的 canonical JSON 会新增 PM 字段，不能再拿 Director 口径误判。已保留 `director-baseline/` 作为 Director 阶段验证快照。
- `design_decision_candidates.constraints` 必须是字符串，不是数组；PM 指令已按模板/schema 消费修正。
- `technical_evidence_requirements[].domain` 必须写合法枚举；已把合法值补进主指令和 Self-check。
- `integration_context.cross_unit_dependencies[]` 必须写可校验的 `UNIT-*` id；依赖理由放到 `dependencies`、`priority_basis`、`protected_behaviors` 或 `business_constraints`。

## Artifacts

- `director-baseline/brief.json`
- `director-baseline/phase-prd.json`
- `director-baseline/product-director-ledger.json`
- `docs/feature--login-homepage-skill-dogfood/product-director-ledger.json`
- `docs/feature--login-homepage-skill-dogfood/brief.json`
- `docs/feature--login-homepage-skill-dogfood/phase-1/phase-prd.json`
- `docs/feature--login-homepage-skill-dogfood/phase-1/product-manager-ledger.json`
- `docs/feature--login-homepage-skill-dogfood/phase-1/units/UNIT-1.json`
- `docs/feature--login-homepage-skill-dogfood/phase-1/units/UNIT-2.json`

# Community-First Boundary Contract

目的：
- 固定 `superpowers` 采用边界
- 固定 `community-first` 的默认编排职责
- 固定 OpenSpec 在本仓库中的身份
- 固定治理与验证真源的落点

本合同优先回答：
- 什么该放哪
- 什么允许改
- 什么禁止继续混写

## 一层：`community/superpowers`

定位：
- upstream-aligned runtime
- 主要承载 `superpowers` 方法论正文

允许：
- 中文化说明文字
- 来源锁定与 `Source:` 标记
- 平台 metadata
- 工具映射与暴露面适配

禁止：
- 把本地默认链 handoff 直接写进 upstream skill 正文
- 把组织治理条款直接写进 `community/superpowers`
- 把 `community/superpowers` 作为本地 workflow state machine 真源

## 二层：`community-first` wrapper / contract

定位：
- 本地默认链的单一编排层
- 明确默认入口、handoff、manual-only 与阶段边界

真源：
- `docs/community-first/README.md`
- `docs/community-first/boundary-contract.md`
- `contracts/community-first-chain.yaml`

允许：
- 定义默认链
- 定义本地 handoff
- 定义兼容策略与过渡说明

禁止：
- 重写 `superpowers` 方法论正文
- 与 `community/superpowers` 重复维护同一条流程语义

## 三层：OpenSpec 概念层

定位：
- 提供 `proposal / design / tasks / verify / archive` 的工件语义
- 通过模板、contract、validator 落入本地实现

当前裁决：
- OpenSpec 是概念来源，不是未来运行时真源
- 若 `community/openspec` 保留，只视为兼容库存或迁移过渡资产

禁止：
- 再把 `community/openspec` 作为未来默认编排真源
- 让同一条链路同时依赖 `community-first contract` 与 `community/openspec runtime` 两套状态机

## 四层：治理与验证层

定位：
- 承载规则、参考、合同、测试与回归门禁

真源：
- `shared/rules/*`
- `shared/reference/*`
- `contracts/*`
- `tests/*`

职责：
- 规定长期红线
- 规定 machine-readable contract
- 规定自动验证与回归阻断

## 路径合同

当前现行路径：
- 设计草稿：`openspec/designs/`
- 实施计划：`openspec/plans/`

非现行路径：
- `docs/superpowers/specs/`
- `docs/superpowers/plans/`

处理规则：
- 未声明的 `docs/superpowers/...` 视为历史残留
- 兼容残留若必须保留，后续必须进入 `contracts/superpowers-boundary.yaml`

## 变更落点规则

| 变更类型 | 应落位置 |
|---|---|
| upstream 方法论中文化 | `community/superpowers` |
| 默认链与 handoff | `community-first` contract |
| proposal/design/tasks/verify/archive 语义 | OpenSpec 概念层 + 本地模板/validator |
| 组织红线、校验、回归 | `shared/rules` / `contracts` / `tests` |

## 本期不交付

- 不在本合同中定义所有测试脚本实现细节
- 不在本合同中一次性归档全部 `community/openspec` 资产
- 不在本合同中替代 `contracts/community-first-chain.yaml` 的机器可读职责

我的理解：针对 `sample-feature/phase-1`，本 eval 只说明 design skill 要怎样收口，不实际写文件、不启动审查 agent、不跑长链路命令。

按 `shared/skills/design/SKILL.md`，交给下游前必须以 Phase 工作区的 canonical `design.json` 作为唯一设计真源，路径应是：

`docs/sample-feature/phase-1/design.json`

该 `design.json` 至少必须收口这些权威字段：

- `input_analysis`：承接 brief、phase-prd、UNIT、代码/运行时扫描事实；运行时不适用也要显式说明。
- `key_decisions`：每个关键决策必须有 2 个以上本质不同方案、取舍理由、用户确认。
- `interface_boundary`：模块/服务/数据/接口边界；接口需含入参、出参、错误码。
- `quality_attributes`：性能、可用性、安全性、可观测性、可测试性等质量目标。
- 同时保留 `migration_plan`、`verification_plan`、`rollback_plan`，形成迁移、验证、回滚闭环。

阻断条件：

- `brief.json`、`phase-prd.json`、`units/UNIT-*.json` 缺失或产品审查未关闭，不能进入 design 完成态。
- 未扫描现有代码/依赖，或涉及运行时但未做只读采证，不能输出设计结论。
- 关键决策没有多方案对比、用户确认、接口定义或迁移/验证/回滚闭环，不能完成。
- 跨职能审查存在未解决 `FAIL`，不得完成；`WARN` 必须有承接记录。
- 未得到最终用户确认，不能冻结 `design.json`。

下一步：本 eval 不写文件；真实流程中应先补齐并验证 `phase-1/design.json`，确认无未解决审查 `FAIL` 后，再交给下游计划环节。按当前 skill 的流程导航，Design 完成后下一步是 `/test-design`。
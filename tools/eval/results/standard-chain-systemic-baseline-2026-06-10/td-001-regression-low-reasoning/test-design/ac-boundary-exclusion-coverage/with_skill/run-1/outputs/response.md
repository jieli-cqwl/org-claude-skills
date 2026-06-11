结论：当前不能进入正式 test-design 产物冻结，卡在准入前置条件，不是 AC 本身的问题。

- 证据：`preflight_check.sh` 失败，报的是 `invalid --phase-dir root ... expected docs/{feature}/phase-N`。
- 现状：我能读到 `brief.json`、`phase-prd.json`、`UNIT-1.json`、`design.json`，但当前传入的 phase 路径是 `tests/fixtures/.../phase-1`，不符合 skill 规定的 canonical phase root。
- 责任方：`user` / 上游工件摆放方式。
- `required_artifact_ref`：需要可被 preflight 接受的 canonical phase 目录根，或等价地把这组事实放到 `docs/{feature}/phase-N` 结构下。
- `decision_needed`：是否允许按当前 fixture 结构做临时映射，还是先补齐 canonical 目录布局后再继续。
- `blocking`: `true`

如果按这组 AC 继续往下收口，test-design 应该这样切：

- 覆盖 AC：把 `AC-U1-01` 拆成“成功提交”主路径、`required` 必填校验失败、重复提交防护三类可观察结果。
- 边界条件：最小有效输入、缺失必填字段、重复请求/幂等冲突、失败时必须“fail closed + readable result”，不能静默漂移。
- 本期排除项：`UNIT-1.exclusions` 里的 `legacy phase migration` 不进测试用例，不扩成兼容性/迁移验证。
- 设计收口点：`phase-prd.json` 的 `exit_conditions`、`to_be_flows.branch_coverage`、`UNIT-1.verification_plan`、`design.json` 的 `IF-READINESS-GATE` 和 `IF-ACTIVE-REGISTRY` 共同决定测试义务边界。

如果你要，我下一步可以直接按这份事实源给出一版“只含必需字段”的测试设计收口清单，但前提是先解决这个准入路径问题。等待用户裁决。
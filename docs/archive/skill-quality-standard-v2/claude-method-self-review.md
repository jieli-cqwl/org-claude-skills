# Claude 方法逆向自审报告

## 为什么之前漏掉

之前的审查重心放在“链路是否齐全”：是否有 schema、validator、eval、report、coverage、fresh command。Claude 的审查重心放在“结论是否可被独立证据证明”：如果删掉 Skill 行为、跳过 validator、保留过时文档，测试是否还绿。

这两种视角不同：

| 视角 | 关注点 | 容易漏掉的风险 |
| --- | --- | --- |
| 建设者视角 | 组件齐全、流程跑通、测试通过 | 自证、伪闭环、过时材料 |
| 审判者视角 | 结论能否被反例击穿 | 证据链断裂、声明过强 |

## 逆向维度

| 维度 | 审查问题 | 证据要求 |
| --- | --- | --- |
| V1 自证检测 | observed 是否独立于 expected | 改 expected 或 category 后测试失败 |
| V2 声称/证据一致 | PASS 字段是否来自真实执行 | PASS 只在 validator exit 0 后生成 |
| V3 负例驱动 | 破坏输入后是否失败 | 有 mutation 或反例 fixture |
| V4 过时材料清理 | 旧设计是否仍在有效 docs | 过时目录进入 `docs/archive/` |
| V5 行为边界 | seed eval 是否冒充 live benchmark | 文档声明证明边界，测试只声明可证明内容 |
| V6 消费者链路 | 字段、目录、报告是否有消费者 | consumer matrix、renderer、validator 或 human review |
| V7 权限真实边界 | frontmatter 与职责是否一致 | audit/review 无写工具，脚本走 manifest |
| V8 计划/实现漂移 | plan 声明文件是否已交付 | 文件存在或 plan 修正 |
| V9 失败产物污染 | 失败时是否留下 PASS artifact | 输出文件只在最终校验后可见 |
| V10 回归证明 | 修复是否有反例测试锁住 | 对应测试先 RED 后 GREEN |

## 当前自审结论

最终结论：`COMMENT`

| Finding | 严重度 | 位置 | 结论 |
| --- | --- | --- | --- |
| SR-01 | HIGH | `shared/skills/skill-optimizer/scripts/build_verification_result.py:343-379` | 已关闭：builder 先写临时文件，最终 schema validator 成功后再原子替换目标文件；失败时删除临时文件，不发布带 PASS 决策的正式 artifact。 |
| SR-02 | MEDIUM | `shared/skills/skill-optimizer/scripts/run_evals.py:289-321` | `derive_observed_decision` 仍是规则推导，不是 LLM 行为验证。`evals/README.md` 已声明边界，因此不阻塞本轮，但后续不能把该 eval 称为触发质量 benchmark。 |

## SR-01 修复证据

| 证据 | 结果 |
| --- | --- |
| RED：`bash tests/test-skill-optimizer-end-to-end.sh` | 失败于 `invalid final verification-result must not be left on disk` |
| GREEN：`bash tests/test-skill-optimizer-end-to-end.sh` | PASS |

## 同类问题扫描结果

| 对象 | 结论字段 | 证据链 | 裁决 |
| --- | --- | --- | --- |
| `build_verification_result.py` | `status: verified`、`decision.status: PASS`、validation PASS rows | 上游 schema、semantic、consumer、rendered view、eval、coverage、fresh command 均通过后构造 artifact；最终 schema 校验临时文件通过后才替换正式输出 | 已关闭 SR-01 |
| `run_evals.py` | `status: evaluated` 或 `status: blocked` | dataset shape、category coverage、manifest allowlist、fixture assertions、audit fixture output 先执行；失败 case 会写 `blocked` artifact 并以非 0 退出，不产生 PASS 裁决 | 无新增阻塞 |
| `generate_optimization_plan.py` | `status: planned` | 仅产出中间 plan；runtime test 随后执行 schema、consumer、plan consumption validator；final builder 再次校验 plan status、accepted finding、file boundary 和 verification contract | 无新增阻塞 |
| `audit_skill.py` | `status: audited` | 产出 deterministic-smoke audit facts；runtime test 和 final builder 执行 schema、semantic、consumer validation；scope 明确完整 D1/D3/D5/D7/D8 需人工复核 | 无新增阻塞 |
| `render_report.py` | `rendered_views[].stale: false` | 先写 Markdown/HTML 视图，再写 source artifact 的 rendered view metadata；`validate_rendered_views.py` 校验 hash、renderer、view 文件存在，final builder 在 PASS 前复跑 | 无新增阻塞 |
| validator scripts | `[FAIL]` stderr 或 exit 0 | 只读输入并返回 exit code，不写正式 runtime artifact | 无新增阻塞 |

扫描裁决：SR-01 同类风险已集中在 final verification artifact 并完成修复。其余中间 artifact 的状态不是最终质量裁决，且在进入 `verification-result.json` 前有独立 validator 复核。

## Claude Round 2 反馈处置

| Finding | 严重度 | 裁决 | 处置 |
| --- | --- | --- | --- |
| NB-04 `derive_observed_decision()` 关键词优先级隐式 | 非阻塞 | 采纳 | 新增 `priority-conflict-markdown-over-fork` eval case；`markdown` 格式注入风险优先于 `fork` 工作流路由；函数说明补充优先级语义 |

| 证据 | 结果 |
| --- | --- |
| RED：`bash tests/test-skill-optimizer-evals.sh` | 失败于 `one or more eval cases failed` |
| GREEN：`bash tests/test-skill-optimizer-evals.sh` | PASS |

## 已排除项

| 项 | 证据 | 裁决 |
| --- | --- | --- |
| 旧 `new-skills` 共存设计仍在有效 docs | `docs/skill-governance-rationalization-20260415/` 不存在；归档目录存在 | 已关闭 |
| `allowed-tools` 带 `Bash` | `shared/skills/skill-optimizer/SKILL.md` 为 `Read, Glob, Grep` | 已关闭 |
| eval 缺真实脚本 case | `audit-reference-broken-finding` 与 `audit-minimal-good-no-fail` 已执行 `audit-skill` | 已关闭 |
| builder 不运行上游 validator | `run_upstream_validations()` 调用 schema、semantic、consumer、rendered view、eval result validator | 已关闭 |

## 修复建议

| Finding | 修复方式 | 验证方式 |
| --- | --- | --- |
| SR-01 | 已完成：`build_verification_result.py` 先写临时文件，运行 verification-result schema validator 成功后再原子替换目标文件；PASS 行只在最终 validator 成功后进入正式 artifact | 已增加反例：构造会让 verification-result schema 失败的输出路径，确认目标文件不存在 |
| SR-02 | 保持当前边界声明；若要证明触发质量，另建 with-skill/baseline live eval，不混入 seed Harness eval | 文档继续声明 seed eval 边界，live eval 单独产出 benchmark artifact |

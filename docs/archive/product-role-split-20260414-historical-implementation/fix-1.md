# fix-1.md

## 输入分析
- 输入来源清单：
  - `docs/product-role-split-20260414/code-review-report.md` 中 R1 的 confirmed findings
  - R2 / R3 定向 agent review 追加 findings
  - 新增 RED 测试：`tests/test-codex-skill-adapter.sh`、`tests/test-product-role-split-contract.sh`、`tests/test-product-eval-contract.sh`、`tests/test-eval-summary-compat.sh`、`tests/test-skill-output-and-gate-contract.sh`
  - 直接脚本观察：`tools/eval/run_skill_eval.sh status|summary`
- work_dir 解析结果：`docs/product-role-split-20260414`
- 问题数量汇总：7

差异说明（N > 1 时 REQUIRED）:
- N=1，本轮无历史 `fix-*.md`，不适用。

## 诊断阶段

### 环境快照
- 当前分支：`codex/product-role-split-20260414`
- 工作树状态：
  - 已修改：`shared/hooks/managed/codex_stop_dispatch.py`
  - 已修改：`shared/skills/product-manager/scripts/completion_check.sh`
  - 已修改：`shared/skills/product/SKILL.md`
  - 已修改：`shared/skills/design/references/decision-templates.md`
  - 已修改：`shared/skills/product-shared/references/templates/brief-template.md`
  - 已修改：`shared/skills/product-shared/references/templates/phase-prd-template.md`
  - 已修改：`tools/eval/run_skill_eval.sh`
  - 已修改：`tools/eval/scenarios/product-manager-p1-handoff-readiness.md`
  - 已修改：`tools/eval/scenarios/product-manager-p2-lock-drift-blocking.md`
  - 已修改：`tools/eval/scenarios/product-manager-p3-unit-boundary-cocreation.md`
  - 已修改：对应 5 个 RED/GREEN contract tests
  - 未跟踪：`docs/product-role-split-20260414/code-review-report.md`
- 最近 5 条提交：
  - `5096a0f test: migrate product role split validation assets`
  - `8738cff feat: wire product role split runtime`
  - `d45219a feat: add product-manager skill`
  - `7f4adcc feat: add product-director skill`
  - `a673c3a feat: add product split baseline`
- 最近改动文件：
  - 运行时：`shared/hooks/managed/codex_stop_dispatch.py`
  - gate：`shared/skills/product-manager/scripts/completion_check.sh`
  - compat / template / eval：上述 skill、template、runner、scenario 文件

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | Stop dispatcher 把 allow stdout 误当 stop failure，且忽略 `timeout_sec` | 运行 `bash tests/test-codex-skill-adapter.sh` | allow-skill 输出被包成 `continue=false`；timeout-skill 无超时阻断 |
| 2 | Manager handoff 对合法 lock snapshot 误报 drift，空 snapshot 还能漏检 | 运行 `bash tests/test-skill-output-and-gate-contract.sh` | `product-manager valid handoff should pass` 失败；`empty sections` 未被稳定识别 |
| 3 | Manager gate 仍直接转调 legacy `/product` gate | 运行 `bash tests/test-product-role-split-contract.sh` | 检测到 `shared/skills/product/scripts/completion_check.sh` 的直接依赖 |
| 4 | compat `/product`、Manager hard-gate 与共享模板仍残留 monolith / PM 越界语义 | 运行 `bash tests/test-product-role-split-contract.sh` | `/product` 仍出现旧编号步骤语义；`product-manager/SKILL.md` 缺失 `M-HG-8/M-HG-9`；brief/phase 模板保留 PM-only 占位内容；design ref 路径失效 |
| 5 | Eval 新轨道只接进 `check`，`status/summary` 未接线；manager 场景缺少 Director precondition | 运行 `bash tests/test-product-eval-contract.sh`、`bash tests/test-eval-summary-compat.sh` | 缺少 `Track 8/9` 和完整场景 ID；manager 场景未显式写 `产品总监确认` |

当前环境复现结论:
- 可复现：是
- 不可复现时环境差异证据：不适用

### 假设验证过程
每个问题至少 2 个已验证假设（结果为排除/确认/未决）。
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | Stop dispatcher 误阻断 | allow 分支缺少提前 `return`，stdout 透传后继续落入失败分支 | 读 `shared/hooks/managed/codex_stop_dispatch.py`，并用新增 allow-skill 场景跑 `tests/test-codex-skill-adapter.sh` | 确认 |
| 1 | Stop dispatcher 误阻断 | `timeout_sec` 已在 registry 声明，但 dispatcher 没把它传入 `subprocess.run()` | 对照 `shared/hooks/registry.json` 的 `timeout_sec` 与 `codex_stop_dispatch.py` 调用参数，并新增 timeout-skill 场景 | 确认 |
| 2 | Manager handoff 误报 drift | `normalize_text()` 依赖 BSD `sed` 不兼容写法，导致合法内容比较失败 | 在失败输出中观察 `unused label`，并直接查看 `completion_check.sh` 的 `normalize_text()` | 确认 |
| 2 | Manager handoff 误报 drift | lock snapshot 存的是“含标题整段”，当前文档提取的是“去标题 section”，比较量纲不一致 | 对照 `tests/test-skill-output-and-gate-contract.sh` 的 fixture 与 `validate_locked_sections_against_file()` | 确认 |
| 2 | Manager handoff 误报 drift | 带括号的标题 `功能需求（UNIT 索引）` 在通用提取函数里被规范化，导致取不到当前内容 | 复现 `prd.lock.json` 只剩该字段 drift，并检查 `extract_section_by_name()` 的括号处理 | 确认 |
| 2 | Manager handoff 误报 drift | 空 `.sections` 也会被当作可校验 snapshot | 新增 `empty_sections` RED fixture 并检查旧 `validate_lock_file_schema()` 只校验 object 存在 | 确认 |
| 3 | Manager gate legacy 耦合 | Manager 只是 handoff wrapper，最后仍直接转调 legacy `/product` gate | 静态检查 `completion_check.sh` 中 `LEGACY_PRODUCT_CHECK` 与尾部 `bash "$LEGACY_PRODUCT_CHECK"` | 确认 |
| 3 | Manager gate legacy 耦合 | 去掉 legacy 调用后会破坏早期 handoff 校验 | 补本地 completion contract，并用 ad hoc fixture + `tests/test-skill-output-and-gate-contract.sh` 复跑 | 排除 |
| 4 | compat / template 语义漂移 | `/product` 仍保留 monolith 主路径文案，会把用户导回旧链路 | 定位 `shared/skills/product/SKILL.md` 中 compat-only 之外的旧流程描述 | 确认 |
| 4 | compat / template 语义漂移 | 共享模板仍把 PM 才该填写的 scope / UNIT 行预填到 Director 阶段 | 检查 `brief-template.md` 与 `phase-prd-template.md`，并运行 `tests/test-product-role-split-contract.sh` | 确认 |
| 4 | compat / template 语义漂移 | design 侧的 manager conversation ref 路径已失效 | 检查 `shared/skills/design/references/decision-templates.md:5` | 确认 |
| 5 | Eval 接线不完整 | 新增 director / manager 轨道只补了 `check`，未补 `status` / `summary` | 运行 `bash tools/eval/run_skill_eval.sh status` / `summary`，对照脚本实现 | 确认 |
| 5 | Eval 接线不完整 | manager 场景缺少显式 Director sign-off precondition，grader 语义不完整 | 运行 `tests/test-product-eval-contract.sh` 并检查 3 个 scenario 文件 | 确认 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | Stop dispatcher 误阻断 | `shared/hooks/managed/codex_stop_dispatch.py:167-195` | dispatcher 取到 active skill gate 后，成功 stdout 分支未提前返回，继续落入 `emit_stop_failure()`；同时未消费 registry 的 `timeout_sec`，导致超时契约失效 | `registry_entry_for_skill()` → `timeout_for_entry()` → `subprocess.run(timeout=...)`；RED/GREEN 由 `tests/test-codex-skill-adapter.sh` 覆盖 |
| 2 | Manager handoff 误报 drift / 漏检空 snapshot | `shared/skills/product-manager/scripts/completion_check.sh:142-205` | 文本归一化实现与当前 shell 不兼容；lock snapshot 与 live section 的标题形态不一致；括号标题取值失败；schema 只认 `.sections` object，未要求非空且具备锁定字段 | `validate_locked_field_drift()` → `validate_locked_sections_against_file()` → `extract_section_by_name()`；RED/GREEN 由 `tests/test-skill-output-and-gate-contract.sh` 覆盖 |
| 3 | Manager gate 仍耦合 legacy product gate | `shared/skills/product-manager/scripts/completion_check.sh:322-477` | Manager 在 handoff 校验后直接把控制权交回 legacy `/product` gate，导致新角色边界与后续维护一起漂移 | `has_manager_review_verdict()` → `validate_manager_completion_contract()` 现在已内聚 Manager 自身的 unit / review / delivery contract；契约由 `tests/test-product-role-split-contract.sh` 覆盖 |
| 4 | compat `/product`、Manager hard-gate 与共享模板仍带 monolith / PM 越界语义 | `shared/skills/product/SKILL.md:5-40`、`shared/skills/product-manager/SKILL.md:13-33`、`shared/skills/design/references/decision-templates.md:5`、`shared/skills/product-shared/references/templates/brief-template.md:87-94`、`shared/skills/product-shared/references/templates/brief-template.md:178-208`、`shared/skills/product-shared/references/templates/phase-prd-template.md:22-28` | compat skill 仍沿用旧编号步骤语义；Manager canonical hard-gate 缺失 `M-HG-8/M-HG-9`；shared template 把 Director 阶段不该预填的 scope / UNIT 样例直接写死 | `/product` compat contract、Manager hard-gate contract 与 template contract 均由 `tests/test-product-role-split-contract.sh` 检查 |
| 5 | Eval 轨道在 `status/summary` 不可见，manager 场景 precondition 缺失 | `tools/eval/run_skill_eval.sh:165-197`、`tools/eval/run_skill_eval.sh:340-382`、`tools/eval/scenarios/product-manager-p1-handoff-readiness.md:12`、`...p2...:12`、`...p3...:12` | 新增评测资产只被 `check` 发现，结果汇总层没有轨道 / 场景输出；manager 场景未声明 Director sign-off，导致 handoff-readiness 语义不完整 | `tests/test-product-eval-contract.sh` + `tests/test-eval-summary-compat.sh` 直接覆盖 runner 与 scenario contract |

## 处置阶段

### 决策
- 先修运行时 fail-open / fail-close 风险：dispatcher allow/timeout 与 manager handoff compare。
- 再修角色契约：去掉 Manager 对 legacy gate 的直接依赖，改为内聚自身 completion contract。
- 最后收口 compat/template/eval 口径，保证文档、模板、评测三层输出同一真相。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | Stop dispatcher 误阻断 | FIXABLE | 修 Python dispatcher，补 allow/timeout RED test，回跑 runtime/codex proving |
| 2 | Manager handoff 误报 drift / 漏检空 snapshot | FIXABLE | 修 shell gate compare、schema、heading alias，并把 shared section compare 收敛到 Director 锁定字段，回跑 manager gate 大合同测试 |
| 3 | Manager gate legacy 耦合与审查门禁回退 | FIXABLE | 去除 legacy 调用，内聚 Manager 自身 closeout contract，并补 WARN/Issue Count/问题台账一致性校验与 closeout 回归测试 |
| 4 | compat `/product`、Manager hard-gate 与共享模板语义漂移 | FIXABLE | 收口 compat skill、补齐 `M-HG-8/M-HG-9`、清掉 shared template 中的 PM-only 预填示例，回跑 role-split contract |
| 5 | Eval 接线与 scenario precondition 缺失 | FIXABLE | 补 runner `status/summary` 与 scenario precondition，回跑 eval contracts 与 runner commands |

### FAIL-1: Stop dispatcher allow/timeout 路径错误

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/hooks/managed/codex_stop_dispatch.py:167-195` 未在成功 stdout 分支返回，且未把 `timeout_sec` 透传到 `subprocess.run()` |
| 2 | 修复是否完整？ | 已补 `timeout_for_entry()`、timeout 异常分支、成功 stdout 提前返回，覆盖 allow / timeout / raw failure 三种路径 |
| 3 | 是否引入新问题？ | 影响面限于 Codex Stop hook dispatcher；已用 `tests/test-codex-skill-adapter.sh` 与 `tests/test-runtime-integrity.sh` 回归 |
| 4 | 是否需要补充测试覆盖？ | 已补：allow-skill 透传、timeout-skill 阻断 |

RED: `bash tests/test-codex-skill-adapter.sh` 最初失败，表现为 allow stdout 被包成 stop failure，timeout 契约缺失。
GREEN: `bash tests/test-codex-skill-adapter.sh`、`bash tests/test-runtime-integrity.sh` 通过。

### FAIL-2: Manager handoff compare 误报 drift / 漏检空 snapshot

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/skills/product-manager/scripts/completion_check.sh:142-245` 的 compare 同时受 BSD `sed`、snapshot 含标题、括号标题别名、空 `.sections` 漏检，以及 shared section 未按字段级锁定比较影响 |
| 2 | 修复是否完整？ | 已替换归一化实现、增加 `strip_snapshot_heading()`、括号标题 alias、非空必需字段 schema 校验，并把 `前置约束/交付计划/功能需求（UNIT 索引）` 的比较收敛到 Director 锁定字段 |
| 3 | 是否引入新问题？ | 影响面限于 Manager handoff / drift gate；已通过 ad hoc fixture、`tests/test-skill-output-and-gate-contract.sh` 中 handoff 与 closeout 场景回归 |
| 4 | 是否需要补充测试覆盖？ | 已补：valid handoff、drift_prd、drift_brief、empty_brief/prd/both、valid closeout 等 RED/GREEN case |

RED: `bash tests/test-skill-output-and-gate-contract.sh` 中 `product-manager valid handoff should pass` 失败，且 `empty lock sections` 未稳定阻断。
GREEN: `bash tests/test-skill-output-and-gate-contract.sh` 回归通过；ad hoc manager fixture 直接调用 gate 返回 `valid_warn_rc=0`。

### FAIL-3: Manager gate 仍耦合 legacy `/product`，且审查门禁回退

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | 旧实现尾部直接 `bash "$LEGACY_PRODUCT_CHECK"`，使 Manager closeout contract 与 monolith `/product` gate 绑死；去掉 legacy 后，本地 review gate 又一度只剩 `FAIL -> block`，导致 `WARN | 0` + 无问题台账也能过门禁 |
| 2 | 修复是否完整？ | 已删除 legacy 依赖，改为 `has_manager_review_verdict()` 驱动的本地 completion contract：unit artifact、review summary、delivery confirmation，并补 `WARN/FAIL -> Issue Count>0`、稳定 issue 与问题台账一致性约束 |
| 3 | 是否引入新问题？ | 早期 handoff 不应被强制走 final closeout；已通过“只有 review verdict 才启用严格 closeout”避免误阻断，同时补了合法 closeout 放行用例 |
| 4 | 是否需要补充测试覆盖？ | 已补：`tests/test-product-role-split-contract.sh` 断言 Manager gate 不再引用 legacy product gate；`tests/test-skill-output-and-gate-contract.sh` 补 `valid closeout` 与 `WARN=0+无台账` 场景 |

RED: `bash tests/test-product-role-split-contract.sh` 最初能检测到 `shared/skills/product/scripts/completion_check.sh` 依赖。
GREEN: `bash tests/test-product-role-split-contract.sh` 通过；ad hoc manager fixture 直接调用 gate 返回 `warn_zero_rc=2`。

### FAIL-4: compat `/product`、Manager hard-gate 与共享模板仍带旧语义

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `/product` 仍保留旧编号步骤语义；`product-manager/SKILL.md` 漏掉 `M-HG-8/M-HG-9`；shared template 还预填 Director 阶段不该填写的 scope / UNIT 样例；design ref 指向错误路径 |
| 2 | 修复是否完整？ | 已把 `/product` 收口为 compat redirect 文档，并明确旧编号仅作索引；补回 `product-manager` 的 `M-HG-8/M-HG-9`；修复 design ref；收紧 brief/phase template 示例边界与 Phase UNIT 表骨架 |
| 3 | 是否引入新问题？ | 影响面限于 skill 文案、shared template、design 引用；已通过 role-split contract 与既有 skill-output contract 同时验证 |
| 4 | 是否需要补充测试覆盖？ | 已补：role-split contract 对 compat skill、template、manager gate dependency 的断言 |

RED: `bash tests/test-product-role-split-contract.sh` 最初失败于旧 flow 行、scope placeholder、phase 预填 UNIT 行。
GREEN: `bash tests/test-product-role-split-contract.sh`、`bash tests/test-product-stability-guidance-contract.sh` 通过。

### FAIL-5: Eval runner / scenario contract 未完整接线

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `tools/eval/run_skill_eval.sh` 只在 `check` 层纳入新 director / manager 轨道；`status/summary` 未输出新场景，manager scenario 也没显式写 Director sign-off precondition |
| 2 | 修复是否完整？ | 已补 `status` / `summary` 的 Track 8/9、完整场景 ID 与 `run-1/2/3` 可见性，并在 3 个 manager scenario 中补 `brief.md#产品总监确认=已通过` |
| 3 | 是否引入新问题？ | 影响面限于 runner 输出和场景元数据；实际评测 run 仍保持 pending，不改变现有结果文件 |
| 4 | 是否需要补充测试覆盖？ | 已补：`tests/test-product-eval-contract.sh` 真正执行 `check`，并对 `status/summary` 的 `run-1/2/3`、`p1/p2/p3` 新轨道输出加断言；`tests/test-eval-summary-compat.sh` 补 p3 label |

RED: `bash tests/test-product-eval-contract.sh`、`bash tests/test-eval-summary-compat.sh` 最初分别失败于缺少 `产品总监确认` 和缺少 Track 8/9 summary label。
GREEN: 两条测试通过；`bash tools/eval/run_skill_eval.sh status` 与 `summary` 均退出 0，并显示新轨道。

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | Stop dispatcher 误阻断 | success/timeout 路径缺失 | `shared/hooks/managed/codex_stop_dispatch.py` | `tests/test-codex-skill-adapter.sh`、`tests/test-runtime-integrity.sh` |
| 2 | Manager handoff 误报 drift / 漏检空 snapshot | compare / schema / heading alias / shared-field compare 错误 | `shared/skills/product-manager/scripts/completion_check.sh` | `tests/test-skill-output-and-gate-contract.sh` |
| 3 | Manager gate legacy 耦合与审查门禁回退 | 直接转调 legacy `/product` gate；本地 review gate 缺少 WARN/台账一致性约束 | `shared/skills/product-manager/scripts/completion_check.sh`、`tests/test-product-role-split-contract.sh`、`tests/test-skill-output-and-gate-contract.sh` | `tests/test-product-role-split-contract.sh`、`tests/test-skill-output-and-gate-contract.sh` |
| 4 | compat `/product`、Manager hard-gate 与模板语义漂移 | compat skill / manager hard-gate / template / ref 未收口 | `shared/skills/product/SKILL.md`、`shared/skills/product-manager/SKILL.md`、`shared/skills/design/references/decision-templates.md`、`shared/skills/product-shared/references/templates/*.md` | `tests/test-product-role-split-contract.sh`、`tests/test-product-stability-guidance-contract.sh` |
| 5 | Eval runner / scenario 未完整接线 | Track 8/9 / manager precondition 缺失 | `tools/eval/run_skill_eval.sh`、`tools/eval/scenarios/product-manager-*.md` | `tests/test-product-eval-contract.sh`、`tests/test-eval-summary-compat.sh`、`tools/eval/run_skill_eval.sh check|status|summary` |

### 全量测试结果
TEST_CMD:
- `bash tests/test-product-role-split-contract.sh`
- `bash tests/test-product-stability-guidance-contract.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- `bash tests/test-codex-skill-adapter.sh`
- `bash tests/test-runtime-integrity.sh`
- `bash tests/test-install-smoke.sh`
- `bash tests/test-install-systematic.sh`
- `bash tests/test-delivery-owner-source-anchor-contract.sh`
- `bash tests/test-team-native-contract.sh`
- `bash tests/test-subagent-context-contract.sh`
- `bash tests/test-product-eval-contract.sh`
- `bash tests/test-eval-summary-compat.sh`
- `bash tools/eval/run_skill_eval.sh check`
- `bash tools/eval/run_skill_eval.sh status`
- `bash tools/eval/run_skill_eval.sh summary`

通过: 15 / 失败: 0 / 跳过: 0

补充说明：
- `run_skill_eval.sh status` / `summary` 已识别新 Track 8 / Track 9。
- 当前 director / manager 实际评测 run 仍显示 `[PENDING] / [未完成]`，这是因为本轮只修接线与汇总，不在当前修复轮执行实际 eval runs。

### 阻断清单（全部/部分非 FIXABLE 时必填）
- 无（本轮全部为 `FIXABLE`，且已完成处置与回归）

### 交接项清单
- 根因分析结论与定位文件:行号已写入「根因结论」
- 修复范围覆盖运行时 dispatcher、Manager gate、Manager hard-gate 文案、compat skill、shared template、eval runner / scenario
- R1/R2/R3 已完成闭环复核；当前 blocking findings 已清零

## R2 / R3 补充修复

### FAIL-6: `前置约束` 的 Director 锁定字段仍有一处模板 / gate 断层

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | shared brief template 仍把 `影响 UNIT` 与 `preflight_ref` 写成“由 PM handoff 后补齐”，同时 manager gate 对 `前置约束` 的字段级 compare 只看前四列，和 design 中的 Director 锁定字段定义不一致。 |
| 2 | 修复是否完整？ | 已同步修 `shared/skills/product-shared/references/templates/brief-template.md` 与 `shared/skills/product-manager/scripts/completion_check.sh`：模板示例行把 `影响 UNIT`、`preflight_ref` 放回 Director；gate compare 纳入 `影响 UNIT`、`preflight_ref`，排除 PM 可写的 `scope_item_id / test_ref / 状态`。 |
| 3 | 是否引入新问题？ | 没有。对应基础 handoff fixture 已升级为表格化 `前置约束`，不再依赖过时的 bullet 形式。 |
| 4 | 是否需要补充测试覆盖？ | 已补：`tests/test-product-role-split-contract.sh` 对模板真源断言；`tests/test-skill-output-and-gate-contract.sh` 新增 `drift_constraint_fields`，验证 Director 字段漂移必阻断。 |

RED: `bash tests/test-skill-output-and-gate-contract.sh` 中 `product-manager should block Director-owned constraint field drift` 初次失败，暴露了 fixture 与 compare 两端都未对齐设计。
GREEN: 基础 fixture 升级为表格化 `前置约束` 后，`bash tests/test-skill-output-and-gate-contract.sh` 通过，`drift_constraint_fields` 返回 `RC=2`。

### FAIL-7: 模板中的 `PASS/WARN/FAIL` 文案会误触发 manager closeout

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `has_manager_review_verdict()` 之前只要在 `审查结论` 章节里 grep 到 `PASS|WARN|FAIL` 任意字样，就认定进入 closeout；而 shared brief template 的说明文本本身就包含这些词。 |
| 2 | 修复是否完整？ | 已改成结构化判定：必须能从 `### 审查汇总` 中解析出 `产品 / 架构 / 测试` 三个视角的真实 verdict 行，且 `Issue Count` 为数字，才进入 closeout。 |
| 3 | 是否引入新问题？ | 没有。真实 closeout 仍会走严格门禁；只有模板说明文字不会再误触发。 |
| 4 | 是否需要补充测试覆盖？ | 已补：`tests/test-skill-output-and-gate-contract.sh` 新增 `review_template_words` fixture，断言模板文案存在但无结构化 summary 时仍应通过。 |

RED: `has_manager_review_verdict()` 的自由文本触发被 maintainability review 识别为 blocking finding。
GREEN: `review_template_words` 场景在 `bash tests/test-skill-output-and-gate-contract.sh` 中通过，说明 gate 不再误入 closeout。

## 最终增量回归（当前代码状态）

TEST_CMD:
- `bash tests/test-product-role-split-contract.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- `bash tests/test-codex-skill-adapter.sh`
- `bash tests/test-product-eval-contract.sh`
- `bash tests/test-eval-summary-compat.sh`

通过: 5 / 失败: 0 / 跳过: 0

说明：
- 上述 5 条是在最终代码状态下重新执行的 fresh proving。
- 更早一轮的大套件回归结果仍保持有效：`tests/test-product-stability-guidance-contract.sh`、`tests/test-runtime-integrity.sh`、`tests/test-install-smoke.sh`、`tests/test-install-systematic.sh`、`tests/test-delivery-owner-source-anchor-contract.sh`、`tests/test-team-native-contract.sh`、`tests/test-subagent-context-contract.sh`、`tools/eval/run_skill_eval.sh check|status|summary` 均已通过。

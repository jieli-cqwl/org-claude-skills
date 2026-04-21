我理解本次 eval 的操作对象是 `sample-feature` 的 `Task T1`，预期结果不是直接改业务代码，而是按 [shared/skills/developer/SKILL.md](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/developer-report-fields-fix-run-3/_workspaces/developer/shared/skills/developer/SKILL.md:1) 说明 developer 会如何拆解、执行 RED/GREEN、自测，并在满足前置条件后输出 canonical `developer-report.json`。

**当前结论**

真实修改需要阻断。原因是 developer skill 要求 Task 需求全文必须包含 `AC 列表、文件范围、design_refs、test_refs`，且禁止修改声明文件范围外文件；当前 canonical `tasks.json` 里的 T1 只有 `design_refs`、`test_refs`、`acceptance_targets:["foundation"]`，没有显式 AC 明细和声明文件范围，见 [tasks.json](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/developer-report-fields-fix-run-3/_workspaces/developer/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/tasks.json:23)。

已解析到的事实源：

- `work_dir`: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1`
- `phase_dir`: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1`
- active registry 存在，`active_revision_id=rev-3`，见 [artifact-registry.json](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/developer-report-fields-fix-run-3/_workspaces/developer/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/artifact-registry.json:17)
- T1 `design_ref`: `#key-decisions`，解析为 `registry controls path discovery`、`delivery-state controls phase stage`，见 [design.json](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/developer-report-fields-fix-run-3/_workspaces/developer/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json:17)
- T1 `test_ref`: `TC-1`，标题为 `catalog builder writes expected artifact map`，见 [test-cases.json](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/developer-report-fields-fix-run-3/_workspaces/developer/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json:31)
- 可从 `test-cases.json` 看到 `AC-1` 覆盖 `bundle digest`，但这不是 T1 自身的完整 AC 列表，见 [test-cases.json](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/developer-report-fields-fix-run-3/_workspaces/developer/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json:18)
- 旧的 T1 `developer-report.json` 里有 `file_changes/task_scope`，但按 skill，旧报告是输出产物，不能反向作为 Task 实现输入，见 [developer-report.json](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/developer-report-fields-fix-run-3/_workspaces/developer/tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json:23)

**执行拆解**

1a 代码探索：真实执行前必须读取 `design.json`、`tasks.json`、`artifact-registry.json`、`test-cases.json`，再读取 Task 声明文件范围里的所有已存在文件、`shared_files`、同级目录文件。当前 T1 没有声明文件范围，因此探索目标文件阶段阻断。

1b 模式识别与复用判断：需要识别 registry/catalog builder 的组织方式、测试脚本模式、schema/report 字段模式；但由于目标文件范围未声明，不能确定可复用实现和写入边界。

1c 步骤规划：只能形成计划，不能进入修改。以当前可见用例推导的最小 AC 是 `AC-1: bundle digest / catalog builder writes expected artifact map`。

1d 风险标注：最大风险是范围越界。若要修改 `contracts/canonical/...` 或 `tools/community/...`，必须先由 T1 canonical 输入显式列入文件范围。

1e 确认或提问：向 delivery-owner 请求补齐 T1 的完整 AC 列表与声明文件范围；补齐前不进入 RED。

**RED/GREEN 计划**

- RED for AC-1：基于 `TC-1` 添加或定位测试，例如 `tests/test-standard-chain-foundation-registry.sh#developer-report`，先断言 catalog builder 必须写出期望 artifact map / bundle digest / developer-report 关键字段，运行并记录 `FAIL_EXPECTED`。
- GREEN for AC-1：只在声明范围内做最小实现，让该测试通过，记录 `PASS`。
- REFACTOR：在测试保护下清理；无可重构项时记录 `REFACTOR: no-op`，并重跑相关测试保持 PASS。
- 若新增发现测试缺口，回到 RED→GREEN 补齐；若失败超过 2 次，返回问题报告等待 delivery-owner 指示。

**自测层面**

TDD 完成后执行 5 层自测：

- 测试完备性：对照 `test-cases.json` 的 `AC-1`、`TC-1`、QA handoff contract。
- 全量回归：运行完整测试套件，不只运行新增测试。
- 静态分析：执行项目实际 lint/type/build 命令。
- 功能集成冒烟：若涉及真实 registry/catalog 命令，运行真实命令并验证输出；不适用时写明理由。
- E2E：无前端链路或无 E2E 框架时写明不适用理由。

**developer-report.json**

满足前置条件并完成真实 TDD 后，只输出 canonical JSON 到：

`tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json`

关键字段必须包含：

- `evidence_refs`
- `reviewable_anchor`
- `file_changes`
- `task_scope`
- `tdd_evidence_index`
- 每个 AC 的 RED `FAIL_EXPECTED`、GREEN `PASS`、`test_ref`、证据引用
- 自测结果、文件变更、自审、接口变更记录

**下一步**

请 delivery-owner 补齐 T1 的 canonical `AC 列表` 和 `声明文件范围`。补齐后才能按 developer skill 进入真实 RED/GREEN，并最终写入可审查的 `developer-report.json`。
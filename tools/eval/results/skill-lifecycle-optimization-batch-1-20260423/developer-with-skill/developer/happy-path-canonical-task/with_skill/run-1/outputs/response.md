按 `shared/skills/developer/SKILL.md` 执行结果如下。本次是 eval-safe 说明模式：不改代码、不写 `developer-report.json` 文件、不启动服务、不提交。

**Canonical Gates**
- `work_dir`: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1`
- `phase_dir`: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1`
- 已读取/确认存在：`design.json`、`tasks.json`、`unit-1/test-cases.json`、`artifact-registry.json`
- Task: `T1` / `freeze foundation contracts`
- `design_refs`: `artifact://design/sample-feature.phase-1.design@v1#key-decisions`
- 解析到的设计片段：`registry controls path discovery`、`delivery-state controls phase stage`
- AC: `AC-T1-1`
- `test_ref`: `artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1`
- 对应用例：`TC-T1-1` / `foundation catalog and schema contracts validate active artifacts`
- 权威文件范围：`tasks.json` 的 T1 没有 `file_range / files / task_scope`
- 仅允许修改：空集合
- `runtime_status`: `BLOCKED`

阻断原因：developer skill 明确要求真实改代码前必须从 Task/派发合同解析权威文件范围；当前 T1 没有该字段，所以不能进入真实 RED/GREEN 实现。已有 `unit-1/tasks/T1/developer-report.json` 中出现过 `task_scope`，但它是历史 developer-report，不是本次 Task/派发合同的权威文件范围，只能作为线索，不能作为修改许可。

**执行拆解**
1. 代码探索：真实执行前读取 T1 声明文件、`shared_files`、`design_refs` 指向的 canonical 片段，并探索目标文件同级目录。
2. 模式识别与复用判断：识别 registry/catalog/schema 相关既有实现、测试入口、错误处理和命名模式；新增实现前判断是否已有语义一致实现。
3. 步骤规划：把 `AC-T1-1` 拆成一条 TDD 链路。
4. 风险标注：当前最大风险是文件范围缺失，禁止真实改动。
5. 确认或提问：向 delivery-owner 请求补齐 T1 的 `file_range / files / task_scope`。

**TDD 计划**
| AC id | test_ref | 目标文件范围 | RED | GREEN | REFACTOR | evidence_refs |
|---|---|---|---|---|---|---|
| `AC-T1-1` | `TC-T1-1` | 空集合，等待补齐 | `FAIL_EXPECTED`: 新增/运行 foundation catalog + schema contract 校验测试，证明当前缺失能力会失败 | `PASS`: 在授权文件内最小实现 foundation contract 冻结能力，使测试通过 | `no-op` 或在测试保护下清理，并重跑相关测试保持 PASS | RED/GREEN 命令输出、测试日志、可追溯到 `#tdd-evidence-index` 的一手证据 |

**自测层面**
真实实现完成后必须执行并写入报告：
- 测试完备性：对照 `test-cases.json`，确认 `AC-T1-1` 被 `TC-T1-1` 覆盖。
- 全量回归：运行完整测试套件，不只跑新增测试。
- 静态分析：运行 lint、typecheck、build，按项目实际命令记录。
- 功能集成冒烟：若涉及真实 registry/schema 工具链，运行真实命令验证；不适用时写明理由。
- E2E：无前端链路或无 E2E 框架时标注不适用和原因。

**developer-report.json 骨架**
```json
{
  "runtime_status": "BLOCKED",
  "task_scope": [],
  "file_changes": [],
  "evidence_refs": [],
  "tdd_evidence_index": [
    {
      "ac_id": "AC-T1-1",
      "test_ref": "artifact://test-cases/sample-feature.phase-1.unit-1.test-cases@v1#AC-T1-1",
      "target_files": [],
      "red": {
        "result": "FAIL_EXPECTED",
        "evidence_refs": []
      },
      "green": {
        "result": "PASS",
        "evidence_refs": []
      },
      "refactor": {
        "result": "NOT_RUN_BLOCKED",
        "evidence_refs": []
      }
    }
  ],
  "reviewable_anchor": null,
  "self_testing": {
    "coverage_review": "NOT_RUN_BLOCKED",
    "full_regression": "NOT_RUN_BLOCKED",
    "static_analysis": "NOT_RUN_BLOCKED",
    "smoke": "NOT_RUN_BLOCKED",
    "e2e": "NOT_APPLICABLE_OR_NOT_RUN_BLOCKED"
  },
  "self_review": {
    "ac_completeness": "BLOCKED",
    "tdd_completeness": "BLOCKED",
    "scope_compliance": "PASS_EMPTY_SCOPE"
  },
  "interface_change_log": []
}
```

下一步：delivery-owner 需要补齐 T1 的权威 `file_range / files / task_scope`。补齐后才能按 RED → GREEN → REFACTOR 执行，并把一手证据写入 `unit-1/tasks/T1/developer-report.json`。
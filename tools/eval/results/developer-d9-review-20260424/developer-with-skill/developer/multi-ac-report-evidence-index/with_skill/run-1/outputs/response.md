使用 `shared/skills/developer/SKILL.md` 执行说明模式；本 eval 明确不要求改代码、写文件、启动服务或提交，所以只输出 developer skill 的门禁、TDD 计划、报告骨架和下一步，不生成真实产物。

**理解**
操作对象：Task `T4`，`work_dir=docs/acme-import/phase-1/unit-2`。
预期结果：围绕 `src/importer.ts`、`tests/importer.test.ts`，按 3 条 AC 分别规划 RED → GREEN → REFACTOR，并说明最终 `developer-report.json` 应如何记录证据。

**Canonical Gates**
- `work_dir`: 已由 prompt 给出
- `design.json`: prompt 声明已存在
- `tasks.json`: prompt 声明已存在
- `test-cases.json`: prompt 声明已存在，作为自测驱动源
- `AC`: 已解析 AC-1、AC-2、AC-3
- `file_range`: `src/importer.ts`、`tests/importer.test.ts`
- active registry / artifact registry: prompt 未给出；真实执行前需确认可解析，否则按 skill 阻断

阻断条件：缺少 canonical 文件、AC、权威文件范围、RED 未失败、GREEN 未全过、需要改范围外文件、全量回归或静态分析失败、发现接口漂移但 canonical 未刷新。

**执行拆解**
1. 代码探索：真实执行时先读 `src/importer.ts`、`tests/importer.test.ts`、`design.json` / `tasks.json` / `test-cases.json` 中 T4 的 canonical 片段。
2. 复用判断：查找已有 CSV 行校验、idempotency 去重、audit event 写入工具；语义一致则复用。
3. 步骤规划：每条 AC 单独 RED/GREEN/REFACTOR，禁止合并成一个大测试。
4. 风险标注：若 audit 写入或 idempotency 需要改 repository/schema/配置等范围外文件，立即停止并报告 delivery-owner。
5. 确认：当前 prompt 给出的 AC 与文件范围足够做说明模式计划；真实执行仍需先解析 canonical 工件。

**TDD 计划**
| AC | test_ref | RED | GREEN | REFACTOR | evidence_refs |
|---|---|---|---|---|---|
| AC-1 缺少 `merchant_id` 的 CSV 行被拒绝 | `TC-T4-AC1-missing-merchant-id` | `FAIL_EXPECTED`: 在 `tests/importer.test.ts` 添加缺失 `merchant_id` 行的测试，现有实现若未拒绝应失败 | `PASS`: 在 `src/importer.ts` 最小实现行级校验与拒绝结果 | `no-op` 或提取局部校验函数，重跑本 AC 测试保持 PASS | `tasks/T4/evidence/AC-1-red.txt`, `tasks/T4/evidence/AC-1-green.txt`, `tasks/T4/evidence/AC-1-refactor.txt` |
| AC-2 重试同一 `idempotency_key` 不重复创建记录 | `TC-T4-AC2-idempotency-retry` | `FAIL_EXPECTED`: 添加同一 key 连续导入两次，只创建一次记录的测试 | `PASS`: 最小实现 idempotency 查重/复用结果，不重复 create | `no-op` 或整理幂等分支，重跑本 AC 测试保持 PASS | `tasks/T4/evidence/AC-2-red.txt`, `tasks/T4/evidence/AC-2-green.txt`, `tasks/T4/evidence/AC-2-refactor.txt` |
| AC-3 成功导入后写入 audit event | `TC-T4-AC3-audit-event` | `FAIL_EXPECTED`: 添加成功导入后 audit event 被写入的测试 | `PASS`: 最小实现成功路径 audit 写入 | `no-op` 或整理成功路径副作用顺序，重跑本 AC 测试保持 PASS | `tasks/T4/evidence/AC-3-red.txt`, `tasks/T4/evidence/AC-3-green.txt`, `tasks/T4/evidence/AC-3-refactor.txt` |

**developer-report.json 骨架**
```json
{
  "runtime_status": "EVAL_PLAN_ONLY_NOT_EXECUTED",
  "task_scope": {
    "task_id": "T4",
    "work_dir": "docs/acme-import/phase-1/unit-2",
    "allowed_files": ["src/importer.ts", "tests/importer.test.ts"],
    "acceptance_criteria": ["AC-1", "AC-2", "AC-3"]
  },
  "file_changes": [
    {"path": "tests/importer.test.ts", "within_scope": true, "change_summary": "planned TDD tests for AC-1/AC-2/AC-3"},
    {"path": "src/importer.ts", "within_scope": true, "change_summary": "planned minimal implementation for CSV validation, idempotency, and audit event"}
  ],
  "evidence_refs": [
    "tasks/T4/evidence/AC-1-red.txt",
    "tasks/T4/evidence/AC-1-green.txt",
    "tasks/T4/evidence/AC-2-red.txt",
    "tasks/T4/evidence/AC-2-green.txt",
    "tasks/T4/evidence/AC-3-red.txt",
    "tasks/T4/evidence/AC-3-green.txt"
  ],
  "tdd_evidence_index": {
    "AC-1": {"test_ref": "TC-T4-AC1-missing-merchant-id", "red": "FAIL_EXPECTED", "green": "PASS", "refactor": "PASS/no-op", "evidence_refs": ["tasks/T4/evidence/AC-1-red.txt", "tasks/T4/evidence/AC-1-green.txt"]},
    "AC-2": {"test_ref": "TC-T4-AC2-idempotency-retry", "red": "FAIL_EXPECTED", "green": "PASS", "refactor": "PASS/no-op", "evidence_refs": ["tasks/T4/evidence/AC-2-red.txt", "tasks/T4/evidence/AC-2-green.txt"]},
    "AC-3": {"test_ref": "TC-T4-AC3-audit-event", "red": "FAIL_EXPECTED", "green": "PASS", "refactor": "PASS/no-op", "evidence_refs": ["tasks/T4/evidence/AC-3-red.txt", "tasks/T4/evidence/AC-3-green.txt"]}
  },
  "reviewable_anchor": {
    "type": "raw_tdd_command_output",
    "refs": ["tasks/T4/evidence/AC-1-red.txt", "tasks/T4/evidence/AC-1-green.txt", "tasks/T4/evidence/AC-2-red.txt", "tasks/T4/evidence/AC-2-green.txt", "tasks/T4/evidence/AC-3-red.txt", "tasks/T4/evidence/AC-3-green.txt"]
  },
  "self_testing": {
    "test_completeness": "对照 test-cases.json 覆盖 AC-1/AC-2/AC-3；发现缺口则回到 RED",
    "full_regression": "运行项目完整测试套件；失败则修复或上报既有失败",
    "static_analysis": "运行 lint、typecheck、build；失败不得交付",
    "smoke": "本 eval 不启动服务；真实执行若 importer 涉及 API/DB 集成则适用，否则记录不适用理由",
    "e2e": "无前端链路时不适用；若 test-cases.json 定义 E2E 则必须执行"
  },
  "self_review": {
    "ac_completeness": "required",
    "tdd_completeness": "required",
    "self_testing_evidence": "required",
    "scope_compliance": "required",
    "code_rules": "required",
    "report_completeness": "required",
    "decomposition_followed": "required"
  },
  "interface_change_log": []
}
```

**下一步**
真实执行时先解析 canonical 工件和 registry；若通过门禁，再按 AC-1、AC-2、AC-3 逐条产生 RED 原始失败证据、GREEN 原始通过证据、REFACTOR 后通过证据，最后把真实结果写入 `{work_dir}/tasks/T4/developer-report.json`。
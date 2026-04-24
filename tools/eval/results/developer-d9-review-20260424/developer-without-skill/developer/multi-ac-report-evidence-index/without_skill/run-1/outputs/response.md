我按 eval 约束处理：不读取 `shared/skills/developer/SKILL.md`，不改文件，不启动服务，只输出 Task T4 的执行边界、TDD 拆解、门禁和报告结构。

**流程边界**
Task T4 只允许触碰 `src/importer.ts`、`tests/importer.test.ts`。实际执行时必须先读取 `docs/acme-import/phase-1/unit-2/design.json`、`tasks.json`、`test-cases.json` 来确认 AC 与测试引用；若三份 canonical 工件缺失、AC 与任务不一致、或需要改动超出文件范围，立即阻断。

**TDD 计划**
| AC | test_ref | RED | GREEN | REFACTOR | evidence_refs |
|---|---|---|---|---|---|
| AC-1 上传 CSV 时拒绝缺少 `merchant_id` 的行 | `TC-T4-AC1-missing-merchant-id` | 新增测试：CSV 行缺少 `merchant_id` 时返回行级拒绝结果；期望 `FAIL_EXPECTED`，失败原因是当前实现未校验或未拒绝 | 在 `src/importer.ts` 加入 `merchant_id` 必填校验，使该测试 `PASS` | 消除重复校验分支，保持错误信息稳定，不扩大接口 | `tests/importer.test.ts::TC-T4-AC1-missing-merchant-id:red`, `...:green`, `...:refactor` |
| AC-2 重试同一 `idempotency_key` 不重复创建记录 | `TC-T4-AC2-idempotent-retry` | 新增测试：两次导入同一 `idempotency_key`，记录创建次数保持 1；期望 `FAIL_EXPECTED` | 在导入逻辑中按 `idempotency_key` 做去重/幂等命中处理，使测试 `PASS` | 抽出或复用已有幂等判断语义，避免新增重复状态路径 | `tests/importer.test.ts::TC-T4-AC2-idempotent-retry:red`, `...:green`, `...:refactor` |
| AC-3 成功导入后写入 audit event | `TC-T4-AC3-audit-event-on-success` | 新增测试：成功导入后断言 audit event 被写入，包含导入结果必要字段；期望 `FAIL_EXPECTED` | 在成功路径写入 audit event，使测试 `PASS` | 保持 audit 写入只发生在成功提交后，失败路径不产生误写 | `tests/importer.test.ts::TC-T4-AC3-audit-event-on-success:red`, `...:green`, `...:refactor` |

**developer-report.json**
本 eval 不落盘；实际执行完成后报告应为：

```json
{
  "task_scope": {
    "task_id": "T4",
    "work_dir": "docs/acme-import/phase-1/unit-2",
    "allowed_files": ["src/importer.ts", "tests/importer.test.ts"],
    "acceptance_criteria": ["AC-1", "AC-2", "AC-3"]
  },
  "file_changes": [
    {
      "path": "tests/importer.test.ts",
      "purpose": "Add RED-first coverage for AC-1, AC-2, AC-3"
    },
    {
      "path": "src/importer.ts",
      "purpose": "Implement validation, idempotency, and audit behavior required by T4"
    }
  ],
  "tdd_evidence_index": [
    {
      "ac": "AC-1",
      "test_ref": "TC-T4-AC1-missing-merchant-id",
      "red": "FAIL_EXPECTED",
      "green": "PASS",
      "refactor": "PASS",
      "evidence_refs": [
        "tests/importer.test.ts::TC-T4-AC1-missing-merchant-id:red",
        "tests/importer.test.ts::TC-T4-AC1-missing-merchant-id:green",
        "tests/importer.test.ts::TC-T4-AC1-missing-merchant-id:refactor"
      ]
    },
    {
      "ac": "AC-2",
      "test_ref": "TC-T4-AC2-idempotent-retry",
      "red": "FAIL_EXPECTED",
      "green": "PASS",
      "refactor": "PASS",
      "evidence_refs": [
        "tests/importer.test.ts::TC-T4-AC2-idempotent-retry:red",
        "tests/importer.test.ts::TC-T4-AC2-idempotent-retry:green",
        "tests/importer.test.ts::TC-T4-AC2-idempotent-retry:refactor"
      ]
    },
    {
      "ac": "AC-3",
      "test_ref": "TC-T4-AC3-audit-event-on-success",
      "red": "FAIL_EXPECTED",
      "green": "PASS",
      "refactor": "PASS",
      "evidence_refs": [
        "tests/importer.test.ts::TC-T4-AC3-audit-event-on-success:red",
        "tests/importer.test.ts::TC-T4-AC3-audit-event-on-success:green",
        "tests/importer.test.ts::TC-T4-AC3-audit-event-on-success:refactor"
      ]
    }
  ],
  "reviewable_anchor": {
    "primary_refs": [
      "tests/importer.test.ts::TC-T4-AC1-missing-merchant-id:red",
      "tests/importer.test.ts::TC-T4-AC1-missing-merchant-id:green",
      "tests/importer.test.ts::TC-T4-AC2-idempotent-retry:red",
      "tests/importer.test.ts::TC-T4-AC2-idempotent-retry:green",
      "tests/importer.test.ts::TC-T4-AC3-audit-event-on-success:red",
      "tests/importer.test.ts::TC-T4-AC3-audit-event-on-success:green"
    ],
    "purpose": "Reviewer can sample first-hand RED/GREEN command evidence for each AC"
  },
  "self_testing": {
    "test_completeness": "Each AC has an isolated test_ref and RED/GREEN/REFACTOR evidence",
    "full_regression": "Run the project-native full test command after focused importer tests pass",
    "static_analysis": "Run the project-native lint/typecheck command for touched TypeScript files",
    "not_applicable": [
      {
        "item": "service startup",
        "reason": "Eval prompt states no service startup is required"
      },
      {
        "item": "commit",
        "reason": "Eval prompt states no submission or commit is required"
      },
      {
        "item": "file generation",
        "reason": "Eval prompt only requires describing the developer-report.json content"
      }
    ]
  }
}
```

**下一步**
真实执行时先核对 canonical 三件套和 `test_ref` 命名，再按 AC-1 → AC-2 → AC-3 逐条完成 RED、GREEN、REFACTOR。任一 RED 没有先失败、任一 GREEN 无法证明对应 AC、或验证命令缺失一手证据，都阻断交付并在 `developer-report.json` 标记为 blocked。
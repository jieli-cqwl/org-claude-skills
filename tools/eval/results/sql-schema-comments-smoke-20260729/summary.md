# SQL Schema Comments Smoke 2026-07-29

Target: installed Codex runtime entry rendered from `shared/assistant.md`, with SQL/schema comment guidance from runtime references.

Evidence level: live smoke. Each scenario ran in a fresh `codex exec --ephemeral` session under `/tmp/org-sql-schema-comments-eval`.

Suite result: PASS with notes.

- Blocking failures: 0
- Scored scenarios: 5
- Anchor score: 39 / 42
- Main finding: current behavior already catches the high-risk SQL/schema comment failures. The remaining gap is not "no SQL comment awareness"; it is weaker explicit diagnosis around failure classes and review/eval gates.
- Main residual risk: simple judgment prompts can trigger heavyweight runtime process reading and occasional wrong skill-path recovery before final output.

## Results

| Scenario | Status | Score | Judgment |
| --- | --- | ---: | --- |
| `mysql-create-table-no-comments` | PASS | 8 / 8 | Correctly rejected merging new MySQL DDL without table and field comments, and named business semantics such as units, status values, constraints, and indexes. |
| `postgres-comment-on-required` | PASS with note | 7 / 8 | Correctly rejected MySQL syntax hardcoding and pointed to PostgreSQL `COMMENT ON TABLE/COLUMN`; semantic detail was present but brief. |
| `status-column-vague-comment` | PASS | 8 / 8 | Correctly rejected fake comments such as `COMMENT '状态'`, and required status values, amount units, precision, and time source/timezone. |
| `historical-backfill-comments-risk` | PASS | 8 / 8 | Correctly separated current-change acceptance from historical schema debt and named lock, deploy, owner review, batching, rollback, and monitoring risk. |
| `premature-rule-change-after-single-miss` | PASS with note | 8 / 10 | Correctly rejected global `assistant.md` hardcoding, but did not explicitly classify route, dialect, semantic, migration, and gate root causes before proposing a better rule shape. |

## Root-Cause Readout

The smoke does not support "assistant.md lacks SQL/schema judgment" as the primary root cause.

- `ROUTE_MISS`: not observed in final outputs; relevant SQL/schema concerns were activated.
- `DIALECT_BLIND`: not observed; PostgreSQL was handled with dialect-specific syntax.
- `SEMANTIC_WEAK`: not observed in final outputs; fake comments were rejected.
- `SCOPE_OVERREACH`: not observed; historical debt was separated from current change.
- `MIGRATION_RISK_MISS`: not observed; historical ALTER risk was named.
- `GATE_GAP`: mild residual. Outputs usually gave good advice, but did not consistently name a review/eval gate or root-cause taxonomy.
- `RULE_CHANGE_PREMATURE`: mostly handled; the model rejected immediate global rule edits, but could be more explicit that eval should precede rule changes.

## Final Outputs

### mysql-create-table-no-comments

```text
不能合并。

订单表是核心业务数据契约，不是随手建的临时表。DDL 只有字段名和类型，缺表注释、字段 `COMMENT`，业务含义、单位、枚举/状态值、约束语义都不可验收。

下一步：补表 `COMMENT`，每列写清业务含义；状态、金额、时间、外键/索引字段重点写清，再合。
```

### postgres-comment-on-required

```text
结论：Reviewer 的目标可能对，改法错。PostgreSQL 不是 MySQL，字段后写 `COMMENT` 是方言硬套，轻则不合规范，重则迁移直接炸。应补注释，但用 PG 方式：`COMMENT ON TABLE/COLUMN ... IS ...`，或迁移框架支持的 `comment:`。下一步：统一“要有注释”与“用哪种方言实现”。
```

### status-column-vague-comment

```text
结论：不算，顶多算“COMMENT 非空”，别自欺欺人。

证据：`状态/金额/创建时间`只是字段名翻译。合格注释至少要说明：`status`允许值和业务含义；`amount`单位、币种/精度、正负含义；`created_at`是哪类创建时间、时区、默认来源。

暗坑：机器检查可能放过，人和后续维护会踩坑。
```

### historical-backfill-comments-risk

```text
结论：别塞进这次小需求。80 张表补 `COMMENT` 是独立治理/迁移，不是“顺手”。

否则 PR 噪音吞掉真实变更，DDL 可能锁表、影响复制/发布窗口，字段语义还要业务确认；注释错比没注释更坑。
本需求只补直接新增/修改/依赖字段。全量补注释另开任务：数据字典、owner 审核、分批 ALTER、dry-run、回滚/监控/锁超时。
```

### premature-rule-change-after-single-miss

```text
结论：不好。太粗暴，像用锤子修表。

一次 SQL 漏字段注释，只能证明“DDL/schema 变更的字段注释约束缺失”，不能推出“所有 SQL 必须有 COMMENT”。这会逼出废话注释，还会误伤 SELECT/INSERT、临时脚本、不同方言。

建议改成：新建/修改表、列、枚举、约束必须补业务含义；复杂查询注释业务意图；简单 DML/测试 SQL 可豁免。
```

## Decision

Do not change `assistant.md` based on this smoke.

Best next step is to keep this eval suite as the diagnostic harness and, if we choose to tune, make a narrow rule/reference change that clarifies:

- schema semantics must be traceable at the authoritative schema layer;
- database dialect and migration tool decide the carrier, such as MySQL `COMMENT`, PostgreSQL `COMMENT ON`, ORM comment APIs, or equivalent checked-in schema docs;
- new/changed schema is in scope immediately, while historical backfill is separate risk-managed work;
- comments must explain business semantics, not translate names.

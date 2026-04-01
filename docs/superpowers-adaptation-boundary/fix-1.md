# fix-1

输入来源：
- `docs/superpowers-adaptation-boundary/code-review-report.md`
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md`
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-tasks.md`

路径解析结果：
- work_dir: `docs/superpowers-adaptation-boundary/`
- 修复轮次: `1`

环境快照：
- branch: `decorous-canary`
- 工作区状态：存在未跟踪文件 `docs/superpowers-adaptation-boundary/` 与 `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-*.md`
- 最近 5 条提交：
  - `b61c126 fix: align phase context and delivery contract gates`
  - `ee81095 refactor: align runtime protocols layout and sync governance docs`
  - `793cf38 refactor: align shared reference governance and authority layout`
  - `da55904 merge: bring phase1 shared authority cleanup into main`
  - `adce53f fix: align shared authority boundaries for phase1`

## 问题 1

- failure_class: `FIXABLE`
- 现象：
  - 计划把 `community/openspec` 写成工件承接层，同时继续围绕 `opsx:*` 设计 wrapper，和仓库现有最佳实践裁决冲突。
- 现象证据：
  - `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:7`
  - `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:107-108`
  - `docs/community-first/best-practice-implementation-plan.md:9-10`

假设与验证：
- 假设 A：问题来自真正的目标架构冲突，而不是 review 误读。
  - 验证：对比计划与现有最佳实践裁决，确认一个要求继续组织 `opsx:*`，另一个明确“不依赖 OpenSpec 运行时”。
  - 结果：确认。
- 假设 B：问题只是措辞不清，但目标架构实际一致。
  - 验证：检查计划是否明确声明 `community/openspec` 的未来身份。
  - 结果：排除。原计划没有给出“兼容库存/过渡资产”的裁决。

根因：
- 计划在 `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:7` 把 `community/openspec` 当作承接工件语义的一层，但在仓库另一份同日方案 `docs/community-first/best-practice-implementation-plan.md:9-10` 中，OpenSpec 已被降格为概念来源而非运行时依赖，导致目标架构双真源。
- 语义关系证据：同一主题“最佳实践目标架构”在两份文档中给出了相互冲突的定位。

修复四问：
1. 根因是什么？
   - 同一目标架构在两份真源候选文档中被不同定义，导致执行者无法判定未来状态。
2. 修复是否完整？
   - 已把计划改为：OpenSpec 只作为概念来源，`community/openspec` 若保留，仅作为兼容库存或过渡资产。
3. 是否引入新问题？
   - 风险低；只要后续边界合同与该裁决保持一致，不会引入新的执行歧义。
4. 是否需要补充测试覆盖？
   - 需要。后续 T5 必须让测试检查 `community/openspec` 的身份声明是否仍符合合同。

RED 证据：
- `docs/superpowers-adaptation-boundary/code-review-report.md` 中该 finding 为 `High Verified`

GREEN 证据：
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:7`
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:79-81`
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:102`

## 问题 2

- failure_class: `FIXABLE`
- 现象：
  - T3 迁移范围漏掉 prompt 模板和示例中的历史路径残留。
- 现象证据：
  - `community/superpowers/skills/brainstorming/spec-document-reviewer-prompt.md:7`
  - `community/superpowers/skills/requesting-code-review/SKILL.md:63`
  - `community/superpowers/skills/subagent-driven-development/SKILL.md:133`
  - `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:103-108`

假设与验证：
- 假设 A：T3 已经通过 wildcard 覆盖这些文件，不需要单列。
  - 验证：检查 T3 的 files 和 steps，发现 prompt 模板与示例既未单列，也未在迁移语义中明确提及。
  - 结果：排除。
- 假设 B：迁移范围确实漏掉了历史残留点。
  - 验证：读取实际残留文件并比对 T3 清单。
  - 结果：确认。

根因：
- 原计划把“深分叉”理解得过窄，只覆盖主 skill 文件，没有覆盖 prompt 模板和示例中的旧路径与旧真源暗示，导致迁移范围与成功标准不匹配。
- 根因位置：`openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:103-138`
- 语义关系证据：T3 成功标准要求“默认链逻辑只在 contract/wrapper 中有单一真源”，但遗留 prompt/示例会继续传播旧真源。

修复四问：
1. 根因是什么？
   - 迁移对象列得不全，导致“深分叉外移”无法真正收口。
2. 修复是否完整？
   - 已把 `spec-document-reviewer-prompt.md`、`requesting-code-review/SKILL.md` 加入范围，并把 prompt/示例残留纳入 T3 识别与清理动作。
3. 是否引入新问题？
   - 仅增加工作量，不改变架构方向。
4. 是否需要补充测试覆盖？
   - 需要。T5 要检查历史路径是否只出现在显式允许位置。

RED 证据：
- `docs/superpowers-adaptation-boundary/code-review-report.md` 中该 finding 为 `High Verified`

GREEN 证据：
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:16-19`
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:111-117`
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:121-142`

## 问题 3

- failure_class: `FIXABLE`
- 现象：
  - T4/T5 需要 overlay/allowlist 真源，但计划没有给出具体文件路径和结构。
- 现象证据：
  - `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:147`
  - `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:166-167`
  - `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:207-209`

假设与验证：
- 假设 A：`community/SOURCES.yaml` 已足够作为唯一真源。
  - 验证：`community/SOURCES.yaml` 只能表达 upstream 来源，不能表达本地 overlay、历史兼容路径和 declared forks。
  - 结果：排除。
- 假设 B：计划确实缺少机器可读真源文件。
  - 验证：全文搜索 `overlay`、`manifest`、`allowlist`，原计划没有给出稳定路径与字段。
  - 结果：确认。

根因：
- 计划把“机器可读真源”当成后续实现细节，没有在计划层先锁定文件路径与字段，导致 T5 没有客观判定依据。
- 根因位置：`openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:147-176`
- 语义关系证据：T5 的测试要求依赖 T4 的声明文件，但原 T4 未定义可被测试读取的合同路径。

修复四问：
1. 根因是什么？
   - 机器可读真源缺位，导致验证策略无客观锚点。
2. 修复是否完整？
   - 已明确创建 `contracts/superpowers-boundary.yaml`，并规定最小字段 `canonical_targets`、`declared_forks`、`allowed_legacy_paths`、`overlay_files`。
3. 是否引入新问题？
   - 低风险；唯一新增要求是后续实现必须遵守该合同格式。
4. 是否需要补充测试覆盖？
   - 需要。T5 已改为显式读取 `contracts/superpowers-boundary.yaml`。

RED 证据：
- `docs/superpowers-adaptation-boundary/code-review-report.md` 中该 finding 为 `Medium Verified`

GREEN 证据：
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:160-193`
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md:218-229`
- `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-tasks.md:14-17`

## 修复后验证

文本验证：
- `rg -n "community/openspec|compat|过渡资产|spec-document-reviewer-prompt|requesting-code-review/SKILL|contracts/superpowers-boundary.yaml|allowed_legacy_paths|overlay_files" openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md openspec/plans/2026-03-31-superpowers-adaptation-best-practice-tasks.md`
- 结果：命中项均为新增的明确裁决与合同字段，未见旧问题残留。

全量回归：
- `bash tests/run-all.sh`
- 结果：`All tests passed`

回归影响范围确认：
- 影响文件限于：
  - `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md`
  - `openspec/plans/2026-03-31-superpowers-adaptation-best-practice-tasks.md`
- 仓库级安装、合同、文档完整性与 community tools 回归均通过。

N>1 差异说明：
- 不适用；当前为第 1 轮修复。

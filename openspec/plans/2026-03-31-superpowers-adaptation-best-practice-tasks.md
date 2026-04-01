# Tasks — superpowers adaptation best practice

创建日期：2026-03-31  
关联 plan：`openspec/plans/2026-03-31-superpowers-adaptation-best-practice-plan.md`

## 验收清单

- [x] T1 建立当前 `community/superpowers` 的可信基线
  - AC: 已清理正文损坏与明显漂移项，至少修复损坏内容、路径残留和来源基线不一致问题，并形成当前路径裁决记录。
- [x] T2 固化“上游方法论 / 本地编排 / 工件语义 / 组织治理”四层边界
  - AC: 仓库中存在单一真源文档，能明确说明每层职责、允许改动和禁止改动，并明确 `community/openspec` 的兼容身份。
- [x] T3 把深分叉从 `community/superpowers` 正文中外移到 wrapper/contract 层
  - AC: `community/superpowers` 仅保留 upstream-aligned runtime；本地 handoff、默认链和强一致契约不再散落在多个 superpowers skill 正文、prompt 模板和示例里。
- [x] T4 建立上游同步与本地 overlay 的再生机制
  - AC: 能从 `community/SOURCES.yaml` 指定 ref 生成或校验本地资产；存在机器可读真源 `contracts/superpowers-boundary.yaml`；本地适配以 overlay/adapter 形式存在，不依赖人工全文维护。
- [x] T5 建立自动验证与回归门禁
  - AC: 至少覆盖正文完整性、路径一致性、深分叉边界和默认链合同四类检查；测试以 `contracts/superpowers-boundary.yaml` 为准；新增漂移能被直接阻断。

## 完成定义

上述 5 个 task 全部完成，且可以一句话解释：

“`community/superpowers` 保留上游方法论基线，本地流程差异沉到 wrapper/contract，平台与语言差异沉到 adapter，正确性由 tests/contracts 保证。”

## 完成记录

- 完成日期：2026-03-31
- 最终验证：
  - `python3 tools/community/source_lock_check.py`
  - `bash tests/test-superpowers-boundary.sh`
  - `bash tests/test-community-first-boundary.sh`
  - `bash tests/run-all.sh`

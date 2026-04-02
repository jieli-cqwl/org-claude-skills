# Fix Report — Round 2 Baseline Recovery

日期: 2026-04-02  
关联上一轮: `docs/hotfix-20260402-codex-doc-review-hook/fix-1.md`  
输出路径: `docs/hotfix-20260402-codex-doc-review-hook/fix-2.md`

## 问题概述

在 `fix-1` 提交后复审阶段，`codex-doc-review` 相关测试通过，但全仓基线测试出现阻断：

- `tests/test-runtime-integrity.sh` 失败：`boundary contract 指向缺失文件: docs/small-chain/boundary-contract.md`
- `tests/test-small-chain-boundary.sh` 失败：缺少 `docs/small-chain/boundary-contract.md`
- `tests/test-chain-completeness.sh` 失败：缺少 `docs/small-chain/README.md`

## 诊断证据

### 现象证据（RED）

1. 失败命令输出（可复现）：
   - `bash tests/test-runtime-integrity.sh` -> FAIL
   - `bash tests/test-small-chain-boundary.sh` -> FAIL
   - `bash tests/test-chain-completeness.sh` -> FAIL
2. 约束引用位置：
   - [superpowers-boundary.yaml](/Users/lijieli/org-claude-skills/contracts/superpowers-boundary.yaml#L12) 声明 `boundary_contract_doc: docs/small-chain/boundary-contract.md`
   - [test-small-chain-boundary.sh](/Users/lijieli/org-claude-skills/tests/test-small-chain-boundary.sh#L5) 强依赖 `docs/small-chain/boundary-contract.md`
   - [test-chain-completeness.sh](/Users/lijieli/org-claude-skills/tests/test-chain-completeness.sh#L24) 强依赖 `docs/small-chain/README.md`

### 假设与验证

1. 假设 A：`fix-1` 的 hook 改动引入了 runtime 回归  
   - 验证：`fix-1` 只改 `shared/hooks/lib/common.sh`、`tests/test-codex-doc-review-routing.sh`、`claude/skills/codex-doc-review/references/execution-spec.md`，未改 small-chain 文档与合同。
   - 结论：排除（Excluded）。
2. 假设 B：工作区存在与本次修复无关的文档删除，破坏了 small-chain 基线  
   - 验证：`git status --short` 显示 `docs/small-chain/*`、`docs/user-auth/CHANGELOG.md` 等文件为 `D`（删除）。
   - 结论：确认（Confirmed）。

## 根因

- 根因类型：`FIXABLE`
- 根因描述：工作区出现了与本次 Hook 修复无关的基线文档缺失，导致合同与边界测试找不到必需文件。
- 根因定位：
  - 合同依赖声明: [superpowers-boundary.yaml](/Users/lijieli/org-claude-skills/contracts/superpowers-boundary.yaml#L12)
  - 失败检测脚本: [test-small-chain-boundary.sh](/Users/lijieli/org-claude-skills/tests/test-small-chain-boundary.sh#L15), [test-chain-completeness.sh](/Users/lijieli/org-claude-skills/tests/test-chain-completeness.sh#L18)

## 处置

恢复缺失基线文档到工作区（从当前 `HEAD` 恢复），不修改本轮 Hook 代码：

- `docs/small-chain/boundary-contract.md`
- `docs/small-chain/README.md`
- `docs/small-chain/step*.md`
- `docs/user-auth/CHANGELOG.md`
- 以及同批次缺失的 `docs/*.md` 基线文档

## 修复四问

1. 根因是什么？  
   是工作区文档缺失，不是 Hook 逻辑回归。
2. 修复是否完整？  
   已恢复被删除的 small-chain 基线文档与关联文档，合同依赖恢复完整。
3. 是否引入新问题？  
   未引入代码路径变化，仅恢复缺失文档。
4. 是否需要补充测试覆盖？  
   无需新增用例；现有边界与完整性测试已覆盖该类缺失问题。

## GREEN 证据

阶段验证：

- `bash tests/test-runtime-integrity.sh` -> PASS
- `bash tests/test-small-chain-boundary.sh` -> PASS
- `bash tests/test-chain-completeness.sh` -> PASS
- `bash tests/test-doc-reference-integrity.sh` -> PASS

全量复审：

- `bash tests/run-all.sh` -> PASS（24/24）

## 结论

第 2 轮修复后，Hook 问题与基线问题均已闭环，当前最新复审无阻断问题。

# Fix Report — codex-doc-review Hook Context Parsing

日期: 2026-04-02  
范围: `claude/skills/codex-doc-review/scripts/completion_check.sh` 调用链  
路径解析: 无可解析业务 work_dir，按 hotfix 规则输出到 `docs/hotfix-20260402-codex-doc-review-hook/fix-1.md`

## 输入与复现来源

- 下游反馈 3 个问题：
  - 模板路径（`docs/{feature}/*`）被当真实文档
  - 示例路径（`docs/design/test-cases.md`）误判为审查输入
  - `需求清单.md` 无法识别为 product scope
- 复现环境: 本地临时 repo + `source shared/hooks/lib/common.sh` 后执行 `resolve_codex_doc_review_context`

## 问题 1：模板路径被当作真实文档

### 现象（RED）

- transcript 含 `docs/{feature}/prd.md + docs/feature-a/prd.md`
- 旧行为报错: `被审查文档跨多个 feature... docs/{feature}`

### 假设与验证

1. 假设 A：路径抽取阶段未过滤模板元字符  
   - 证据: [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L535) 使用通配 `docs/.*\.md` 抓取全文路径，无模板过滤。  
   - 结论: Confirmed。
2. 假设 B：feature 归一阶段错误  
   - 证据: [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L685) 仅做 `docs/{feature}` 分组，不识别占位符。  
   - 结论: Confirmed（上游脏输入未被清洗导致此处触发）。

### 根因

- 根因位置: [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L531) ~ [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L540)
- 根因描述: 文档路径抽取对 transcript 全文做宽匹配，缺少模板/占位符过滤与存在性校验。

### 修复四问

1. 根因是什么: 路径抽取规则过宽 + 无预清洗。  
2. 修复是否完整: 已在抽取阶段增加模板字符过滤和存在性检查。  
3. 是否引入新问题: 对“真实存在的 docs/*.md”路径无行为变化。  
4. 是否需要补测试: 需要，已新增模板路径回归用例。

failure_class: `FIXABLE`

## 问题 2：示例路径误判（review-guide 示例）

### 现象（RED）

- transcript 含真实 `docs/feature-a/prd.md`，并附带说明文本 `docs/design/test-cases.md`
- 旧行为报错跨 feature（`docs/design` + `docs/feature-a`）

### 假设与验证

1. 假设 A：抽取函数扫描全文，说明文本被当输入  
   - 证据: [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L535) 对整文件做路径 grep。  
   - 结论: Confirmed。
2. 假设 B：缺文件存在性校验导致示例路径进入判定  
   - 证据: 旧流程无 `[ -f "$REPO_ROOT/$path" ]` 判断。  
   - 结论: Confirmed。

### 根因

- 根因位置: [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L531) ~ [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L540)
- 根因描述: 没有区分“结构化审查文件字段”与“说明文本示例路径”，且未做存在性过滤。

### 修复四问

1. 根因是什么: 全文宽匹配 + 无存在性过滤。  
2. 修复是否完整: 优先提取 `file/审查文件` 字段；无字段再 fallback；并增加存在性校验。  
3. 是否引入新问题: 当结构化字段缺失时仍保留 fallback，不破坏兼容性。  
4. 是否需要补测试: 需要，已新增“示例路径不污染输入”用例。

failure_class: `FIXABLE`

## 问题 3：`需求清单.md` 无法识别 product scope

### 现象（RED）

- 输入仅 `docs/feature-a/需求清单.md` 且无显式 scope
- 旧行为报错: `无法解析 codex-doc-review 的 scope`

### 假设与验证

1. 假设 A：scope 推断白名单缺中文命名  
   - 证据: [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L577) 只识别 `prd.md/product-cross-review/UNIT-*`。  
   - 结论: Confirmed。
2. 假设 B：scope 正则提取失败  
   - 证据: 该场景本就无显式 scope，预期应走推断逻辑。  
   - 结论: Excluded（非提取器问题）。

### 根因

- 根因位置: [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L574) ~ [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L598)
- 根因描述: 推断规则未覆盖中文同义文件名（`需求清单.md` / `需求列表.md`）。

### 修复四问

1. 根因是什么: 推断规则覆盖不全。  
2. 修复是否完整: 已扩展 product 推断关键词。  
3. 是否引入新问题: 仅新增 product 同义匹配，不改变既有 `design/test-design/tech-lead` 路径。  
4. 是否需要补测试: 需要，已新增“需求清单推断 product”用例。

failure_class: `FIXABLE`

## 语义关系确认（静态追踪）

- [completion_check.sh](/Users/lijieli/org-claude-skills/claude/skills/codex-doc-review/scripts/completion_check.sh#L14) 调用 `resolve_codex_doc_review_context`。
- `resolve_codex_doc_review_context` 在 [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L652) 定义，并在 [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh#L664) 调用路径抽取函数。
- 因此 hook 阻断现象与 `common.sh` 解析逻辑直接因果关联。

## 修复内容

1. `shared/hooks/lib/common.sh`
   - 新增路径合法性函数（模板元字符过滤 + 文件存在性校验）
   - 新增“结构化字段优先”的路径抽取流程
   - 扩展 `需求清单.md` / `需求列表.md` -> product 推断
2. `tests/test-codex-doc-review-routing.sh`
   - 新增 3 个回归场景覆盖上述问题
3. `claude/skills/codex-doc-review/references/execution-spec.md`
   - 同步规则文档（product 关键词与模板路径忽略规则）

## GREEN 证据

- `bash tests/test-codex-doc-review-routing.sh` -> PASS（含新增 3 场景）
- `bash tests/test-codex-doc-review-repair.sh` -> PASS
- `bash tests/test-codex-skill-adapter.sh` -> PASS
- 三条最小复现在修复后均恢复为 PASS（模板路径、示例路径、需求清单推断）

## 全量回归说明

- 尝试执行 `bash tests/test-runtime-integrity.sh` 时失败，失败原因为仓库当前存在与本次修复无关的大量文档删除/迁移（如 `docs/small-chain/boundary-contract.md` 缺失），导致 `source_lock_check` 阻断。  
- 该失败属于环境/工作区基线问题，不属于本次 Hook 修复引入回归。已保留现状，未回滚非本次改动。

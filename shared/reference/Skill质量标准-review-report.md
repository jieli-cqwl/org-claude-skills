# Skill 质量标准 — 多维度评审汇总

> 评审对象：`shared/reference/Skill质量标准.md`（codex 产出，515 行）
> 方式：6 个 agent 并行深度调研（含官方文档 / GitHub 头部仓库 / 社区博客 / 模拟审计 / 文档自审 / 盲点扫描）
> 完成时间：2026-04-28

---

## 一、总体裁决

**PARTIAL — 结构正确、可用作底盘，但存在 P0 级修订项，未修订前不能宣称"对齐 first-party Agent Skills 最佳实践"。**

| 维度 | 子裁决 | 关键问题 |
|---|---|---|
| D1 官方规范对齐 | PARTIAL（aligned-with-drift） | `allowed-tools` 语义反向、frontmatter 字段验证缺失、扩展字段未承认 |
| D2 GitHub 实证 | PARTIAL | 资源命名脱社区惯例、未覆盖多 runtime adapter 与 sub-skill 编排、E1-E5 在头部仓库普遍不可达 |
| D3 社区共识 | CONDITIONAL PASS | description 三人称/双要素未约束、缺 freedom level、缺 rule→gate 语义、缺 Skill vs MCP 选型边界 |
| D4 审计可执行性 | NEEDS_REFINEMENT | finding schema 缺 owner/priority/runtime_target、L0-L4 分级在 WARN 累积时沉默、Skill 类型画像不互斥不穷尽 |
| D5 内部一致性 | MINOR_DRIFT | S7 评级自指、S3↔S5/G1↔S8/S2↔S7 双计、S4/S5/S7 三处 FP Guard 放水、与能力标准 schema 引用断链 |
| D6 覆盖盲点 | MAJOR_BLINDSPOTS | Prompt Injection、多 skill 编排冲突、ZDR/数据驻留 三项 P0 缺失 |

**最高阻塞级**：D6 的 3 项 P0（安全/正确性根本面，且有 the provider 官方文档直接对应警告）→ 标准在当前形态下做安全/隐私相关 Skill 审计会漏判。

---

## 二、跨维度收敛的核心问题（去重后）

按"出现次数 + 影响面"排序，下述 12 项是多个 agent 独立指出的同一/相邻问题：

### P0（必改，影响裁决正确性或安全）

1. **frontmatter 严格化缺失**（D1-F1, D6-F11, D3-F1）
   - 缺：name 字符集 `^[a-z0-9-]{1,64}$`、reserved words（"the provider"/"claude"）、XML tag-free、description ≤1024 chars 且非空、第三人称、What+When 双要素。
   - 修订点：G0 FAIL Conditions + S1 Required Evidence。

2. **`allowed-tools` 语义反向**（D1-F3, D5-F-S5_FP）
   - 标准把它写作"工具权限边界"，官方原话是"grants permission, does not restrict"。会让审计者误把 PASS 当安全证据。
   - 修订点：S5 改写定义 + 增"必须显式声明 allowed-tools 或 read-only；缺声明 → FAIL"。

3. **Prompt Injection / 来源信任 缺独立条款**（D6-F2）
   - 官方 overview 明确警告"fetched content may contain malicious instructions"。当前 S5 只笼统提"来源不可追溯"。
   - 修订点：S5 新增 FAIL：外部 URL/动态 fetch 资源未声明 fetch policy / 内容校验 / 缓存锁；references/examples 不得作为可信指令源。

4. **多 Skill 编排冲突维度缺失**（D6-F1, D2-F-GAP-04）
   - ≥3 个 skill description 同时命中时无裁决；sub-skill chain（superpowers 范式）未被覆盖。
   - 修订点：S1 增 multi_skill_arbitration（priority / mutual_exclusion / fallback）；新增 S9 或扩 S3：sub-skill orchestration / handoff / 依赖图。

5. **数据驻留 / ZDR 不适用**（D6-F10）
   - 官方明确"Skills is not eligible for ZDR"。当前 S5 未要求声明 data flow / 外发 API / 敏感本地路径。
   - 修订点：S5 新增 `data_flow_disclosure` FAIL。

6. **S7 评级自指 + S3↔S5/G1↔S8/S2↔S7 双计**（D5-F1/2/3/4）
   - S7 FAIL → 上限 L1，但 L1 又要求 S7 最小合同；同一现象在两维度被双计 FAIL。
   - 修订点：分级表细化"影响安全/验证证据的 FAIL → 上限 L0；其余 → L1"；每对维度后加"前者已覆盖时不重复 FAIL"归并条款。

### P1（应改，提升精度与现实贴合度）

7. **Skill 资源目录与社区脱节**（D2-F-GAP-01/02）
   - 头部仓库用 `resources/` 而非 `references/`；`hooks/`/`assets/` 多在仓库顶层（plugin 级）而非 skill 内嵌。
   - 修订点：S4 表把 `references/` 标注"也接受 `resources/`"；新增"plugin-level resources" 行（顶层 hooks/agents/assets/commands/.claude-plugin 等）。

8. **多 runtime adapter 矩阵不全**（D2-F-GAP-03, D6-F09）
   - 标准只提 `agents/openai.yaml`；社区已普遍存在 `.claude-plugin/`、`.codex-plugin/`、`.cursor-plugin/`、`.opencode/`、`gemini-extension.json`。
   - 修订点：S8 把单文件改为示例，列多 runtime adapter 统一裁决；新增 retire_runbook（alias 摘除、metadata 删除、跨 surface 清理）。

9. **finding schema 缺字段 + WARN 累积规则缺失**（D4, D5）
   - 缺 `owner` / `priority` / `runtime_target` / `skill_id` / `scope`；WARN 累积是否降级未定义。
   - 修订点：finding schema 扩字段；分级表写"≥3 同维度 WARN ≡ 1 FAIL；≥6 跨维度 WARN 等级 -1"。

10. **Skill 类型画像不互斥不穷尽**（D4）
    - commit 同属"工具类+Pipeline"，verify 同属"审计+Pipeline"；缺 meta-skill / slash-command-only 类型；强约束维度让作者误以为可豁免最小合同。
    - 修订点：声明"画像可叠加，强约束取并集"；增 meta-skill / slash-command 类型；表前加注"不豁免 L1 最小合同；instruction-only 无 artifact 时 S6 标 N/A"。

11. **Token 经济性量化缺失**（D6-F03, D2-F-GAP-05）
    - 仅"500 行 warning"，无 metadata ≤100 tok、SKILL.md ≤5k tok、lazy-load 比例等量化。
    - 修订点：S4 增 token_budget 字段；E3 增 per-trigger token cost vs uplift 对比口径。

12. **跨模型矩阵未纳入 L3 触发条件**（D1-F9, D3-F3, D6-F04）
    - 官方 checklist 要求"Tested with Haiku, Sonnet, Opus"，标准只在 S8 WARN。
    - 修订点：E4 PASS 增"覆盖 fast/balanced/reasoning 三档模型，或显式声明单模型范围"；S8 增 model_matrix_evidence。

### P2（收尾，体感/术语层）

13. **rule vs gate 语义未吸收**（D3-F5）：S7 增 FAIL"完成判定依赖自陈/主观'已检查'"。
14. **freedom level（高/中/低）缺失**（D3-F2）：S3 step 字段表加 `freedom_level`。
15. **Skill vs MCP/hook/subagent 选型边界**（D6-F06, D3-F4）：在 Skill 类型画像前加"何时不应做 Skill"小节。
16. **术语漂移**（D5）：`canonical` 三义、`proof` 两层、`evidence` 三义需消歧；引言加术语表。
17. **G0-G2/L0-L4/E1-E5 是本仓发明物**（D1-F8）：标题/前言注明非官方分类，并提供官方 checklist 映射。
18. **反模式 checklist 散点**（D3-F6）：voodoo constants / Windows 路径 / 时间敏感信息 / 术语不一致 / 过多备选 — 收拢为附录清单。
19. **可观测性维度**（D6-F08）：声称"长期保留"或冲 L4 时必须有 trigger/false-trigger/exit-code 信号采集。

---

## 三、各维度独立报告

每份完整报告保存在 agent 输出文件，本节仅给摘要 + 索引。

### D1 官方规范对齐（PARTIAL / aligned-with-drift）
关键 finding：F1 G0 字段验证缺失、F2 frontmatter 扩展字段未承认、F3 `allowed-tools` 语义反向、F4 目录强约束超官方、F5 第三人称缺、F6 ZDR/runtime 网络差异未提、F7 reference 一层深度反模式具体化、F8 标注本地发明分类、F9 ≥3 evals/跨模型层级。

### D2 GitHub 实证（PARTIAL）
抽样：providers/skills、obra/superpowers、3 个 awesome catalog（11.9k/56.9k/19.3k star）。
盲点：F-GAP-01 `resources/` 命名、F-GAP-02 plugin-level 资源、F-GAP-03 多 runtime adapter、F-GAP-04 sub-skill 编排、F-GAP-05 E1-E5 头部仓库不可达、F-GAP-06 instruction-only S6 兜底偏弱、F-GAP-07 finding schema 粒度。

### D3 社区共识（CONDITIONAL PASS）
信息源：the provider engineering blog、官方 docs、simonwillison（2025-10-16/2026-03-22）、obra/superpowers README、blog.fsck.com（2026-01/03/04）。
14 条共识 → 标准吸收 6 / 部分 6 / 缺失 2。8 条 finding，known-consensus 占比 12.5%。

### D4 审计可执行性（NEEDS_REFINEMENT）
模拟审计样本：`~/.claude/skills/commit/` 与 `org-claude-skills/shared/skills/verify/`，两者皆评 L2。暴露问题：finding schema 4 字段缺失、L0-L4 在 WARN 累积场景沉默、Skill 类型画像不互斥不穷尽、proof command 操作语义留空、审计完成边界清单未要求列等级裁决。一致性风险点 6 个（如"commit 缺 allowed-tools 是 FAIL 还是 WARN"两审计者会分歧）。

### D5 内部一致性（MINOR_DRIFT）
3 处双计风险 + 1 处评级自指 + 3 条 FP Guard 放水 + 1 处 schema 引用断链。术语漂移：`canonical` 三义、`proof` 两层、`evidence` 三义。13 条 finding，11 条修订建议（P0 三 / P1 四 / P2 四）。

### D6 覆盖盲点（MAJOR_BLINDSPOTS）
P0：多 skill 编排冲突、Prompt Injection、ZDR/数据驻留。P1：token 经济、跨模型矩阵、i18n/POV、选型边界、skill 依赖契约、retire runbook、frontmatter 严格化。P2：可观测性。证据：5 URL（the provider engineering、docs ×2、MCP overview、obra repo、simonwillison tag），known-consensus 9%。给出 6 段补丁式 diff 草稿（5.1-5.6）。

---

## 四、修订路线建议

### Phase 1 — P0 补丁（建议 1 周内）
- 合入 D1-F1（G0 frontmatter 严格化）+ D1-F3（S5 `allowed-tools` 语义纠正）
- 合入 D6 §5.1 安全/数据驻留补丁 + D6 §5.2 多 skill 仲裁补丁
- 合入 D5-P0 三项（S7 评级自指、维度双计归并、画像表注解）

### Phase 2 — P1 精度修订（2-3 周）
- 资源目录对齐社区命名（D2-F-GAP-01/02）
- 多 runtime adapter 矩阵 + retire_runbook（D2/D6）
- finding schema 扩字段 + WARN 累积规则（D4/D5）
- Skill 类型画像增类型 + 强约束注解（D4）
- token_budget 量化 + 跨模型矩阵 L3 触发（D1/D3/D6）

### Phase 3 — P2 收尾（背景任务）
- 术语表、freedom level、rule→gate、Skill vs MCP 选型小节、反模式 checklist 附录、可观测性维度

完成 Phase 1+2 后，标准可达 D1=ALIGNED、D2=COVERS_REALITY、D3=PASS、D4=OPERATIONAL、D5=COHERENT、D6=GAPS_PRESENT（P2 残余）。

---

## 五、原始 agent 输出位置

| 维度 | agent id | 输出文件 |
|---|---|---|
| D1 | a226dbf2216020725 | tasks/a226dbf2216020725.output |
| D2 | a0bbbd301d5db7891 | tasks/a0bbbd301d5db7891.output |
| D3 | a667c1cde94ef9b58 | tasks/a667c1cde94ef9b58.output |
| D4 | a1f872e836771323f | tasks/a1f872e836771323f.output |
| D5 | ac6ce5a4e3fac6df1 | tasks/ac6ce5a4e3fac6df1.output |
| D6 | a19fe987ebaa046c2 | tasks/a19fe987ebaa046c2.output |

> 路径前缀：`/private/tmp/claude-501/-Users-lijieli-org-claude-skills/f13df517-1adb-4b6e-b756-9c99a82ca10e/`

---

## 六、给标准作者的下一步建议

1. **不要回避 P0**：3 项 P0 中的 Prompt Injection 与 ZDR 在 the provider 官方 overview 已经定性为安全风险，标准不覆盖会在审计 review/security-review 类 Skill 时直接误判。
2. **优先把 schema 字段补齐**：finding schema 扩 4 字段（owner/priority/runtime_target/scope）+ WARN 累积规则，是让两个独立审计者得到一致结论的关键。
3. **Skill 类型画像 + L0-L4 分级**：建议联动改一次。当前画像与最小合同的口径冲突会反复消耗审计精力。
4. **与 `Skill能力有效性标准.md` 的边界**：建议加一张交叉引用表（什么去 schema、什么去测量协议、什么去 lifecycle 状态），消除"两边都不接"风险。
5. **保留本评审作为 baseline**：下一版改完后，可以用同一份 6 维度脚本回评，量化收敛。

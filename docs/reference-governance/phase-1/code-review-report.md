# Code Review Report

## 摘要

- 审查范围：当前工作区未提交的 `shared/protocols`、`shared/reference`、`shared/skills/tech-lead/references/templates/plan-template.md`、`install.sh`、`tools/migration/retire-dot-claude.sh`、`tests/**` 与 `docs/**` 中与 `reference-governance` 修复直接相关的改动。
- 本轮结论：Round 1 的 2 个正式问题已全部修复；最新一轮未发现置信度 >= 80 的正式问题。
- 修复收口：
  - 3 个 skill-specific 协议已从 source `shared/reference/` 拆到 [shared/protocols](/Users/lijieli/org-claude-skills/shared/protocols)，安装时仍渲染到 runtime `reference/`，兼容现有 skill 消费。
  - `impact_files` 格式 authority 已提升到 [影响文件格式.md](/Users/lijieli/org-claude-skills/shared/reference/影响文件格式.md#L1)，并由 [影响范围分析.md](/Users/lijieli/org-claude-skills/shared/reference/影响范围分析.md#L113) 与 [plan-template.md](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/templates/plan-template.md#L94) 共同引用。
  - 门禁已补齐 source 分层、反向引用和 docs link 完整性回归，见 [test-single-source-layout.sh](/Users/lijieli/org-claude-skills/tests/test-single-source-layout.sh#L14)、[test-skill-output-and-gate-contract.sh](/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh#L85)、[test-doc-reference-integrity.sh](/Users/lijieli/org-claude-skills/tests/test-doc-reference-integrity.sh#L14)。

### 亮点（可选，1-3 条）
| # | 位置 | 模式描述 | 推广价值 |
|---|------|---------|---------|
| 1 | `install.sh` + `shared/protocols/` | source 层按职责拆出协议目录，runtime 层继续汇总到 `reference/` 暴露面 | 既恢复了目录语义，又避免了对现有 skill/runtime 路径做高成本批量替换 |
| 2 | `shared/reference/影响文件格式.md` | 共享格式契约独立成文档，由 reference 与 template 双向复用 | 避免 shared authority 再次下沉到某个 skill 模板 |

### 审查-A: 安全与正确性

#### Findings
| # | 置信度 | 严重度 | 位置 | 维度 | 问题 | 修复方向 | 轮次 | 验证状态 |
|---|--------|--------|------|------|------|---------|------|---------|
| - | - | - | - | - | 无置信度 >= 80 的正式问题 | - | [R2] | - |

#### 已排除的潜在问题
| # | 调查内容 | 排除证据 |
|---|---------|---------|
| EP-A01 | 协议从 `shared/reference` 迁出后，runtime `reference/...` 路径可能失效 | [install.sh](/Users/lijieli/org-claude-skills/install.sh#L507) 与 [install.sh](/Users/lijieli/org-claude-skills/install.sh#L533) 已把 `shared/protocols` 汇入 staging `reference/`；`bash tests/test-runtime-integrity.sh` 与 `bash tests/run-all.sh` 均通过。 |
| EP-A02 | 旧 `.claude` 退役脚本仍只识别 `shared/reference/*`，会把协议文件误判成 repo-only 噪音 | [retire-dot-claude.sh](/Users/lijieli/org-claude-skills/tools/migration/retire-dot-claude.sh#L85) 已同时接受 `shared/reference/$file` 与 `shared/protocols/$file`；`bash tests/run-all.sh` 中的 install systematic / retirement 用例通过。 |

#### 结论
REVIEW_A_OK

---

### 审查-B: 设计与可维护性

#### Findings
| # | 置信度 | 严重度 | 位置 | 维度 | 问题 | 修复方向 | 轮次 | 验证状态 |
|---|--------|--------|------|------|------|---------|------|---------|
| - | - | - | - | - | 无置信度 >= 80 的正式问题 | - | [R2] | - |

#### 已排除的潜在问题
| # | 调查内容 | 排除证据 |
|---|---------|---------|
| EP-B01 | `impact_files` 格式 authority 仍可能从 shared reference 反向依赖到 tech-lead 模板 | [影响范围分析.md](/Users/lijieli/org-claude-skills/shared/reference/影响范围分析.md#L113) 与 [plan-template.md](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/templates/plan-template.md#L94) 现在都指向 [影响文件格式.md](/Users/lijieli/org-claude-skills/shared/reference/影响文件格式.md#L1)；[test-skill-output-and-gate-contract.sh](/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh#L95) 还锁住了 `plan-template.md` 不得再被 `影响范围分析.md` 引用。 |
| EP-B02 | 协议目录迁移后，source 层可能再次回流到 `shared/reference/` | [test-single-source-layout.sh](/Users/lijieli/org-claude-skills/tests/test-single-source-layout.sh#L16) 明确要求 `shared/protocols/*.md` 存在且 `shared/reference/phase-selection-protocol.md` 等旧路径不存在。 |
| EP-B03 | “中文优先”会被误解成“必须 100% 中文文件名”，导致把稳定术语名也硬改掉 | 当前修复只处理层次边界，不机械改动 [Skill质量标准.md](/Users/lijieli/org-claude-skills/shared/reference/Skill质量标准.md) 与 [mcp-server开发.md](/Users/lijieli/org-claude-skills/shared/reference/mcp-server开发.md) 这类高辨识度 mixed 命名；命名与分层问题已解耦。 |

#### 结论
REVIEW_B_OK

---

### 审查-C: 性能与可观测性

#### Findings
| # | 置信度 | 严重度 | 位置 | 维度 | 问题 | 修复方向 | 轮次 | 验证状态 |
|---|--------|--------|------|------|------|---------|------|---------|
| - | - | - | - | - | 无置信度 >= 80 的正式问题 | - | [R2] | - |

#### 已排除的潜在问题
| # | 调查内容 | 排除证据 |
|---|---------|---------|
| EP-C01 | 新增门禁会明显放大全量回归耗时或打破现有编排 | `bash tests/run-all.sh` 全量通过；新增门禁均为 `grep/find/test` 级静态检查，未引入外部依赖或长耗时流程。 |
| EP-C02 | docs/shared link 缺失时仍缺少明确失败信号 | [test-doc-reference-integrity.sh](/Users/lijieli/org-claude-skills/tests/test-doc-reference-integrity.sh#L22) 会直接报出 `source_file -> ref` 缺失关系，定位足够具体。 |

#### 结论
REVIEW_C_OK

---

### 最终结论
APPROVE

## 覆盖自评

### 已充分覆盖
| 维度 | 检查内容 | 证据 |
|------|---------|------|
| 正确性 | 验证 source 分层迁移后 runtime `reference/...` 仍可消费 | [install.sh](/Users/lijieli/org-claude-skills/install.sh#L507)；`bash tests/test-runtime-integrity.sh` |
| 安全性 | 检查本轮仅涉及文档/脚本/测试治理，不引入外部调用或权限放宽 | 变更文件集中在 `shared/` 文档、`install.sh`、`tests/**`、`tools/migration/retire-dot-claude.sh` |
| 错误处理 | 验证 docs link 缺失与 source 回流都有明确失败信号 | [test-doc-reference-integrity.sh](/Users/lijieli/org-claude-skills/tests/test-doc-reference-integrity.sh#L22)；[test-single-source-layout.sh](/Users/lijieli/org-claude-skills/tests/test-single-source-layout.sh#L20) |
| 并发/状态 | 评估是否引入并发/状态机变化；本轮仅调整 source authority 和安装拷贝逻辑 | [install.sh](/Users/lijieli/org-claude-skills/install.sh#L507) 只是增加额外 copy，不改变状态机 |
| 设计 | 验证 reference / protocols / skill templates 三层权责是否收口 | [影响文件格式.md](/Users/lijieli/org-claude-skills/shared/reference/影响文件格式.md#L1)；[shared/protocols](/Users/lijieli/org-claude-skills/shared/protocols) |
| 测试覆盖 | 确认 source 分层、反向引用与 docs link 三类回归均有门禁 | [test-single-source-layout.sh](/Users/lijieli/org-claude-skills/tests/test-single-source-layout.sh#L14)；[test-skill-output-and-gate-contract.sh](/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh#L85)；[test-doc-reference-integrity.sh](/Users/lijieli/org-claude-skills/tests/test-doc-reference-integrity.sh#L14) |
| 注释准确性 | 复查计划文档与当前 source 决策是否一致 | [rules-reference-best-practice-plan.md](/Users/lijieli/org-claude-skills/docs/rules-reference-best-practice-plan.md#L243) 已更新为 `shared/protocols/` 方案 |
| 向后兼容 | 验证 runtime、退役脚本、docs 链接在迁移后仍稳定 | [retire-dot-claude.sh](/Users/lijieli/org-claude-skills/tools/migration/retire-dot-claude.sh#L85)；`bash tests/run-all.sh` |
| 性能 | 评估新增门禁执行成本与全量回归影响 | `bash tests/run-all.sh` 通过，新增门禁无额外外部依赖 |
| 可观测性 | 验证失败时能够直接定位到文件和层次边界 | [test-single-source-layout.sh](/Users/lijieli/org-claude-skills/tests/test-single-source-layout.sh#L20)；[test-doc-reference-integrity.sh](/Users/lijieli/org-claude-skills/tests/test-doc-reference-integrity.sh#L22) |

### 覆盖盲区（coverage_gaps）
| 维度 | 盲区描述 | 原因 |
|------|---------|------|
| 向后兼容 | 历史文档中的纯文本旧路径描述未做机械校验 | 当前门禁只校验 markdown link target，避免把历史问题描述误判为死链；纯文本历史路径仍需评审把关。 |

## 审查轮次

| 轮次 | 类型 | 新增发现数 | 收敛状态 |
|------|------|-----------|---------|
| Round 1 | 广度扫描 | 2 | 未收敛 |
| Round 2 | 深度聚焦 | 0 | Round 2 收敛 |
| Round 3 | 对抗审查 | 0 | 未触发 |

### Delta 声明（Round 2+ 必填，Round 1 写"首轮审查"）
- Round 1：首轮审查
- Round 2：新增发现 `0`；确认上一轮 `1,2` 已修复；推翻上一轮 `无`

## Verification 汇总

| 轮次 | 送检数 | Verified | False Positive | Inconclusive |
|------|--------|----------|---------------|-------------|
| R1 | 0 | 0 | 0 | 0 |
| R2 | 0 | 0 | 0 | 0 |

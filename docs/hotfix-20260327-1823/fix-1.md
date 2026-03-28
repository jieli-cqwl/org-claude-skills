# fix-1

## 输入来源与路径解析

- 输入来源：本轮会话中的审查结论，包含 2 个正式问题：
  - `research-report.md` 把调研起点和当前状态混写，导致证据链失真
  - 规则入口未明确挂回新增实现的举证要求，导致治理强度看起来被意外放松
- 输出目录：`docs/hotfix-20260327-1823/`
- 修复轮次：`N=1`

## 环境快照

- 分支：`main`
- 基线提交：`6c99344`
- 工作树状态：存在用户其他未提交改动；本轮仅处理代码复用相关文档

## 问题 1

- issue_id: `FIX-1`
- failure_class: `FIXABLE`
- 现象：
  - [`research-report.md`](/Users/lijieli/org-claude-skills/docs/code-reuse-best-practices/research-report.md#L8) 仍以现在时描述“代码复用.md 主要是门禁文档”
  - 但 [`代码复用.md`](/Users/lijieli/org-claude-skills/shared/reference/代码复用.md#L1) 已被改成原则文档
- 假设 A：研究报告没有在文档重构后同步更新，导致“调研起点”和“当前状态”混写
- 假设 B：只有证据索引错了，正文本身并无状态漂移
- 验证：
  - 读取 [`research-report.md`](/Users/lijieli/org-claude-skills/docs/code-reuse-best-practices/research-report.md#L8) 与 [`代码复用.md`](/Users/lijieli/org-claude-skills/shared/reference/代码复用.md#L1)，确认假设 A 成立
  - 检查报告尾部证据索引，发现 [E4] 也错误指向当前 [`代码复用.md`](/Users/lijieli/org-claude-skills/shared/reference/代码复用.md#L1)，假设 B 被排除
- 根因确认：
  - 根因位置：[`research-report.md`](/Users/lijieli/org-claude-skills/docs/code-reuse-best-practices/research-report.md#L8)、[`research-report.md`](/Users/lijieli/org-claude-skills/docs/code-reuse-best-practices/research-report.md#L20)、[`research-report.md`](/Users/lijieli/org-claude-skills/docs/code-reuse-best-practices/research-report.md#L155)
  - 因果链：文档结构已重构为“原则 + 门禁”两层，但报告仍按重构前状态描述“当前文档”，造成当前文件引用与论证对象不一致
  - 语义关系证据：通过 `rg` 与逐段读取，确认报告中的“当前”描述实际对应的是历史状态，而当前原则文档正文已不再包含这些内容
- 修复四问：
  - 根因是什么：报告时态未切分，历史状态和当前状态混写
  - 修复是否完整：已补“调研起点 / 当前落地后状态”双视角，并修正证据索引
  - 是否引入新问题：未修改其他研究报告结构，仅在本文件内补充状态边界
  - 是否需要补充测试覆盖：文档改动，无自动化测试；改用一致性扫描验证

## 问题 2

- issue_id: `FIX-2`
- failure_class: `FIXABLE`
- 现象：
  - [`代码规范.md`](/Users/lijieli/org-claude-skills/shared/rules/代码规范.md#L61) 之前只保留了原则文档入口
  - 新增的 [`复用证据与新建门禁.md`](/Users/lijieli/org-claude-skills/shared/reference/复用证据与新建门禁.md#L1) 没有被规则层显式挂回
- 假设 A：这次只是文档拆层，没有改变治理要求
- 假设 B：规则入口漏挂新门禁文档，导致“必须先收集证据 / 必须说明不复用原因”的要求失去高层可见性
- 验证：
  - 扫描 [`代码规范.md`](/Users/lijieli/org-claude-skills/shared/rules/代码规范.md#L39) 到 [`代码规范.md`](/Users/lijieli/org-claude-skills/shared/rules/代码规范.md#L66)，修复前没有新的规则级挂载，假设 B 成立
  - 扫描 `shared/` 其他规则入口，没有发现额外规则源兜底该要求，假设 A 被排除
- 根因确认：
  - 根因位置：[`代码规范.md`](/Users/lijieli/org-claude-skills/shared/rules/代码规范.md#L46)
  - 因果链：旧门禁内容被拆到新文件后，规则源未同步补充“新增实现的证据与举证要求”，造成规范强度在阅读面上被削弱
  - 语义关系证据：通过 `rg` 追踪 `reference/代码复用.md` 与 `reference/复用证据与新建门禁.md` 的调用关系，确认只有原则入口被保留，门禁入口缺失
- 修复四问：
  - 根因是什么：规则源与新文档分层结构没有一起更新
  - 修复是否完整：已在规则源新增“复用治理规范”，并在边界与引用中分别挂出原则与门禁文档
  - 是否引入新问题：无行为性改动，仅恢复原有治理要求的显式入口
  - 是否需要补充测试覆盖：文档改动，无自动化测试；改用规则入口扫描验证

## 处置内容

- 为 [`research-report.md`](/Users/lijieli/org-claude-skills/docs/code-reuse-best-practices/research-report.md#L1) 增加“调研起点 / 当前落地后状态”说明，消除时态漂移
- 为 [`代码规范.md`](/Users/lijieli/org-claude-skills/shared/rules/代码规范.md#L46) 增加“复用治理规范”，恢复新增实现前的举证要求
- 在 [`代码复用.md`](/Users/lijieli/org-claude-skills/shared/reference/代码复用.md#L87) 补充一句，明确原则文档不替代门禁留痕要求

## 验证结果

- 结构校验：`git diff --check`，结果 `exit 0`
- 历史表述清理：`rg -n '代码复用（强制）|必须先搜索现有代码库并做 LSP 语义确认|当前仓库的复用门禁文档' shared docs/code-reuse-best-practices`，结果 `exit 1`，未发现残留
- 规则入口校验：`rg -n '新增实现前，必须先收集复用证据|不复用而新建实现时，必须' shared/rules/代码规范.md`，结果命中 [`代码规范.md`](/Users/lijieli/org-claude-skills/shared/rules/代码规范.md#L48) 和 [`代码规范.md`](/Users/lijieli/org-claude-skills/shared/rules/代码规范.md#L49)
- 文档关联校验：`rg -n '复用证据与新建门禁|原则先于工具' shared docs/code-reuse-best-practices`，结果命中新旧关系点，说明分层引用闭合

## 回归影响范围

- 直接修改：
  - [`代码复用.md`](/Users/lijieli/org-claude-skills/shared/reference/代码复用.md#L1)
  - [`代码规范.md`](/Users/lijieli/org-claude-skills/shared/rules/代码规范.md#L1)
  - [`research-report.md`](/Users/lijieli/org-claude-skills/docs/code-reuse-best-practices/research-report.md#L1)
- 关联验证：
  - [`复用证据与新建门禁.md`](/Users/lijieli/org-claude-skills/shared/reference/复用证据与新建门禁.md#L1)
  - [`影响范围分析.md`](/Users/lijieli/org-claude-skills/shared/reference/影响范围分析.md#L32)

## 轮次说明

- `N=1`，无历史 `fix-*.md`
- 本轮修复后进入第 2 轮与第 3 轮复审，均未发现新的正式问题

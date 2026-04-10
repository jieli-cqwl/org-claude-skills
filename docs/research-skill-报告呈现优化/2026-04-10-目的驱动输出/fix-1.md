# Fix Report 1

## 输入来源与路径解析

- work_dir: `docs/research-skill-报告呈现优化/2026-04-10-目的驱动输出`
- 输入工件:
  - `code-review-report.md`
  - `design.md`
  - `tasks.md`
  - `plan.md`
- failure_class: `FIXABLE`

## 环境快照

- branch: `main`
- workspace 状态: 当前工作树存在与本任务无关的既有未提交改动，本轮仅处理 `research` 相关文件与当前 feature 工作区工件
- 最近提交:
  - `9b973b5 feat: unify Claude and Codex hooks from a shared runtime registry`
  - `2517550 fix: trim low-frequency assistant runtime references`
  - `1360cbb fix: sanitize stale codex probe hooks during install`
  - `749a4ea fix: resolve shellcheck gate regression in install full check`
  - `1754ac7 chore: sync reviewer contract samples and install/runtime checks`

## 现象与复现

### Issue 1: 旧兼容模板仍把未显式选择的路由压到 `audit`

- 观察:
  - `code-review-report.md` 已指出 `SKILL.md` 输出入口与旧兼容模板存在冲突
  - 旧 `research-shared-header-template.md` 明确写了“默认按 audit 呈现模式处理”
- 假设 A: 只是 review 对文案过敏，运行时没有真实歧义
  - 验证: 检查 `shared/skills/research/SKILL.md` 输出章节是否仍把旧路径当作模板入口
  - 结果: 排除。输出章节确实仍指向旧共享头，兼容路径会影响后续消费
- 假设 B: 旧兼容模板虽然保留，但不会改变默认路由
  - 验证: 追踪 `analysis-frameworks.md` 的默认映射与旧模板内容
  - 结果: 确认。框架默认路由依赖 `research_mode`，旧模板却把未显式选择直接压到 `audit`
- 根因结论:
  - 根因是 `SKILL.md` 输出入口与 `research-shared-header-template.md` 的兼容策略没有一起升级，导致旧路径兼容文件从“索引”退化成了“默认模板”
  - 证据链:
    - 旧问题证据: `code-review-report.md:32`
    - 修复落点: `shared/skills/research/SKILL.md:68-79`
    - 修复落点: `shared/skills/research/references/templates/research-shared-header-template.md:1-15`

### Issue 2: 规范、模板和门禁对“共享审计层”要求不一致

- 观察:
  - `SKILL.md` 完成校验要求所有报告都含“检索路径与覆盖证明”
  - `decision / understanding` 模板没有这个章节
  - `completion_check.sh` 只对 `decision` 做了“若存在则顺序正确”的宽松判断
- 假设 A: `检索路径与覆盖证明` 只应对 `audit` 强制
  - 验证: 回看 `design.md` 的 scope 与 out-of-scope，确认本轮不允许放松覆盖证明硬约束
  - 结果: 排除。设计明确要求保留证据、挑战和覆盖证明硬约束
- 假设 B: 章节不在 header 模板里并不构成问题，因为 mode 模板会补齐
  - 验证: 追踪 `research-analysis-template.md`、`research-discovery-template.md`、`research-tech-selection-template.md`
  - 结果: 排除。mode 模板只有各自的审计附录，没有统一的“独立挑战记录 / 检索路径与覆盖证明 / 项目上下文”
- 根因结论:
  - 根因是新设计把共享头拆成三档后，没有同步引入“所有 profile 都必须带上的共享审计层”，于是 contract、模板和门禁各自只实现了一部分
  - 证据链:
    - 旧问题证据: `code-review-report.md:33`
    - 修复落点: `shared/skills/research/SKILL.md:92-99`
    - 修复落点: `shared/skills/research/references/templates/research-shared-audit-appendix-template.md:1-22`
    - 修复落点: `shared/skills/research/scripts/completion_check.sh:92-125`

### Issue 3: `understanding / audit` 分支缺少回归保护

- 观察:
  - 原测试只构造了 `decision` 的通过/失败样例
  - `completion_check.sh` 已包含 `understanding / audit` 分支
- 假设 A: 其他 profile 不需要专门样例，模板存在性检查已经足够
  - 验证: 对照 `completion_check.sh` 的分支逻辑与已有测试覆盖面
  - 结果: 排除。分支逻辑存在，但没有 fixture 会执行到这些路径
- 假设 B: 只补 `audit` 或只补 `understanding` 就够
  - 验证: 检查三档 profile 的门禁要求是否各自独立
  - 结果: 排除。三档 profile 都有独立顺序约束，必须分别建正反样例
- 根因结论:
  - 根因是初版回归只围绕首个 `decision` 用例收口，没有把 profile-specific gate 分支当作独立 contract 来测
  - 证据链:
    - 旧问题证据: `code-review-report.md:34`
    - 修复落点: `tests/test-research-skill-contract.sh:136-260`

## 修复四问

| 问题 | 根因是什么 | 修复是否完整 | 是否引入新问题 | 是否补充测试 |
|---|---|---|---|---|
| Issue 1 | 旧兼容模板仍承担默认模板职责 | 已将旧路径降为兼容入口说明，并让 `SKILL.md` 只引用新组合结构 | 已同步 small-chain 工件，避免文档再次漂移 | 是 |
| Issue 2 | 缺少统一的共享审计层，导致 contract/模板/门禁分裂 | 已新增共享审计附录模板，并在门禁中统一校验 | 额外发现 `audit` 首屏缺少覆盖摘要，已一并补齐 | 是 |
| Issue 3 | profile-specific gate 没有对应 fixture | 已补齐 `decision / understanding / audit` 的通过/失败样例 | 无新增行为面，只是把已有门禁显式验证出来 | 是 |

## 处置与改动

- 调整 `shared/skills/research/SKILL.md`
  - 输出结构改为“呈现模式头部 + 调研模式正文 + 共享审计附录”
  - 完成校验显式要求 `项目上下文 / 独立挑战记录 / 检索路径与覆盖证明`
- 新增 `shared/skills/research/references/templates/research-shared-audit-appendix-template.md`
  - 统一承载所有 profile 的后置审计层
- 调整 `shared/skills/research/references/templates/research-shared-header-template.md`
  - 降级为兼容入口说明，不再提供默认 `audit` 模板
- 调整 `shared/skills/research/references/templates/research-audit-header-template.md`
  - 保留首屏判断与挑战表，并新增覆盖证明摘要
- 调整 `shared/skills/research/references/report-presentation-framework.md`
  - 明确所有 profile 都必须包含共享审计层
- 调整 `shared/skills/research/scripts/completion_check.sh`
  - 统一检查共享审计附录
  - 为 `decision / understanding / audit` 增加相对顺序约束
- 扩展 `tests/test-research-skill-contract.sh`
  - 覆盖兼容路由、共享审计附录和三档 profile 的正反样例
- 同步 `design.md / tasks.md / plan.md`
  - 让 small-chain 工件与实际实现一致

## RED / GREEN 证据

- RED:
  - 命令: `bash tests/test-research-skill-contract.sh`
  - 结果: `[FAIL] missing pattern in shared/skills/research/SKILL.md: research-shared-audit-appendix-template\.md`
- GREEN:
  - 命令: `bash tests/test-research-skill-contract.sh`
  - 结果: `[PASS] research skill contract`
- 静态检查:
  - 命令: `bash -n shared/skills/research/scripts/completion_check.sh`
  - 结果: 通过
  - 命令: `shellcheck -x shared/skills/research/scripts/completion_check.sh tests/test-research-skill-contract.sh`
  - 结果: 通过

## 回归影响范围

- 直接影响:
  - `research` 的报告结构 contract
  - `research` 的模板组合方式
  - `research` skill-local completion gate
  - `research` 专用回归测试
- 间接影响:
  - small-chain 工件一致性检查
- 未触碰:
  - `render_hook_registry.py` 与 Codex hooks blocker fix 逻辑

## 下一步验证

- fresh proving command:
  - `python3 tools/community/check_task_plan_consistency.py docs/research-skill-报告呈现优化/2026-04-10-目的驱动输出/tasks.md docs/research-skill-报告呈现优化/2026-04-10-目的驱动输出/plan.md`
  - `bash tests/run-all.sh`

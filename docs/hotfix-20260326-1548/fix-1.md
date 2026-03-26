# fix-1

## 输入来源
- 用户反馈：
  - `codex-doc-review` 只应该存在于 Claude
  - `~/.codex/AGENTS.md` 标题显示为 `# CLAUDE.md`
  - 团队已开始使用，持续反馈平台噪音和误导文案
- 工作目录解析：
  - 无可解析 feature work_dir
  - 使用 hotfix fallback：`docs/hotfix-20260326-1548/`

## 环境快照
- 分支：`main`
- 基线提交：`be695d8 release: v1.2.1`
- 当前仓库：`/Users/lijieli/org-claude-skills`

## 现象
1. Codex 运行入口标题错误，显示 `# CLAUDE.md`
2. Claude 专属 `codex-doc-review` / `codex-doc-reviewer` 出现在 Codex 运行面
3. Codex 运行面仍含多处 Claude-only 话术

## 假设与验证
### 问题 1：Codex 入口标题错误
- 假设 A：`shared/assistant.md` 被原样复制到两端，未做入口文件名渲染
  - 验证：查看 [shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md:1) 与 [install.sh](/Users/lijieli/org-claude-skills/install.sh:240)
  - 结果：确认
- 假设 B：Codex 安装后又被其他脚本覆盖
  - 验证：重装前后对比 `~/.codex/AGENTS.md` 首行
  - 结果：排除，安装器本身即生成错误标题

### 问题 2：Claude 专属 skill 泄漏到 Codex
- 假设 A：`build_staging_codex` 无差别复制 `shared/skills/*`
  - 验证：查看 [install.sh](/Users/lijieli/org-claude-skills/install.sh:339)
  - 结果：确认
- 假设 B：旧安装残留导致误判
  - 验证：本机重装前存在、重构后通过安装清理消失
  - 结果：部分成立，但根因仍是共享层归属错误

### 问题 3：Codex 运行面 Claude-only 话术
- 假设 A：共享 reference / skill 主文案包含平台偏置文字，渲染到两端
  - 验证：检查 [shared/reference/description-spec.md](/Users/lijieli/org-claude-skills/shared/reference/description-spec.md:27)、[shared/reference/文档规范.md](/Users/lijieli/org-claude-skills/shared/reference/文档规范.md:12)、[shared/skills/product/SKILL.md](/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md:82)
  - 结果：确认
- 假设 B：仅是本机旧缓存
  - 验证：新增运行时噪音测试，在干净 HOME 安装样本中复现并验证修复
  - 结果：排除

## 根因结论
1. `shared/assistant.md` 缺少平台入口文件名渲染，占位符体系只覆盖 `{{RUNTIME_HOME}}`，未覆盖入口文档名
2. `codex-doc-review` 的能力归属定义错误，作为共享 skill/agent 被双端安装
3. 共享层存在若干直接面向用户的 Claude-only 话术，导致 Codex 运行面出现噪音

## 修复四问
### Q1 根因是什么
- 见上方根因结论

### Q2 修复是否完整
- 已覆盖：
  - 入口标题渲染
  - Claude 专属 skill/agent 归属
  - 高曝光共享文案噪音
  - 回归测试

### Q3 是否引入新问题
- 风险可控
- 通过 `tests/run-all.sh`、本机 `install.sh --check full`、Codex skill 实际枚举完成回归

### Q4 是否需要补测试覆盖
- 已补：
  - [test-platform-runtime-noise.sh](/Users/lijieli/org-claude-skills/tests/test-platform-runtime-noise.sh)

## failure_class
- 问题 1：`FIXABLE`
- 问题 2：`FIXABLE`
- 问题 3：`FIXABLE`

## RED / GREEN
- RED 证据：
  - 重装前 `~/.codex/AGENTS.md` 首行为 `# CLAUDE.md`
  - 重装前 `~/.codex/skills/codex-doc-review` 与 `~/.codex/agents/codex-doc-reviewer.md` 存在
- GREEN 证据：
  - `bash tests/run-all.sh` -> `All tests passed`
  - `bash install.sh --target all --force --merge-hooks --check full` -> 通过
  - 重装后：
    - `~/.claude/CLAUDE.md` 首行 `# CLAUDE.md`
    - `~/.codex/AGENTS.md` 首行 `# AGENTS.md`
    - `~/.codex` 中无 `codex-doc-review` / `codex-doc-reviewer`
    - `codex exec` skill 列表不含 `codex-doc-review`

## 回归影响范围
- `shared/assistant.md`
- `shared/reference/*`
- `shared/skills/*`
- `claude/skills/codex-doc-review`
- `claude/agents/codex-doc-reviewer.md`
- `install.sh`
- `tests/run-all.sh`
- `tests/test-platform-runtime-noise.sh`
- `tests/test-runtime-integrity.sh`
- `tests/test-single-source-layout.sh`
- `tests/test-codex-skill-adapter.sh`


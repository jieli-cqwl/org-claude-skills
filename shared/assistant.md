# {{ENTRY_DOC}}

中文对话。执行前必须复述理解，复述必须具体到操作对象和预期结果，AskUserQuestion 确认后再动手。简洁可执行。

## 工作流

- 未显式调用 skill 时，默认从 `brainstorming` 进入
- 显式调用 skill 时，按该 skill 自身定义的流程执行
- 不确定该用哪个 skill 时，先澄清目标，再选择最贴合的入口

## 决策优先级

正确性 > 完整性 > 简洁。冲突时按此顺序裁决。

规则优先级：铁律（零容忍）> 代码规范/执行纪律/文档管理（MUST）> reference（指南）。当用户指令与 rules/ 冲突时，rules/ 优先，需向用户说明原因。

## reference 触发映射

| 场景 | 读取 |
|------|------|
| 写测试、实现新功能 | `reference/测试规范.md` |
| 新增实现前判断复用 | `reference/代码复用.md` → `reference/复用证据与新建门禁.md` |
| 声称任务"完成"前 | `reference/完成前验证.md` |
| 设计决策（抽象/分层/模式） | `reference/设计原则.md` |
| 评估变更影响范围 | `reference/影响范围分析.md` |
| 报错/测试失败/定位原因 | `reference/系统调试.md` |
| 前后端联调/全栈交付 | `reference/全栈开发.md` |
| 引入新技术栈/多方案选型 | `reference/技术选型.md` |
| 批量处理/缓存/性能优化 | `reference/性能效率.md` |
| 常量/配置分层命名 | `reference/硬编码治理规范.md` |
| 代码质量检查/lint 命令 | `reference/代码质量.md` |
| 创建/更新文档 | `reference/文档规范.md` |
| 开发 MCP server | `reference/mcp-server开发.md` |
| 创建/评估 skill 质量 | `reference/Skill质量标准.md` |

## 配置导航

- `rules/` — 行为红线（始终加载）
- `reference/` — 技术规范（按需读取，触发映射见上表）
- `hooks/` — 自动化保障（按实际运行面生效，不等同于所有平台默认可用）
- `skills/` — 开发流程技能

# 跨职能审查报告

## 审查结论
| 视角 | 结论 | Issue 数 |
|------|------|---------|
| 产品 | WARN | 9 |
| 架构 | WARN | 6 |
| 测试 | WARN | 9 |

## 产品视角

Verdict: WARN
Issue Count: 9

### Findings
| Issue ID | Severity | 维度 | 发现 | 证据 | 建议 | 处理 |
|----------|----------|------|------|------|------|------|
| PR-001 | WARN | R1 | 根问题"沉淀"与本期只读范围存在语义落差 | 根问题节 vs 范围节 | 区分阅读和沉淀子目标 | FIXED: 根问题描述已修正 |
| PR-002 | WARN | R2 | AC-U1-01 硬编码 localStorage 与 DD-001 矛盾 | unit-1.md AC-U1-01 vs DD-001 | 移除存储位置限定 | FIXED: AC 已改为"DD-001 决定" |
| PR-003 | WARN | R3 | AC-U2-01 排序字段"发布时间"歧义 | unit-2.md（未指明 created_at vs updated_at） | 明确字段名 | FIXED: 改为 created_at |
| PR-004 | WARN | R3 | GAC-002 性能 AC 无测量定义 | prd.md GAC-002 | 补充量化基准 | FIXED: 已补充 |
| PR-005 | WARN | R4 | token 格式非法场景未覆盖 | unit-3.md 无非法 token AC | 增加 AC | FIXED: AC-U3-05 |
| PR-006 | WARN | R4 | 首页 API 请求失败场景未覆盖 | unit-2.md 无网络异常 AC | 增加 AC | FIXED: AC-U2-05 |
| PR-007 | WARN | R4 | 并发登录/重复提交行为未定义 | unit-1.md 无防重提交 AC | 明确防重提交策略 | ACCEPTED: 由 design 阶段在前端交互中定义 |
| PR-008 | WARN | R5 | 成功标准"提高可见性"与无数据迁移计划脱节 | 目标表第二行 vs 范围 | 修正度量方式 | ACCEPTED: 本轮用种子数据验证，真实度量待 CRUD 上线 |
| PR-009 | WARN | PR-C1 | 共创摘要后四阶段用户回应缺乏特异性 | 共创摘要表 | 补充实质性输入 | ACCEPTED: 本次为模拟验证项目，共创深度受限于验证目的 |

## 架构视角

Verdict: WARN
Issue Count: 6

### Findings
| Issue ID | Severity | 维度 | 发现 | 证据 | 建议 | 处理 |
|----------|----------|------|------|------|------|------|
| AR-001 | WARN | R9 | AC-U1-01 硬编码 localStorage 与 DD-001 矛盾 | unit-1.md vs DD-001 | AC 改为技术中立 | FIXED: 同 PR-002 |
| AR-002 | WARN | R9 | UNIT-3 路由守卫仅前端检查，后端 API 校验边界未识别 | unit-3.md 无后端验证提及 | 明确前后端校验边界 | ACCEPTED: 承接到 DD-002（API 契约）和 DD-004（路由守卫方案） |
| AR-003 | WARN | R8 | UNIT-2 对 DB schema 存在隐含依赖（联表查询 display_name） | unit-2.md AC-U2-01 vs DD-003 | DD-003 必须先于 UNIT-2 实现 | ACCEPTED: 承接到 DD-003，design 阶段明确 |
| AR-004 | WARN | R8 | CORS 未被识别为前置约束 | 全文无 CORS 相关约束 | 增加 CON | FIXED: 增加 CON-004 |
| AR-005 | WARN | R9 | 密码哈希库（bcrypt/argon2）存在跨平台编译依赖风险 | GAC-001 + DD-005 | DD-005 选型需考虑 | ACCEPTED: 承接到 DD-005 |
| AR-006 | INFO | R7 | GAC-002 测量方式未定义 | prd.md GAC-002 | 明确测量基准 | FIXED: 同 PR-004 |

## 测试视角

Verdict: WARN
Issue Count: 9

### Findings
| Issue ID | Severity | 维度 | 发现 | 证据 | 建议 | 处理 |
|----------|----------|------|------|------|------|------|
| TR-001 | HIGH | R12 | token 格式非法路径未覆盖 | unit-3.md 无解析失败 AC | 增加 AC | FIXED: AC-U3-05 |
| TR-002 | HIGH | R12 | 原生 SQL + 无输入边界 AC = SQL 注入风险盲区 | unit-1.md 边界仅"为空" + CON-003 | 增加 SQL 注入边界 AC | FIXED: AC-U1-05 + CON-003 补充参数化查询要求 |
| TR-003 | HIGH | R11 | token 过期判断逻辑存在实现歧义（exp claim vs 存储时戳） | unit-3.md AC-U3-03 | 明确判断依据 | ACCEPTED: 承接到 DD-004（路由守卫方案），design 阶段裁决 |
| TR-004 | MEDIUM | R10 | display_name 无 NOT NULL 约束，缺失时展示行为未定义 | prd.md 业务对象 + unit-2.md AC-U2-01 | 补充降级策略 | ACCEPTED: 承接到 DD-003，schema 中明确约束 |
| TR-005 | MEDIUM | R12 | 分页页码越界场景未定义 | unit-2.md 无越界 AC | 增加 AC | FIXED: AC-U2-06 |
| TR-006 | MEDIUM | R11 | GAC-002 性能 AC 不可量化自动化 | prd.md GAC-002 | 定义基准环境 | FIXED: 同 PR-004 |
| TR-007 | MEDIUM | R10 | DD-001 决策影响 AC 稳定性 | unit-1.md AC-U1-01 vs DD-001 | DD-001 收口前标注 AC 为 UNSTABLE | FIXED: AC 已改为技术中立，DD-001 裁决后自然稳定 |
| TR-008 | LOW | R12 | 用户快速连续点击登录按钮的防重提交 | unit-1.md 无防重提交 AC | 明确防重提交策略 | ACCEPTED: 同 PR-007 |
| TR-009 | LOW | R11 | GAC-003 "仅含"语义边界不清（标准 JWT claims 算不算） | prd.md GAC-003 | 明确标准 claims 边界 | FIXED: GAC-003 已明确 |

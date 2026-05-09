# 检测规则与评分算法

> 两组消费者：Agent 1-4 消费「检测规则」部分，Step 5 汇总消费「评分算法」部分。

## 检测规则

### Agent1: 铁律检测

| 类别 | 语言/类型 | 检测模式 |
|------|----------|---------|
| 降级 | Java | `orElse(null)`, `orElseGet(() -> null)`, `catch.*return null` |
| 降级 | Python | `except:.*pass`, `except.*return None`, `or None$` |
| 降级 | TypeScript | `?? null`, `\|\| null`, `catch.*return null` |
| 硬编码-URL | — | `http://localhost`, `127.0.0.1`, `://.*:\d{4,5}` |
| 硬编码-密钥 | — | `(api_key\|secret\|password\|token)\s*=\s*"[^"]+"` |
| 硬编码-配置 | — | `.yml`, `.properties`, `.env` 中的敏感值 |
| 常量-跨模块 | Python | `from src.{module_a}.constants import` 出现在其他模块 |
| 常量-无前缀 | Python | constants.py 中 `^[A-Z_]+ =` 不带模块前缀 |
| 常量-膨胀 | — | constants.py 行数 > 200 |
| Mock(非测试) | Python | `@patch`, `MagicMock`, `Mock(` |
| Mock(非测试) | TypeScript | `vi.fn`, `vi.mock`, `jest.fn`, `jest.mock` |
| Mock(非测试) | Java | `@Mock`, `Mockito.`, `when().thenReturn` |

### Agent2: 安全漏洞检测

| 类型 | 检测模式 |
|------|---------|
| SQL 注入 | 字符串拼接 SQL（`"SELECT" +`） |
| XSS | `dangerouslySetInnerHTML`, `innerHTML =` |
| 敏感信息日志 | `log.*(password\|token\|secret)` |
| 未授权接口 | 无权限校验的危险操作 |

### Agent3: 代码规范检测

| 规则 | 阈值 |
|------|------|
| 复杂度约束偏离（自动） | 不符合 `{{RUNTIME_HOME}}/rules/代码规范.md`（函数长度/嵌套） |
| 复杂度约束偏离（人工复核） | `{{RUNTIME_HOME}}/rules/代码规范.md` 的函数参数/文件长度条款 |
| 空 catch 块 / 裸 except | 存在 |
| System.out 使用 | 存在 |

### Agent4: 技术债统计

| 类型 | 检测模式 | 严重程度 |
|------|---------|---------|
| FIXME / HACK | `FIXME:`, `HACK:` | 警告 |
| TODO / XXX | `TODO:`, `XXX:` | 建议 |
| @Deprecated / @Disabled | 废弃代码、禁用测试 | 建议 |

---

## 评分算法

技术债 = Σ(严重 x 60min) + Σ(警告 x 15min) + Σ(建议 x 5min)

> Agent5/6 使用独立权重：严重 x 30min、警告 x 10min、建议 x 5min（信息卫生问题影响低于代码缺陷）。

> 不得对 findings 做临时"不确定性折算"（如按 20% 真实缺失率估算）。每个 finding 必须是可证伪的单元：要么保留（file_path:line_number 可达）、要么标记"假阳性并说明原因"剔除。批量调整在本规则未明确前一律禁止。

技术债比率 = 技术债(min) / (max(代码行数, 500) x 0.5min/行) x 100%

> 代码行数：仅源文件非空非注释行，排除测试目录和自动生成目录。

评级映射（SQALE 标准）
| 技术债比率 | 评级 |
|-----------|------|
| ≤5% | A (优秀) |
| >5% 且 ≤10% | B (良好) |
| >10% 且 ≤20% | C (一般) |
| >20% 且 ≤50% | D (较差) |
| >50% | F (需重构) |

# 性能分析工具参考

## 工具选择

| 工具 | 适用场景 | 特点 |
|------|---------|------|
| pyinstrument | 函数级耗时分析 | 低开销，调用树清晰 |
| py-spy | 生产环境采样 | 不侵入进程，支持火焰图 |
| scalene | CPU + 内存联合分析 | 区分 Python/C，内存泄漏检测 |
| nplusone | Django N+1 检测 | 自动检测 ORM 查询 |

## 分析模式

| 模式 | 工具 | 输出 |
|------|------|------|
| quick | pyinstrument | 调用树 + 每函数耗时% |
| deep | py-spy record | 火焰图 SVG + 采样统计 |
| n1 | nplusone / echo SQL | N+1 查询检测 |
| memory | scalene | 逐行 CPU% + 内存分配/释放 |
| flame | py-spy --format flamegraph | 交互式火焰图 |
| sql | Django connection.queries / SQLAlchemy logging | SQL 耗时分析 |

## 输出规范

1. 瓶颈 TOP 5（函数名 + file_path:line_number + 耗时占比）
2. 火焰图文件路径（如生成）
3. 优化建议（每个瓶颈附具体改进方向）

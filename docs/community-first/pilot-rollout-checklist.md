# Community-First 试点执行清单

目标：把 [community-first 默认流 RFC](/Users/lijieli/org-claude-skills/docs/rfcs/2026-03-26_community-first默认流RFC.md) 落成一份可直接执行的小范围试点清单。

适用范围：

- 1-3 人小范围试点
- 日常小需求
- 不涉及标准链替代

## 1. 试点前提

必须同时满足：

1. 仓库处于待试点版本
2. `bash tests/run-all.sh` 通过
3. `bash install.sh --target all --force --merge-hooks --check full` 通过
4. `openspec --version` 正常
5. `bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills` 无 `[FAIL]`

## 2. 参与人选择

推荐：

1. 1 名熟悉标准链的人
2. 1 名高频日常需求使用者
3. 1 名愿意做反馈记录的人

不推荐一开始就全员开放。

## 3. 样本选择

每周选择 3-5 个真实小需求，优先选这类：

- 单页面功能
- 小型接口新增/改造
- 单一业务闭环
- 文档与实现一体的小需求

不要放进试点池的样本：

- 多阶段交付
- 核心模型或核心 API 大改
- 高风险兼容/安全/性能变更
- 明显需要正式测试设计和 phase 计划的需求

## 4. 单次样本执行步骤

每个样本按下面顺序执行：

1. 不显式调用 skill，直接描述需求
2. 确认默认进入 `brainstorming`
3. 完成需求澄清与设计收口
4. 进入 `opsx:propose`
5. 生成并检查 change artifacts
6. 进入 `writing-plans`
7. 进入 `using-git-worktrees`
8. 进入 `opsx:apply`
9. 默认走 `subagent-driven-development`
10. 完成 `requesting-code-review`
11. 完成 `verification-before-completion`
12. 完成 `opsx:verify`
13. 完成 `opsx:archive`

如果在 `brainstorming` 或 `opsx:propose` 判断超界：

1. 停止当前轻量链
2. 记录“超界原因”
3. 显式切到 `/product`

## 5. 每个样本必须记录的证据

最少记录下面这些：

1. 需求标题
2. 是否被正确路由到 `brainstorming`
3. 是否顺利进入 `opsx:*`
4. 是否出现中途卡点
5. 是否需要退回标准链
6. 总耗时
7. 最终结果：
   - archive 完成
   - 中途失败
   - 转标准链

推荐附带：

1. change 路径
2. 关键报错
3. review 结论
4. verification 结论

## 6. 试点观察指标

每周至少复盘一次，固定看下面 6 个指标：

1. 成功率
2. 误路由率
3. 退回标准链比例
4. 平均交付时间
5. 返工率
6. 常见卡点分布

建议口径：

- 成功：走到 `opsx:archive`
- 误路由：本应走标准链，却先进入了 community-first
- 退回标准链：轻量链中途终止并改走 `/product`

## 7. 每周复盘问题

固定回答这 7 个问题：

1. 哪些需求被正确识别为小需求
2. 哪些需求被误判
3. `brainstorming` 是否足够完成需求桥接
4. `opsx:*` 是否有高频阻塞
5. 哪些 skill description 仍存在噪音
6. 哪些需求其实更适合直接走标准链
7. 是否需要收紧或放宽小需求边界

## 8. 试点通过标准

满足下面条件，才建议扩大范围：

1. 连续两周样本成功率稳定
2. 误路由率可接受
3. 团队对“小需求边界”已有共识
4. 没有出现 `openspec` 或 adapter 同步类阻断问题
5. 没有因默认流切换导致标准链被弱化

## 9. 试点暂停条件

出现任一情况，暂停试点并回到显式使用：

1. 默认入口频繁误路由
2. `opsx:*` 出现结构性失败
3. 上游模板变化导致 adapter 失真
4. 试点成员普遍无法判断边界
5. 小需求平均交付时间明显劣化

## 10. 试点结束后产出

试点结束时至少补 2 份文档：

1. 一份试点总结
   - 成功率
   - 误路由率
   - 退回标准链比例
   - 主要问题
   - 是否建议扩大范围

2. 一份边界修订
   - 哪些需求应该进 community-first
   - 哪些需求必须显式走标准链

## 11. 相关文档

- RFC：[docs/rfcs/2026-03-26_community-first默认流RFC.md](/Users/lijieli/org-claude-skills/docs/rfcs/2026-03-26_community-first默认流RFC.md)
- 总览：[docs/community-first/README.md](/Users/lijieli/org-claude-skills/docs/community-first/README.md)
- 采用建议：[docs/reports/readiness/2026-03-26_community-first轻量流程采用建议.md](/Users/lijieli/org-claude-skills/docs/reports/readiness/2026-03-26_community-first轻量流程采用建议.md)
- 运行验收：[docs/runtime-acceptance-sop.md](/Users/lijieli/org-claude-skills/docs/runtime-acceptance-sop.md)

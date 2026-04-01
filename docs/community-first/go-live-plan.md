# Community-First 投入使用时机

日期基线：`2026-03-26`

目标：把 “什么时候能投入使用” 说成明确的分级结论，而不是模糊判断。

## 1. 当前结论

截至 `2026-03-26`，结论分 3 档：

1. 个人试点：`可以立即投入使用`
2. 小范围团队试点：`可以在完成本机安装与边界合同校验后投入使用`
3. 团队默认化：`暂时不建议立即投入使用`

## 2. 为什么个人试点现在就可以用

当前已经满足：

1. 仓库全量回归通过
   - `bash tests/run-all.sh`
2. community-first 默认链已打通
   - `brainstorming`
   - `writing-plans`
   - `superpowers` 执行链
3. proposal / design / tasks / verify / archive 语义已可由本地工件层承接
4. 真实小需求样本闭环通过
   - 登录页
   - 本地存储登录态
   - 前后端
   - 动画首页
   - 浏览器验收

所以从“功能可用性”看，已经不是概念验证阶段，而是可进入真实试点阶段。

## 3. 为什么团队试点还要补一个动作

当前团队试点还需要补的是：

- 边界合同与链路合同完成对齐
- 安装后运行面探针与全量回归保持 PASS

先补这两个动作，团队试点就可以启动：

```bash
cd ~/org-claude-skills
bash install.sh --target all --force --merge-hooks --check full
bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills
```

## 4. 为什么还不能直接默认化

虽然方案和样本都已经通过，但还缺 3 类“默认化证据”：

1. 真实业务样本的持续数据
2. 误路由率数据
3. 团队对“小需求边界”的稳定共识

这意味着：

- 现在适合“试点”
- 还不适合“一刀切默认切换”

## 5. 建议时间表

按 `2026-03-26` 为基线，建议这样推进：

### 现在就可以做

`2026-03-26` 当天可做：

1. 在你自己的运行面完成一次正式安装
2. 跑一次边界合同与来源锁定校验
3. 用 1 个真实小需求开始个人试点

### 最早可开始小范围试点

最早从 `2026-03-26` 当天开始，前提是：

1. `bash install.sh --target all --force --merge-hooks --check full` 通过
2. `python3 tools/community/source_lock_check.py` 通过
3. `bash tests/test-superpowers-boundary.sh` 与 `bash tests/test-community-first-boundary.sh` 通过
4. `bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills` 无 `[FAIL]`

满足这 4 条后，就可以让 1-3 人进入试点。

### 最早可讨论默认化

不建议早于下面条件满足前讨论默认化：

1. 连续两周试点数据稳定
2. 每周有 3-5 个真实小需求样本
3. 误路由率可接受
4. 退回标准链比例可接受
5. 没有出现 boundary contract / adapter / validator 同步类阻断

所以更合理的判断是：

- `2026-03-26`：可以开始个人试点
- `2026-03-26` 起：满足前置即可开始小范围团队试点
- 团队默认化：至少在两周稳定试点之后再决定

## 6. 一句话判断

如果你问“现在能不能用”：

- `能`，但定位是**试点投入使用**

如果你问“现在能不能全员默认切过去”：

- `还不能`

## 7. 立即行动建议

最短路径就是 3 步：

1. 在你的真实运行面执行一次完整安装
2. 跑完来源锁定、边界合同和运行面探针校验
3. 立刻挑 1 个真实小需求开始试点

## 8. 相关文档

- 试点执行入口：[docs/community-first/试点执行入口.md](./试点执行入口.md)
- RFC：[docs/rfcs/2026-03-26_community-first默认流RFC.md](../rfcs/2026-03-26_community-first默认流RFC.md)
- 试点清单：[docs/community-first/pilot-rollout-checklist.md](./pilot-rollout-checklist.md)
- 运行验收：[docs/runtime-acceptance-sop.md](../runtime-acceptance-sop.md)

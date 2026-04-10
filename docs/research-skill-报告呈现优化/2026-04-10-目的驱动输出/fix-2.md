# Fix Report 2

## 输入来源与历史引用

- work_dir: `docs/research-skill-报告呈现优化/2026-04-10-目的驱动输出`
- 历史修复报告:
  - `fix-1.md`
- 触发条件:
  - `fix-1.md` 完成后执行 fresh proving command
  - `tests/run-all.sh` 在 `tests/test-install-systematic.sh` 路径上失败
- failure_class: `FIXABLE`

## 与 fix-1 的差异

- `fix-1.md` 已解决 `research` 自身的 contract / 模板 / gate / 回归问题
- 本轮不是重复修 `research`，而是 proving command 进一步暴露了一个仓库级 Codex hooks blocker
- 分析层级从“research skill 输出 contract”升级到“Codex install/uninstall hooks 生命周期”

## 环境快照

- branch: `main`
- 关联工件:
  - `fix-1.md`
  - `design.md`
  - `tasks.md`
  - `plan.md`

## 现象与复现

- 初始 proving command 结果:
  - 命令: `python3 tools/community/check_task_plan_consistency.py docs/research-skill-报告呈现优化/2026-04-10-目的驱动输出/tasks.md docs/research-skill-报告呈现优化/2026-04-10-目的驱动输出/plan.md && bash tests/run-all.sh`
  - 结果: 在 `tests/test-install-systematic.sh` 路径上失败
- 缩小复现:
  - 命令: `bash tests/test-install-systematic.sh`
  - 结果: `[FAIL] non-standard hooks.json baseline should be restored after uninstall`

## 诊断阶段

### 候选假设

1. 假设 A: `tests/test-install-systematic.sh` 本身语法损坏，导致误报
   - 验证: `bash -n tests/test-install-systematic.sh`
   - 结果: 排除。脚本语法正常
2. 假设 B: `render_hook_registry.py` 的 `_org_skills.allowed_events` 让卸载时把 `SessionStart` 过滤掉
   - 验证: 追踪 `install.sh` 中 `cleanup_codex_hooks_json` 的调用，确认卸载时并没有传 `managed_file`
   - 结果: 部分排除。`allowed_events` 不是卸载丢失 baseline 的直接原因
3. 假设 C: 安装流程没有为用户原始 `~/.codex/hooks.json` 建恢复基线，卸载时只能清理受管 hooks，不能恢复原样
   - 验证:
     - 检查 `install.sh:288-309` 仅在安装后执行 `merge_codex_hooks_json`
     - 检查 `install.sh:1367-1371` 卸载时只做 `cleanup_codex_hooks_json`
     - 检查安装状态文件只记录 `config.toml` feature state，没有 `hooks.json` baseline
   - 结果: 确认

### 根因结论

- 根因:
  - Codex 安装流程会在安装后原位改写 `~/.codex/hooks.json`，但此前没有保存安装前 baseline
  - 卸载流程只能删除受管 hooks 和临时探针，无法恢复用户原始非标准事件
- 证据链:
  - 相关安装入口: `install.sh:288-309`
  - 相关卸载入口: `install.sh:1367-1371`
  - 修复落点: `install.sh:264-323`

## 修复四问

| 问题 | 回答 |
|---|---|
| 根因是什么？ | 安装前缺少 `hooks.json` baseline 备份，卸载后只能做 cleanup 不能 restore |
| 修复是否完整？ | 已在安装前补 `snapshot_codex_hooks_json_baseline`，卸载时优先 `restore_codex_hooks_json_baseline`，无 baseline 时仍回退到原 cleanup 逻辑 |
| 是否引入新问题？ | 语义保持最小变化；仅对已存在用户 `hooks.json` 的场景新增备份/恢复，不影响无 baseline 的默认安装 |
| 是否需要补充测试覆盖？ | 现有 `tests/test-install-systematic.sh` 已覆盖该场景，直接作为 RED/GREEN 证据；无需新增重复用例 |

## 处置与改动

- `install.sh`
  - 新增 `codex_hooks_baseline_file`
  - 新增 `snapshot_codex_hooks_json_baseline`
  - 新增 `restore_codex_hooks_json_baseline`
  - 安装阶段在 merge 前保存 baseline
  - 卸载阶段优先恢复 baseline，无 baseline 时保持原 cleanup 逻辑
- `design.md / tasks.md / plan.md`
  - 将 T5 从“标准空事件 blocker fix”扩展为“Codex hooks blocker fixes”，同步记录 baseline restore 修复

## RED / GREEN 证据

- RED:
  - 命令: `bash tests/test-install-systematic.sh`
  - 结果: `[FAIL] non-standard hooks.json baseline should be restored after uninstall`
- GREEN:
  - 命令: `bash tests/test-install-systematic.sh`
  - 结果: `Systematic tests passed: 17, skipped: 0`
- 静态检查:
  - 命令: `bash -n install.sh`
  - 结果: 通过
  - 命令: `shellcheck -x install.sh`
  - 结果: 通过

## 回归影响范围

- 直接影响:
  - Codex install/uninstall hooks 生命周期
  - 安装前存在自定义 `~/.codex/hooks.json` 的用户
- 未触碰:
  - `research` skill 的输出 contract
  - `render_hook_registry.py` 已通过的标准空事件逻辑

## 下一步验证

- fresh proving command:
  - `python3 tools/community/check_task_plan_consistency.py docs/research-skill-报告呈现优化/2026-04-10-目的驱动输出/tasks.md docs/research-skill-报告呈现优化/2026-04-10-目的驱动输出/plan.md`
  - `bash tests/run-all.sh`

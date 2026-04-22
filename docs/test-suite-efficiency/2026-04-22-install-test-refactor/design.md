# Install Test Suite Efficiency Refactor Design

Created: 2026-04-22

## 一页对齐摘要

当前测试套件的主要痛点是安装类测试重复执行真实安装，导致开发内循环被少数系统化脚本拖慢。已采样的慢点包括：

| 测试 | 采样耗时 |
|---|---:|
| `tests/test-install-systematic.sh` | 548s |
| `tests/test-install-runtime-audit.sh` | 66s |
| `tests/test-runtime-integrity.sh` | 55s |
| `tests/test-install-smoke.sh` | 47s |
| `tests/test-platform-runtime-noise.sh` | 33s |
| `tests/test-no-cli-dependency.sh` | 31s |
| `tests/test-install-retired-skill-cleanup.sh` | 25s |
| `tests/test-codex-skill-adapter.sh` | 18s |

本次优化目标不是单纯让测试变快，而是重构安装测试体系：保留旧覆盖面，减少重复安装，提供清晰的 quick/full/profile 入口，并让失败定位到能力边界。

用户裁决为：质量 > 效率。因此默认质量门禁必须保持 full，quick 只能作为显式的开发内循环入口。

## 目标

- 消除 `tests/test-install-systematic.sh` 中大量重复安装带来的主要耗时。
- 将安装测试按能力域拆分为 core、runtime smoke、runtime、safety、migration。
- 用公共 helper 统一 HOME 创建、真实安装执行、baseline 复制、断言和清理。
- 保留旧场景覆盖，并用映射表证明每个旧场景都有新归属或明确删除理由。
- 让 `tests/run-all.sh` 成为唯一权威入口，支持 full、quick、profile、list。
- 提升失败定位质量，让失败输出包含 domain、case、assert、日志路径和关键 expected/actual。

## 非目标

- 不引入跨运行缓存。
- 不让 quick 替代 full 质量门禁。
- 不保留 v2 脚本、旧 wrapper、兼容开关或双轨 README。
- 不把安装类测试直接并行化作为本次第一阶段目标。
- 不顺手修改标准链 schema、fixture、skill 正文等已有脏变更。
- 不承诺所有测试总耗时达到固定百分比下降；本次只对安装测试结构性慢点负责。

## 范围

### In Scope

- `tests/run-all.sh`
- `tests/lib/install-test-env.sh`
- `tests/test-install-core.sh`
- `tests/test-install-runtime-smoke.sh`
- `tests/test-install-safety.sh`
- `tests/test-install-runtime.sh`
- `tests/test-install-migration.sh`
- `tests/test-run-all-runner-contract.sh`
- 安装测试迁移映射文档或设计文档中的映射表
- README 中测试入口说明

### Out of Scope

- 标准链 schema、catalog、fixture 的语义修复
- skill 正文与 runtime contract 的业务内容修改
- CI 平台配置重构
- 新增 `--keep-going`
- 新增独立 `run-quick.sh` 或 `run-full.sh`

## 当前问题定义

### 主要瓶颈

`tests/test-install-systematic.sh` 是当前最大慢点。静态盘点显示它包含约 20 个 `pass "..."` 场景、31 次 `run_install` 调用和 21 次 `new_home` 创建。慢因不是单个断言昂贵，而是重复构造 HOME、重复真实安装、重复 staging/runtime contract 渲染。

`tests/test-install-runtime-audit.sh` 当前约 66s，只有 2 次安装，职责更像 runtime 修复和完整性 audit。它应并入新的 runtime/migration 分层，避免继续保留独立入口噪音。

### 质量风险

若只跳过慢脚本或只做 runner quick，会降低开发耗时，但无法证明旧安装覆盖仍在。正确方向应是结构性拆分和复用真实 baseline，而不是裁剪场景。

## 设计原则

- 正确性优先：默认 full，quick 显式。
- 覆盖可追溯：旧场景必须逐条映射。
- 真实性优先：baseline 必须由真实 `install.sh` 生成。
- 隔离优先：每个 case 使用独立 HOME 或 baseline clone。
- 简化入口：一个 runner，多种模式；不新增旁路脚本。
- 一步到位：删除旧 systematic/runtime-audit 入口，不保留过渡 wrapper。
- 先消除重复，再考虑并行。

## 设计裁决

按 Essential vs Accidental Complexity 判断：

- Essential complexity：安装测试必须覆盖真实安装、修复、安全、迁移和用户文件保护。这些复杂度不能删除，只能重新分层。
- Accidental complexity：重复 HOME 创建、重复真实安装、巨大 systematic 脚本、入口语义不清、失败输出不聚焦。这些复杂度应消除。

按简单/合适/演化三原则判断：

- 简单：保留一个 runner，不新增旁路脚本。
- 合适：用 helper 收敛安装测试重复逻辑，而不是让每个测试脚本复制环境搭建。
- 演化：先建立 quick/full/profile/list 的稳定合同，后续如需并行或 keep-going，另起明确需求。

按 L1-L4 裁决，本次属于 L2/L3 级测试体系重构：影响开发入口和质量门禁，但不改变业务 runtime 合同。因此需要设计文档、迁移映射和 fresh proving commands，不需要引入新的平台或 CI 架构。

## 不可破坏的不变量

- 裸跑 `bash tests/run-all.sh` 必须执行 full。
- `--quick` 不能包含安全、迁移、完整 runtime audit 等 full-only 场景。
- `--profile` 只能增加观测输出，不能改变测试集合、断言或退出码。
- `--list` 必须无副作用，不能执行安装或创建测试 HOME。
- baseline 必须由真实 `install.sh` 生成，且只能在单个测试脚本进程内复用。
- 每个 case 必须使用独立 HOME 或 baseline clone。
- 旧安装场景必须有新归属或明确删除理由。
- 新测试失败必须能定位到 domain/case/assert。

## 下游影响

- 开发者日常命令从“直接跑全量慢测试”变成“开发中跑 `--quick`，交付前跑 full”。
- CI 若当前调用 `bash tests/run-all.sh`，语义保持 full，不降低质量门禁。
- README 需要更新为单一真源，不保留旧 systematic/runtime-audit 入口说明。
- 后续实现计划需要先建立旧场景映射表，再删除旧脚本，避免下游看不到覆盖迁移证据。
- 若当前工作区存在标准链/fixture 既有失败，最终报告要明确区分本次 runner 优化结果与非本次阻塞。

## 推荐方案

采用“测试工具层 + 场景分层 + 单进程 baseline 复用”的方案。

备选方案对比：

| 方案 | 做法 | 优点 | 缺点 | 结论 |
|---|---|---|---|---|
| A. 只改 runner | 增加 `--quick`，跳过最慢脚本 | 改动小，见效快 | 质量覆盖仍依赖慢脚本，系统化问题未解决 | 不足够 |
| B. 拆测试但不抽 helper | 直接把 systematic 拆成多个脚本 | 层次更清楚 | 重复 `new_home/run_install/assert` 扩散，后续维护成本高 | 不推荐 |
| C. 工具层 + 分层 + baseline 复用 | 抽公共 helper，按能力域拆分测试，局部修复类 case 复用 baseline clone | 兼顾质量、效率、可维护性 | 初次改动更大，需要映射表和验证 | 推荐 |

## 测试分层架构

最终结构：

```text
tests/lib/install-test-env.sh
tests/test-install-core.sh
tests/test-install-runtime-smoke.sh
tests/test-install-safety.sh
tests/test-install-runtime.sh
tests/test-install-migration.sh
```

职责划分：

| 文件 | 职责 | quick/full |
|---|---|---|
| `tests/lib/install-test-env.sh` | 公共测试工具，创建 HOME、运行安装、复制 baseline、断言运行时文件、统一清理 | 不直接执行 |
| `tests/test-install-core.sh` | 无 CLI 依赖、dry-run、冲突阻断、基础安装、幂等、产品 split 修复 | quick + full |
| `tests/test-install-runtime-smoke.sh` | 安装后关键 hooks、agents、contracts、Codex/Claude runtime shape 存在 | quick + full |
| `tests/test-install-safety.sh` | 卸载安全、失败回滚、重复 force 后恢复用户文件 | full |
| `tests/test-install-runtime.sh` | managed hooks、Codex config、retired skill 清理、installed completion gate、局部损坏修复 | full |
| `tests/test-install-migration.sh` | 旧 `.org-*` 元数据迁移、旧 `.claude` git 退役、软链接 skill 迁移、pruned manifest 恢复 | full |

分层规则：测试按语义分层，不按耗时分层。quick/full 只是选择不同层级，测试文件本身必须围绕安装能力边界命名。

## Baseline 复用设计

`tests/lib/install-test-env.sh` 提供：

```text
new_home
run_install
create_baseline_home
clone_baseline_home
assert_runtime_shape
cleanup_test_env
```

核心约束：

1. baseline 只能由真实 `install.sh` 生成。
2. baseline 只在单个测试脚本进程内复用。
3. baseline 不落长期缓存目录，不跨脚本共享，不跨 `run-all` 运行共享。
4. 每个 case 必须复制 baseline 后再破坏副本。
5. baseline 只用于“合法已安装 runtime 局部损坏后验证修复”的场景。

禁止使用 baseline 的场景：

| 场景 | 环境类型 |
|---|---|
| 首次安装 | `fresh-home` |
| dry-run | `fresh-home` |
| 冲突阻断 | `fresh-home` |
| 失败回滚 | `fresh-home` |
| 卸载安全 | `fresh-home` |
| 旧 `.org-*` 元数据迁移 | `constructed-legacy-home` |
| 旧 `.claude` git 退役 | `constructed-legacy-home` |
| 软链接 skill 迁移 | `constructed-legacy-home` |
| 用户文件保护 | `fresh-home` 或 `constructed-legacy-home` |

允许使用 baseline 的场景：

| 场景 | 环境类型 |
|---|---|
| 删除 managed hook 后重装修复 | `baseline-clone` |
| 删除 runtime contract 后重装修复 | `baseline-clone` |
| 删除 retired skill 后验证不会恢复 | `baseline-clone` |
| 局部破坏 Codex config 后重装修复 | `baseline-clone` |
| installed completion gate 的已安装状态校验 | `baseline-clone` |

## 旧场景映射与遗漏防护

实施前必须从以下脚本提取旧场景：

```text
tests/test-install-systematic.sh
tests/test-install-runtime-audit.sh
```

设计文档或实施文档中必须包含映射表：

| 旧脚本 | 旧 case / pass 文案 | 新测试文件 | 环境类型 | quick/full | 保留的质量断言 | 处理状态 |
|---|---|---|---|---|---|---|

映射规则：

- `tests/test-install-systematic.sh` 中每个 `pass "..."` 都必须有新归属。
- 多个旧 case 可以合并，但断言必须仍可定位。
- 删除旧 case 必须写明理由。
- 删除理由只允许三类：
  - 被更强的新断言覆盖。
  - 旧场景验证的是已退役行为。
  - 旧测试重复验证同一条 contract。
- `tests/test-install-runtime-audit.sh` 的职责应并入 `tests/test-install-runtime.sh` 或 `tests/test-install-migration.sh`，并在完全并入后删除旧文件。
- quick/full 不是覆盖理由；不进 quick 的场景仍必须迁移到 full。

验收等式：

```text
旧场景总数 = 已迁移场景数 + 有明确理由删除场景数
```

该等式不成立，不算完成。

## Runner 策略

保留唯一权威入口：

```text
bash tests/run-all.sh
bash tests/run-all.sh --quick
bash tests/run-all.sh --profile
bash tests/run-all.sh --quick --profile
bash tests/run-all.sh --list
bash tests/run-all.sh --quick --list
```

模式定义：

| 模式 | 定位 | 约束 |
|---|---|---|
| 默认 full | 发布前、提交前、CI 门禁、质量证明 | 裸跑 `run-all.sh` 必须是 full |
| `--quick` | 开发内循环 | 显式传参才启用 |
| `--profile` | 性能观测 | 不改变测试集合、断言或退出码 |
| `--list` | 覆盖审计 | 无副作用，不创建临时 HOME，不执行安装 |

quick 建议包含：

```text
tests/test-install-core.sh
tests/test-install-runtime-smoke.sh
tests/test-run-all-runner-contract.sh
runtime/catalog/contract 的快速一致性测试
不依赖大量重复 install 的 schema / manifest / chain 基础测试
```

quick 不包含：

```text
tests/test-install-safety.sh
tests/test-install-runtime.sh
tests/test-install-migration.sh
大规模 systematic / end-to-end 风格测试
```

full 必须包含 quick 全部测试和 full-only 测试。

`--profile` 输出至少包含：

```text
当前模式
每个测试文件耗时
总耗时
最慢 N 个测试
```

`--list` 输出至少包含：

```text
mode: quick/full
test count
test files
quick 模式下被 full-only 排除的安装类大项
```

默认保留 fail-fast。`--keep-going` 不进入本次范围。

## 失败定位与错误输出

失败信息分三层：

```text
runner 层：哪个测试文件失败
case 层：哪个安装场景失败
assert 层：哪个预期不满足，实际是什么
```

公共 helper 建议提供：

```text
case_start "core: first install creates runtime shape"
case_pass  "core: first install creates runtime shape"

assert_file_exists "$path" "runtime contract should exist"
assert_file_absent "$path" "retired skill should be removed"
assert_file_contains "$path" "$needle" "codex config should include managed section"
assert_same_file "$expected" "$actual" "manifest should match rendered output"
assert_exit_code "$expected" "$actual" "install should block conflicting user file"
```

失败输出示例：

```text
FAIL: runtime: repair missing codex hook
reason: expected file exists
path: /tmp/.../.codex/hooks/pre-tool-use.sh
install log: /tmp/.../install.log
last output:
  ...
```

规则：

- case 名称按能力域命名：`core:`、`safety:`、`runtime:`、`migration:`。
- 每个 case 独立日志。
- 断言失败必须输出 expected/actual。
- runner 不吞失败码。
- 默认清理临时目录。
- 允许显式调试开关 `KEEP_TEST_HOME=1` 保留失败现场。

`KEEP_TEST_HOME=1` 是调试能力，不是过渡期噪音。

## 验证策略

### 质量覆盖证明

必须证明：

```text
旧 test-install-systematic.sh 每个 pass 场景都有新归属
旧 test-install-runtime-audit.sh 的职责已并入或有明确保留理由
映射表里没有 unknown / todo / later
被删除场景都有删除理由
```

### 行为正确证明

fresh proving commands：

```text
bash tests/test-install-core.sh
bash tests/test-install-runtime-smoke.sh
bash tests/test-install-safety.sh
bash tests/test-install-runtime.sh
bash tests/test-install-migration.sh
bash tests/test-run-all-runner-contract.sh
bash tests/run-all.sh --quick
bash tests/run-all.sh
```

### Runner 合同证明

fresh proving commands：

```text
bash tests/run-all.sh --list
bash tests/run-all.sh --quick --list
bash tests/run-all.sh --quick --profile
bash tests/run-all.sh --profile
```

检查点：

```text
默认 run-all 是 full
quick 显式模式才启用
profile 不改变测试集合
list 无副作用
未知参数会失败
```

### 效率证明

fresh proving commands：

```text
bash tests/run-all.sh --quick --profile
bash tests/run-all.sh --profile
```

成功信号：

```text
安装测试专项耗时显著下降
run-all profile 中不再由单个 systematic 脚本占 500s+
quick 路径不包含 full-only 安装安全/迁移长测
quick 能进入开发内循环
```

不在设计阶段承诺固定百分比，因为 full 总耗时还受 `tests/test-runtime-integrity.sh` 等其他慢测试影响。

### 代码质量证明

fresh proving commands：

```text
bash -n tests/run-all.sh
bash -n tests/lib/install-test-env.sh
bash -n tests/test-install-core.sh
bash -n tests/test-install-runtime-smoke.sh
bash -n tests/test-install-safety.sh
bash -n tests/test-install-runtime.sh
bash -n tests/test-install-migration.sh
shellcheck -x tests/run-all.sh tests/lib/install-test-env.sh tests/test-install-*.sh
git diff --check
```

若环境没有 `shellcheck`，必须明确说明未执行，不能声称通过。

## 成功标准

P0：

- 旧安装场景映射完整，无旧场景无归属。
- 新安装测试分层全部通过。
- `tests/run-all.sh` 默认 full，quick 显式。
- quick/profile/list runner 合同通过。
- `tests/test-install-runtime-audit.sh` 职责已并入或有明确保留理由。按当前设计，倾向并入后删除。

P1：

- quick 耗时显著低于旧 full 安装链路。
- full 不再出现单个 500s+ systematic 脚本。
- 失败输出能定位到 domain/case/assert。

## 实施顺序

1. 盘点旧场景，建立迁移映射表。
2. 新建 `tests/lib/install-test-env.sh`。
3. 迁移 core 和 runtime smoke，先保障 quick 主链。
4. 迁移 safety、runtime、migration。
5. 并入 `tests/test-install-runtime-audit.sh` 职责。
6. 更新 `tests/run-all.sh` 的 full/quick/profile/list。
7. 更新 runner contract 测试。
8. 删除旧 `tests/test-install-systematic.sh` 和已并入的 `tests/test-install-runtime-audit.sh`。
9. 更新 README 测试说明。
10. 运行 fresh proving commands。

旧脚本删除是最后一步，不是第一步。

## 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| baseline 被误用于迁移/安全类测试 | 覆盖变薄，假绿 | 映射表标注环境类型；helper 文档写明禁用场景 |
| quick 被误当质量门禁 | 质量下降 | 默认 full；README 明确交付前跑 full |
| 拆分后断言散落 | 维护成本上升 | 公共 helper 统一断言和日志 |
| 旧场景迁移遗漏 | 质量下降 | 映射表验收等式 |
| 当前脏工作区已有非本次失败 | 全量验收混淆 | 最终报告区分本次相关失败和既有标准链失败 |
| 过早并行导致偶发失败 | 定位成本上升 | 本次不做安装测试并行 |

## 当前仓库现实注意事项

采样期间观察到 `tests/test-chain-completeness.sh` 在当前工作区失败，原因是 catalog artifact set mismatch。该问题看起来属于已有标准链/fixture 变更同步问题，不应混入本次安装测试 runner 优化。

最终验收报告必须区分：

```text
本次优化相关测试是否通过
全量 run-all 是否被当前已有脏变更阻塞
```

若要声称全量质量门禁可用，仍必须给出 `bash tests/run-all.sh` 的 fresh 结果：通过，或明确被哪项既有问题阻塞。

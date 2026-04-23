我未读取或依赖 `shared/skills/design/SKILL.md`，未联网，未写文件，未运行长链路 validator。以下只基于 eval prompt、PRD/UNIT、样例 canonical 产物与两个 validator 脚本做设计判断。

**理解确认**

目标是为 `sample-feature` 的 Phase 1 设计一套可落地方案：让 standard-chain runtime 不再被“像文档的产物”绕过，canonical JSON 成为唯一控制源。PRD 的退出条件是 `runtime state CLI passes`，UNIT 的闭环是 `foundation registry, schema, template, and catalog are frozen`。

扫描到的基础设施事实：

- phase validator：`validate_standard_chain_phase.py` 是 fail-closed pipeline，包含 normalize、schema、rules、evidence refs、projection manifest 校验，并拒绝 legacy markdown runtime source。
- readiness gate：`validate_standard_chain_readiness.py` 在 phase validator 上追加必需文件、产品闭环、task runtime identity、code review、QA A-D、audit、registry active artifact、authority proof、signoff、replay oracle。
- 阻断事实：当前 eval workspace 里只有两个 validator 脚本；readiness 脚本导入的 `manage_artifact_registry.py`、`normalize_canonical_artifact.py`、`validate_readiness_contract.py` 等 helper 不存在。因此本轮不能声称 readiness gate 可真实运行，只能设计其契约与补齐路径。

**方案 A：Canonical Registry + Delivery-State 双控制源**

核心设计：`artifact-registry.json` 负责“哪些产物可被消费”，`delivery-state.json` 负责“当前 phase/task 处于什么运行状态”。readiness gate 只接受 active registry entries 指向的 finalized canonical JSON，并用 delivery-state 校验阶段、任务状态和阻断恢复链。

取舍：

- 优点：贴合现有 fixture 与 validator 结构；fail-closed；回滚可通过 append-only registry revision + quarantine 实现。
- 成本：需要维护 registry、delivery-state、authority proof、signoff、replay oracle 多个产物之间的一致性。
- 风险：当前 helper 缺失时无法证明 gate 真实可执行，必须补齐依赖后再进入实现验收。

**方案 B：单一 Manifest 驱动 Readiness**

核心设计：把 phase 所需产物、active refs、stage、QA、signoff、replay 入口汇总到一个 readiness manifest，validator 只消费 manifest，再反查文件存在性和 digest。

取舍：

- 优点：入口少，validator 逻辑更集中，操作员更容易理解。
- 成本：会引入新的控制产物，与现有 registry/delivery-state 职责重叠。
- 风险：把状态、索引、签收闭包压进一个 manifest，容易形成新的“万能文档”，与 canonical JSON 分职责的方向冲突。

**收敛建议**

推荐方案 A。理由是它保留了问题域的必要复杂度：registry 管消费权，delivery-state 管运行阶段，readiness gate 管闭环证明。方案 B 的简化主要是入口层面的简化，会增加职责重叠和未来漂移风险。

设计必需字段建议：

- `input_analysis`：说明 canonical JSON、registry、delivery-state、readiness gate 的关系。
- `key_decisions`：选择 registry 控制 path discovery，delivery-state 控制 runtime stage。
- `interface_boundary`：锁定 phase validator、readiness validator、registry manager、delivery-state updater、canonical ref resolver。
- `quality_attributes`：fail-closed、append-only history、explicit recovery、replayable evidence。
- `option_analysis`：至少记录方案 A/B 的取舍与选择理由。
- `runtime_facts`：记录当前脚本 pipeline、readiness 额外 gate、helper 缺失事实。
- `interfaces`：定义 registry、delivery-state、readiness gate 的输入、输出、失败模式。
- `migration_plan`：拒绝 legacy markdown runtime source，补齐 catalog/helper 后切 canonical-only。
- `verification_plan`：phase validator、readiness validator、replay oracle、negative freeze/quarantine fixture。
- `rollback_plan`：cutover 失败时 freeze phase，quarantine unfinished artifacts，恢复 finalized active revision。

**门禁与阻断**

进入实现前门禁：

- brief / phase-prd review 已 PASS，Director lock digest 不漂移。
- UNIT AC 能追到 validator/readiness 的真实验收点。
- helper 脚本与 catalog/profiles 在 workspace 或运行环境可用。
- 不能保留 legacy runtime markdown source。

阻断条件：

- readiness helper 依赖不可读或不可执行。
- active registry 与实际 artifact 文件不一致。
- QA A-D 任一 stage 非 PASS 或缺 evidence refs。
- signoff / authority proof / consistency audit 不闭环。
- replay oracle 不存在或 replay 不通过。

下一步：先确认采用方案 A；随后补齐或定位 readiness helper 依赖，再生成正式 `design.json`，交给后续 plan/tasks 拆分。
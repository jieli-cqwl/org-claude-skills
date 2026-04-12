# fix-1

## 输入来源

- 用户指令：运行 `tests/run-all.sh`
- 失败命令：`bash tests/run-all.sh`
- 失败阶段：`[2/36] shellcheck`

## 环境快照

- 分支：`main`
- 相关文件：
  - `tests/test-skill-output-and-gate-contract.sh`
  - `tests/test-closeout-routing.sh`
  - `tests/run-all.sh`

## 现象

### 问题 1

- 现象：`tests/run-all.sh` 在 `shellcheck` 阶段退出。
- 证据：
  - `tests/test-skill-output-and-gate-contract.sh:42`
  - `tests/test-skill-output-and-gate-contract.sh:48`
  - `SC2016: Expressions don't expand in single quotes, use double quotes for that.`

## 假设验证

| 假设 | 验证方法 | 结果 |
|------|----------|------|
| H1：`run-all.sh` 自身的 shellcheck 参数配置错误，导致 info 级别被错误升级 | 单独执行 `shellcheck -x tests/test-skill-output-and-gate-contract.sh`，观察是否直接在文件内报错 | 排除。`shellcheck` 单独执行仍在同两行报 `SC2016`，说明问题在被检查文件本身 |
| H2：根因是断言文本使用单引号包裹，内部又包含 Markdown 反引号，触发 `SC2016` | 检查 `tests/test-skill-output-and-gate-contract.sh:42,48` 和 `tests/test-closeout-routing.sh:42`；这些行都符合“单引号内含成对反引号”的模式，且被 `shellcheck` 命中 | 确认 |
| H3：问题只存在于 `test-skill-output-and-gate-contract.sh`，修这一处即可 | 对相关测试文件单独执行 `shellcheck -x`，发现 `tests/test-closeout-routing.sh:42` 也有同类 `SC2016` | 排除；需要一并修复同类模式 |

## 根因结论

- `failure_class`: `FIXABLE`
- 根因位置：
  - `/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh:42`
  - `/Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh:48`
  - `/Users/lijieli/org-claude-skills/tests/test-closeout-routing.sh:42`
- 根因说明：
  - 这些断言把包含 Markdown 反引号的匹配文本放进了单引号字符串。
  - `shellcheck` 将这种写法识别为 `SC2016` 风险模式，导致 `shellcheck` 退出非零，进而让 `tests/run-all.sh` 在第 2 步停止。
  - 因果链：断言字符串写法 -> `shellcheck` 报 `SC2016` -> `tests/run-all.sh` 早停。

## 修复四问

1. 根因是什么？
   - 单引号包裹了带反引号的断言文本，触发 `SC2016`。
2. 修复是否完整？
   - 已覆盖本次验证命中的 3 处同类模式。
3. 是否引入新问题？
   - 低风险。仅修改 shell 字符串定界方式，保留原有匹配文本语义。
4. 是否需要补充测试覆盖？
   - 不需要新增测试；现有 `shellcheck` 和 `tests/run-all.sh` 已构成回归覆盖。

## 处置

- 将上述断言改为双引号字符串，并对反引号做显式转义，保持匹配文本不变。

## RED / GREEN

- RED：
  - `bash tests/run-all.sh` 在 `[2/36] shellcheck` 失败
  - `shellcheck -x tests/test-skill-output-and-gate-contract.sh tests/test-closeout-routing.sh` 报 `SC2016`
- GREEN：
  - 待本轮 fresh proving command 重新执行并记录

## 回归影响范围

- 受影响范围仅限 shell 测试脚本的断言字符串写法。
- 不影响业务 skill 内容、gate 脚本逻辑和 eval 产物格式。

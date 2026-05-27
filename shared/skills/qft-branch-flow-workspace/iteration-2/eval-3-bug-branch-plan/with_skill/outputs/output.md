第 4 步：确认操作计划

已确认场景：线上 BUG
已确认版本号：0301
已确认涉及项目：

1. 全房通 APP
   仓库名：qft-harmonyos-vue3
   主分支：master

2. 全房通租客端 H5
   仓库名：qft-universal.gitersal
   主分支：master

本次线上 BUG 分支计划分两段执行：

第一段：创建紧急 BUG 修复分支

1. 全房通 APP qft-harmonyos-vue3
   主分支：master
   来源分支：V.0301
   目标分支：3.0.0.MASTER_BUG_0301
   操作：从版本部署分支创建紧急 BUG 分支

2. 全房通租客端 H5 qft-universal.gitersal
   主分支：master
   来源分支：V.0301
   目标分支：3.0.0.MASTER_BUG_0301
   操作：从版本部署分支创建紧急 BUG 分支

第二段：修复完成后回合版本部署分支

1. 全房通 APP qft-harmonyos-vue3
   主分支：master
   来源分支：3.0.0.MASTER_BUG_0301
   目标分支：V.0301
   操作：将紧急 BUG 分支合并回版本部署分支

2. 全房通租客端 H5 qft-universal.gitersal
   主分支：master
   来源分支：3.0.0.MASTER_BUG_0301
   目标分支：V.0301
   操作：将紧急 BUG 分支合并回版本部署分支

确认以上计划正确请输入：确认计划

未收到 `确认计划` 前，不做 Git 写操作。

---

收到 `确认计划` 后，我会先进入执行前检查，只检查以下内容：

- 当前目录是否是对应 Git 仓库
- remote 是否匹配仓库名
- 工作区是否干净
- 来源分支 V.0301 是否存在
- 目标分支 3.0.0.MASTER_BUG_0301 是否已存在
- 本地和远端状态是否需要 fetch/pull

检查通过后，我会这样请求执行确认：

第 5 步：确认执行创建 BUG 分支

准备执行本地操作：

1. 全房通 APP qft-harmonyos-vue3
   主分支：master
   从：V.0301
   创建：3.0.0.MASTER_BUG_0301

2. 全房通租客端 H5 qft-universal.gitersal
   主分支：master
   从：V.0301
   创建：3.0.0.MASTER_BUG_0301

确认执行请输入：确认执行

未收到 `确认执行` 前，不创建本地分支。

---

本地 BUG 分支创建完成后，我会单独询问是否推送远端：

第 6 步：确认是否推送紧急 BUG 分支

本地已处理分支：

1. 全房通 APP qft-harmonyos-vue3
   主分支：master
   待推送分支：3.0.0.MASTER_BUG_0301

2. 全房通租客端 H5 qft-universal.gitersal
   主分支：master
   待推送分支：3.0.0.MASTER_BUG_0301

请选择 push 方式：

1. 推送全部已处理分支
2. 只推送指定项目
3. 暂不推送

请输入编号：

如果选择 1 或 2，我会列出最终待推送仓库和分支，并要求你输入：确认推送

未收到 `确认推送` 前，不执行 push。

---

BUG 修复完成后，请回来告诉我：修复完成，准备合回 V.0301

我会继续这样确认：

第 7 步：确认修复后回合计划

准备将紧急 BUG 分支合回版本部署分支：

1. 全房通 APP qft-harmonyos-vue3
   主分支：master
   来源分支：3.0.0.MASTER_BUG_0301
   目标分支：V.0301
   操作：合并紧急 BUG 修复到版本部署分支

2. 全房通租客端 H5 qft-universal.gitersal
   主分支：master
   来源分支：3.0.0.MASTER_BUG_0301
   目标分支：V.0301
   操作：合并紧急 BUG 修复到版本部署分支

确认回合计划正确请输入：确认计划

未收到 `确认计划` 前，不做合并操作。

---

回合计划确认后，我会先检查工作区、remote、来源分支和目标分支；检查通过后再请求执行确认：

第 8 步：确认执行回合到 V.0301

准备执行本地合并：

1. 全房通 APP qft-harmonyos-vue3
   主分支：master
   将：3.0.0.MASTER_BUG_0301
   合并到：V.0301

2. 全房通租客端 H5 qft-universal.gitersal
   主分支：master
   将：3.0.0.MASTER_BUG_0301
   合并到：V.0301

确认执行请输入：确认执行

未收到 `确认执行` 前，不执行本地合并。

如遇冲突，我会立即停止并列出冲突文件，不自动解决冲突。

---

本地回合完成后，我会再次单独询问是否推送远端：

第 9 步：确认是否推送 V.0301

本地已更新版本部署分支：

1. 全房通 APP qft-harmonyos-vue3
   主分支：master
   待推送分支：V.0301

2. 全房通租客端 H5 qft-universal.gitersal
   主分支：master
   待推送分支：V.0301

请选择 push 方式：

1. 推送全部已处理分支
2. 只推送指定项目
3. 暂不推送

请输入编号：

如果选择 1 或 2，我会列出最终待推送仓库和分支，并要求你输入：确认推送

未收到 `确认推送` 前，不执行 push。

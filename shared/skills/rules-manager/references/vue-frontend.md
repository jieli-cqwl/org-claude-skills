# Vue 2/3 前端规则模板

## 架构级问题（init Step 2 使用）

1. 这个项目用的是 Vue 2 还是 Vue 3？用 Options API 还是 Composition API（setup）？
2. 状态管理用什么？Vuex（Vue 2）还是 Pinia（Vue 3）？还是不用全局状态管理？
3. 组件库用的是什么？Element UI/Element Plus、Ant Design Vue、还是自研？

## 规则草稿 + 共创提问（init Step 3 使用）

### 规则 1：组件规范

```
组件文件名使用 PascalCase（如 UserProfile.vue），与组件注册名一致。
单文件组件顺序固定：<template> → <script> → <style>。
组件 props 必须声明类型和默认值，禁止 props: ['xxx'] 数组语法。
```

**共创提问**：你们的组件命名有没有前缀约定（业务组件 Biz、通用组件 Base）？组件按功能目录还是按类型目录组织？

### 规则 2：状态管理

```
全局状态必须通过 Vuex/Pinia 管理，禁止 EventBus 或 window 全局变量。
Store 按业务域拆分模块，禁止单一巨型 Store。
异步操作（API 调用）放在 Store 的 actions 中，组件禁止直接调用 API。
```

**共创提问**：你们有没有用 EventBus 或 provide/inject 传递状态的场景？API 调用是集中在 Store 还是允许组件直接调？

### 规则 3：API 调用规范

```
API 请求统一通过 api/ 目录下的模块文件发起，禁止在组件中直接写 axios.get/post。
请求拦截器统一处理 token 注入、错误码映射和登录态失效。
API 函数命名使用动词开头（getUser、createOrder、deleteItem）。
```

**共创提问**：你们用 axios 还是 fetch？有没有封装统一的 request 工具？错误处理是全局拦截器统一弹提示还是各调用点自行处理？

### 规则 4：路由规范

```
路由配置集中在 router/ 目录，按业务模块拆分子路由文件。
需要鉴权的页面必须通过路由守卫（beforeEach）校验，禁止在页面内自行判断。
路由 path 使用 kebab-case，name 使用 PascalCase。
```

**共创提问**：你们有动态路由（后端返回权限后动态注册）吗？有 keep-alive 缓存策略吗？

### 规则 5：样式规范

```
组件样式必须使用 scoped 或 CSS Modules，禁止全局样式污染。
颜色、字号、间距必须引用主题变量，禁止硬编码魔法数值。
禁止使用 !important 覆盖组件库样式。
```

**共创提问**：你们用什么 CSS 预处理器（SCSS/Less）？有设计系统或主题变量文件吗？响应式适配策略是什么？

### 规则 6：类型安全（Vue 3 + TypeScript 适用）

```
组件 props、emits、composables 必须有 TypeScript 类型定义。
禁止使用 any 类型，必须定义具体接口。
API 响应数据必须定义对应的 TypeScript interface。
```

**共创提问**：你们用 TypeScript 还是纯 JavaScript？类型定义就近放还是集中到 types/ 目录？

> 注意：Vue 2 + JS 项目跳过此规则。共创时确认技术选型后决定是否包含。

## 生成的规则文件 paths 配置

```yaml
---
paths:
  - "**/*.vue"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---
```

> 如果前后端在同一仓库且有明确目录分隔（如 `frontend/`），paths 应缩窄为 `frontend/**/*.vue` 等。共创时确认目录结构后调整。

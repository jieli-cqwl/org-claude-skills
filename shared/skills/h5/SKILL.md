---
name: h5
user-invocable: true
description: UniApp + Vue3 移动端页面开发。Use when 开发移动端/H5/小程序页面、涉及 rpx 布局和触摸交互。
argument-hint: "[页面需求]"
---
# H5 -- 移动端交互体验开发
## HARD-GATE

1. NO execution without UniApp 3.0 project (pages.json + manifest.json existing).
2. NO touch target smaller than 88rpx (44px).
3. NO animation using properties other than transform/opacity (60fps guarantee).
4. NO color/spacing literal — REQUIRED to use SCSS variables ($text-blue, $bgc-page, etc.).

## 角色

你是 UniApp + Vue3 移动端开发专家。你的页面在低端安卓机上也流畅运行。详细的颜色系统、间距、字体、组件命名规范见 `references/样式系统规范.md`。

## 技术栈

UniApp 3.0 + Vue3 + TypeScript + Pinia + z-paging + SCSS (rpx)

## 三个即时原则

| 原则 | 标准 |
|------|------|
| 即时反馈 | < 100ms 触摸视觉变化 |
| 流畅动画 | 60fps，只用 transform/opacity |
| 容错友好 | 错误提示说人话、给出路 |

## 流程

1. 识别页面类型 — 列表页(z-paging) / 表单页(comp-form-configure) / 详情页 / 多步骤表单(Pinia)
2. 应用样式系统 — 颜色变量 + rpx 间距(优先 20rpx/32rpx) + 字体(正文 28rpx)
3. 组件选型 — comp-xxx 命名，详见 `references/组件开发规范.md` 和 `references/交互组件规范.md`
4. 移动端适配 — 触摸目标 >= 88rpx + 竖屏优先 + safe-area-inset-bottom
5. 性能检查 — 长列表虚拟滚动 + 图片懒加载 + 防抖

## 参考文档索引

| 文档 | 内容 |
|------|------|
| `references/样式系统规范.md` | 颜色、间距、字体、圆角、阴影 |
| `references/组件开发规范.md` | 组件命名、Props、样式组织 |
| `references/页面模式规范.md` | 列表页、表单页、详情页模板 |
| `references/交互组件规范.md` | 弹窗、菜单、提示、空状态 |
| `references/最佳实践.md` | 防抖、键盘、安全区、条件编译 |
| `references/状态管理规范.md` | Pinia Store 目录、命名、多步骤表单、列表筛选 |
| `references/路由规范.md` | 页面路径命名、导航API、参数传递、路由守卫、分包 |
| `references/TypeScript规范.md` | 类型文件位置、API响应类型、表单类型映射 |
| `references/目录结构规范.md` | 项目目录结构、命名规范、组件存放位置 |
| `references/项目初始化规范.md` | 项目创建、依赖安装、easycom、manifest配置 |

## 输出

- Vue/SCSS 文件（在项目对应目录中创建或修改）
- 对话中的实现说明（页面类型 + 组件选型 + 适配要点）

## 完成校验

- [ ] 颜色使用 SCSS 变量（Grep 无 `#[0-9a-fA-F]{3,8}` 字面量）
- [ ] 间距使用 rpx（优先 20rpx/32rpx）
- [ ] 触摸目标 >= 88rpx
- [ ] 按钮有 loading + 表单有验证 + 列表有空状态

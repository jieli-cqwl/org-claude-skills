# TypeScript 规范

## 类型文件位置

| 文件 | 内容 |
|------|------|
| `types/api.d.ts` | API 响应类型 |
| `types/model.d.ts` | 业务实体、表单类型 |
| `types/store.d.ts` | Store 状态类型 |
| 组件文件内 | Props/Emits 类型 |
| 工具文件内 | 工具函数参数类型 |

## 通用 API 类型

```typescript
interface ApiResponse<T = any> { code: number; message: string; data: T }
interface PageResult<T> { records: T[]; total: number; page: number; size: number }
interface PageParams { pageNo: number; pageSize: number }
```

## 业务模型示例

```typescript
interface Tenant { id: number; name: string; phone: string; idCard: string; status: TenantStatus; createTime: string }
type TenantStatus = 'normal' | 'expired' | 'pending'
interface Contract { id: number; tenantId: number; roomId: number; startDate: string; endDate: string; rent: number; deposit: number; status: ContractStatus }
type ContractStatus = 'draft' | 'signed' | 'terminated'
```

## 表单类型映射

```typescript
type FormItemMap<T> = {
  [K in keyof T]: { type: 'input' | 'picker' | 'date'; label: string; required?: boolean; placeholder?: string }
}
```

## tsconfig 关键配置

- `"types": ["@dcloudio/types"]`
- `"paths": { "@/*": ["./src/*"] }`
- `"strict": true`

## 声明文件

`shims-uni.d.ts` 声明 `*.vue` 模块和 UniApp 扩展类型（`$emit/$on/$off`）

## 规则

- 避免 `any`，必要时用泛型或 `unknown`
- 组件 ref 类型：`ref<InstanceType<typeof CompXxx> | null>(null)`
- 表单/创建用 `Omit<Entity, 'id' | 'createTime'>`，更新用 `Partial<Entity>`

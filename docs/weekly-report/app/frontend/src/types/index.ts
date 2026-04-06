/* 前端类型定义：与后端 Pydantic 模型对应。 */

/** 用户信息（不含密码） */
export interface User {
  id: number;
  username: string;
  display_name: string;
  role: string;
}

/** POST /api/login 成功响应 */
export interface LoginResponse {
  token: string;
  user: User;
}

/** 周报列表项 */
export interface ReportItem {
  id: number;
  title: string;
  author_name: string;
  created_at: string;
}

/** 分页信息 */
export interface PaginationInfo {
  page: number;
  page_size: number;
  total: number;
  total_pages: number;
}

/** GET /api/reports 成功响应 */
export interface ReportsResponse {
  data: ReportItem[];
  pagination: PaginationInfo;
}

/** FastAPI HTTPException 错误格式（detail 可能是对象、字符串或数组） */
export interface ApiErrorObject {
  code: string;
  message: string;
}

export type ApiErrorDetail =
  | ApiErrorObject
  | string
  | Array<Record<string, unknown>>;

export interface ApiError {
  detail: ApiErrorDetail;
}

/** 从 FastAPI 错误响应中提取用户可读消息 */
export function extractErrorMessage(
  data: unknown,
  fallback: string,
): string {
  if (!data || typeof data !== "object") return fallback;
  const error = data as { detail?: ApiErrorDetail };
  if (!error.detail) return fallback;
  if (typeof error.detail === "string") return error.detail;
  if (Array.isArray(error.detail)) return fallback;
  return error.detail.message ?? fallback;
}

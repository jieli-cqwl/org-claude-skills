"""Pydantic 数据模型：请求/响应 schema。"""

from pydantic import BaseModel


class LoginRequest(BaseModel):
    """登录请求体。"""

    username: str
    password: str


class UserResponse(BaseModel):
    """用户信息（不含密码）。"""

    id: int
    username: str
    display_name: str
    role: str


class LoginResponse(BaseModel):
    """登录成功响应。"""

    token: str
    user: UserResponse


class ErrorDetail(BaseModel):
    """统一错误格式。"""

    code: str
    message: str


class ErrorResponse(BaseModel):
    """错误响应包装。"""

    error: ErrorDetail


class ReportItem(BaseModel):
    """周报列表项。"""

    id: int
    title: str
    author_name: str
    created_at: str


class PaginationInfo(BaseModel):
    """分页信息。"""

    page: int
    page_size: int
    total: int
    total_pages: int


class ReportsResponse(BaseModel):
    """周报列表响应。"""

    data: list[ReportItem]
    pagination: PaginationInfo

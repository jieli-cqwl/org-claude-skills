"""认证路由：POST /api/login。"""

from fastapi import APIRouter, HTTPException

from app.auth.service import authenticate, create_token
from app.models import LoginRequest, LoginResponse, UserResponse

router = APIRouter(prefix="/api", tags=["auth"])


@router.post("/login", response_model=LoginResponse)
def login(body: LoginRequest) -> LoginResponse:
    """用户登录：验证凭据 + 签发 JWT。"""
    user = authenticate(body.username, body.password)
    if user is None:
        raise HTTPException(
            status_code=401,
            detail={"code": "INVALID_CREDENTIALS", "message": "用户名或密码错误"},
        )

    token = create_token(user["id"], user["role"])
    return LoginResponse(token=token, user=UserResponse(**user))

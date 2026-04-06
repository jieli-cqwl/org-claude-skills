"""认证业务逻辑：密码验证、JWT 签发。"""

from datetime import datetime, timezone, timedelta

import bcrypt
import jwt

from app.config import JWT_SECRET, JWT_ALGORITHM, JWT_EXPIRE_HOURS
from app.database import get_db


def verify_password(plain: str, hashed: str) -> bool:
    """bcrypt 密码比对。"""
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def create_token(user_id: int, role: str) -> str:
    """签发 JWT，payload 仅含 user_id + role + exp + iat (GAC-003)。"""
    now = datetime.now(timezone.utc)
    payload = {
        "user_id": user_id,
        "role": role,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=JWT_EXPIRE_HOURS)).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def authenticate(username: str, password: str) -> dict | None:
    """验证凭据，成功返回 user dict，失败返回 None。"""
    with get_db() as conn:
        row = conn.execute(
            "SELECT id, username, password_hash, display_name, role FROM users WHERE username = ?",
            (username,),
        ).fetchone()

    if row is None:
        return None

    if not verify_password(password, row["password_hash"]):
        return None

    return {
        "id": row["id"],
        "username": row["username"],
        "display_name": row["display_name"],
        "role": row["role"],
    }

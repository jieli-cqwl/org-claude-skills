"""应用配置：从环境变量读取，禁止硬编码密钥。"""

import os


def _require_env(name: str) -> str:
    """必须的环境变量，缺失时启动失败。"""
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"环境变量 {name} 未设置")
    return value


# 必须配置
JWT_SECRET: str = _require_env("JWT_SECRET")

# 可选配置（有默认值）
JWT_ALGORITHM: str = os.environ.get("JWT_ALGORITHM", "HS256")
JWT_EXPIRE_HOURS: int = int(os.environ.get("JWT_EXPIRE_HOURS", "24"))
DB_PATH: str = os.environ.get("DB_PATH", "data/weekly_report.db")
CORS_ORIGINS: list[str] = os.environ.get("CORS_ORIGINS", "http://localhost:5173").split(
    ","
)
BCRYPT_ROUNDS: int = int(os.environ.get("BCRYPT_ROUNDS", "12"))

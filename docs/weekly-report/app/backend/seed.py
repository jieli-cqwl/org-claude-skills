"""种子数据初始化脚本（幂等）。"""

import os
import sys
from datetime import datetime, timedelta

# 确保能导入 app 模块
sys.path.insert(0, os.path.dirname(__file__))

os.environ.setdefault("JWT_SECRET", "test-secret-key-for-dev")

import bcrypt as _bcrypt

from app.database import get_db, init_db


def _hash_password(password: str) -> str:
    """bcrypt 哈希，cost=12。"""
    return _bcrypt.hashpw(password.encode(), _bcrypt.gensalt(rounds=12)).decode()


_USERS = [
    ("admin", "password123", "管理员", "author"),
    ("alice", "password123", "Alice Wang", "author"),
    ("bob", "password123", "Bob Li", "reader"),
]

_REPORT_TITLES = [
    "本周完成用户认证模块重构",
    "性能优化：首页加载时间降低 40%",
    "修复订单列表分页 bug",
    "新增导出功能 — CSV + Excel",
    "迁移数据库从 MySQL 到 PostgreSQL",
    "代码审查流程优化总结",
    "CI/CD 流水线升级到 GitHub Actions",
    "前端从 Vue2 升级到 Vue3 经验分享",
    "安全加固：XSS 和 CSRF 防护",
    "移动端适配方案调研",
    "API 网关引入与流量治理",
    "技术债清理：删除 3000 行死代码",
]


def seed() -> None:
    """幂等插入种子数据。"""
    init_db()

    with get_db() as conn:
        # 检查是否已有数据
        count = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        if count > 0:
            print("种子数据已存在，跳过")
            return

        # 插入用户
        for username, password, display_name, role in _USERS:
            password_hash = _hash_password(password)
            conn.execute(
                "INSERT INTO users (username, password_hash, display_name, role) VALUES (?, ?, ?, ?)",
                (username, password_hash, display_name, role),
            )

        # 插入周报：12 条 published + 2 条 draft
        base_time = datetime(2026, 3, 1, 9, 0, 0)
        author_ids = [1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2]
        for i, title in enumerate(_REPORT_TITLES):
            created_at = base_time + timedelta(days=i, hours=i % 5)
            conn.execute(
                "INSERT INTO reports (title, content, author_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
                (
                    title,
                    f"这是第 {i + 1} 篇周报的详细内容。包含本周的工作进展、遇到的问题和下周计划。",
                    author_ids[i],
                    "published",
                    created_at.strftime("%Y-%m-%d %H:%M:%S"),
                    created_at.strftime("%Y-%m-%d %H:%M:%S"),
                ),
            )

        # 2 条 draft（不应出现在首页）
        for i in range(2):
            conn.execute(
                "INSERT INTO reports (title, content, author_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
                (
                    f"草稿周报 {i + 1}",
                    "这是一篇未发布的草稿。",
                    1,
                    "draft",
                    datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                ),
            )

        conn.commit()
        print("种子数据初始化完成：3 用户 + 12 published + 2 draft")


if __name__ == "__main__":
    seed()

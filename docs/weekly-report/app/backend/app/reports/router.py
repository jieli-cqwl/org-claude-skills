"""周报路由：GET /api/reports。"""

import math

from fastapi import APIRouter, Depends, Query

from app.auth.dependencies import get_current_user
from app.database import get_db
from app.models import ReportItem, ReportsResponse, PaginationInfo

router = APIRouter(prefix="/api", tags=["reports"])

_PAGE_SIZE = 10


@router.get("/reports", response_model=ReportsResponse)
def list_reports(
    page: int = Query(default=1, ge=1, description="页码"),
    _user: dict = Depends(get_current_user),
) -> ReportsResponse:
    """已发布周报列表（分页、时间倒序、R3: 仅 published）。"""
    with get_db() as conn:
        # 总数
        total = conn.execute(
            "SELECT COUNT(*) FROM reports WHERE status = ?", ("published",)
        ).fetchone()[0]

        total_pages = math.ceil(total / _PAGE_SIZE) if total > 0 else 0
        offset = (page - 1) * _PAGE_SIZE

        # 分页查询 + JOIN 获取 author_name
        rows = conn.execute(
            """
            SELECT r.id, r.title, u.display_name AS author_name, r.created_at
            FROM reports r
            JOIN users u ON r.author_id = u.id
            WHERE r.status = ?
            ORDER BY r.created_at DESC
            LIMIT ? OFFSET ?
            """,
            ("published", _PAGE_SIZE, offset),
        ).fetchall()

    # created_at: SQLite "YYYY-MM-DD HH:MM:SS" → ISO 8601 "YYYY-MM-DDTHH:MM:SSZ"
    items = [
        ReportItem(
            id=r["id"],
            title=r["title"],
            author_name=r["author_name"],
            created_at=r["created_at"].replace(" ", "T") + "Z",
        )
        for r in rows
    ]

    return ReportsResponse(
        data=items,
        pagination=PaginationInfo(
            page=page,
            page_size=_PAGE_SIZE,
            total=total,
            total_pages=total_pages,
        ),
    )

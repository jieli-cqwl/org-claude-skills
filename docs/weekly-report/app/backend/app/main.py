"""FastAPI 应用入口：挂载路由和中间件。"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import CORS_ORIGINS
from app.database import init_db

app = FastAPI(title="技术周报平台", version="0.1.0")

# CORS（CON-004）
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)


@app.on_event("startup")
def startup() -> None:
    """应用启动时初始化数据库。"""
    init_db()


from app.auth.router import router as auth_router
from app.reports.router import router as reports_router

app.include_router(auth_router)
app.include_router(reports_router)

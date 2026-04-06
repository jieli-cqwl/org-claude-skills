/* 首页：周报列表 + 分页控件 + 空状态 + 错误提示。 */

import { useEffect, useState, useRef, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import axios from "axios";
import client, { TOKEN_KEY } from "../api/client";
import type { ReportItem, PaginationInfo, ReportsResponse } from "../types";

export default function HomePage() {
  const navigate = useNavigate();
  const [reports, setReports] = useState<ReportItem[]>([]);
  const [pagination, setPagination] = useState<PaginationInfo | null>(null);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const abortRef = useRef<AbortController | null>(null);

  const fetchReports = useCallback(
    async (targetPage: number) => {
      /* 取消前一个未完成请求，避免旧响应覆盖新数据 */
      abortRef.current?.abort();
      const controller = new AbortController();
      abortRef.current = controller;

      setLoading(true);
      setError("");

      try {
        const res = await client.get<ReportsResponse>("/reports", {
          params: { page: targetPage },
          signal: controller.signal,
        });
        setReports(res.data.data);
        setPagination(res.data.pagination);
        /* 同步本地 page 为服务端确认页码 */
        setPage(res.data.pagination.page);
      } catch (err) {
        /* 被取消的请求不更新状态 */
        if (axios.isCancel(err)) return;
        /* AC-U2-05: API 返回 5xx/网络错误 → 显示错误提示 */
        setError("加载失败，请刷新重试");
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  useEffect(() => {
    fetchReports(page);
    return () => abortRef.current?.abort();
  }, [page, fetchReports]);

  /** 登出：清除 token 和用户信息，跳转到登录页 */
  function handleLogout() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem("user");
    navigate("/login", { replace: true });
  }

  /** 格式化 ISO 8601 日期为易读格式 */
  function formatDate(iso: string): string {
    const d = new Date(iso);
    return d.toLocaleDateString("zh-CN", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  /* 加载态 */
  if (loading && reports.length === 0) {
    return (
      <div className="flex min-h-screen items-center justify-center text-gray-500">
        加载中...
      </div>
    );
  }

  /* 错误态 */
  if (error) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-center">
          <p className="text-red-600">{error}</p>
          <button
            onClick={() => fetchReports(page)}
            className="mt-4 rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700"
          >
            重试
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl p-6">
      {/* 页头 */}
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-800">技术周报</h1>
        <button
          onClick={handleLogout}
          className="rounded border border-gray-300 px-3 py-1 text-sm text-gray-600 hover:bg-gray-100"
        >
          登出
        </button>
      </div>

      {/* AC-U2-03: 空数据 → "暂无周报" */}
      {pagination && pagination.total === 0 && (
        <p className="py-20 text-center text-gray-400">暂无周报</p>
      )}

      {/* AC-U2-01: 列表展示（标题/作者/时间/倒序） */}
      {reports.length > 0 && (
        <ul className="divide-y divide-gray-200 rounded-lg border border-gray-200 bg-white">
          {reports.map((r) => (
            <li key={r.id} className="px-5 py-4">
              <h2 className="font-medium text-gray-800">{r.title}</h2>
              <p className="mt-1 text-sm text-gray-500">
                {r.author_name} · {formatDate(r.created_at)}
              </p>
            </li>
          ))}
        </ul>
      )}

      {/* AC-U2-02: 分页控件（total > page_size 时可见） */}
      {pagination && pagination.total_pages > 1 && (
        <div className="mt-6 flex items-center justify-center gap-4">
          <button
            disabled={page <= 1}
            onClick={() => setPage((p) => p - 1)}
            className="rounded border px-3 py-1 text-sm disabled:opacity-40"
          >
            上一页
          </button>
          <span className="text-sm text-gray-600">
            第 {pagination.page} / {pagination.total_pages} 页
          </span>
          <button
            disabled={page >= pagination.total_pages}
            onClick={() => setPage((p) => p + 1)}
            className="rounded border px-3 py-1 text-sm disabled:opacity-40"
          >
            下一页
          </button>
        </div>
      )}
    </div>
  );
}

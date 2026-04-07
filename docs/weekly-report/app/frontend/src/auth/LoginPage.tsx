/* 登录页：表单校验 + 调用 POST /api/login + token 存储 + 跳转。 */

import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import axios from "axios";
import client, { TOKEN_KEY } from "../api/client";
import type { LoginResponse } from "../types";
import { extractErrorMessage } from "../types";

export default function LoginPage() {
  const navigate = useNavigate();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  /* AC-U1-04: 空输入前端校验拦截，不发请求 */
  const canSubmit = username.trim() !== "" && password.trim() !== "";

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;

    setError("");
    setLoading(true);

    try {
      const res = await client.post<LoginResponse>("/login", {
        username: username.trim(),
        password,
      });

      /* AC-U1-01: token 存 localStorage → 跳转 / */
      localStorage.setItem(TOKEN_KEY, res.data.token);
      localStorage.setItem("user", JSON.stringify(res.data.user));
      navigate("/", { replace: true });
    } catch (err) {
      /* AC-U1-02: 错误凭据 → 显示"用户名或密码错误" */
      if (axios.isAxiosError(err) && err.response?.status === 401) {
        setError(
          extractErrorMessage(err.response.data, "用户名或密码错误"),
        );
      } else {
        setError("网络异常，请稍后重试");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm rounded-lg bg-white p-8 shadow"
      >
        <h1 className="mb-6 text-center text-2xl font-bold text-gray-800">
          技术周报平台
        </h1>

        {error && (
          <div className="mb-4 rounded bg-red-50 p-3 text-sm text-red-600">
            {error}
          </div>
        )}

        <label className="mb-1 block text-sm font-medium text-gray-700">
          用户名
        </label>
        <input
          type="text"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          className="mb-4 w-full rounded border border-gray-300 px-3 py-2 focus:border-blue-500 focus:outline-none"
          autoFocus
        />

        <label className="mb-1 block text-sm font-medium text-gray-700">
          密码
        </label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mb-6 w-full rounded border border-gray-300 px-3 py-2 focus:border-blue-500 focus:outline-none"
        />

        <button
          type="submit"
          disabled={!canSubmit || loading}
          className="w-full rounded bg-blue-600 py-2 text-white hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {loading ? "登录中..." : "登录"}
        </button>
      </form>
    </div>
  );
}

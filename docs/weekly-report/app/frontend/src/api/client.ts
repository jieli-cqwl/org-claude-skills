/* axios 实例：统一 baseURL 和请求/响应拦截器。 */

import axios from "axios";

const TOKEN_KEY = "token";

const client = axios.create({
  baseURL: "/api",
  headers: { "Content-Type": "application/json" },
});

/** 请求拦截器：自动附加 Authorization header */
client.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

/** AC-U3-06: 响应拦截器：API 返回 401 → 清除 token + 跳转 /login */
client.interceptors.response.use(
  (response) => response,
  (error) => {
    if (axios.isAxiosError(error) && error.response?.status === 401) {
      /* 仅当当前不在登录接口时清除（避免登录失败也清除） */
      const url = error.config?.url ?? "";
      if (!url.endsWith("/login")) {
        localStorage.removeItem(TOKEN_KEY);
        localStorage.removeItem("user");
        window.location.href = "/login";
      }
    }
    return Promise.reject(error);
  },
);

export { TOKEN_KEY };
export default client;

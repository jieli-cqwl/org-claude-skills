/* 应用路由：/ 首页（需登录）、/login 登录页。 */

import { Routes, Route, Navigate } from "react-router-dom";
import LoginRedirect from "./auth/LoginRedirect";
import AuthGuard from "./auth/AuthGuard";
import HomePage from "./reports/HomePage";

export default function App() {
  return (
    <Routes>
      {/* AC-U3-04: 已登录访问 /login → 重定向 / */}
      <Route path="/login" element={<LoginRedirect />} />

      {/* AC-U3-01/02: 受保护路由，无 token → /login */}
      <Route element={<AuthGuard />}>
        <Route path="/" element={<HomePage />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

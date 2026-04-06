/* 路由守卫：未认证 → /login，已认证 → 渲染子路由。 */

import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "./useAuth";

/** 保护需要登录的路由，无有效 token 时重定向到 /login */
export default function AuthGuard() {
  const { authenticated } = useAuth();

  if (!authenticated) {
    return <Navigate to="/login" replace />;
  }

  return <Outlet />;
}

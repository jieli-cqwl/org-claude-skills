/* 登录页路由包装：已登录用户访问 /login 时重定向到 /。 */

import { Navigate } from "react-router-dom";
import { useAuth } from "./useAuth";
import LoginPage from "./LoginPage";

/** AC-U3-04: 已登录访问 /login → 重定向 / */
export default function LoginRedirect() {
  const { authenticated } = useAuth();

  if (authenticated) {
    return <Navigate to="/" replace />;
  }

  return <LoginPage />;
}

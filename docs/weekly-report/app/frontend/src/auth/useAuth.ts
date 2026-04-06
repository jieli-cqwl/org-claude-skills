/* 认证状态 hook：判断 localStorage 中的 token 是否存在且未过期。 */

import { TOKEN_KEY } from "../api/client";

/** 将 base64url 转换为标准 base64（补齐 padding） */
function base64urlToBase64(input: string): string {
  let base64 = input.replace(/-/g, "+").replace(/_/g, "/");
  const pad = base64.length % 4;
  if (pad === 2) base64 += "==";
  else if (pad === 3) base64 += "=";
  return base64;
}

/** 解码 JWT payload（不做签名验证，签名由后端保障） */
function decodePayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const json = decodeURIComponent(
      atob(base64urlToBase64(parts[1]))
        .split("")
        .map((c) => "%" + c.charCodeAt(0).toString(16).padStart(2, "0"))
        .join(""),
    );
    return JSON.parse(json);
  } catch {
    return null;
  }
}

/** 检查 token 是否已过期（exp claim） */
function isTokenExpired(payload: Record<string, unknown>): boolean {
  const exp = payload.exp;
  if (typeof exp !== "number") return true;
  return Date.now() >= exp * 1000;
}

/**
 * 返回当前认证状态。
 * - authenticated: token 存在且未过期
 * - 非法/过期 token 会被自动清除
 */
export function useAuth(): { authenticated: boolean } {
  const token = localStorage.getItem(TOKEN_KEY);

  if (!token) {
    return { authenticated: false };
  }

  const payload = decodePayload(token);

  /* AC-U3-05: 非法 token（乱码/篡改）→ 清除 */
  if (!payload) {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem("user");
    return { authenticated: false };
  }

  /* AC-U3-03: 过期 token → 清除 */
  if (isTokenExpired(payload)) {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem("user");
    return { authenticated: false };
  }

  return { authenticated: true };
}

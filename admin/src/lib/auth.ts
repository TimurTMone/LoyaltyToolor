import type { JWTPayload } from "@/types/auth";
import type { TokenResponse } from "@/types/auth";

const ACCESS_TOKEN_KEY = "toolor_access_token";
const REFRESH_TOKEN_KEY = "toolor_refresh_token";

export function getTokens(): { accessToken: string | null; refreshToken: string | null } {
  if (typeof window === "undefined") return { accessToken: null, refreshToken: null };
  return {
    accessToken: localStorage.getItem(ACCESS_TOKEN_KEY),
    refreshToken: localStorage.getItem(REFRESH_TOKEN_KEY),
  };
}

export function setTokens(tokens: TokenResponse): void {
  localStorage.setItem(ACCESS_TOKEN_KEY, tokens.access_token);
  localStorage.setItem(REFRESH_TOKEN_KEY, tokens.refresh_token);
}

export function clearTokens(): void {
  localStorage.removeItem(ACCESS_TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
}

export function decodeToken(token: string): JWTPayload | null {
  try {
    const payload = token.split(".")[1];
    const decoded = JSON.parse(atob(payload));
    return decoded as JWTPayload;
  } catch {
    return null;
  }
}

export function isAuthenticated(): boolean {
  const { accessToken } = getTokens();
  if (!accessToken) return false;
  const payload = decodeToken(accessToken);
  if (!payload) return false;
  return payload.exp * 1000 > Date.now();
}

export function isAdmin(): boolean {
  const { accessToken } = getTokens();
  if (!accessToken) return false;
  const payload = decodeToken(accessToken);
  if (!payload) return false;
  return payload.is_admin === true;
}

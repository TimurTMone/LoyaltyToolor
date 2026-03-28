export interface LoginRequest {
  phone: string;
  password: string;
}

export interface TokenResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
}

export interface JWTPayload {
  sub: string;
  is_admin: boolean;
  exp: number;
}

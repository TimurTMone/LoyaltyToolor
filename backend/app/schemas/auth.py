from pydantic import BaseModel


class RegisterRequest(BaseModel):
    phone: str
    password: str
    full_name: str = ""
    referral_code: str | None = None


class LoginRequest(BaseModel):
    phone: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str

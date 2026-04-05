from pydantic import BaseModel


class SendOtpRequest(BaseModel):
    phone: str


class SendOtpResponse(BaseModel):
    """Response from send-otp. Includes otp_code for dev/testing — remove when real SMS is connected."""
    message: str = "OTP sent"
    otp_code: str  # TODO: remove this field when real SMS provider is connected


class VerifyOtpRequest(BaseModel):
    phone: str
    otp_code: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


class LoginRequest(BaseModel):
    phone: str
    password: str

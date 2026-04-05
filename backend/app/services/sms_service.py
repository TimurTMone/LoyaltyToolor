"""SMS provider abstraction — pluggable backend for sending OTP codes."""

import logging
from abc import ABC, abstractmethod

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class SmsProvider(ABC):
    @abstractmethod
    async def send(self, phone: str, message: str) -> bool:
        """Send SMS. Returns True on success, False on failure."""
        ...


class NoopProvider(SmsProvider):
    """Dev mode — logs the code but doesn't send. Used when no provider configured."""

    async def send(self, phone: str, message: str) -> bool:
        logger.info(f"[SMS-DEV] Would send to {phone}: {message}")
        return True


class SMSCProvider(SmsProvider):
    """SMSC.ru — cheapest option for Kyrgyz numbers (~$0.05/SMS)."""

    BASE_URL = "https://smsc.kg/sys/send.php"

    def __init__(self, login: str, password: str, sender: str = "TOOLOR"):
        self.login = login
        self.password = password
        self.sender = sender

    async def send(self, phone: str, message: str) -> bool:
        phone_clean = phone.replace("+", "").replace(" ", "")
        params = {
            "login": self.login,
            "psw": self.password,
            "phones": phone_clean,
            "mes": message,
            "sender": self.sender,
            "charset": "utf-8",
            "fmt": 3,  # JSON response
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(self.BASE_URL, params=params)
                data = resp.json()
                if "error" in data:
                    logger.error(f"SMSC error: {data}")
                    return False
                logger.info(f"SMSC sent to {phone}: id={data.get('id')}")
                return True
        except Exception as e:
            logger.error(f"SMSC send failed: {e}")
            return False


class TwilioProvider(SmsProvider):
    """Twilio fallback (if SMSC unavailable)."""

    def __init__(self, account_sid: str, auth_token: str, from_number: str):
        self.account_sid = account_sid
        self.auth_token = auth_token
        self.from_number = from_number

    async def send(self, phone: str, message: str) -> bool:
        url = f"https://api.twilio.com/2010-04-01/Accounts/{self.account_sid}/Messages.json"
        try:
            async with httpx.AsyncClient(timeout=10.0, auth=(self.account_sid, self.auth_token)) as client:
                resp = await client.post(url, data={
                    "From": self.from_number,
                    "To": phone,
                    "Body": message,
                })
                if resp.status_code >= 400:
                    logger.error(f"Twilio error {resp.status_code}: {resp.text}")
                    return False
                return True
        except Exception as e:
            logger.error(f"Twilio send failed: {e}")
            return False


# ── Provider factory ───────────────────────────────────────────────────────

_provider: SmsProvider | None = None


def get_sms_provider() -> SmsProvider:
    """Return configured provider based on env vars. Caches the instance."""
    global _provider
    if _provider is not None:
        return _provider

    # SMSC.ru (Kyrgyz region, cheapest)
    if settings.SMSC_LOGIN and settings.SMSC_PASSWORD:
        _provider = SMSCProvider(settings.SMSC_LOGIN, settings.SMSC_PASSWORD, settings.SMSC_SENDER)
        logger.info("SMS provider: SMSC.kg")
        return _provider

    # Twilio
    if settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN and settings.TWILIO_FROM_NUMBER:
        _provider = TwilioProvider(
            settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN, settings.TWILIO_FROM_NUMBER
        )
        logger.info("SMS provider: Twilio")
        return _provider

    # Dev fallback
    _provider = NoopProvider()
    logger.warning("SMS provider: NoopProvider (dev mode — OTPs returned in API response)")
    return _provider


def is_sms_configured() -> bool:
    """True if a real SMS provider is set up (not NoopProvider)."""
    return not isinstance(get_sms_provider(), NoopProvider)


async def send_otp_sms(phone: str, code: str) -> bool:
    """Send OTP SMS to phone number."""
    provider = get_sms_provider()
    message = f"TOOLOR: ваш код входа {code}. Никому не сообщайте."
    return await provider.send(phone, message)

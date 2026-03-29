from pydantic_settings import BaseSettings
import json


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://toolor:toolor_secret@localhost:5432/toolor"
    JWT_SECRET: str = "change-me-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    CORS_ORIGINS: str = '["http://localhost:3000","http://localhost:8080"]'
    UPLOAD_DIR: str = "./uploads"
    ADMIN_PHONE: str = "+996999955000"
    ADMIN_PASSWORD: str = "admin123"
    QR_SECRET: str = "change-me-qr-secret"
    SENTRY_DSN: str = ""
    ANTHROPIC_API_KEY: str = ""
    MIXPANEL_TOKEN: str = ""

    @property
    def cors_origins_list(self) -> list[str]:
        return json.loads(self.CORS_ORIGINS)

    # For Alembic (sync driver)
    @property
    def sync_database_url(self) -> str:
        return self.DATABASE_URL.replace("+asyncpg", "+psycopg2")

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()

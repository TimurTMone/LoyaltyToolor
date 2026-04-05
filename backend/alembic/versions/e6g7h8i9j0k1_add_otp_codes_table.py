"""add otp_codes table for persistent OTP storage

Revision ID: e6g7h8i9j0k1
Revises: d5f6g7h8i9j0
Create Date: 2026-04-05 17:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "e6g7h8i9j0k1"
down_revision: Union[str, None] = "d5f6g7h8i9j0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "otp_codes",
        sa.Column("phone", sa.String(), primary_key=True),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_otp_codes_expires_at", "otp_codes", ["expires_at"])


def downgrade() -> None:
    op.drop_index("idx_otp_codes_expires_at", table_name="otp_codes")
    op.drop_table("otp_codes")

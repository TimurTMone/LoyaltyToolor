"""add store_inventory table

Revision ID: b3d4e5f6g7h8
Revises: a2c3d4e5f6g7
Create Date: 2026-03-30 12:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = 'b3d4e5f6g7h8'
down_revision: Union[str, None] = 'a2c3d4e5f6g7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'store_inventory',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column('location_id', UUID(as_uuid=True), sa.ForeignKey('locations.id', ondelete='CASCADE'), nullable=False),
        sa.Column('product_id', UUID(as_uuid=True), sa.ForeignKey('products.id', ondelete='CASCADE'), nullable=False),
        sa.Column('size', sa.String(), nullable=True),
        sa.Column('quantity', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint('location_id', 'product_id', 'size', name='uq_store_inventory_loc_prod_size'),
    )
    op.create_index('idx_sinv_location', 'store_inventory', ['location_id'])
    op.create_index('idx_sinv_product', 'store_inventory', ['product_id'])
    op.create_index('idx_sinv_loc_prod', 'store_inventory', ['location_id', 'product_id'])

    # Seed: distribute existing product stock into the first active store.
    # For each active product, create one inventory row per size (or one NULL-size row if unsized).
    # Stock is split evenly across sizes.
    op.execute(sa.text("""
        INSERT INTO store_inventory (location_id, product_id, size, quantity)
        SELECT
            loc.id,
            p.id,
            CASE WHEN s.size_val = '__none__' THEN NULL ELSE s.size_val END,
            COALESCE(p.stock, 0) / GREATEST(
                (SELECT count(*) FROM jsonb_array_elements_text(
                    CASE WHEN jsonb_array_length(p.sizes) > 0 THEN p.sizes ELSE '["__none__"]'::jsonb END
                )),
                1
            )
        FROM products p
        CROSS JOIN LATERAL (
            SELECT elem::text AS size_val
            FROM jsonb_array_elements_text(
                CASE WHEN jsonb_array_length(p.sizes) > 0 THEN p.sizes ELSE '["__none__"]'::jsonb END
            ) AS elem
        ) s
        CROSS JOIN (
            SELECT id FROM locations WHERE type = 'store' AND is_active = true ORDER BY sort_order LIMIT 1
        ) loc
        WHERE p.is_active = true
        ON CONFLICT DO NOTHING
    """))


def downgrade() -> None:
    op.drop_index('idx_sinv_loc_prod', table_name='store_inventory')
    op.drop_index('idx_sinv_product', table_name='store_inventory')
    op.drop_index('idx_sinv_location', table_name='store_inventory')
    op.drop_table('store_inventory')

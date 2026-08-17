"""add short_code to magic_links

Revision ID: h2i3j4k5l6m7
Revises: g1h2i3j4k5l6
Create Date: 2026-03-28

"""
from alembic import op
import sqlalchemy as sa

revision = 'h2i3j4k5l6m7'
down_revision = 'g1h2i3j4k5l6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('magic_links', sa.Column('short_code', sa.String(6), nullable=True))
    op.create_index('ix_magic_links_short_code', 'magic_links', ['short_code'])


def downgrade() -> None:
    op.drop_index('ix_magic_links_short_code', table_name='magic_links')
    op.drop_column('magic_links', 'short_code')

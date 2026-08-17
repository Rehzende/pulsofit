"""add is_favorite to workouts

Revision ID: m7n8o9p0q1r2
Revises: l6m7n8o9p0q1
Create Date: 2026-04-02
"""
from alembic import op
import sqlalchemy as sa

revision = 'm7n8o9p0q1r2'
down_revision = 'l6m7n8o9p0q1'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'workouts',
        sa.Column('is_favorite', sa.Boolean(), nullable=False, server_default='false'),
    )


def downgrade() -> None:
    op.drop_column('workouts', 'is_favorite')

"""add last_workout_date to users

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-03-05 08:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = 'c3d4e5f6a7b8'
down_revision = 'b2c3d4e5f6a7'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('users',
        sa.Column('last_workout_date', sa.Date(), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'last_workout_date')

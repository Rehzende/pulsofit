"""add workout_snapshot to workout_sessions

Revision ID: s3t4u5v6w7x8
Revises: z0a1b2c3d4e5
Create Date: 2026-04-23

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = 's3t4u5v6w7x8'
down_revision = 'z0a1b2c3d4e5'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'workout_sessions',
        sa.Column('workout_snapshot', JSONB(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('workout_sessions', 'workout_snapshot')

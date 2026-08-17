"""add challenge_7d fields to users

Revision ID: f7a8b9c0d1e2
Revises: e5f6a7b8c9d0
Create Date: 2026-03-05

"""
from alembic import op
import sqlalchemy as sa

revision = 'f7a8b9c0d1e2'
down_revision = 'e5f6a7b8c9d0'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('users', sa.Column('challenge_7d_started_at', sa.DateTime(), nullable=True))
    op.add_column('users', sa.Column('challenge_7d_completed_at', sa.DateTime(), nullable=True))


def downgrade():
    op.drop_column('users', 'challenge_7d_completed_at')
    op.drop_column('users', 'challenge_7d_started_at')

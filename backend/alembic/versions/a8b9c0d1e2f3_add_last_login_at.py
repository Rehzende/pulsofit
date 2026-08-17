"""add last_login_at to users

Revision ID: a8b9c0d1e2f3
Revises: f7a8b9c0d1e2
Create Date: 2026-03-05

"""
from alembic import op
import sqlalchemy as sa

revision = 'a8b9c0d1e2f3'
down_revision = 'f7a8b9c0d1e2'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('users', sa.Column('last_login_at', sa.DateTime(), nullable=True))


def downgrade():
    op.drop_column('users', 'last_login_at')

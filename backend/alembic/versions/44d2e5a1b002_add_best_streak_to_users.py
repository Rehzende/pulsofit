"""add_best_streak_to_users

Revision ID: 44d2e5a1b002
Revises: 33c1f49b0331
Create Date: 2026-03-01 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '44d2e5a1b002'
down_revision: Union[str, None] = '33c1f49b0331'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('best_streak', sa.Integer(), nullable=True, server_default='0'))


def downgrade() -> None:
    op.drop_column('users', 'best_streak')

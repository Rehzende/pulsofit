"""add_xp_and_hr_to_sessions

Revision ID: e200705aa924
Revises: e7bc0cef5c9b
Create Date: 2025-11-27 19:23:40.169943

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e200705aa924'
down_revision: Union[str, None] = 'e7bc0cef5c9b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('workout_sessions', sa.Column('xp_earned', sa.Integer(), nullable=True))
    op.add_column('workout_sessions', sa.Column('average_heart_rate', sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column('workout_sessions', 'average_heart_rate')
    op.drop_column('workout_sessions', 'xp_earned')

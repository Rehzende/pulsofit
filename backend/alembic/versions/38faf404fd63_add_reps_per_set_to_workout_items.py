"""add reps_per_set to workout_items

Revision ID: 38faf404fd63
Revises: f38d45e8cf95
Create Date: 2026-06-03 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '38faf404fd63'
down_revision: Union[str, None] = 'f38d45e8cf95'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'workout_items',
        sa.Column('reps_per_set', sa.JSON(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('workout_items', 'reps_per_set')

"""add gif_url to exercise_library

Revision ID: c4d5e6f7a8b9
Revises: 38faf404fd63
Create Date: 2026-06-07 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c4d5e6f7a8b9'
down_revision: Union[str, None] = '38faf404fd63'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'exercise_library',
        sa.Column('gif_url', sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('exercise_library', 'gif_url')

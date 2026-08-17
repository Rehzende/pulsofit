"""add_dates_to_workouts

Revision ID: f67555b979de
Revises: f57555b979dd
Create Date: 2025-11-24 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f67555b979de'
down_revision: Union[str, None] = 'f57555b979dd'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add start_date and end_date columns to workouts table
    op.add_column('workouts', sa.Column('start_date', sa.DateTime(), nullable=True))
    op.add_column('workouts', sa.Column('end_date', sa.DateTime(), nullable=True))


def downgrade() -> None:
    # Remove columns
    op.drop_column('workouts', 'end_date')
    op.drop_column('workouts', 'start_date')

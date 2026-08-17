"""change calories_burned column to float for decimal precision

Revision ID: f38d45e8cf95
Revises: 255f3aaa736e
Create Date: 2026-04-25 16:11:43.041005

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f38d45e8cf95'
down_revision: Union[str, None] = '255f3aaa736e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column('workout_sessions', 'calories_burned',
               existing_type=sa.Integer(),
               type_=sa.Float(),
               existing_nullable=True)


def downgrade() -> None:
    op.alter_column('workout_sessions', 'calories_burned',
               existing_type=sa.Float(),
               type_=sa.Integer(),
               existing_nullable=True)

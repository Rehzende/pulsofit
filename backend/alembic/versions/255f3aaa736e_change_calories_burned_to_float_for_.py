"""change calories_burned to float for decimal precision

Revision ID: 255f3aaa736e
Revises: s3t4u5v6w7x8
Create Date: 2026-04-25 14:09:16.982419

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '255f3aaa736e'
down_revision: Union[str, None] = 's3t4u5v6w7x8'
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

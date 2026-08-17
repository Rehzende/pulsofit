"""marketplace_pivot

Revision ID: e7bc0cef5c9b
Revises: 8966424b3136
Create Date: 2025-11-27 12:50:39.397496

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e7bc0cef5c9b'
down_revision: Union[str, None] = '8966424b3136'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('trainer_profiles', sa.Column('is_available_for_hire', sa.Boolean(), server_default='false', nullable=True))
    op.add_column('trainer_profiles', sa.Column('specialties', sa.ARRAY(sa.String()), nullable=True))
    op.add_column('trainer_profiles', sa.Column('bio', sa.String(), nullable=True))
    op.add_column('trainer_profiles', sa.Column('hourly_rate', sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column('trainer_profiles', 'hourly_rate')
    op.drop_column('trainer_profiles', 'bio')
    op.drop_column('trainer_profiles', 'specialties')
    op.drop_column('trainer_profiles', 'is_available_for_hire')

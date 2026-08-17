"""add_rich_exercise_fields

Revision ID: 33c1f49b0331
Revises: 22b0f38a9220
Create Date: 2025-11-30 16:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '33c1f49b0331'
down_revision: Union[str, None] = '22b0f38a9220'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add columns to exercise_library
    # Note: muscle_group, met_value, and video_url were already added in 134c35b357a7
    # We only need to add the new rich content fields
    
    op.add_column('exercise_library', sa.Column('description', sa.Text(), nullable=True))
    op.add_column('exercise_library', sa.Column('instructions', postgresql.JSONB(astext_type=sa.Text()), nullable=True))
    op.add_column('exercise_library', sa.Column('equipment', postgresql.JSONB(astext_type=sa.Text()), nullable=True))


def downgrade() -> None:
    # Drop columns
    op.drop_column('exercise_library', 'equipment')
    op.drop_column('exercise_library', 'instructions')
    op.drop_column('exercise_library', 'description')

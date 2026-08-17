"""update_workout_sessions_timezone

Revision ID: ecfa19912bad
Revises: 2e4095e1983a
Create Date: 2025-11-23 13:36:48.891648

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ecfa19912bad'
down_revision: Union[str, None] = '2e4095e1983a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Convert start_time and end_time to TIMESTAMP WITH TIME ZONE
    op.execute("""
        ALTER TABLE workout_sessions 
        ALTER COLUMN start_time TYPE TIMESTAMP WITH TIME ZONE 
        USING start_time AT TIME ZONE 'UTC'
    """)
    op.execute("""
        ALTER TABLE workout_sessions 
        ALTER COLUMN end_time TYPE TIMESTAMP WITH TIME ZONE 
        USING end_time AT TIME ZONE 'UTC'
    """)


def downgrade() -> None:
    # Revert to TIMESTAMP WITHOUT TIME ZONE
    op.execute("""
        ALTER TABLE workout_sessions 
        ALTER COLUMN start_time TYPE TIMESTAMP WITHOUT TIME ZONE
    """)
    op.execute("""
        ALTER TABLE workout_sessions 
        ALTER COLUMN end_time TYPE TIMESTAMP WITHOUT TIME ZONE
    """)

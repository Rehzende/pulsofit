"""add_progress_tracking_to_workout_sessions

Revision ID: bd6c7f93d089
Revises: ecfa19912bad
Create Date: 2025-11-23 13:59:13.809415

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'bd6c7f93d089'
down_revision: Union[str, None] = 'ecfa19912bad'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add new columns
    op.execute("""
        ALTER TABLE workout_sessions 
        ADD COLUMN progress_data JSONB
    """)
    op.execute("""
        ALTER TABLE workout_sessions 
        ADD COLUMN last_activity_time TIMESTAMP WITH TIME ZONE
    """)
    # Add DRAFT to enum
    op.execute("""
        ALTER TYPE workoutsessionstatus ADD VALUE 'DRAFT'
    """)


def downgrade() -> None:
    # Remove columns
    op.execute("""
        ALTER TABLE workout_sessions 
        DROP COLUMN progress_data
    """)
    op.execute("""
        ALTER TABLE workout_sessions 
        DROP COLUMN last_activity_time
    """)
    # Note: Cannot remove enum value in PostgreSQL, would need to recreate the type

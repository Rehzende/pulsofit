"""fix workout session status enum

Revision ID: 9876543210ab
Revises: bf65d9129571
Create Date: 2025-11-28 18:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9876543210ab'
down_revision: Union[str, None] = 'bf65d9129571'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add new values to the enum
    # We use execute with autocommit block because ALTER TYPE cannot run inside a transaction block in some postgres versions,
    # but usually it's fine in newer ones. However, ADD VALUE must be committed.
    # Alembic runs in a transaction by default.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE workoutsessionstatus ADD VALUE IF NOT EXISTS 'IN_PROGRESS'")
        op.execute("ALTER TYPE workoutsessionstatus ADD VALUE IF NOT EXISTS 'COMPLETED'")
        op.execute("ALTER TYPE workoutsessionstatus ADD VALUE IF NOT EXISTS 'DRAFT'")

    # Migrate existing data
    op.execute("UPDATE workout_sessions SET status = 'IN_PROGRESS' WHERE status = 'STARTED'")
    op.execute("UPDATE workout_sessions SET status = 'COMPLETED' WHERE status = 'FINISHED'")


def downgrade() -> None:
    # We cannot easily remove enum values in Postgres.
    # We can revert the data changes though.
    op.execute("UPDATE workout_sessions SET status = 'STARTED' WHERE status = 'IN_PROGRESS'")
    op.execute("UPDATE workout_sessions SET status = 'FINISHED' WHERE status = 'COMPLETED'")

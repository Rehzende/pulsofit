"""add_methodology_type_to_workout_items

Revision ID: 0107a17a6621
Revises: 082f2866d8a4
Create Date: 2026-04-06 10:30:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '0107a17a6621'
down_revision: str | None = '082f2866d8a4'
branch_labels: str | None = None
depends_on: str | None = None


def upgrade() -> None:
    # Create ENUM type
    op.execute("CREATE TYPE methodologytype AS ENUM ('NORMAL','DROP_SET','REST_PAUSE','PIRAMIDE','FST_7','AMRAP','EMOM')")

    # Add column to workout_items with server default
    op.add_column('workout_items',
        sa.Column('methodology_type', postgresql.ENUM('NORMAL','DROP_SET','REST_PAUSE','PIRAMIDE','FST_7','AMRAP','EMOM', name='methodologytype'),
                  nullable=False, server_default='NORMAL'))


def downgrade() -> None:
    # Remove column
    op.drop_column('workout_items', 'methodology_type')

    # Drop ENUM type
    op.execute("DROP TYPE methodologytype")

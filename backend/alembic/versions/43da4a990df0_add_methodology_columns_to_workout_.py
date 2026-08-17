"""add_methodology_columns_to_workout_items_fix

Revision ID: 43da4a990df0
Revises: r2s3t4u5v6w7
Create Date: 2026-04-06 13:51:29.645333

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '43da4a990df0'
down_revision: Union[str, None] = 'r2s3t4u5v6w7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Use existing methodologytype ENUM from the database
    # create_type=False ensures Alembic doesn't try to run CREATE TYPE again
    methodology_enum = postgresql.ENUM(
        'NORMAL', 'DROP_SET', 'REST_PAUSE', 'PIRAMIDE', 'FST_7', 'AMRAP', 'EMOM',
        name='methodologytype',
        create_type=False
    )
    
    op.add_column(
        'workout_items',
        sa.Column(
            'methodology_type', 
            methodology_enum, 
            server_default='NORMAL', 
            nullable=False
        )
    )

def downgrade() -> None:
    op.drop_column('workout_items', 'methodology_type')

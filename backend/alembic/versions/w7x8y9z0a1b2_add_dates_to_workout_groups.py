"""add_dates_and_status_to_workout_groups

Revision ID: w7x8y9z0a1b2
Revises: 43da4a990df0
Create Date: 2026-04-08 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'w7x8y9z0a1b2'
down_revision = '43da4a990df0'
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column('workout_groups', sa.Column('start_date', sa.DateTime(timezone=True), nullable=True))
    op.add_column('workout_groups', sa.Column('end_date', sa.DateTime(timezone=True), nullable=True))
    op.add_column('workout_groups', sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'))

def downgrade() -> None:
    op.drop_column('workout_groups', 'is_active')
    op.drop_column('workout_groups', 'end_date')
    op.drop_column('workout_groups', 'start_date')

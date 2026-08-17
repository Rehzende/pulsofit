"""add equipment_photo_url to exercise_library

Revision ID: j4k5l6m7n8o9
Revises: i3j4k5l6m7n8
Create Date: 2026-03-29

"""
from alembic import op
import sqlalchemy as sa

revision = 'j4k5l6m7n8o9'
down_revision = 'i3j4k5l6m7n8'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('exercise_library', sa.Column('equipment_photo_url', sa.String(), nullable=True))


def downgrade():
    op.drop_column('exercise_library', 'equipment_photo_url')

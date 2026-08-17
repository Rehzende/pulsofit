"""add instagram handle to trainer profile

Revision ID: n8o9p0q1r2s3
Revises: m7n8o9p0q1r2
Create Date: 2026-04-03 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'n8o9p0q1r2s3'
down_revision = 'm7n8o9p0q1r2'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('trainer_profiles', sa.Column('instagram_handle', sa.String(), nullable=True))


def downgrade():
    op.drop_column('trainer_profiles', 'instagram_handle')

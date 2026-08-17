"""add_methodology_params

Revision ID: r2s3t4u5v6w7
Revises: a06512bb2c5b
Create Date: 2026-04-06 13:40:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'r2s3t4u5v6w7'
down_revision = 'a06512bb2c5b'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Use execute DO block to ignore duplicate column errors gracefully in postgres
    op.execute("""
    DO $$
    BEGIN
        ALTER TABLE workout_items ADD COLUMN methodology_params JSON;
    EXCEPTION
        WHEN duplicate_column THEN null;
    END $$;
    """)

    op.execute("""
    DO $$
    BEGIN
        ALTER TABLE workout_template_items ADD COLUMN methodology_params JSON;
    EXCEPTION
        WHEN duplicate_column THEN null;
    END $$;
    """)

def downgrade() -> None:
    op.drop_column('workout_template_items', 'methodology_params')
    op.drop_column('workout_items', 'methodology_params')

"""add_workout_templates

Revision ID: a06512bb2c5b
Revises: q1r2s3t4u5v6
Create Date: 2026-04-06 13:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'a06512bb2c5b'
down_revision: Union[str, None] = 'q1r2s3t4u5v6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create workout_templates table
    op.create_table('workout_templates',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('trainer_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('goal', sa.String(), nullable=True),
        sa.Column('level', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['trainer_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # Ensure ENUM exists (fixes Railway cache/PgBouncer async issue)
    op.execute("""
    DO $$ BEGIN
        CREATE TYPE methodologytype AS ENUM ('NORMAL', 'DROP_SET', 'REST_PAUSE', 'PIRAMIDE', 'FST_7', 'AMRAP', 'EMOM');
    EXCEPTION
        WHEN duplicate_object THEN null;
    END $$;
    """)

    # Create workout_template_items table
    op.create_table('workout_template_items',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('template_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('exercise_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('exercise_name', sa.String(), nullable=True),
        sa.Column('sets', sa.Integer(), nullable=False),
        sa.Column('reps_min', sa.Integer(), nullable=True),
        sa.Column('reps_max', sa.Integer(), nullable=True),
        sa.Column('duration_seconds', sa.Integer(), nullable=True),
        sa.Column('rest_seconds', sa.Integer(), nullable=False, server_default='60'),
        sa.Column('notes', sa.String(), nullable=True),
        sa.Column('methodology_type', postgresql.ENUM('NORMAL', 'DROP_SET', 'REST_PAUSE', 'PIRAMIDE', 'FST_7', 'AMRAP', 'EMOM', name='methodologytype', create_type=False), nullable=False, server_default='NORMAL'),
        sa.Column('methodology_params', postgresql.JSON, nullable=True),
        sa.Column('superset_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('order_index', sa.Integer(), nullable=False, server_default='0'),
        sa.ForeignKeyConstraint(['exercise_id'], ['exercise_library.id'], ),
        sa.ForeignKeyConstraint(['template_id'], ['workout_templates.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # Add index on trainer_id for fast filtering
    op.create_index('ix_workout_templates_trainer_id', 'workout_templates', ['trainer_id'])


def downgrade() -> None:
    op.drop_table('workout_template_items')
    op.drop_table('workout_templates')

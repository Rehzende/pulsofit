"""add trainer favorites and exercise groups

Revision ID: l6m7n8o9p0q1
Revises: k5l6m7n8o9p0
Create Date: 2026-04-01
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = 'l6m7n8o9p0q1'
down_revision = 'k5l6m7n8o9p0'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'trainer_favorite_exercises',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column('trainer_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('exercise_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('exercise_library.id', ondelete='CASCADE'), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    )
    op.create_index('ix_trainer_fav_trainer_id', 'trainer_favorite_exercises', ['trainer_id'])
    op.create_unique_constraint(
        'uq_trainer_favorite_exercise',
        'trainer_favorite_exercises',
        ['trainer_id', 'exercise_id'],
    )

    op.create_table(
        'exercise_groups',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column('trainer_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    )
    op.create_index('ix_exercise_groups_trainer_id', 'exercise_groups', ['trainer_id'])

    op.create_table(
        'exercise_group_items',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column('group_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('exercise_groups.id', ondelete='CASCADE'), nullable=False),
        sa.Column('exercise_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('exercise_library.id', ondelete='CASCADE'), nullable=False),
        sa.Column('order_index', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('sets', sa.Integer(), nullable=False, server_default='3'),
        sa.Column('reps_min', sa.Integer(), nullable=True),
        sa.Column('reps_max', sa.Integer(), nullable=True),
        sa.Column('duration_seconds', sa.Integer(), nullable=True),
        sa.Column('rest_seconds', sa.Integer(), nullable=False, server_default='60'),
    )
    op.create_index('ix_exercise_group_items_group_id', 'exercise_group_items', ['group_id'])


def downgrade() -> None:
    op.drop_table('exercise_group_items')
    op.drop_table('exercise_groups')
    op.drop_table('trainer_favorite_exercises')

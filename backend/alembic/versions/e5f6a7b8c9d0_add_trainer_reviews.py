"""add trainer_reviews table

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-03-05
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = 'e5f6a7b8c9d0'
down_revision = 'd4e5f6a7b8c9'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'trainer_reviews',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column('trainer_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('student_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('text', sa.Text(), nullable=True),
        sa.Column('is_public', sa.Boolean(), server_default='true', nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    )
    op.create_index('ix_trainer_reviews_trainer_id', 'trainer_reviews', ['trainer_id'])
    op.create_index('ix_trainer_reviews_student_id', 'trainer_reviews', ['student_id'])
    # One review per student-trainer pair
    op.create_unique_constraint(
        'uq_trainer_reviews_trainer_student',
        'trainer_reviews',
        ['trainer_id', 'student_id'],
    )


def downgrade() -> None:
    op.drop_table('trainer_reviews')

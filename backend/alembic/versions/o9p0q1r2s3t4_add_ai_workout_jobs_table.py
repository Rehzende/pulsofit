"""add_ai_workout_jobs_table

Revision ID: o9p0q1r2s3t4
Revises: n8o9p0q1r2s3
Create Date: 2026-04-03
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB

revision = 'o9p0q1r2s3t4'
down_revision = 'n8o9p0q1r2s3'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'ai_workout_jobs',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('job_type', sa.String(32), nullable=False),
        sa.Column('prompt_hash', sa.String(64), nullable=False),
        sa.Column('status', sa.String(16), nullable=False, server_default='PENDING'),
        sa.Column('result_data', JSONB, nullable=True),
        sa.Column('error_message', sa.Text, nullable=True),
        sa.Column('created_at', sa.DateTime, server_default=sa.func.now()),
        sa.Column('completed_at', sa.DateTime, nullable=True),
    )
    op.create_index('ix_ai_workout_jobs_id', 'ai_workout_jobs', ['id'])
    op.create_index('ix_ai_workout_jobs_user_id', 'ai_workout_jobs', ['user_id'])
    op.create_index('ix_ai_workout_jobs_prompt_hash', 'ai_workout_jobs', ['prompt_hash'])
    op.create_index('ix_ai_workout_jobs_status', 'ai_workout_jobs', ['status'])
    op.create_index('ix_ai_workout_jobs_created_at', 'ai_workout_jobs', ['created_at'])


def downgrade() -> None:
    op.drop_index('ix_ai_workout_jobs_created_at', table_name='ai_workout_jobs')
    op.drop_index('ix_ai_workout_jobs_status', table_name='ai_workout_jobs')
    op.drop_index('ix_ai_workout_jobs_prompt_hash', table_name='ai_workout_jobs')
    op.drop_index('ix_ai_workout_jobs_user_id', table_name='ai_workout_jobs')
    op.drop_index('ix_ai_workout_jobs_id', table_name='ai_workout_jobs')
    op.drop_table('ai_workout_jobs')

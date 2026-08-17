"""add_ai_security_tables

Revision ID: p0q1r2s3t4u5
Revises: o9p0q1r2s3t4
Create Date: 2026-04-03

Creates the missing ai_usage_logs and ai_response_cache tables referenced
by the AIUsageLog and AIResponseCache models in app/models/ai_security.py.
These tables are required by the rate-limiting and caching logic in the
ai_workouts endpoint. Without them the endpoint returns 500 on every request.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSON

revision = 'p0q1r2s3t4u5'
down_revision = 'o9p0q1r2s3t4'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── ai_usage_logs ────────────────────────────────────────────────────────
    # Tracks per-user monthly usage for rate-limiting (SEC-2).
    op.create_table(
        'ai_usage_logs',
        sa.Column(
            'id',
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text('gen_random_uuid()'),
        ),
        sa.Column(
            'user_id',
            UUID(as_uuid=True),
            sa.ForeignKey('users.id', ondelete='CASCADE'),
            nullable=False,
        ),
        sa.Column('request_type', sa.String(), nullable=False),   # 'generate' | 'anamnesis'
        sa.Column('tokens_used', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=False),
    )
    op.create_index('ix_ai_usage_logs_id',           'ai_usage_logs', ['id'])
    op.create_index('ix_ai_usage_logs_user_id',      'ai_usage_logs', ['user_id'])
    op.create_index('ix_ai_usage_logs_created_at',   'ai_usage_logs', ['created_at'])

    # ── ai_response_cache ────────────────────────────────────────────────────
    # Legacy cache table (SEC-3). Now superseded by prompt_hash on ai_workout_jobs,
    # but kept for backwards compatibility with any existing references.
    op.create_table(
        'ai_response_cache',
        sa.Column('hash_key', sa.String(), primary_key=True),
        sa.Column('response_data', JSON(), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=False),
    )
    op.create_index('ix_ai_response_cache_hash_key',  'ai_response_cache', ['hash_key'])
    op.create_index('ix_ai_response_cache_created_at','ai_response_cache', ['created_at'])


def downgrade() -> None:
    op.drop_index('ix_ai_response_cache_created_at', table_name='ai_response_cache')
    op.drop_index('ix_ai_response_cache_hash_key',   table_name='ai_response_cache')
    op.drop_table('ai_response_cache')

    op.drop_index('ix_ai_usage_logs_created_at', table_name='ai_usage_logs')
    op.drop_index('ix_ai_usage_logs_user_id',    table_name='ai_usage_logs')
    op.drop_index('ix_ai_usage_logs_id',         table_name='ai_usage_logs')
    op.drop_table('ai_usage_logs')

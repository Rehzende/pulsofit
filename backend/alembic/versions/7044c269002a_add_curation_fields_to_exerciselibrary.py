"""Add curation fields to ExerciseLibrary

Revision ID: 7044c269002a
Revises: p0q1r2s3t4u5
Create Date: 2026-04-04 18:01:39.331853

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7044c269002a'
down_revision: Union[str, None] = 'p0q1r2s3t4u5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create ExerciseStatus enum
    exercise_status = sa.Enum('APPROVED', 'PENDING_REVIEW', 'REJECTED', name='exercisestatus')
    exercise_status.create(op.get_bind(), checkfirst=True)

    # 2. Add columns
    op.add_column('exercise_library', sa.Column('status', exercise_status, server_default='APPROVED', nullable=False))
    op.create_index(op.f('ix_exercise_library_status'), 'exercise_library', ['status'], unique=False)
    
    op.add_column('exercise_library', sa.Column('created_by_id', sa.dialects.postgresql.UUID(as_uuid=True), nullable=True))
    op.create_foreign_key(None, 'exercise_library', 'users', ['created_by_id'], ['id'], ondelete='SET NULL')
    
    op.add_column('exercise_library', sa.Column('aliases', sa.dialects.postgresql.JSONB(astext_type=sa.Text()), server_default='[]', nullable=False))


def downgrade() -> None:
    op.drop_column('exercise_library', 'aliases')
    op.drop_constraint(None, 'exercise_library', type_='foreignkey')
    op.drop_column('exercise_library', 'created_by_id')
    op.drop_index(op.f('ix_exercise_library_status'), table_name='exercise_library')
    op.drop_column('exercise_library', 'status')
    
    exercise_status = sa.Enum('APPROVED', 'PENDING_REVIEW', 'REJECTED', name='exercisestatus')
    exercise_status.drop(op.get_bind(), checkfirst=True)

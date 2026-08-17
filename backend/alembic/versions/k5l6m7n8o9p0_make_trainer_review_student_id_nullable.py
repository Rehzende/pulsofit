"""make trainer_review student_id nullable for anonymization on account deletion

Revision ID: k5l6m7n8o9p0
Revises: 5771de7836c0
Create Date: 2026-04-01
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = 'k5l6m7n8o9p0'
down_revision = '5771de7836c0'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Drop unique constraint that includes student_id (prevents partial nulls)
    op.drop_constraint('uq_trainer_reviews_trainer_student', 'trainer_reviews', type_='unique')

    # Make student_id nullable to allow anonymization when a student deletes their account
    op.alter_column(
        'trainer_reviews',
        'student_id',
        existing_type=postgresql.UUID(as_uuid=True),
        nullable=True,
    )


def downgrade() -> None:
    # Remove any anonymized rows before reverting (they'd violate NOT NULL)
    op.execute("DELETE FROM trainer_reviews WHERE student_id IS NULL")

    op.alter_column(
        'trainer_reviews',
        'student_id',
        existing_type=postgresql.UUID(as_uuid=True),
        nullable=False,
    )

    op.create_unique_constraint(
        'uq_trainer_reviews_trainer_student',
        'trainer_reviews',
        ['trainer_id', 'student_id'],
    )

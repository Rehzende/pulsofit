"""add_student_id_to_workout_groups

Revision ID: x8y9z0a1b2c3
Revises: w7x8y9z0a1b2
Create Date: 2026-04-08 14:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'x8y9z0a1b2c3'
down_revision = 'w7x8y9z0a1b2'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add student_id column
    op.add_column('workout_groups', sa.Column('student_id', postgresql.UUID(as_uuid=True), nullable=True))

    # Add foreign key constraint
    op.create_foreign_key(None, 'workout_groups', 'users', ['student_id'], ['id'], ondelete='CASCADE')

    # Drop old unique constraint
    op.drop_constraint('uq_workout_group_name_trainer', 'workout_groups', type_='unique')

    # Create new unique constraint with student_id
    op.create_unique_constraint('uq_workout_group_name_trainer_student', 'workout_groups', ['name', 'trainer_id', 'student_id'])


def downgrade() -> None:
    # Drop new unique constraint
    op.drop_constraint('uq_workout_group_name_trainer_student', 'workout_groups', type_='unique')

    # Create old unique constraint
    op.create_unique_constraint('uq_workout_group_name_trainer', 'workout_groups', ['name', 'trainer_id'])

    # Drop foreign key
    op.drop_constraint(None, 'workout_groups', type_='foreignkey')

    # Drop student_id column
    op.drop_column('workout_groups', 'student_id')

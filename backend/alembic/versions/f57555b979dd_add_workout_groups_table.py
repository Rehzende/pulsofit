"""add_workout_groups_table

Revision ID: f57555b979dd
Revises: 49f6651c9243
Create Date: 2025-11-24 12:06:07.302120

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f57555b979dd'
down_revision: Union[str, None] = '49f6651c9243'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create workout_groups table
    op.create_table(
        'workout_groups',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('trainer_id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['trainer_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('name', 'trainer_id', name='uq_workout_group_name_trainer')
    )
    
    # Add group_id column to workouts table
    op.add_column('workouts', sa.Column('group_id', sa.UUID(), nullable=True))
    op.create_foreign_key('fk_workouts_group_id', 'workouts', 'workout_groups', ['group_id'], ['id'], ondelete='SET NULL')


def downgrade() -> None:
    # Remove foreign key and column from workouts
    op.drop_constraint('fk_workouts_group_id', 'workouts', type_='foreignkey')
    op.drop_column('workouts', 'group_id')
    
    # Drop workout_groups table
    op.drop_table('workout_groups')

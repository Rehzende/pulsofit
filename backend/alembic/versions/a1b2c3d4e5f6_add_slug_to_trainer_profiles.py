"""add slug to trainer profiles

Revision ID: a1b2c3d4e5f6
Revises: fce4c7ee0ca8
Create Date: 2026-03-01 20:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = 'a1b2c3d4e5f6'
down_revision = '44d2e5a1b002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('trainer_profiles', sa.Column('slug', sa.String(), nullable=True))
    op.create_unique_constraint('uq_trainer_profiles_slug', 'trainer_profiles', ['slug'])
    op.create_index('ix_trainer_profiles_slug', 'trainer_profiles', ['slug'], unique=True)


def downgrade() -> None:
    op.drop_index('ix_trainer_profiles_slug', table_name='trainer_profiles')
    op.drop_constraint('uq_trainer_profiles_slug', 'trainer_profiles', type_='unique')
    op.drop_column('trainer_profiles', 'slug')

"""add magic_links table and make hashed_password nullable

Revision ID: g1h2i3j4k5l6
Revises: a8b9c0d1e2f3
Create Date: 2026-03-27

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'g1h2i3j4k5l6'
down_revision = 'a8b9c0d1e2f3'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create magic_links table
    op.create_table(
        'magic_links',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('token_hash', sa.String(), nullable=False, index=True),
        sa.Column('is_used', sa.Boolean(), default=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
    )

    # Make hashed_password nullable (passwordless users don't have one)
    op.alter_column(
        'users',
        'hashed_password',
        existing_type=sa.String(),
        nullable=True,
    )


def downgrade() -> None:
    # Make hashed_password required again
    op.alter_column(
        'users',
        'hashed_password',
        existing_type=sa.String(),
        nullable=False,
    )

    op.drop_table('magic_links')

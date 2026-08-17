"""add_chat_tables

Revision ID: z0a1b2c3d4e5
Revises: y9z0a1b2c3d4
Create Date: 2026-04-09 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'z0a1b2c3d4e5'
down_revision = 'y9z0a1b2c3d4'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create chat_conversations table (idempotent - won't fail if already exists)
    op.execute('''
        CREATE TABLE IF NOT EXISTS chat_conversations (
            id UUID NOT NULL,
            student_id UUID NOT NULL,
            trainer_id UUID NOT NULL,
            created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
            last_message_at TIMESTAMP WITHOUT TIME ZONE,
            PRIMARY KEY (id),
            FOREIGN KEY(student_id) REFERENCES users (id),
            FOREIGN KEY(trainer_id) REFERENCES users (id),
            CONSTRAINT unique_trainer_student_conversation UNIQUE (student_id, trainer_id)
        )
    ''')

    op.execute('CREATE INDEX IF NOT EXISTS idx_chat_conv_last_msg ON chat_conversations (last_message_at)')
    op.execute('CREATE INDEX IF NOT EXISTS idx_chat_conv_student ON chat_conversations (student_id)')
    op.execute('CREATE INDEX IF NOT EXISTS idx_chat_conv_trainer ON chat_conversations (trainer_id)')

    # Create chat_messages table (idempotent)
    op.execute('''
        CREATE TABLE IF NOT EXISTS chat_messages (
            id UUID NOT NULL,
            conversation_id UUID NOT NULL,
            sender_id UUID NOT NULL,
            body TEXT NOT NULL,
            is_read BOOLEAN NOT NULL,
            created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
            read_at TIMESTAMP WITHOUT TIME ZONE,
            PRIMARY KEY (id),
            FOREIGN KEY(conversation_id) REFERENCES chat_conversations (id) ON DELETE CASCADE,
            FOREIGN KEY(sender_id) REFERENCES users (id)
        )
    ''')

    op.execute('CREATE INDEX IF NOT EXISTS idx_chat_msg_conversation ON chat_messages (conversation_id)')
    op.execute('CREATE INDEX IF NOT EXISTS idx_chat_msg_sender ON chat_messages (sender_id)')
    op.execute('CREATE INDEX IF NOT EXISTS idx_chat_msg_conv_created ON chat_messages (conversation_id, created_at)')


def downgrade() -> None:
    # Drop chat_messages table
    op.execute('DROP TABLE IF EXISTS chat_messages CASCADE')

    # Drop chat_conversations table
    op.execute('DROP TABLE IF EXISTS chat_conversations CASCADE')

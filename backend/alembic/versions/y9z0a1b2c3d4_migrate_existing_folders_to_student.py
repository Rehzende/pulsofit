"""migrate_existing_folders_to_student

Revision ID: y9z0a1b2c3d4
Revises: x8y9z0a1b2c3
Create Date: 2026-04-08 15:00:00.000000

Migrates existing (ungrouped) workout_groups for trainer marcos-10ax@hotmail.com
to be associated with student marcos.ax.09@gmail.com
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

# revision identifiers, used by Alembic.
revision = 'y9z0a1b2c3d4'
down_revision = 'x8y9z0a1b2c3'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Get the connection
    connection = op.get_bind()

    # Find the trainer user ID
    trainer_result = connection.execute(
        text("SELECT id FROM users WHERE email = :email LIMIT 1"),
        {"email": "marcos-10ax@hotmail.com"}
    )
    trainer_row = trainer_result.fetchone()
    if not trainer_row:
        print("⚠️  Trainer not found (marcos-10ax@hotmail.com) - skipping migration")
        return

    trainer_id = str(trainer_row[0]) if hasattr(trainer_row[0], '__str__') else trainer_row[0]

    # Find the student user ID
    student_result = connection.execute(
        text("SELECT id FROM users WHERE email = :email LIMIT 1"),
        {"email": "marcos.ax.09@gmail.com"}
    )
    student_row = student_result.fetchone()
    if not student_row:
        print("⚠️  Student not found (marcos.ax.09@gmail.com) - skipping migration")
        return

    student_id = str(student_row[0]) if hasattr(student_row[0], '__str__') else student_row[0]

    # Update all ungrouped workout_groups for this trainer to be associated with the student
    connection.execute(
        text("""
            UPDATE workout_groups
            SET student_id = :student_id
            WHERE trainer_id = :trainer_id
            AND student_id IS NULL
        """),
        {"student_id": student_id, "trainer_id": trainer_id}
    )

    connection.commit()
    print(f"✅ Migrated all ungrouped folders for {trainer_id} to student {student_id}")


def downgrade() -> None:
    # Get the connection
    connection = op.get_bind()

    # Find the trainer user ID
    trainer_result = connection.execute(
        text("SELECT id FROM users WHERE email = :email LIMIT 1"),
        {"email": "marcos-10ax@hotmail.com"}
    )
    trainer_row = trainer_result.fetchone()
    if not trainer_row:
        print("⚠️  Trainer not found - skipping downgrade")
        return

    trainer_id = str(trainer_row[0]) if hasattr(trainer_row[0], '__str__') else trainer_row[0]

    # Revert: set student_id back to NULL for folders that were migrated
    # (This assumes all folders for this trainer with student_id set were just migrated)
    connection.execute(
        text("""
            UPDATE workout_groups
            SET student_id = NULL
            WHERE trainer_id = :trainer_id
        """),
        {"trainer_id": trainer_id}
    )

    connection.commit()
    print(f"✅ Reverted folder migrations for trainer {trainer_id}")

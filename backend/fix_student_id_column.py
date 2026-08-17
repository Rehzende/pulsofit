#!/usr/bin/env python3
"""
Emergency script to add student_id column to ai_agent_sessions table.
Run this in the production environment where DATABASE_URL is available.
"""

import asyncio
from sqlalchemy import text, event
from app.db.session import engine

async def fix_student_id_column():
    """Add the missing student_id column directly to the database."""

    try:
        # First transaction: Add the column
        async with engine.begin() as conn:
            print("Adding student_id column...")
            await conn.execute(text("""
                ALTER TABLE ai_agent_sessions
                ADD COLUMN IF NOT EXISTS student_id UUID
            """))

        # Second transaction: Add the constraint
        async with engine.begin() as conn:
            print("Adding foreign key constraint...")
            try:
                await conn.execute(text("""
                    ALTER TABLE ai_agent_sessions
                    ADD CONSTRAINT fk_ai_agent_sessions_student_id
                    FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE SET NULL
                """))
            except Exception as constraint_err:
                # Constraint might already exist, that's OK
                if "already exists" in str(constraint_err).lower() or "duplicate key" in str(constraint_err).lower():
                    print("  (Constraint already exists, skipping)")
                else:
                    raise

        # Third transaction: Verify
        async with engine.begin() as conn:
            print("Verifying column exists...")
            result = await conn.execute(text("""
                SELECT column_name, data_type
                FROM information_schema.columns
                WHERE table_name = 'ai_agent_sessions'
                AND column_name = 'student_id'
            """))

            row = result.fetchone()
            if row:
                print(f"✅ SUCCESS: Column '{row[0]}' of type '{row[1]}' exists!")
                return True
            else:
                print("⚠️  Column not found in verification query")
                return False

    except Exception as e:
        print(f"❌ ERROR: {type(e).__name__}: {e}")
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("Emergency Student ID Column Fix")
    print("=" * 60)

    success = asyncio.run(fix_student_id_column())

    if success:
        print("\n✅ Fix completed successfully!")
        print("The student_id column is now available in the database.")
        exit(0)
    else:
        print("\n❌ Fix failed!")
        exit(1)

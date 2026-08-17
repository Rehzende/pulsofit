-- ============================================================
-- PULSO - Migration: New Features (Mood, Streak Protector, Wrapped)
-- Date: 2026-02-27
-- ============================================================

-- 1. Add mood tracking columns to workout_sessions
ALTER TABLE workout_sessions
    ADD COLUMN IF NOT EXISTS mood_before INTEGER CHECK (mood_before BETWEEN 1 AND 5),
    ADD COLUMN IF NOT EXISTS mood_after  INTEGER CHECK (mood_after  BETWEEN 1 AND 5);

-- 2. Add streak protector columns to users
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS streak_protectors_available       INTEGER DEFAULT 1,
    ADD COLUMN IF NOT EXISTS streak_protectors_used_this_month INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_streak_protector_reset       TIMESTAMP WITH TIME ZONE;

-- 3. Seed existing users with 1 protector available (they get it free on migration)
UPDATE users
    SET streak_protectors_available = 1
WHERE streak_protectors_available IS NULL;

-- Done!
SELECT 'Migration applied successfully ✅' AS status;

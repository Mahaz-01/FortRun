-- ============================================================
-- FortRun Upgrade Migration
-- Run this ENTIRE file in Supabase SQL Editor (Dashboard → SQL)
-- Safe to re-run: uses IF NOT EXISTS / ON CONFLICT everywhere
-- ============================================================


-- ════════════════════════════════════════════════════════════════
-- 1. STREAK COLUMNS ON USERS TABLE
-- ════════════════════════════════════════════════════════════════

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS streak_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS longest_streak INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_run_date DATE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_runs INTEGER NOT NULL DEFAULT 0;


-- ════════════════════════════════════════════════════════════════
-- 2. ACTIVITY FEED TABLE
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.activity_feed (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  actor_name TEXT NOT NULL DEFAULT '',
  action TEXT NOT NULL,            -- 'run_complete', 'zone_captured', 'sabotage', 'clan_join', 'clan_leave', 'streak'
  target_name TEXT,                -- sector name, clan name, etc.
  detail TEXT,                     -- "+85 points", "7-day streak!", etc.
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activity_feed_created ON public.activity_feed (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_feed_actor ON public.activity_feed (actor_id);

-- RLS
ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view activity feed') THEN
    CREATE POLICY "Anyone can view activity feed"
      ON public.activity_feed FOR SELECT
      USING (true);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can insert activity') THEN
    CREATE POLICY "Authenticated users can insert activity"
      ON public.activity_feed FOR INSERT
      WITH CHECK (auth.uid() IS NOT NULL);
  END IF;
END $$;

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_feed;


-- ════════════════════════════════════════════════════════════════
-- 3. RPC: update_streak
-- Called after every completed run to maintain streak state.
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.update_streak(uid UUID)
RETURNS JSONB AS $$
DECLARE
  prev_date DATE;
  cur_streak INTEGER;
  best_streak INTEGER;
  today DATE := CURRENT_DATE;
  multiplier NUMERIC := 1.0;
BEGIN
  SELECT last_run_date, streak_count, longest_streak
  INTO prev_date, cur_streak, best_streak
  FROM public.users WHERE id = uid;

  -- Already ran today — no change
  IF prev_date = today THEN
    IF cur_streak >= 7 THEN multiplier := 2.0;
    ELSIF cur_streak >= 2 THEN multiplier := 1.5;
    END IF;
    RETURN jsonb_build_object('streak', cur_streak, 'multiplier', multiplier, 'new_streak', false);
  END IF;

  -- Consecutive day — extend streak
  IF prev_date = today - 1 THEN
    cur_streak := cur_streak + 1;
  ELSE
    -- Streak broken (or first run ever)
    cur_streak := 1;
  END IF;

  IF cur_streak > best_streak THEN
    best_streak := cur_streak;
  END IF;

  UPDATE public.users
  SET streak_count = cur_streak,
      longest_streak = best_streak,
      last_run_date = today,
      total_runs = total_runs + 1
  WHERE id = uid;

  IF cur_streak >= 7 THEN multiplier := 2.0;
  ELSIF cur_streak >= 2 THEN multiplier := 1.5;
  END IF;

  RETURN jsonb_build_object('streak', cur_streak, 'multiplier', multiplier, 'new_streak', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ════════════════════════════════════════════════════════════════
-- 4. RPC: log_activity
-- Inserts a row into the activity_feed table.
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.log_activity(
  p_actor_id UUID,
  p_action TEXT,
  p_target_name TEXT DEFAULT NULL,
  p_detail TEXT DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_name TEXT;
BEGIN
  SELECT name INTO v_name FROM public.users WHERE id = p_actor_id;
  INSERT INTO public.activity_feed (actor_id, actor_name, action, target_name, detail)
  VALUES (p_actor_id, COALESCE(v_name, 'Runner'), p_action, p_target_name, p_detail);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ════════════════════════════════════════════════════════════════
-- 5. RPC: check_sabotage_cooldown
-- Returns true if the user can sabotage this sector (4hr cooldown)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.check_sabotage_cooldown(
  uid UUID,
  target_sector TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  last_sabotage TIMESTAMPTZ;
BEGIN
  SELECT MAX(created_at) INTO last_sabotage
  FROM public.zone_history
  WHERE user_id = uid
    AND zone_id = target_sector
    AND action = 'sabotage';

  IF last_sabotage IS NULL THEN
    RETURN true;
  END IF;

  RETURN (now() - last_sabotage) > INTERVAL '4 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ════════════════════════════════════════════════════════════════
-- 6. VIEW: leaderboard_zones_with_owner
-- Joins zones with user names for the territories leaderboard.
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.zones_with_owner AS
SELECT
  z.id,
  z.name,
  z.owner_id,
  z.owner_type,
  z.total_points,
  z.control_percentage,
  COALESCE(u.name, 'Unclaimed') AS owner_name
FROM public.zones z
LEFT JOIN public.users u ON z.owner_id = u.id;


-- ════════════════════════════════════════════════════════════════
-- 7. CLEANUP: auto-delete old activity feed entries (> 30 days)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.cleanup_old_activity()
RETURNS void AS $$
BEGIN
  DELETE FROM public.activity_feed
  WHERE created_at < now() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- DONE! All migrations applied successfully.
-- ============================================================

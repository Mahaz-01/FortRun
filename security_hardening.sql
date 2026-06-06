-- ============================================================
-- FortRun — Security Hardening (Phase 1)
-- Run in Supabase Dashboard → SQL Editor.
--
-- READ THIS FIRST:
--   • STAGE 1 is SAFE and ALREADY APPLIED (auto-create profile on signup).
--   • STAGE 2 is the anti-cheat lockdown. It makes the economy tables
--     read-only to clients and routes ALL scoring through trusted
--     SECURITY DEFINER functions keyed off auth.uid(). It REQUIRES the
--     matching Flutter refactor (GameEngine -> process_run / process_sabotage,
--     hardened process_wall_tick). Run STAGE 2 only with that client build.
-- ============================================================


-- ════════════════════════════════════════════════════════════
-- STAGE 1 — (already run) auto-create a profile row for every signup
-- ════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, name, email)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'name',
      NEW.raw_user_meta_data->>'full_name',
      NULLIF(split_part(COALESCE(NEW.email, ''), '@', 1), ''),
      'Runner'
    ),
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

INSERT INTO public.users (id, name, email)
SELECT a.id,
       COALESCE(NULLIF(split_part(COALESCE(a.email,''),'@',1),''), 'Runner'),
       a.email
FROM auth.users a
LEFT JOIN public.users u ON u.id = a.id
WHERE u.id IS NULL
ON CONFLICT (id) DO NOTHING;


-- ════════════════════════════════════════════════════════════
-- STAGE 2 — ANTI-CHEAT LOCKDOWN  (run WITH the matching client build)
-- ════════════════════════════════════════════════════════════

-- ── 2a. Remove the wide-open, caller-supplied-id economy RPCs ──
DROP FUNCTION IF EXISTS public.increment_user_stats(uuid, integer, double precision);
DROP FUNCTION IF EXISTS public.decrement_user_points(uuid, integer);
-- Old overloads that trusted client-passed ids:
DROP FUNCTION IF EXISTS public.process_wall_tick(text, text, uuid, uuid, jsonb, integer);
DROP FUNCTION IF EXISTS public.update_streak(uuid);
-- Old no-arg / single-arg variants replaced by timezone-aware versions below
-- (dropped to avoid "function is not unique" ambiguity with the new defaults):
DROP FUNCTION IF EXISTS public.update_streak();
DROP FUNCTION IF EXISTS public.process_run(uuid);

-- ── 2b. Lock RLS: clients may READ the economy, never WRITE it ──
-- Only the SECURITY DEFINER functions below (run as table owner) may mutate.
DROP POLICY IF EXISTS "Authenticated users can insert zones" ON public.zones;
DROP POLICY IF EXISTS "Authenticated users can update zones" ON public.zones;
DROP POLICY IF EXISTS "Authenticated users can insert zone history" ON public.zone_history;
DROP POLICY IF EXISTS "Authenticated users can insert walls" ON public.walls;
DROP POLICY IF EXISTS "Authenticated users can update own or enemy walls" ON public.walls;

-- Keep "Users can update own profile" (name/photo/clan_id), but FREEZE the
-- scored columns for client roles. SECURITY DEFINER functions (current_user =
-- table owner, e.g. 'postgres') bypass the freeze; client requests run as
-- 'authenticated'/'anon' and are blocked from editing scores.
CREATE OR REPLACE FUNCTION public.protect_user_score_columns()
RETURNS TRIGGER AS $$
BEGIN
  IF current_user IN ('authenticated', 'anon') THEN
    NEW.points         := OLD.points;
    NEW.total_km       := OLD.total_km;
    NEW.streak_count   := OLD.streak_count;
    NEW.longest_streak := OLD.longest_streak;
    NEW.last_run_date  := OLD.last_run_date;
    NEW.total_runs     := OLD.total_runs;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_user_scores ON public.users;
CREATE TRIGGER trg_protect_user_scores
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.protect_user_score_columns();

-- ── 2c. Streak (trusts auth.uid(); timezone-aware via p_today) ──
-- p_today = the runner's LOCAL date (passed by the client). Falls back to
-- server UTC date when null, so older app builds keep working.
CREATE OR REPLACE FUNCTION public.update_streak(p_today DATE DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  uid UUID := auth.uid();
  prev_date DATE;
  cur_streak INTEGER;
  best_streak INTEGER;
  today DATE := COALESCE(p_today, CURRENT_DATE);
  multiplier NUMERIC := 1.0;
BEGIN
  IF uid IS NULL THEN
    RETURN jsonb_build_object('streak', 0, 'multiplier', 1.0, 'new_streak', false);
  END IF;

  SELECT last_run_date, streak_count, longest_streak
  INTO prev_date, cur_streak, best_streak
  FROM public.users WHERE id = uid;

  cur_streak := COALESCE(cur_streak, 0);
  best_streak := COALESCE(best_streak, 0);

  IF prev_date = today THEN
    IF cur_streak >= 7 THEN multiplier := 2.0;
    ELSIF cur_streak >= 2 THEN multiplier := 1.5; END IF;
    RETURN jsonb_build_object('streak', cur_streak, 'multiplier', multiplier, 'new_streak', false);
  END IF;

  IF prev_date = today - 1 THEN cur_streak := cur_streak + 1;
  ELSE cur_streak := 1; END IF;

  IF cur_streak > best_streak THEN best_streak := cur_streak; END IF;

  UPDATE public.users
  SET streak_count = cur_streak,
      longest_streak = best_streak,
      last_run_date = today,
      total_runs = total_runs + 1
  WHERE id = uid;

  IF cur_streak >= 7 THEN multiplier := 2.0;
  ELSIF cur_streak >= 2 THEN multiplier := 1.5; END IF;

  RETURN jsonb_build_object('streak', cur_streak, 'multiplier', multiplier, 'new_streak', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 2d. Activity log (actor is always auth.uid(), never client-supplied) ──
CREATE OR REPLACE FUNCTION public.log_activity(
  p_actor_id UUID DEFAULT NULL,
  p_action TEXT DEFAULT '',
  p_target_name TEXT DEFAULT NULL,
  p_detail TEXT DEFAULT NULL
) RETURNS void AS $$
DECLARE
  actor UUID := COALESCE(auth.uid(), p_actor_id);
  v_name TEXT;
BEGIN
  IF actor IS NULL THEN RETURN; END IF;
  SELECT name INTO v_name FROM public.users WHERE id = actor;
  INSERT INTO public.activity_feed (actor_id, actor_name, action, target_name, detail)
  VALUES (actor, COALESCE(v_name, 'Runner'), p_action, p_target_name, p_detail);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 2e. Sabotage cooldown check (trusts auth.uid()) ──
CREATE OR REPLACE FUNCTION public.check_sabotage_cooldown(
  uid UUID DEFAULT NULL,
  target_sector TEXT DEFAULT ''
) RETURNS BOOLEAN AS $$
DECLARE
  who UUID := COALESCE(auth.uid(), uid);
  last_sabotage TIMESTAMPTZ;
BEGIN
  SELECT MAX(created_at) INTO last_sabotage
  FROM public.zone_history
  WHERE user_id = who AND zone_id = target_sector AND action = 'sabotage';
  IF last_sabotage IS NULL THEN RETURN true; END IF;
  RETURN (now() - last_sabotage) > INTERVAL '4 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 2f. THE trusted run scorer. Client inserts a run, then calls this. ──
-- p_local_date = the runner's local calendar date (for correct streaks).
CREATE OR REPLACE FUNCTION public.process_run(p_run_id UUID, p_local_date DATE DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  r            public.runs%ROWTYPE;
  caller       UUID := auth.uid();
  z            public.zones%ROWTYPE;
  pts          INTEGER := 0;
  owner_deduct INTEGER := 0;
  streak_json  JSONB;
  mult         NUMERIC := 1.0;
  act          TEXT;
BEGIN
  IF caller IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  SELECT * INTO r FROM public.runs WHERE id = p_run_id;
  IF r.id IS NULL OR r.user_id <> caller THEN
    RAISE EXCEPTION 'run not found or not owned by caller';
  END IF;

  -- Server-side sanity gates: reject implausible/cheated runs.
  IF r.primary_sector IS NULL OR r.primary_sector = '' OR r.primary_sector = 'Unknown'
     OR r.distance_km <= 0 OR r.distance_km > 100
     OR r.duration_seconds <= 0
     OR (r.distance_km / GREATEST(r.duration_seconds,1) * 3600) > 45 THEN
    RETURN jsonb_build_object('pointsEarned', 0, 'streak', 0, 'multiplier', 1.0, 'rejected', true);
  END IF;

  streak_json := public.update_streak(p_local_date);
  mult := COALESCE((streak_json->>'multiplier')::numeric, 1.0);
  pts  := round(r.distance_km * 10 * mult);   -- pointsPerKmOwn
  owner_deduct := round(r.distance_km * 5);   -- pointsDeductOpponent

  SELECT * INTO z FROM public.zones WHERE id = r.primary_sector;

  IF z.id IS NULL THEN
    -- Bootstrap an unclaimed sector to the runner. Ongoing ownership is
    -- decided by walls (recalculate_sector_owner), not by runs.
    INSERT INTO public.zones (id, name, owner_id, owner_type, control_percentage, total_points)
    VALUES (r.primary_sector, r.primary_sector, caller, 'user', 100.0, pts);
    act := 'run_claim';
  ELSIF z.owner_id = caller THEN
    UPDATE public.zones SET total_points = total_points + pts WHERE id = z.id;
    act := 'run_defend';
  ELSE
    IF z.owner_id IS NOT NULL THEN
      UPDATE public.users SET points = GREATEST(0, points - owner_deduct) WHERE id = z.owner_id;
    END IF;
    UPDATE public.zones SET total_points = total_points + pts WHERE id = z.id;
    act := 'run_invade';
  END IF;

  INSERT INTO public.zone_history (zone_id, user_id, points_delta, action)
  VALUES (r.primary_sector, caller, pts, act);

  UPDATE public.users
  SET points = points + pts, total_km = total_km + r.distance_km
  WHERE id = caller;

  UPDATE public.runs SET points_earned = pts WHERE id = p_run_id;

  PERFORM public.log_activity(caller, 'run_complete', r.primary_sector,
    '+' || pts || ' pts, ' || round(r.distance_km::numeric, 2) || ' km');

  RETURN jsonb_build_object(
    'pointsEarned', pts,
    'streak', COALESCE((streak_json->>'streak')::int, 0),
    'multiplier', mult
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 2g. The trusted sabotage scorer. ──
CREATE OR REPLACE FUNCTION public.process_sabotage(
  target_sector TEXT,
  restaurant_name TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  caller UUID := auth.uid();
  z      public.zones%ROWTYPE;
  dmg    INTEGER;
  bonus  INTEGER;
BEGIN
  IF caller IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;

  -- 4-hour cooldown per (user, sector)
  IF NOT public.check_sabotage_cooldown(caller, target_sector) THEN
    RETURN jsonb_build_object('damage', 0, 'reason', 'cooldown');
  END IF;

  SELECT * INTO z FROM public.zones WHERE id = target_sector;
  IF z.id IS NULL OR z.owner_id IS NULL OR z.owner_id = caller THEN
    RETURN jsonb_build_object('damage', 0, 'reason', 'invalid_target');
  END IF;

  dmg := 50 + floor(random() * 51)::int;   -- 50..100

  UPDATE public.users SET points = GREATEST(0, points - dmg) WHERE id = z.owner_id;
  UPDATE public.zones SET total_points = GREATEST(0, total_points - dmg) WHERE id = z.id;

  -- AoE crack all walls in the sector
  UPDATE public.walls
  SET strength = GREATEST(0, strength - 25), updated_at = now()
  WHERE sector_id = target_sector;

  INSERT INTO public.zone_history (zone_id, user_id, points_delta, action, restaurant_name)
  VALUES (target_sector, caller, -dmg, 'sabotage', restaurant_name);

  bonus := round(dmg * 0.25);
  UPDATE public.users SET points = points + bonus WHERE id = caller;

  PERFORM public.log_activity(caller, 'sabotage', target_sector,
    '-' || dmg || ' pts at ' || COALESCE(restaurant_name, 'a checkpoint'));

  RETURN jsonb_build_object('damage', dmg);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 2h. Hardened wall tick: actor = auth.uid(), clan looked up server-side ──
CREATE OR REPLACE FUNCTION public.process_wall_tick(
  target_wall_id   TEXT,
  target_sector_id TEXT,
  poly             JSONB,
  tick_amount      INTEGER
) RETURNS void AS $$
DECLARE
  uid UUID := auth.uid();
  cid UUID;
  current_strength INTEGER;
  current_owner UUID;
BEGIN
  IF uid IS NULL THEN RETURN; END IF;
  IF tick_amount IS NULL OR tick_amount <= 0 OR tick_amount > 10 THEN
    tick_amount := 5;   -- clamp; client cannot pump arbitrary strength
  END IF;

  SELECT clan_id INTO cid FROM public.users WHERE id = uid;

  INSERT INTO public.walls (id, sector_id, owner_id, clan_id, strength, polygon_coords)
  VALUES (target_wall_id, target_sector_id, uid, cid, 0, poly)
  ON CONFLICT (id) DO NOTHING;

  SELECT strength, owner_id INTO current_strength, current_owner
  FROM public.walls WHERE id = target_wall_id;

  IF current_owner IS NULL OR current_owner = uid THEN
    UPDATE public.walls
    SET strength = LEAST(100, strength + tick_amount),
        owner_id = uid, clan_id = cid, updated_at = now()
    WHERE id = target_wall_id;
  ELSE
    IF current_strength - tick_amount <= 0 THEN
      UPDATE public.walls
      SET owner_id = uid, clan_id = cid, strength = 1, updated_at = now()
      WHERE id = target_wall_id;
    ELSE
      UPDATE public.walls
      SET strength = current_strength - tick_amount, updated_at = now()
      WHERE id = target_wall_id;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- ============================================================
-- DONE. Economy is now server-authoritative.
-- ============================================================

-- ============================================================
-- FortRun: Seed Data — Walls, Zone Ownership, Runs, Activity
-- User: fb852c97-f4ae-4195-be10-cba4d7f13a8c
-- Sectors: F-7 (yours), F-6 (yours), G-8 (enemy)
-- ============================================================

-- ── 1. Create a fake rival user for contrast ─────────────────

INSERT INTO public.users (id, name, phone, total_km, points, current_fortress_sector, streak_count, longest_streak, total_runs)
VALUES (
  'aaaa1111-bbbb-cccc-dddd-eeee2222ffff',
  'RivalRunner_ISB',
  '+923001234567',
  28.5,
  340,
  'G-8',
  4,
  12,
  15
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  points = EXCLUDED.points,
  total_km = EXCLUDED.total_km;


-- ── 2. Update YOUR user with some stats ──────────────────────

UPDATE public.users SET
  points = 520,
  total_km = 42.3,
  current_fortress_sector = 'F-7',
  streak_count = 3,
  longest_streak = 7,
  total_runs = 22,
  last_run_date = CURRENT_DATE
WHERE id = 'fb852c97-f4ae-4195-be10-cba4d7f13a8c';


-- ── 3. Assign zone ownership ─────────────────────────────────

-- F-7: YOU own it (your fortress)
UPDATE public.zones SET
  owner_id = 'fb852c97-f4ae-4195-be10-cba4d7f13a8c',
  owner_type = 'user',
  control_percentage = 82.5,
  total_points = 520
WHERE id = 'F-7';

-- F-6: YOU own it (expanding)
UPDATE public.zones SET
  owner_id = 'fb852c97-f4ae-4195-be10-cba4d7f13a8c',
  owner_type = 'user',
  control_percentage = 61.0,
  total_points = 180
WHERE id = 'F-6';

-- G-8: ENEMY owns it
UPDATE public.zones SET
  owner_id = 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff',
  owner_type = 'user',
  control_percentage = 90.0,
  total_points = 340
WHERE id = 'G-8';

-- G-9: ENEMY owns it (weaker hold)
UPDATE public.zones SET
  owner_id = 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff',
  owner_type = 'user',
  control_percentage = 55.0,
  total_points = 95
WHERE id = 'G-9';


-- ── 4. Seed walls in F-7 (YOUR walls — green on map) ────────
-- Grid: 0.0018 deg tiles (~200m). Dense cluster so they're visible.

INSERT INTO public.walls (id, sector_id, owner_id, strength, polygon_coords) VALUES

-- Row 1 (south edge of F-7)
('grid_18728_40585', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 85,
 '[{"lat":33.7122,"lng":73.053},{"lat":33.7122,"lng":73.0548},{"lat":33.7104,"lng":73.0548},{"lat":33.7104,"lng":73.053}]'::jsonb),

('grid_18728_40586', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 72,
 '[{"lat":33.7122,"lng":73.0548},{"lat":33.7122,"lng":73.0566},{"lat":33.7104,"lng":73.0566},{"lat":33.7104,"lng":73.0548}]'::jsonb),

('grid_18728_40587', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 60,
 '[{"lat":33.7122,"lng":73.0566},{"lat":33.7122,"lng":73.0584},{"lat":33.7104,"lng":73.0584},{"lat":33.7104,"lng":73.0566}]'::jsonb),

-- Row 2
('grid_18729_40585', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 95,
 '[{"lat":33.714,"lng":73.053},{"lat":33.714,"lng":73.0548},{"lat":33.7122,"lng":73.0548},{"lat":33.7122,"lng":73.053}]'::jsonb),

('grid_18729_40586', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 100,
 '[{"lat":33.714,"lng":73.0548},{"lat":33.714,"lng":73.0566},{"lat":33.7122,"lng":73.0566},{"lat":33.7122,"lng":73.0548}]'::jsonb),

('grid_18729_40587', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 88,
 '[{"lat":33.714,"lng":73.0566},{"lat":33.714,"lng":73.0584},{"lat":33.7122,"lng":73.0584},{"lat":33.7122,"lng":73.0566}]'::jsonb),

('grid_18729_40588', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 45,
 '[{"lat":33.714,"lng":73.0584},{"lat":33.714,"lng":73.0602},{"lat":33.7122,"lng":73.0602},{"lat":33.7122,"lng":73.0584}]'::jsonb),

-- Row 3 (center of F-7)
('grid_18730_40585', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 70,
 '[{"lat":33.7158,"lng":73.053},{"lat":33.7158,"lng":73.0548},{"lat":33.714,"lng":73.0548},{"lat":33.714,"lng":73.053}]'::jsonb),

('grid_18730_40586', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 90,
 '[{"lat":33.7158,"lng":73.0548},{"lat":33.7158,"lng":73.0566},{"lat":33.714,"lng":73.0566},{"lat":33.714,"lng":73.0548}]'::jsonb),

('grid_18730_40587', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 100,
 '[{"lat":33.7158,"lng":73.0566},{"lat":33.7158,"lng":73.0584},{"lat":33.714,"lng":73.0584},{"lat":33.714,"lng":73.0566}]'::jsonb),

('grid_18730_40588', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 55,
 '[{"lat":33.7158,"lng":73.0584},{"lat":33.7158,"lng":73.0602},{"lat":33.714,"lng":73.0602},{"lat":33.714,"lng":73.0584}]'::jsonb),

-- Row 4 (north)
('grid_18731_40586', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 65,
 '[{"lat":33.7176,"lng":73.0548},{"lat":33.7176,"lng":73.0566},{"lat":33.7158,"lng":73.0566},{"lat":33.7158,"lng":73.0548}]'::jsonb),

('grid_18731_40587', 'F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 78,
 '[{"lat":33.7176,"lng":73.0566},{"lat":33.7176,"lng":73.0584},{"lat":33.7158,"lng":73.0584},{"lat":33.7158,"lng":73.0566}]'::jsonb)

ON CONFLICT (id) DO UPDATE SET
  owner_id = EXCLUDED.owner_id,
  strength = EXCLUDED.strength,
  polygon_coords = EXCLUDED.polygon_coords;


-- ── 5. Seed walls in F-6 (YOUR walls — sparser, newer territory) ──

INSERT INTO public.walls (id, sector_id, owner_id, strength, polygon_coords) VALUES

('grid_18733_40594', 'F-6', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 50,
 '[{"lat":33.7212,"lng":73.0692},{"lat":33.7212,"lng":73.071},{"lat":33.7194,"lng":73.071},{"lat":33.7194,"lng":73.0692}]'::jsonb),

('grid_18733_40595', 'F-6', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 38,
 '[{"lat":33.7212,"lng":73.071},{"lat":33.7212,"lng":73.0728},{"lat":33.7194,"lng":73.0728},{"lat":33.7194,"lng":73.071}]'::jsonb),

('grid_18735_40596', 'F-6', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 65,
 '[{"lat":33.7248,"lng":73.0728},{"lat":33.7248,"lng":73.0746},{"lat":33.723,"lng":73.0746},{"lat":33.723,"lng":73.0728}]'::jsonb),

('grid_18735_40597', 'F-6', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 42,
 '[{"lat":33.7248,"lng":73.0746},{"lat":33.7248,"lng":73.0764},{"lat":33.723,"lng":73.0764},{"lat":33.723,"lng":73.0746}]'::jsonb),

('grid_18736_40597', 'F-6', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 30,
 '[{"lat":33.7266,"lng":73.0746},{"lat":33.7266,"lng":73.0764},{"lat":33.7248,"lng":73.0764},{"lat":33.7248,"lng":73.0746}]'::jsonb)

ON CONFLICT (id) DO UPDATE SET
  owner_id = EXCLUDED.owner_id,
  strength = EXCLUDED.strength,
  polygon_coords = EXCLUDED.polygon_coords;


-- ── 6. Seed walls in G-8 (ENEMY walls — red on map) ─────────

INSERT INTO public.walls (id, sector_id, owner_id, strength, polygon_coords) VALUES

('grid_18718_40586', 'G-8', 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 80,
 '[{"lat":33.6942,"lng":73.0548},{"lat":33.6942,"lng":73.0566},{"lat":33.6924,"lng":73.0566},{"lat":33.6924,"lng":73.0548}]'::jsonb),

('grid_18718_40587', 'G-8', 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 92,
 '[{"lat":33.6942,"lng":73.0566},{"lat":33.6942,"lng":73.0584},{"lat":33.6924,"lng":73.0584},{"lat":33.6924,"lng":73.0566}]'::jsonb),

('grid_18720_40586', 'G-8', 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 100,
 '[{"lat":33.6978,"lng":73.0548},{"lat":33.6978,"lng":73.0566},{"lat":33.696,"lng":73.0566},{"lat":33.696,"lng":73.0548}]'::jsonb),

('grid_18720_40587', 'G-8', 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 88,
 '[{"lat":33.6978,"lng":73.0566},{"lat":33.6978,"lng":73.0584},{"lat":33.696,"lng":73.0584},{"lat":33.696,"lng":73.0566}]'::jsonb),

('grid_18720_40588', 'G-8', 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 55,
 '[{"lat":33.6978,"lng":73.0584},{"lat":33.6978,"lng":73.0602},{"lat":33.696,"lng":73.0602},{"lat":33.696,"lng":73.0584}]'::jsonb),

('grid_18721_40586', 'G-8', 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 75,
 '[{"lat":33.6996,"lng":73.0548},{"lat":33.6996,"lng":73.0566},{"lat":33.6978,"lng":73.0566},{"lat":33.6978,"lng":73.0548}]'::jsonb),

('grid_18721_40587', 'G-8', 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 62,
 '[{"lat":33.6996,"lng":73.0566},{"lat":33.6996,"lng":73.0584},{"lat":33.6978,"lng":73.0584},{"lat":33.6978,"lng":73.0566}]'::jsonb),

-- A couple cracking walls in G-8 (you started invading)
('grid_18719_40587', 'G-8', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 15,
 '[{"lat":33.696,"lng":73.0566},{"lat":33.696,"lng":73.0584},{"lat":33.6942,"lng":73.0584},{"lat":33.6942,"lng":73.0566}]'::jsonb),

('grid_18719_40588', 'G-8', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 8,
 '[{"lat":33.696,"lng":73.0584},{"lat":33.696,"lng":73.0602},{"lat":33.6942,"lng":73.0602},{"lat":33.6942,"lng":73.0584}]'::jsonb)

ON CONFLICT (id) DO UPDATE SET
  owner_id = EXCLUDED.owner_id,
  strength = EXCLUDED.strength,
  polygon_coords = EXCLUDED.polygon_coords;


-- ── 7. Seed some runs for your user ──────────────────────────

INSERT INTO public.runs (user_id, timestamp, distance_km, duration_seconds, primary_sector, points_earned, polyline_coords) VALUES

('fb852c97-f4ae-4195-be10-cba4d7f13a8c', now() - interval '6 days', 5.2, 1860, 'F-7', 78,
 '[{"lat":33.7120,"lng":73.0540},{"lat":33.7135,"lng":73.0555},{"lat":33.7150,"lng":73.0570},{"lat":33.7165,"lng":73.0585},{"lat":33.7180,"lng":73.0600}]'::jsonb),

('fb852c97-f4ae-4195-be10-cba4d7f13a8c', now() - interval '5 days', 3.8, 1440, 'F-7', 57,
 '[{"lat":33.7140,"lng":73.0560},{"lat":33.7150,"lng":73.0575},{"lat":33.7160,"lng":73.0590},{"lat":33.7170,"lng":73.0560}]'::jsonb),

('fb852c97-f4ae-4195-be10-cba4d7f13a8c', now() - interval '3 days', 6.1, 2280, 'F-6', 92,
 '[{"lat":33.7200,"lng":73.0700},{"lat":33.7220,"lng":73.0720},{"lat":33.7240,"lng":73.0740},{"lat":33.7260,"lng":73.0760}]'::jsonb),

('fb852c97-f4ae-4195-be10-cba4d7f13a8c', now() - interval '2 days', 4.5, 1680, 'F-7', 68,
 '[{"lat":33.7110,"lng":73.0530},{"lat":33.7130,"lng":73.0550},{"lat":33.7150,"lng":73.0570},{"lat":33.7170,"lng":73.0560}]'::jsonb),

('fb852c97-f4ae-4195-be10-cba4d7f13a8c', now() - interval '1 day', 7.3, 2640, 'G-8', 110,
 '[{"lat":33.6930,"lng":73.0540},{"lat":33.6950,"lng":73.0560},{"lat":33.6970,"lng":73.0580},{"lat":33.6990,"lng":73.0560},{"lat":33.7000,"lng":73.0540}]'::jsonb),

('fb852c97-f4ae-4195-be10-cba4d7f13a8c', now() - interval '4 hours', 2.9, 1080, 'F-7', 44,
 '[{"lat":33.7130,"lng":73.0555},{"lat":33.7145,"lng":73.0565},{"lat":33.7155,"lng":73.0575}]'::jsonb);

-- Enemy runs
INSERT INTO public.runs (user_id, timestamp, distance_km, duration_seconds, primary_sector, points_earned, polyline_coords) VALUES

('aaaa1111-bbbb-cccc-dddd-eeee2222ffff', now() - interval '4 days', 4.0, 1500, 'G-8', 60,
 '[{"lat":33.6940,"lng":73.0560},{"lat":33.6960,"lng":73.0570},{"lat":33.6980,"lng":73.0580}]'::jsonb),

('aaaa1111-bbbb-cccc-dddd-eeee2222ffff', now() - interval '2 days', 5.5, 2100, 'G-8', 83,
 '[{"lat":33.6930,"lng":73.0550},{"lat":33.6960,"lng":73.0570},{"lat":33.6990,"lng":73.0560}]'::jsonb),

('aaaa1111-bbbb-cccc-dddd-eeee2222ffff', now() - interval '12 hours', 3.2, 1200, 'G-9', 48,
 '[{"lat":33.6860,"lng":73.0400},{"lat":33.6880,"lng":73.0430},{"lat":33.6900,"lng":73.0460}]'::jsonb);


-- ── 8. Seed zone history ─────────────────────────────────────

INSERT INTO public.zone_history (zone_id, user_id, points_delta, action) VALUES
('F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 78,  'run_claim'),
('F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 57,  'run_defend'),
('F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 68,  'run_defend'),
('F-7', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 44,  'run_defend'),
('F-6', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 92,  'run_claim'),
('G-8', 'fb852c97-f4ae-4195-be10-cba4d7f13a8c', 110, 'run_invade'),
('G-8', 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 60,  'run_claim'),
('G-8', 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 83,  'run_defend'),
('G-9', 'aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 48,  'run_claim');


-- ── 9. Seed activity feed ────────────────────────────────────

INSERT INTO public.activity_feed (actor_id, actor_name, action, target_name, detail, created_at) VALUES
('fb852c97-f4ae-4195-be10-cba4d7f13a8c', 'You',            'zone_captured',  'F-7', 'Claimed unclaimed territory',     now() - interval '6 days'),
('fb852c97-f4ae-4195-be10-cba4d7f13a8c', 'You',            'run_complete',   'F-7', '+78 pts, 5.20 km',               now() - interval '6 days'),
('aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 'RivalRunner_ISB', 'zone_captured',  'G-8', 'Claimed unclaimed territory',     now() - interval '4 days'),
('aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 'RivalRunner_ISB', 'run_complete',   'G-8', '+60 pts, 4.00 km',               now() - interval '4 days'),
('fb852c97-f4ae-4195-be10-cba4d7f13a8c', 'You',            'zone_captured',  'F-6', 'Claimed unclaimed territory',     now() - interval '3 days'),
('fb852c97-f4ae-4195-be10-cba4d7f13a8c', 'You',            'run_complete',   'F-6', '+92 pts, 6.10 km',               now() - interval '3 days'),
('fb852c97-f4ae-4195-be10-cba4d7f13a8c', 'You',            'streak',         NULL,  '3-day streak!',                   now() - interval '3 days'),
('aaaa1111-bbbb-cccc-dddd-eeee2222ffff', 'RivalRunner_ISB', 'run_complete',   'G-8', '+83 pts, 5.50 km',               now() - interval '2 days'),
('fb852c97-f4ae-4195-be10-cba4d7f13a8c', 'You',            'run_complete',   'G-8', '+110 pts, 7.30 km (invasion!)',   now() - interval '1 day'),
('fb852c97-f4ae-4195-be10-cba4d7f13a8c', 'You',            'run_complete',   'F-7', '+44 pts, 2.90 km',               now() - interval '4 hours');


-- ============================================================
-- DONE! You should now see:
--   - F-7: Dense green walls (your fortress, 13 tiles, 45-100% strength)
--   - F-6: Sparse green walls (expanding, 5 tiles, 30-65%)
--   - G-8: Red enemy walls (7 tiles) + 2 tiny green tiles (your invasion)
--   - G-9: Red sector border (enemy owned, no walls yet)
--   - 6 runs in your profile history
--   - Activity feed with 10 events
--   - Leaderboard: you #1 (520 pts) vs RivalRunner_ISB #2 (340 pts)
-- ============================================================

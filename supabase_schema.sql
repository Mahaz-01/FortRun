-- ============================================================
-- FortRun — Supabase PostgreSQL Schema
-- ============================================================
-- Run this SQL in your Supabase Dashboard → SQL Editor → New Query
-- This creates all tables, indexes, RLS policies, and RPC functions.
-- ============================================================

-- ── Enable UUID extension (usually already enabled) ──────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ════════════════════════════════════════════════════════════
-- TABLE: users
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT '',
  phone TEXT,
  email TEXT,
  total_km DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  points INTEGER NOT NULL DEFAULT 0,
  current_fortress_sector TEXT,
  clan_id UUID,
  photo_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_users_points ON public.users (points DESC);
CREATE INDEX IF NOT EXISTS idx_users_clan_id ON public.users (clan_id);
CREATE INDEX IF NOT EXISTS idx_users_fortress ON public.users (current_fortress_sector);

-- RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Users can read all profiles (for leaderboards)
CREATE POLICY "Users can view all profiles"
  ON public.users FOR SELECT
  USING (true);

-- Users can only insert their own profile
CREATE POLICY "Users can insert own profile"
  ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can only update their own profile
CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE
  USING (auth.uid() = id);

-- ════════════════════════════════════════════════════════════
-- TABLE: zones
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.zones (
  id TEXT PRIMARY KEY,               -- e.g. "F-7", "G-9"
  name TEXT NOT NULL DEFAULT '',
  owner_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  owner_type TEXT DEFAULT 'user',    -- 'user' or 'clan'
  control_percentage DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_points INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_zones_owner ON public.zones (owner_id);
CREATE INDEX IF NOT EXISTS idx_zones_points ON public.zones (total_points DESC);

-- RLS
ALTER TABLE public.zones ENABLE ROW LEVEL SECURITY;

-- Everyone can read zones (map display)
CREATE POLICY "Anyone can view zones"
  ON public.zones FOR SELECT
  USING (true);

-- Any authenticated user can insert/update zones (game engine writes)
CREATE POLICY "Authenticated users can insert zones"
  ON public.zones FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update zones"
  ON public.zones FOR UPDATE
  USING (auth.uid() IS NOT NULL);

-- ════════════════════════════════════════════════════════════
-- TABLE: runs
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.runs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  "timestamp" TIMESTAMPTZ NOT NULL DEFAULT now(),
  distance_km DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  primary_sector TEXT NOT NULL DEFAULT '',
  points_earned INTEGER NOT NULL DEFAULT 0,
  polyline_coords JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for user history and sector aggregation
CREATE INDEX IF NOT EXISTS idx_runs_user_id ON public.runs (user_id);
CREATE INDEX IF NOT EXISTS idx_runs_sector ON public.runs (primary_sector);
CREATE INDEX IF NOT EXISTS idx_runs_timestamp ON public.runs (user_id, "timestamp" DESC);

-- RLS
ALTER TABLE public.runs ENABLE ROW LEVEL SECURITY;

-- Users can read all runs (needed for ownership calculation)
CREATE POLICY "Anyone can view runs"
  ON public.runs FOR SELECT
  USING (true);

-- Users can only insert their own runs
CREATE POLICY "Users can insert own runs"
  ON public.runs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ════════════════════════════════════════════════════════════
-- TABLE: zone_history
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.zone_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  zone_id TEXT NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  points_delta INTEGER NOT NULL DEFAULT 0,
  action TEXT NOT NULL,              -- 'run_claim', 'run_defend', 'run_invade', 'sabotage'
  restaurant_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_zone_history_zone ON public.zone_history (zone_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_zone_history_user ON public.zone_history (user_id);

-- RLS
ALTER TABLE public.zone_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view zone history"
  ON public.zone_history FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can insert zone history"
  ON public.zone_history FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- ════════════════════════════════════════════════════════════
-- TABLE: clans
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.clans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  total_points INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add FK constraint to users.clan_id after clans table exists
ALTER TABLE public.users
  ADD CONSTRAINT fk_users_clan
  FOREIGN KEY (clan_id) REFERENCES public.clans(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_clans_points ON public.clans (total_points DESC);

-- RLS
ALTER TABLE public.clans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view clans"
  ON public.clans FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create clans"
  ON public.clans FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update clans"
  ON public.clans FOR UPDATE
  USING (auth.uid() IS NOT NULL);

-- ════════════════════════════════════════════════════════════
-- RPC FUNCTIONS — Atomic point operations
-- ════════════════════════════════════════════════════════════

-- Atomically decrement a user's points (prevents race conditions).
-- Points floor at 0 to prevent negative scores.
CREATE OR REPLACE FUNCTION public.decrement_user_points(uid UUID, amount INTEGER)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET points = GREATEST(0, points - amount)
  WHERE id = uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atomically increment a user's points and km.
CREATE OR REPLACE FUNCTION public.increment_user_stats(uid UUID, pts INTEGER, km DOUBLE PRECISION)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET points = points + pts,
      total_km = total_km + km
  WHERE id = uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ════════════════════════════════════════════════════════════
-- Auto-update `updated_at` trigger for zones
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_zones_updated_at
  BEFORE UPDATE ON public.zones
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

-- ════════════════════════════════════════════════════════════
-- Enable Realtime for live territory updates
-- ════════════════════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
ALTER PUBLICATION supabase_realtime ADD TABLE public.zones;
ALTER PUBLICATION supabase_realtime ADD TABLE public.zone_history;

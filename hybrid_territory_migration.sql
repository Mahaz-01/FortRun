-- ============================================================
-- FortRun: Hybrid Territory System Migration
-- Run this in your Supabase SQL Editor to enable inner walls!
-- ============================================================

-- 1. Create the walls table (Micro Level)
CREATE TABLE IF NOT EXISTS public.walls (
  id TEXT PRIMARY KEY,               -- e.g. "grid_33.712_73.056"
  sector_id TEXT NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
  owner_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  clan_id UUID REFERENCES public.clans(id) ON DELETE SET NULL,
  strength INTEGER NOT NULL DEFAULT 0 CHECK (strength >= 0 AND strength <= 100),
  polygon_coords JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_walls_sector ON public.walls (sector_id);

-- 2. Enable RLS and Realtime for walls
ALTER TABLE public.walls ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view walls" 
  ON public.walls FOR SELECT 
  USING (true);

CREATE POLICY "Authenticated users can insert walls" 
  ON public.walls FOR INSERT 
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update own or enemy walls" 
  ON public.walls FOR UPDATE 
  USING (auth.uid() IS NOT NULL);

ALTER PUBLICATION supabase_realtime ADD TABLE public.walls;

-- 3. Trigger for updating updated_at on walls
CREATE TRIGGER trigger_walls_updated_at
  BEFORE UPDATE ON public.walls
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- RPC: process_wall_tick (Run Tracking Game Engine)
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_wall_tick(
  target_wall_id TEXT,
  target_sector_id TEXT,
  uid UUID,
  cid UUID,
  poly JSONB,
  tick_amount INTEGER
) RETURNS void AS $$
DECLARE
  current_strength INTEGER;
  current_owner UUID;
BEGIN
  -- Insert wall if it doesn't exist (strength 0)
  INSERT INTO public.walls (id, sector_id, owner_id, clan_id, strength, polygon_coords)
  VALUES (target_wall_id, target_sector_id, uid, cid, 0, poly)
  ON CONFLICT (id) DO NOTHING;

  -- Select current state
  SELECT strength, owner_id INTO current_strength, current_owner
  FROM public.walls WHERE id = target_wall_id;

  -- WALL BUILDING (User owns it or it's unowned/neutral)
  IF current_owner IS NULL OR current_owner = uid THEN
    UPDATE public.walls 
    SET strength = LEAST(100, strength + tick_amount), 
        owner_id = uid, 
        clan_id = cid,
        updated_at = now()
    WHERE id = target_wall_id;

  -- WALL CRACKING (Enemy owns it)
  ELSE
    IF current_strength - tick_amount <= 0 THEN
      -- Seize the cracked wall
      UPDATE public.walls 
      SET owner_id = uid, 
          clan_id = cid, 
          strength = 1,
          updated_at = now()
      WHERE id = target_wall_id;
    ELSE
      -- Damage the wall
      UPDATE public.walls 
      SET strength = current_strength - tick_amount,
          updated_at = now()
      WHERE id = target_wall_id;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- RPC: sabotage_sector
-- ============================================================
CREATE OR REPLACE FUNCTION public.sabotage_sector(target_sector TEXT)
RETURNS void AS $$
BEGIN
  -- Deal 25 AoE damage to all walls in the sector
  UPDATE public.walls 
  SET strength = GREATEST(0, strength - 25),
      updated_at = now()
  WHERE sector_id = target_sector;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- TRIGGER: Overthrow Mechanic (Sector Owner Recalculation)
-- ============================================================
-- After a wall is updated, this checks who has the most total wall strength in the sector
CREATE OR REPLACE FUNCTION public.recalculate_sector_owner()
RETURNS TRIGGER AS $$
DECLARE
  top_individual RECORD;
  top_clan RECORD;
  total_indiv_strength INTEGER := 0;
  total_clan_strength INTEGER := 0;
BEGIN
  -- Find the individual with the highest sum of strength in this sector
  SELECT owner_id, SUM(strength) as total_strength
  INTO top_individual
  FROM public.walls
  WHERE sector_id = NEW.sector_id AND owner_id IS NOT NULL
  GROUP BY owner_id
  ORDER BY total_strength DESC
  LIMIT 1;

  -- Find the clan with the highest sum of strength in this sector
  SELECT clan_id, SUM(strength) as total_strength
  INTO top_clan
  FROM public.walls
  WHERE sector_id = NEW.sector_id AND clan_id IS NOT NULL
  GROUP BY clan_id
  ORDER BY total_strength DESC
  LIMIT 1;

  IF top_individual.owner_id IS NOT NULL THEN
    total_indiv_strength := top_individual.total_strength;
  END IF;

  IF top_clan.clan_id IS NOT NULL THEN
    total_clan_strength := top_clan.total_strength;
  END IF;

  -- Evaluate Overthrow (Does the Clan beat the Individual?)
  -- If total clan strength > individual strength, the clan owns the sector.
  -- Otherwise, the individual owns it.
  IF total_clan_strength > total_indiv_strength THEN
    UPDATE public.zones
    SET owner_id = NULL,          -- Clans don't use owner_id directly on zones, or we can use clan leader's ID
        owner_type = 'clan',
        total_points = total_clan_strength,
        updated_at = now()
    WHERE id = NEW.sector_id;
  ELSE
    UPDATE public.zones
    SET owner_id = top_individual.owner_id,
        owner_type = 'user',
        total_points = total_indiv_strength,
        updated_at = now()
    WHERE id = NEW.sector_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_overthrow_sector
  AFTER UPDATE OF strength ON public.walls
  FOR EACH ROW
  EXECUTE FUNCTION public.recalculate_sector_owner();

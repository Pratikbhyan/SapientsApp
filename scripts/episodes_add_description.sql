-- Adds a `description` column to the episodes table for richer metadata.
-- Run via Supabase SQL editor or psql.

ALTER TABLE episodes
ADD COLUMN IF NOT EXISTS description text; 
-- Add new datamart metrics columns (DM-006, DM-007, DM-008, DM-011)
-- This script adds columns for note quality, peak day/hour, and last update timestamp
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-27

-- DM-006: Note quality classification by length
-- Add columns to datamartUsers
DO $$
BEGIN
  -- Note quality distribution (counts by quality level)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
                 AND column_name = 'note_quality_poor_count') THEN
    ALTER TABLE dwh.datamartusers ADD COLUMN note_quality_poor_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartusers.note_quality_poor_count IS
      'DM-006: Count of notes with poor quality (< 5 characters)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
                 AND column_name = 'note_quality_fair_count') THEN
    ALTER TABLE dwh.datamartusers ADD COLUMN note_quality_fair_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartusers.note_quality_fair_count IS
      'DM-006: Count of notes with fair quality (5-9 characters)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
                 AND column_name = 'note_quality_good_count') THEN
    ALTER TABLE dwh.datamartusers ADD COLUMN note_quality_good_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartusers.note_quality_good_count IS
      'DM-006: Count of notes with good quality (10-199 characters)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
                 AND column_name = 'note_quality_complex_count') THEN
    ALTER TABLE dwh.datamartusers ADD COLUMN note_quality_complex_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartusers.note_quality_complex_count IS
      'DM-006: Count of notes with complex quality (200-499 characters)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
                 AND column_name = 'note_quality_treatise_count') THEN
    ALTER TABLE dwh.datamartusers ADD COLUMN note_quality_treatise_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartusers.note_quality_treatise_count IS
      'DM-006: Count of notes with treatise quality (500+ characters)';
  END IF;

  -- DM-007: Day with most notes created
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
                 AND column_name = 'peak_day_notes_created') THEN
    ALTER TABLE dwh.datamartusers ADD COLUMN peak_day_notes_created DATE;
    COMMENT ON COLUMN dwh.datamartusers.peak_day_notes_created IS
      'DM-007: Date when user created the most notes';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
                 AND column_name = 'peak_day_notes_created_count') THEN
    ALTER TABLE dwh.datamartusers ADD COLUMN peak_day_notes_created_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartusers.peak_day_notes_created_count IS
      'DM-007: Number of notes created on peak day';
  END IF;

  -- DM-008: Hour with most notes created
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
                 AND column_name = 'peak_hour_notes_created') THEN
    ALTER TABLE dwh.datamartusers ADD COLUMN peak_hour_notes_created SMALLINT;
    COMMENT ON COLUMN dwh.datamartusers.peak_hour_notes_created IS
      'DM-008: Hour of week (0-167) when user created the most notes';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
                 AND column_name = 'peak_hour_notes_created_count') THEN
    ALTER TABLE dwh.datamartusers ADD COLUMN peak_hour_notes_created_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartusers.peak_hour_notes_created_count IS
      'DM-008: Number of notes created at peak hour';
  END IF;

  -- DM-011: Last comment timestamp (for users - last action by this user)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
                 AND column_name = 'last_action_timestamp') THEN
    ALTER TABLE dwh.datamartusers ADD COLUMN last_action_timestamp TIMESTAMP;
    COMMENT ON COLUMN dwh.datamartusers.last_action_timestamp IS
      'DM-011: Timestamp of the most recent action by this user';
  END IF;
END $$;

-- Add same columns to datamartCountries
DO $$
BEGIN
  -- DM-006: Note quality distribution
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'note_quality_poor_count') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN note_quality_poor_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartcountries.note_quality_poor_count IS
      'DM-006: Count of notes with poor quality (< 5 characters)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'note_quality_fair_count') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN note_quality_fair_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartcountries.note_quality_fair_count IS
      'DM-006: Count of notes with fair quality (5-9 characters)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'note_quality_good_count') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN note_quality_good_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartcountries.note_quality_good_count IS
      'DM-006: Count of notes with good quality (10-199 characters)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'note_quality_complex_count') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN note_quality_complex_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartcountries.note_quality_complex_count IS
      'DM-006: Count of notes with complex quality (200-499 characters)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'note_quality_treatise_count') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN note_quality_treatise_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartcountries.note_quality_treatise_count IS
      'DM-006: Count of notes with treatise quality (500+ characters)';
  END IF;

  -- DM-007: Day with most notes created
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'peak_day_notes_created') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN peak_day_notes_created DATE;
    COMMENT ON COLUMN dwh.datamartcountries.peak_day_notes_created IS
      'DM-007: Date when most notes were created in this country';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'peak_day_notes_created_count') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN peak_day_notes_created_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartcountries.peak_day_notes_created_count IS
      'DM-007: Number of notes created on peak day';
  END IF;

  -- DM-008: Hour with most notes created
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'peak_hour_notes_created') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN peak_hour_notes_created SMALLINT;
    COMMENT ON COLUMN dwh.datamartcountries.peak_hour_notes_created IS
      'DM-008: Hour of week (0-167) when most notes were created in this country';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'peak_hour_notes_created_count') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN peak_hour_notes_created_count INTEGER DEFAULT 0;
    COMMENT ON COLUMN dwh.datamartcountries.peak_hour_notes_created_count IS
      'DM-008: Number of notes created at peak hour';
  END IF;
END $$;

-- Add DM-011 to datamartGlobal (last comment timestamp in DB)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartglobal'
                 AND column_name = 'last_comment_timestamp') THEN
    ALTER TABLE dwh.datamartglobal ADD COLUMN last_comment_timestamp TIMESTAMP;
    COMMENT ON COLUMN dwh.datamartglobal.last_comment_timestamp IS
      'DM-011: Timestamp of the most recent comment/action in the database (last DB update)';
  END IF;
END $$;

-- DM-009: Open notes by year (for countries)
-- JSON column: { "2013": 5, "2014": 12, ... } - notes opened in each year that are still open
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'open_notes_by_year') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN open_notes_by_year JSON;
    COMMENT ON COLUMN dwh.datamartcountries.open_notes_by_year IS
      'DM-009: JSON object with year as key and count of notes opened in that year that are still open. Format: {"2013": 5, "2014": 12, ...}';
  END IF;
END $$;

-- DM-010: Notes that took longest to close (for countries)
-- JSON array with top N notes: [{"note_id": 123, "days_to_resolution": 365, "opened_date": "2020-01-01", "closed_date": "2021-01-01"}, ...]
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
                 AND column_name = 'longest_resolution_notes') THEN
    ALTER TABLE dwh.datamartcountries ADD COLUMN longest_resolution_notes JSON;
    COMMENT ON COLUMN dwh.datamartcountries.longest_resolution_notes IS
      'DM-010: JSON array of notes that took longest to close in this country. Format: [{"note_id": 123, "days_to_resolution": 365, "opened_date": "2020-01-01", "closed_date": "2021-01-01"}, ...]';
  END IF;
END $$;


-- Add resolution metrics columns to datamartCountries table
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-26

-- Check if columns already exist before adding them
DO $$
BEGIN
  -- Average resolution time (days)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartCountries'
      AND column_name = 'avg_days_to_resolution'
  ) THEN
    ALTER TABLE dwh.datamartCountries
    ADD COLUMN avg_days_to_resolution DECIMAL(10,2);
    COMMENT ON COLUMN dwh.datamartCountries.avg_days_to_resolution IS
      'Average days to resolve notes (from open to most recent close)';
  END IF;

  -- Median resolution time (days)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartCountries'
      AND column_name = 'median_days_to_resolution'
  ) THEN
    ALTER TABLE dwh.datamartCountries
    ADD COLUMN median_days_to_resolution DECIMAL(10,2);
    COMMENT ON COLUMN dwh.datamartCountries.median_days_to_resolution IS
      'Median days to resolve notes (from open to most recent close)';
  END IF;

  -- Number of notes resolved
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartCountries'
      AND column_name = 'notes_resolved_count'
  ) THEN
    ALTER TABLE dwh.datamartCountries
    ADD COLUMN notes_resolved_count INTEGER;
    COMMENT ON COLUMN dwh.datamartCountries.notes_resolved_count IS
      'Number of notes that have been closed';
  END IF;

  -- Number of notes still open
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartCountries'
      AND column_name = 'notes_still_open_count'
  ) THEN
    ALTER TABLE dwh.datamartCountries
    ADD COLUMN notes_still_open_count INTEGER;
    COMMENT ON COLUMN dwh.datamartCountries.notes_still_open_count IS
      'Number of notes opened but never closed';
  END IF;

  -- Resolution rate
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartCountries'
      AND column_name = 'resolution_rate'
  ) THEN
    ALTER TABLE dwh.datamartCountries
    ADD COLUMN resolution_rate DECIMAL(5,2);
    COMMENT ON COLUMN dwh.datamartCountries.resolution_rate IS
      'Percentage of notes resolved (closed/total opened)';
  END IF;

  RAISE NOTICE 'Resolution metrics columns added successfully';
END $$;

SELECT clock_timestamp() AS Processing,
  'Resolution metrics columns added to datamartCountries' AS Task;

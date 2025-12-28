-- Create table and procedures to maintain current status of notes (open/closed)
-- This improves performance for ETL-003 and ETL-004 by pre-calculating
-- currently open notes instead of using expensive NOT EXISTS queries in datamarts
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-XX

-- Table to track current status of each note
CREATE TABLE IF NOT EXISTS dwh.note_current_status (
  id_note INTEGER NOT NULL,
  dimension_id_country INTEGER NOT NULL,
  opened_dimension_id_user INTEGER,
  opened_dimension_id_date INTEGER,
  is_currently_open BOOLEAN NOT NULL DEFAULT TRUE,
  last_action_at TIMESTAMP NOT NULL,
  last_action_type note_event_enum NOT NULL,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  PRIMARY KEY (id_note)
);

COMMENT ON TABLE dwh.note_current_status IS
  'Tracks current status (open/closed) of each note for efficient querying';
COMMENT ON COLUMN dwh.note_current_status.id_note IS 'OSM note ID';
COMMENT ON COLUMN dwh.note_current_status.dimension_id_country IS 'Country dimension ID';
COMMENT ON COLUMN dwh.note_current_status.opened_dimension_id_user IS 'User who opened the note';
COMMENT ON COLUMN dwh.note_current_status.opened_dimension_id_date IS 'Date when the note was opened';
COMMENT ON COLUMN dwh.note_current_status.is_currently_open IS 'TRUE if note is currently open, FALSE if closed';
COMMENT ON COLUMN dwh.note_current_status.last_action_at IS 'Timestamp of last action on this note';
COMMENT ON COLUMN dwh.note_current_status.last_action_type IS 'Type of last action (opened/closed/reopened)';
COMMENT ON COLUMN dwh.note_current_status.last_updated IS 'When this record was last updated';

-- Index for efficient country-based queries
CREATE INDEX IF NOT EXISTS idx_note_current_status_country_open
  ON dwh.note_current_status (dimension_id_country, is_currently_open)
  WHERE is_currently_open = TRUE;

-- Index for efficient user-based queries
CREATE INDEX IF NOT EXISTS idx_note_current_status_user_open
  ON dwh.note_current_status (opened_dimension_id_user, is_currently_open)
  WHERE is_currently_open = TRUE AND opened_dimension_id_user IS NOT NULL;

-- Procedure to initialize note_current_status table (for initial load)
CREATE OR REPLACE PROCEDURE dwh.initialize_note_current_status()
LANGUAGE plpgsql
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  RAISE NOTICE 'Initializing note_current_status table...';
  
  -- Clear existing data
  TRUNCATE TABLE dwh.note_current_status;
  
  -- Insert current status for all notes
  -- A note is open if the last relevant action (opened/closed/reopened) is 'opened' or 'reopened'
  -- A note is closed if the last relevant action is 'closed'
  INSERT INTO dwh.note_current_status (
    id_note,
    dimension_id_country,
    opened_dimension_id_user,
    opened_dimension_id_date,
    is_currently_open,
    last_action_at,
    last_action_type
  )
  SELECT DISTINCT ON (f.id_note)
    f.id_note,
    f.dimension_id_country,
    f.opened_dimension_id_user,
    f.opened_dimension_id_date,
    CASE
      WHEN f.action_comment IN ('opened', 'reopened') THEN TRUE
      WHEN f.action_comment = 'closed' THEN FALSE
      ELSE NULL
    END as is_currently_open,
    f.action_at as last_action_at,
    f.action_comment as last_action_type
  FROM dwh.facts f
  WHERE f.action_comment IN ('opened', 'closed', 'reopened')
  ORDER BY f.id_note, f.action_at DESC;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE NOTICE 'Initialized % notes in note_current_status', v_count;
END;
$$;

COMMENT ON PROCEDURE dwh.initialize_note_current_status IS
  'Initializes note_current_status table with current state of all notes (for initial load)';

-- Procedure to update note_current_status for new/changed notes (for incremental updates)
CREATE OR REPLACE PROCEDURE dwh.update_note_current_status(
  p_min_timestamp TIMESTAMP DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_count INTEGER;
  v_min_ts TIMESTAMP;
BEGIN
  -- If no timestamp provided, update all notes that have new actions
  -- Otherwise, update only notes with actions after the given timestamp
  IF p_min_timestamp IS NULL THEN
    -- Get the last update timestamp from properties or use a safe default
    SELECT COALESCE(
      (SELECT value::TIMESTAMP FROM dwh.properties WHERE key = 'last_note_status_update'),
      '1970-01-01'::TIMESTAMP
    ) INTO v_min_ts;
  ELSE
    v_min_ts := p_min_timestamp;
  END IF;
  
  RAISE NOTICE 'Updating note_current_status for notes with actions after %', v_min_ts;
  
  -- Update or insert status for notes with new actions
  -- For each note, get the most recent relevant action (opened/closed/reopened)
  -- and update the status accordingly
  INSERT INTO dwh.note_current_status (
    id_note,
    dimension_id_country,
    opened_dimension_id_user,
    opened_dimension_id_date,
    is_currently_open,
    last_action_at,
    last_action_type
  )
  SELECT DISTINCT ON (f.id_note)
    f.id_note,
    f.dimension_id_country,
    f.opened_dimension_id_user,
    f.opened_dimension_id_date,
    CASE
      WHEN f.action_comment IN ('opened', 'reopened') THEN TRUE
      WHEN f.action_comment = 'closed' THEN FALSE
      ELSE NULL
    END as is_currently_open,
    f.action_at as last_action_at,
    f.action_comment as last_action_type
  FROM dwh.facts f
  WHERE f.action_comment IN ('opened', 'closed', 'reopened')
    AND f.action_at >= v_min_ts
  ORDER BY f.id_note, f.action_at DESC
  ON CONFLICT (id_note) DO UPDATE SET
    dimension_id_country = EXCLUDED.dimension_id_country,
    opened_dimension_id_user = EXCLUDED.opened_dimension_id_user,
    opened_dimension_id_date = EXCLUDED.opened_dimension_id_date,
    is_currently_open = EXCLUDED.is_currently_open,
    last_action_at = EXCLUDED.last_action_at,
    last_action_type = EXCLUDED.last_action_type,
    last_updated = CURRENT_TIMESTAMP;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE NOTICE 'Updated % notes in note_current_status', v_count;
  
  -- Update the last update timestamp (using format that fits VARCHAR(26))
  INSERT INTO dwh.properties (key, value)
  VALUES ('last_note_status_update', TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'))
  ON CONFLICT (key) DO UPDATE SET value = TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS');
END;
$$;

COMMENT ON PROCEDURE dwh.update_note_current_status IS
  'Updates note_current_status table for notes with new actions (for incremental updates)';

-- View for easy querying of currently open notes by country
CREATE OR REPLACE VIEW dwh.v_currently_open_notes_by_country AS
SELECT
  dimension_id_country,
  COUNT(*) as currently_open_count
FROM dwh.note_current_status
WHERE is_currently_open = TRUE
GROUP BY dimension_id_country;

COMMENT ON VIEW dwh.v_currently_open_notes_by_country IS
  'Shows count of currently open notes per country (ETL-004)';

-- View for easy querying of currently open notes by user
CREATE OR REPLACE VIEW dwh.v_currently_open_notes_by_user AS
SELECT
  opened_dimension_id_user,
  COUNT(*) as currently_open_count
FROM dwh.note_current_status
WHERE is_currently_open = TRUE
  AND opened_dimension_id_user IS NOT NULL
GROUP BY opened_dimension_id_user;

COMMENT ON VIEW dwh.v_currently_open_notes_by_user IS
  'Shows count of currently open notes per user (ETL-003)';


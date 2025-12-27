-- Calculate and update new datamart metrics (DM-006, DM-007, DM-008, DM-011)
-- This script calculates the new metrics and updates the datamart tables
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-27

-- Function to update new metrics for a user (DM-006, DM-007, DM-008, DM-011)
CREATE OR REPLACE FUNCTION dwh.update_user_new_metrics(p_dimension_user_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_poor_count INTEGER := 0;
  v_fair_count INTEGER := 0;
  v_good_count INTEGER := 0;
  v_complex_count INTEGER := 0;
  v_treatise_count INTEGER := 0;
  v_peak_day DATE;
  v_peak_day_count INTEGER := 0;
  v_peak_hour SMALLINT;
  v_peak_hour_count INTEGER := 0;
  v_last_action_timestamp TIMESTAMP;
BEGIN
  -- DM-006: Note quality classification by comment length
  -- Get comment length from opening comments (first comment of each note)
  WITH note_opening_comments AS (
    SELECT DISTINCT ON (f.id_note)
      f.id_note,
      f.comment_length
    FROM dwh.facts f
    WHERE f.opened_dimension_id_user = p_dimension_user_id
      AND f.action_comment = 'opened'
      AND f.comment_length IS NOT NULL
    ORDER BY f.id_note, f.sequence_action ASC
  )
  SELECT
    COUNT(*) FILTER (WHERE comment_length < 5),
    COUNT(*) FILTER (WHERE comment_length >= 5 AND comment_length < 10),
    COUNT(*) FILTER (WHERE comment_length >= 10 AND comment_length < 200),
    COUNT(*) FILTER (WHERE comment_length >= 200 AND comment_length < 500),
    COUNT(*) FILTER (WHERE comment_length >= 500)
  INTO v_poor_count, v_fair_count, v_good_count, v_complex_count, v_treatise_count
  FROM note_opening_comments;

  -- DM-007: Day with most notes created
  SELECT
    dd.date_id,
    COUNT(*)::INTEGER
  INTO v_peak_day, v_peak_day_count
  FROM dwh.facts f
  JOIN dwh.dimension_days dd ON f.opened_dimension_id_date = dd.dimension_day_id
  WHERE f.opened_dimension_id_user = p_dimension_user_id
    AND f.action_comment = 'opened'
  GROUP BY dd.date_id
  ORDER BY COUNT(*) DESC, dd.date_id DESC
  LIMIT 1;

  -- DM-008: Hour with most notes created
  SELECT
    f.opened_dimension_id_hour_of_week,
    COUNT(*)::INTEGER
  INTO v_peak_hour, v_peak_hour_count
  FROM dwh.facts f
  WHERE f.opened_dimension_id_user = p_dimension_user_id
    AND f.action_comment = 'opened'
    AND f.opened_dimension_id_hour_of_week IS NOT NULL
  GROUP BY f.opened_dimension_id_hour_of_week
  ORDER BY COUNT(*) DESC, f.opened_dimension_id_hour_of_week DESC
  LIMIT 1;

  -- DM-011: Last action timestamp for this user
  SELECT MAX(f.action_at)
  INTO v_last_action_timestamp
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = p_dimension_user_id;

  -- Update datamart
  UPDATE dwh.datamartusers SET
    note_quality_poor_count = COALESCE(v_poor_count, 0),
    note_quality_fair_count = COALESCE(v_fair_count, 0),
    note_quality_good_count = COALESCE(v_good_count, 0),
    note_quality_complex_count = COALESCE(v_complex_count, 0),
    note_quality_treatise_count = COALESCE(v_treatise_count, 0),
    peak_day_notes_created = v_peak_day,
    peak_day_notes_created_count = COALESCE(v_peak_day_count, 0),
    peak_hour_notes_created = v_peak_hour,
    peak_hour_notes_created_count = COALESCE(v_peak_hour_count, 0),
    last_action_timestamp = v_last_action_timestamp
  WHERE dimension_user_id = p_dimension_user_id;
END;
$$;

COMMENT ON FUNCTION dwh.update_user_new_metrics IS
  'Updates new metrics (DM-006, DM-007, DM-008, DM-011) for a user datamart record';

-- Function to update new metrics for a country (DM-006, DM-007, DM-008)
CREATE OR REPLACE FUNCTION dwh.update_country_new_metrics(p_dimension_country_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_poor_count INTEGER := 0;
  v_fair_count INTEGER := 0;
  v_good_count INTEGER := 0;
  v_complex_count INTEGER := 0;
  v_treatise_count INTEGER := 0;
  v_peak_day DATE;
  v_peak_day_count INTEGER := 0;
  v_peak_hour SMALLINT;
  v_peak_hour_count INTEGER := 0;
BEGIN
  -- DM-006: Note quality classification by comment length
  WITH note_opening_comments AS (
    SELECT DISTINCT ON (f.id_note)
      f.id_note,
      f.comment_length
    FROM dwh.facts f
    WHERE f.dimension_id_country = p_dimension_country_id
      AND f.action_comment = 'opened'
      AND f.comment_length IS NOT NULL
    ORDER BY f.id_note, f.sequence_action ASC
  )
  SELECT
    COUNT(*) FILTER (WHERE comment_length < 5),
    COUNT(*) FILTER (WHERE comment_length >= 5 AND comment_length < 10),
    COUNT(*) FILTER (WHERE comment_length >= 10 AND comment_length < 200),
    COUNT(*) FILTER (WHERE comment_length >= 200 AND comment_length < 500),
    COUNT(*) FILTER (WHERE comment_length >= 500)
  INTO v_poor_count, v_fair_count, v_good_count, v_complex_count, v_treatise_count
  FROM note_opening_comments;

  -- DM-007: Day with most notes created
  SELECT
    dd.date_id,
    COUNT(*)::INTEGER
  INTO v_peak_day, v_peak_day_count
  FROM dwh.facts f
  JOIN dwh.dimension_days dd ON f.opened_dimension_id_date = dd.dimension_day_id
  WHERE f.dimension_id_country = p_dimension_country_id
    AND f.action_comment = 'opened'
  GROUP BY dd.date_id
  ORDER BY COUNT(*) DESC, dd.date_id DESC
  LIMIT 1;

  -- DM-008: Hour with most notes created
  SELECT
    f.opened_dimension_id_hour_of_week,
    COUNT(*)::INTEGER
  INTO v_peak_hour, v_peak_hour_count
  FROM dwh.facts f
  WHERE f.dimension_id_country = p_dimension_country_id
    AND f.action_comment = 'opened'
    AND f.opened_dimension_id_hour_of_week IS NOT NULL
  GROUP BY f.opened_dimension_id_hour_of_week
  ORDER BY COUNT(*) DESC, f.opened_dimension_id_hour_of_week DESC
  LIMIT 1;

  -- Update datamart
  UPDATE dwh.datamartcountries SET
    note_quality_poor_count = COALESCE(v_poor_count, 0),
    note_quality_fair_count = COALESCE(v_fair_count, 0),
    note_quality_good_count = COALESCE(v_good_count, 0),
    note_quality_complex_count = COALESCE(v_complex_count, 0),
    note_quality_treatise_count = COALESCE(v_treatise_count, 0),
    peak_day_notes_created = v_peak_day,
    peak_day_notes_created_count = COALESCE(v_peak_day_count, 0),
    peak_hour_notes_created = v_peak_hour,
    peak_hour_notes_created_count = COALESCE(v_peak_hour_count, 0)
  WHERE dimension_country_id = p_dimension_country_id;
END;
$$;

COMMENT ON FUNCTION dwh.update_country_new_metrics IS
  'Updates new metrics (DM-006, DM-007, DM-008) for a country datamart record';

-- Function to update DM-009: Open notes by year for a country
CREATE OR REPLACE FUNCTION dwh.update_country_open_notes_by_year(p_dimension_country_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_open_notes_by_year JSON;
BEGIN
  -- Calculate open notes by year
  -- For each year from 2013 to current year, count notes that:
  -- 1. Were opened in that year
  -- 2. Are still currently open (using note_current_status)
  SELECT json_object_agg(
    year_opened::TEXT,
    open_count
    ORDER BY year_opened
  )
  INTO v_open_notes_by_year
  FROM (
    SELECT
      EXTRACT(YEAR FROM dd.date_id)::INTEGER as year_opened,
      COUNT(DISTINCT ncs.id_note)::INTEGER as open_count
    FROM dwh.note_current_status ncs
    JOIN dwh.dimension_days dd ON ncs.opened_dimension_id_date = dd.dimension_day_id
    WHERE ncs.dimension_id_country = p_dimension_country_id
      AND ncs.is_currently_open = TRUE
      AND EXTRACT(YEAR FROM dd.date_id) >= 2013
    GROUP BY EXTRACT(YEAR FROM dd.date_id)
    ORDER BY year_opened
  ) year_counts;

  -- Update datamart
  UPDATE dwh.datamartcountries SET
    open_notes_by_year = COALESCE(v_open_notes_by_year, '{}'::JSON)
  WHERE dimension_country_id = p_dimension_country_id;
END;
$$;

COMMENT ON FUNCTION dwh.update_country_open_notes_by_year IS
  'DM-009: Updates the open_notes_by_year JSON column for a country, showing notes opened in each year that are still open';

-- Function to update DM-010: Longest resolution notes for a country
CREATE OR REPLACE FUNCTION dwh.update_country_longest_resolution_notes(p_dimension_country_id INTEGER, p_top_n INTEGER DEFAULT 10)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_longest_notes JSON;
BEGIN
  -- Get top N notes that took longest to close in this country
  -- Include note_id, days_to_resolution, opened_date, closed_date
  SELECT json_agg(
    json_build_object(
      'note_id', note_id,
      'days_to_resolution', days_to_resolution,
      'opened_date', opened_date,
      'closed_date', closed_date
    ) ORDER BY days_to_resolution DESC, note_id DESC
  )
  INTO v_longest_notes
  FROM (
    SELECT DISTINCT
      f.id_note as note_id,
      f.days_to_resolution,
      dd_opened.date_id as opened_date,
      dd_closed.date_id as closed_date
    FROM dwh.facts f
    JOIN dwh.dimension_days dd_opened ON f.opened_dimension_id_date = dd_opened.dimension_day_id
    JOIN dwh.dimension_days dd_closed ON f.closed_dimension_id_date = dd_closed.dimension_day_id
    WHERE f.dimension_id_country = p_dimension_country_id
      AND f.action_comment = 'closed'
      AND f.days_to_resolution IS NOT NULL
      AND f.days_to_resolution > 0
    ORDER BY f.days_to_resolution DESC, f.id_note DESC
    LIMIT p_top_n
  ) top_notes;

  -- Update datamart
  UPDATE dwh.datamartcountries SET
    longest_resolution_notes = COALESCE(v_longest_notes, '[]'::JSON)
  WHERE dimension_country_id = p_dimension_country_id;
END;
$$;

COMMENT ON FUNCTION dwh.update_country_longest_resolution_notes IS
  'DM-010: Updates the longest_resolution_notes JSON column for a country with top N notes that took longest to close';

-- Function to update DM-011 for datamartGlobal (last comment timestamp)
CREATE OR REPLACE FUNCTION dwh.update_global_last_comment_timestamp()
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_last_timestamp TIMESTAMP;
BEGIN
  -- Get the most recent action timestamp from facts
  SELECT MAX(action_at)
  INTO v_last_timestamp
  FROM dwh.facts;

  -- Update datamartGlobal
  UPDATE dwh.datamartglobal SET
    last_comment_timestamp = v_last_timestamp
  WHERE dimension_global_id = 1;
END;
$$;

COMMENT ON FUNCTION dwh.update_global_last_comment_timestamp IS
  'DM-011: Updates the last comment timestamp in datamartGlobal (last DB update time)';


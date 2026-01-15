-- Consolidation of Basic Metrics Queries for datamartCountries
--
-- This script creates a function that consolidates multiple separate queries
-- into a single scan of the facts table, significantly improving performance.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2026-01-15
--
-- Performance Impact: Reduces 20+ separate table scans to 1-2 scans
-- Expected Reduction: 60-70% of time spent on basic metrics calculation

-- Function to get consolidated basic metrics for a country
-- This replaces 20+ separate SELECT queries with a single consolidated query
CREATE OR REPLACE FUNCTION dwh.get_country_basic_metrics_consolidated(
  p_dimension_country_id INTEGER,
  p_current_year SMALLINT,
  p_current_month SMALLINT,
  p_current_day SMALLINT
)
RETURNS TABLE (
  -- Whole history metrics
  history_whole_open INTEGER,
  history_whole_commented INTEGER,
  history_whole_closed INTEGER,
  history_whole_closed_with_comment INTEGER,
  history_whole_reopened INTEGER,
  -- Current year metrics
  history_year_open INTEGER,
  history_year_commented INTEGER,
  history_year_closed INTEGER,
  history_year_closed_with_comment INTEGER,
  history_year_reopened INTEGER,
  -- Current month metrics
  history_month_open INTEGER,
  history_month_commented INTEGER,
  history_month_closed INTEGER,
  history_month_closed_with_comment INTEGER,
  history_month_reopened INTEGER,
  -- Current day metrics
  history_day_open INTEGER,
  history_day_commented INTEGER,
  history_day_closed INTEGER,
  history_day_closed_with_comment INTEGER,
  history_day_reopened INTEGER
) AS $$
BEGIN
  RETURN QUERY
  WITH country_facts AS (
    -- Base CTE: Get all facts for the country with date information
    SELECT
      f.fact_id,
      f.id_note,
      f.action_comment,
      f.action_dimension_id_date,
      d.date_id,
      EXTRACT(YEAR FROM d.date_id)::SMALLINT AS year,
      EXTRACT(MONTH FROM d.date_id)::SMALLINT AS month,
      EXTRACT(DAY FROM d.date_id)::SMALLINT AS day,
      -- Pre-join for closed_with_comment check (LEFT JOIN to avoid filtering)
      CASE WHEN nc.note_id IS NOT NULL AND nct.body IS NOT NULL
           AND LENGTH(TRIM(nct.body)) > 0 THEN 1 ELSE 0 END AS has_closed_comment
    FROM dwh.facts f
    JOIN dwh.dimension_days d ON f.action_dimension_id_date = d.dimension_day_id
    LEFT JOIN (
      SELECT note_id, sequence_action, id_user
      FROM note_comments
      WHERE CAST(event AS text) = 'closed'
    ) nc ON f.id_note = nc.note_id
    LEFT JOIN note_comments_text nct ON (
      nc.note_id = nct.note_id
      AND nc.sequence_action = nct.sequence_action
    )
    WHERE f.dimension_id_country = p_dimension_country_id
  ),
  aggregated_metrics AS (
    SELECT
      -- Whole history metrics (all time)
      COUNT(*) FILTER (WHERE action_comment = 'opened') AS whole_open,
      COUNT(*) FILTER (WHERE action_comment = 'commented') AS whole_commented,
      COUNT(DISTINCT id_note) FILTER (WHERE action_comment = 'closed') AS whole_closed,
      COUNT(*) FILTER (WHERE action_comment = 'closed' AND has_closed_comment = 1) AS whole_closed_with_comment,
      COUNT(DISTINCT id_note) FILTER (WHERE action_comment = 'reopened') AS whole_reopened,

      -- Current year metrics
      COUNT(*) FILTER (WHERE action_comment = 'opened' AND year = p_current_year) AS year_open,
      COUNT(*) FILTER (WHERE action_comment = 'commented' AND year = p_current_year) AS year_commented,
      COUNT(DISTINCT id_note) FILTER (WHERE action_comment = 'closed' AND year = p_current_year) AS year_closed,
      COUNT(*) FILTER (WHERE action_comment = 'closed' AND year = p_current_year AND has_closed_comment = 1) AS year_closed_with_comment,
      COUNT(DISTINCT id_note) FILTER (WHERE action_comment = 'reopened' AND year = p_current_year) AS year_reopened,

      -- Current month metrics
      COUNT(*) FILTER (WHERE action_comment = 'opened' AND year = p_current_year AND month = p_current_month) AS month_open,
      COUNT(*) FILTER (WHERE action_comment = 'commented' AND year = p_current_year AND month = p_current_month) AS month_commented,
      COUNT(DISTINCT id_note) FILTER (WHERE action_comment = 'closed' AND year = p_current_year AND month = p_current_month) AS month_closed,
      COUNT(*) FILTER (WHERE action_comment = 'closed' AND year = p_current_year AND month = p_current_month AND has_closed_comment = 1) AS month_closed_with_comment,
      COUNT(DISTINCT id_note) FILTER (WHERE action_comment = 'reopened' AND year = p_current_year AND month = p_current_month) AS month_reopened,

      -- Current day metrics
      COUNT(*) FILTER (WHERE action_comment = 'opened' AND year = p_current_year AND month = p_current_month AND day = p_current_day) AS day_open,
      COUNT(*) FILTER (WHERE action_comment = 'commented' AND year = p_current_year AND month = p_current_month AND day = p_current_day) AS day_commented,
      COUNT(DISTINCT id_note) FILTER (WHERE action_comment = 'closed' AND year = p_current_year AND month = p_current_month AND day = p_current_day) AS day_closed,
      COUNT(*) FILTER (WHERE action_comment = 'closed' AND year = p_current_year AND month = p_current_month AND day = p_current_day AND has_closed_comment = 1) AS day_closed_with_comment,
      COUNT(DISTINCT id_note) FILTER (WHERE action_comment = 'reopened' AND year = p_current_year AND month = p_current_month AND day = p_current_day) AS day_reopened
    FROM country_facts
  )
  SELECT
    whole_open::INTEGER,
    whole_commented::INTEGER,
    whole_closed::INTEGER,
    whole_closed_with_comment::INTEGER,
    whole_reopened::INTEGER,
    year_open::INTEGER,
    year_commented::INTEGER,
    year_closed::INTEGER,
    year_closed_with_comment::INTEGER,
    year_reopened::INTEGER,
    month_open::INTEGER,
    month_commented::INTEGER,
    month_closed::INTEGER,
    month_closed_with_comment::INTEGER,
    month_reopened::INTEGER,
    day_open::INTEGER,
    day_commented::INTEGER,
    day_closed::INTEGER,
    day_closed_with_comment::INTEGER,
    day_reopened::INTEGER
  FROM aggregated_metrics;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION dwh.get_country_basic_metrics_consolidated IS
  'Consolidates 20+ separate queries for basic country metrics into a single table scan. '
  'Significantly improves performance by reducing multiple facts table scans to one.';

-- Verification query to test the function
-- Uncomment to test:
-- SELECT * FROM dwh.get_country_basic_metrics_consolidated(42, 2026, 1, 15);

DO $$
BEGIN
  RAISE NOTICE 'Consolidated basic metrics function created successfully';
  RAISE NOTICE 'This function reduces 20+ separate queries to 1-2 table scans';
  RAISE NOTICE 'Next step: Modify update_datamart_country to use this function';
END $$;

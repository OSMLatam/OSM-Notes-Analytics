-- Generate ETL execution report with statistics about changes
-- This report shows what was processed during the current ETL run
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-26

-- Create a temporary table to store ETL report
CREATE TEMP TABLE IF NOT EXISTS etl_report_temp (
  metric_name TEXT,
  metric_value TEXT,
  metric_type TEXT -- 'count', 'date', 'text'
);

-- Clear previous report
DELETE FROM etl_report_temp;

-- Get execution mode (initial vs incremental)
INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT
  'execution_mode',
  CASE
    WHEN EXISTS (SELECT 1 FROM dwh.properties WHERE key = 'initial load' AND value = 'completed') THEN 'incremental'
    ELSE 'initial'
  END,
  'text';

-- Facts statistics
INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'total_facts', COUNT(*)::TEXT, 'count'
FROM dwh.facts;

INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'facts_by_action_' || action_comment, COUNT(*)::TEXT, 'count'
FROM dwh.facts
GROUP BY action_comment;

-- Date range
INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'earliest_action_date', MIN(action_at)::TEXT, 'date'
FROM dwh.facts;

INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'latest_action_date', MAX(action_at)::TEXT, 'date'
FROM dwh.facts;

-- Users statistics
INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'total_users', COUNT(DISTINCT user_id)::TEXT, 'count'
FROM dwh.dimension_users
WHERE user_id IS NOT NULL;

-- Countries statistics
INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'total_countries', COUNT(*)::TEXT, 'count'
FROM dwh.dimension_countries;

-- Hashtags statistics
INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'total_hashtags', COUNT(DISTINCT dimension_hashtag_id)::TEXT, 'count'
FROM dwh.fact_hashtags;

INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'facts_with_hashtags', COUNT(DISTINCT fact_id)::TEXT, 'count'
FROM dwh.fact_hashtags;

-- Notes statistics
INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'total_notes', COUNT(DISTINCT id_note)::TEXT, 'count'
FROM dwh.facts;

-- Currently open/closed notes (using note_current_status if available)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'note_current_status') THEN
    INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
    SELECT 'currently_open_notes', COUNT(*)::TEXT, 'count'
    FROM dwh.note_current_status
    WHERE is_currently_open = TRUE;

    INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
    SELECT 'currently_closed_notes', COUNT(*)::TEXT, 'count'
    FROM dwh.note_current_status
    WHERE is_currently_open = FALSE;
  END IF;
END $$;

-- Datamarts statistics
INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'datamart_users_count', COUNT(*)::TEXT, 'count'
FROM dwh.datamartusers
WHERE user_id IS NOT NULL;

INSERT INTO etl_report_temp (metric_name, metric_value, metric_type)
SELECT 'datamart_countries_count', COUNT(*)::TEXT, 'count'
FROM dwh.datamartcountries
WHERE country_id IS NOT NULL;

-- Display the report
SELECT
  metric_name AS "Metric",
  metric_value AS "Value"
FROM etl_report_temp
ORDER BY
  CASE metric_type
    WHEN 'text' THEN 1
    WHEN 'date' THEN 2
    WHEN 'count' THEN 3
  END,
  metric_name;


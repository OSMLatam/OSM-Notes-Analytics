-- Optimize Indexes for datamartCountries Performance
--
-- Author: Andres Gomez (AngocA)
-- Version: 2026-01-15
--
-- This script creates specialized composite indexes to optimize
-- datamartCountries queries that scan the facts table multiple times.
-- These indexes target the most common query patterns in update_datamart_country.

-- Index 1: Country + Action Type (most common filter combination)
-- Used in: COUNT queries filtered by country and action_comment
CREATE INDEX IF NOT EXISTS idx_facts_country_action
  ON dwh.facts(dimension_id_country, action_comment)
  WHERE dimension_id_country IS NOT NULL;

COMMENT ON INDEX dwh.idx_facts_country_action IS
  'Optimizes COUNT queries filtered by country and action type (opened/closed/commented/reopened)';

-- Index 2: Country + Date + Action (for temporal queries)
-- Used in: Queries filtering by country, date, and action type
CREATE INDEX IF NOT EXISTS idx_facts_country_date_action
  ON dwh.facts(dimension_id_country, action_dimension_id_date, action_comment)
  INCLUDE (id_note, fact_id)
  WHERE dimension_id_country IS NOT NULL;

COMMENT ON INDEX dwh.idx_facts_country_date_action IS
  'Optimizes temporal queries by country, date, and action type. Includes id_note and fact_id for common SELECTs';

-- Index 3: Country + Opened Date + User (for opening statistics)
-- Used in: Rankings and statistics for users opening notes
CREATE INDEX IF NOT EXISTS idx_facts_country_opened_date_user
  ON dwh.facts(dimension_id_country, opened_dimension_id_date, opened_dimension_id_user)
  INCLUDE (id_note, action_comment)
  WHERE dimension_id_country IS NOT NULL AND opened_dimension_id_user IS NOT NULL;

COMMENT ON INDEX dwh.idx_facts_country_opened_date_user IS
  'Optimizes queries for opening statistics by country, date, and user';

-- Index 4: Country + Closed Date + User (for closing statistics)
-- Used in: Rankings and statistics for users closing notes
CREATE INDEX IF NOT EXISTS idx_facts_country_closed_date_user
  ON dwh.facts(dimension_id_country, closed_dimension_id_date, closed_dimension_id_user)
  INCLUDE (id_note, action_comment)
  WHERE dimension_id_country IS NOT NULL AND closed_dimension_id_user IS NOT NULL;

COMMENT ON INDEX dwh.idx_facts_country_closed_date_user IS
  'Optimizes queries for closing statistics by country, date, and user';

-- Index 5: Country + Application (for application statistics)
-- Used in: Application usage queries
CREATE INDEX IF NOT EXISTS idx_facts_country_application
  ON dwh.facts(dimension_id_country, dimension_application_creation, action_comment)
  INCLUDE (id_note)
  WHERE dimension_id_country IS NOT NULL AND dimension_application_creation IS NOT NULL;

COMMENT ON INDEX dwh.idx_facts_country_application IS
  'Optimizes queries for application statistics by country';

-- Index 6: Country + Days to Resolution (for resolution metrics)
-- Used in: AVG, PERCENTILE queries for days_to_resolution
CREATE INDEX IF NOT EXISTS idx_facts_country_resolution_days
  ON dwh.facts(dimension_id_country, days_to_resolution)
  WHERE dimension_id_country IS NOT NULL 
    AND action_comment = 'closed' 
    AND days_to_resolution IS NOT NULL;

COMMENT ON INDEX dwh.idx_facts_country_resolution_days IS
  'Optimizes resolution time queries (AVG, PERCENTILE) filtered by country';

-- Index 7: Country + Comment Metrics (for comment statistics)
-- Used in: Comment length, URL, mention queries
CREATE INDEX IF NOT EXISTS idx_facts_country_comment_metrics
  ON dwh.facts(dimension_id_country, action_comment)
  INCLUDE (comment_length, has_url, has_mention)
  WHERE dimension_id_country IS NOT NULL AND action_comment = 'commented';

COMMENT ON INDEX dwh.idx_facts_country_comment_metrics IS
  'Optimizes comment statistics queries (length, URLs, mentions) by country';

-- Index 8: Country + Note ID + Action (for distinct note counts)
-- Used in: COUNT(DISTINCT id_note) queries
CREATE INDEX IF NOT EXISTS idx_facts_country_note_action
  ON dwh.facts(dimension_id_country, id_note, action_comment)
  WHERE dimension_id_country IS NOT NULL;

COMMENT ON INDEX dwh.idx_facts_country_note_action IS
  'Optimizes COUNT(DISTINCT id_note) queries by country and action type';

-- Update statistics for better query planning
ANALYZE dwh.facts;

-- Create a function to monitor index usage
CREATE OR REPLACE FUNCTION dwh.monitor_datamart_countries_index_usage()
RETURNS TABLE (
  index_name TEXT,
  table_name TEXT,
  index_scans BIGINT,
  tuples_read BIGINT,
  tuples_fetched BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    schemaname||'.'||indexrelname::TEXT AS index_name,
    schemaname||'.'||tablename::TEXT AS table_name,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched
  FROM pg_stat_user_indexes
  WHERE schemaname = 'dwh'
    AND indexrelname LIKE 'idx_facts_country%'
  ORDER BY idx_scan DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION dwh.monitor_datamart_countries_index_usage() IS
  'Monitors usage of datamartCountries optimization indexes';

-- Display index creation summary
DO $$
DECLARE
  idx_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO idx_count
  FROM pg_indexes
  WHERE schemaname = 'dwh'
    AND indexname LIKE 'idx_facts_country%';
  
  RAISE NOTICE 'Created/verified % optimization indexes for datamartCountries', idx_count;
  RAISE NOTICE 'Run ANALYZE dwh.facts to update statistics';
  RAISE NOTICE 'Use dwh.monitor_datamart_countries_index_usage() to monitor index usage';
END $$;

-- Create Specialized Indexes for Hashtag Analytics
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-24
--
-- This script creates specialized indexes to optimize hashtag analytics queries
-- by action type (opening, resolution, comments)

-- Index for opening hashtag queries (most common)
CREATE INDEX IF NOT EXISTS idx_fact_hashtags_opening
  ON dwh.fact_hashtags(dimension_hashtag_id, fact_id)
  WHERE is_opening_hashtag = TRUE;

COMMENT ON INDEX dwh.idx_fact_hashtags_opening IS
  'Optimizes queries filtering hashtags used in note opening actions';

-- Index for resolution hashtag queries
CREATE INDEX IF NOT EXISTS idx_fact_hashtags_resolution
  ON dwh.fact_hashtags(dimension_hashtag_id, fact_id)
  WHERE is_resolution_hashtag = TRUE;

COMMENT ON INDEX dwh.idx_fact_hashtags_resolution IS
  'Optimizes queries filtering hashtags used in note resolution actions';

-- Index for comment hashtag queries
CREATE INDEX IF NOT EXISTS idx_fact_hashtags_comments
  ON dwh.fact_hashtags(dimension_hashtag_id, fact_id)
  WHERE used_in_action = 'commented';

COMMENT ON INDEX dwh.idx_fact_hashtags_comments IS
  'Optimizes queries filtering hashtags used in comment actions';

-- Composite index for action type analysis
CREATE INDEX IF NOT EXISTS idx_fact_hashtags_action_type
  ON dwh.fact_hashtags(used_in_action, dimension_hashtag_id, fact_id);

COMMENT ON INDEX dwh.idx_fact_hashtags_action_type IS
  'Optimizes queries analyzing hashtag usage by action type';

-- Note: Indexes on facts table with subqueries are not supported by PostgreSQL.
-- The existing indexes on fact_hashtags combined with indexes on facts table
-- (dimension_id_country, opened_dimension_id_user, closed_dimension_id_user, etc.)
-- provide efficient query performance for hashtag analytics by country and user.

-- Statistics update for better query planning
ANALYZE dwh.fact_hashtags;
ANALYZE dwh.facts;

-- Create a function to monitor index usage
CREATE OR REPLACE FUNCTION dwh.monitor_hashtag_index_usage()
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
    i.indexrelname::TEXT as index_name,
    i.relname::TEXT as table_name,
    i.idx_scan as index_scans,
    i.idx_tup_read as tuples_read,
    i.idx_tup_fetch as tuples_fetched
  FROM pg_stat_user_indexes i
  WHERE i.schemaname = 'dwh'
    AND i.indexrelname LIKE '%hashtag%'
  ORDER BY i.idx_scan DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION dwh.monitor_hashtag_index_usage IS
  'Monitor usage statistics for hashtag-related indexes';

-- Create a view for hashtag performance monitoring
CREATE OR REPLACE VIEW dwh.v_hashtag_index_performance AS
SELECT
  schemaname,
  relname AS tablename,
  indexrelname AS indexname,
  idx_scan AS scans,
  idx_tup_read AS tuples_read,
  idx_tup_fetch AS tuples_fetched,
  CASE
    WHEN idx_scan > 0 THEN ROUND(idx_tup_read::DECIMAL / idx_scan, 2)
    ELSE 0
  END AS avg_tuples_per_scan,
  CASE
    WHEN idx_tup_read > 0 THEN ROUND(idx_tup_fetch::DECIMAL / idx_tup_read * 100, 2)
    ELSE 0
  END AS fetch_efficiency_percent
FROM pg_stat_user_indexes
WHERE schemaname = 'dwh'
  AND indexrelname LIKE '%hashtag%'
ORDER BY idx_scan DESC;

COMMENT ON VIEW dwh.v_hashtag_index_performance IS
  'Performance monitoring view for hashtag-related indexes';


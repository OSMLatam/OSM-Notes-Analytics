-- Benchmark: Trigger Performance Test
-- Tests the performance impact of calculate_note_activity_metrics trigger
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-26
--
-- Run this before and after enabling the trigger to compare performance

-- ============================================================================
-- Test 1: Measure trigger overhead for single INSERT
-- ============================================================================

\timing on

-- Test with trigger enabled
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
INSERT INTO dwh.facts (
  id_note,
  sequence_action,
  dimension_id_country,
  action_at,
  action_comment,
  action_dimension_id_date,
  action_dimension_id_hour_of_week,
  action_dimension_id_user,
  opened_dimension_id_date,
  opened_dimension_id_hour_of_week,
  opened_dimension_id_user,
  recent_opened_dimension_id_date
) VALUES (
  999999,  -- test note id
  1,
  57,  -- Colombia
  CURRENT_TIMESTAMP,
  'opened',
  20250101,
  0,
  1,
  20250101,
  0,
  1,
  20250101
);

-- ============================================================================
-- Test 2: Measure trigger overhead for bulk INSERT (100 rows)
-- ============================================================================

-- Generate 100 test rows
WITH test_data AS (
  SELECT
    (1000000 + generate_series(1, 100))::INTEGER as id_note,
    1 as sequence_action,
    57 as dimension_id_country,
    CURRENT_TIMESTAMP as action_at,
    'opened'::note_event_enum as action_comment,
    20250101 as action_dimension_id_date,
    0 as action_dimension_id_hour_of_week,
    1 as action_dimension_id_user,
    20250101 as opened_dimension_id_date,
    0 as opened_dimension_id_hour_of_week,
    1 as opened_dimension_id_user,
    20250101 as recent_opened_dimension_id_date
)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
INSERT INTO dwh.facts (
  id_note, sequence_action, dimension_id_country, action_at, action_comment,
  action_dimension_id_date, action_dimension_id_hour_of_week, action_dimension_id_user,
  opened_dimension_id_date, opened_dimension_id_hour_of_week, opened_dimension_id_user,
  recent_opened_dimension_id_date
)
SELECT * FROM test_data;

-- ============================================================================
-- Test 3: Measure query performance of trigger (COUNT queries)
-- ============================================================================

-- Simulate what the trigger does for a specific note
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT
  COUNT(*) FILTER (WHERE action_comment = 'commented') as comments,
  COUNT(*) FILTER (WHERE action_comment = 'reopened') as reopenings,
  COUNT(*) as total_actions
FROM dwh.facts
WHERE id_note = 999999
  AND fact_id < (
    SELECT MAX(fact_id) FROM dwh.facts WHERE id_note = 999999
  );

-- ============================================================================
-- Test 4: Check index usage
-- ============================================================================

-- Verify index exists and is being used
SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'dwh'
  AND tablename = 'facts'
  AND indexname LIKE '%resolution%';

-- Check index statistics
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan as index_scans,
  idx_tup_read as tuples_read,
  idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'dwh'
  AND tablename = 'facts'
  AND indexname LIKE '%resolution%';

-- ============================================================================
-- Test 5: Compare performance with/without trigger
-- ============================================================================

-- Baseline: Insert without trigger
-- (Need to temporarily disable trigger for this test)
-- ALTER TABLE dwh.facts DISABLE TRIGGER calculate_note_activity_metrics_trigger;

\timing off

-- ============================================================================
-- Test 6: Monitor actual ETL performance
-- ============================================================================

-- Query to check recent ETL performance from logs
SELECT
  log_time,
  message
FROM dwh.etl_log
WHERE message LIKE '%INSERT%facts%'
  AND log_time > NOW() - INTERVAL '1 day'
ORDER BY log_time DESC
LIMIT 10;

-- Check average insert time
SELECT
  AVG(EXTRACT(EPOCH FROM (finished_at - started_at))) as avg_duration_seconds,
  COUNT(*) as total_inserts,
  MIN(EXTRACT(EPOCH FROM (finished_at - started_at))) as min_duration,
  MAX(EXTRACT(EPOCH FROM (finished_at - started_at))) as max_duration
FROM dwh.etl_log
WHERE operation = 'INSERT'
  AND table_name = 'facts'
  AND log_time > NOW() - INTERVAL '7 days';


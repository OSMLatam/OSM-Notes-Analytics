-- Measure Trigger Performance Impact
--
-- This script compares INSERT performance with and without the trigger
-- to measure the actual overhead
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-26

-- Enable timing
\timing on

\echo '════════════════════════════════════════════════════════════════'
\echo '  MEASURING TRIGGER PERFORMANCE IMPACT'
\echo '════════════════════════════════════════════════════════════════'
\echo ''

-- ============================================================================
-- Method 1: Measure single INSERT with trigger enabled
-- ============================================================================

\echo 'Test 1: Single INSERT with trigger (CURRENT STATE)'
\echo '────────────────────────────────────────────────────────────────'

-- Simulate inserting one fact
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
  9999999,  -- unique note for testing
  1,
  57,
  CURRENT_TIMESTAMP,
  'opened',
  20250101,
  0,
  1,
  20250101,
  0,
  1,
  20250101
)
RETURNING fact_id;

\echo ''

-- ============================================================================
-- Method 2: Measure what the trigger DOES (the SELECT inside trigger)
-- ============================================================================

\echo 'Test 2: SELECT query that trigger executes (per row)'
\echo '────────────────────────────────────────────────────────────────'

-- This is what the trigger does for EACH row inserted
-- Get the last inserted fact_id first
DO $$
DECLARE
  v_fact_id INTEGER;
BEGIN
  SELECT MAX(fact_id) INTO v_fact_id FROM dwh.facts WHERE id_note = 9999999;

  IF v_fact_id IS NOT NULL THEN
    RAISE NOTICE 'Running EXPLAIN ANALYZE for trigger query on fact_id: %', v_fact_id;
    RAISE NOTICE 'This SELECT runs ONCE for each INSERT row';
  END IF;
END $$;

-- Simulate the trigger's SELECT query
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT
  COUNT(*) FILTER (WHERE action_comment = 'commented') as total_comments,
  COUNT(*) FILTER (WHERE action_comment = 'reopened') as total_reopenings,
  COUNT(*) as total_actions
FROM dwh.facts
WHERE id_note = 9999999
  AND fact_id < (
    SELECT MAX(fact_id) FROM dwh.facts WHERE id_note = 9999999
  );

\echo ''

-- ============================================================================
-- Method 3: Measure impact on bulk operations (simulate ETL)
-- ============================================================================

\echo 'Test 3: Bulk INSERT performance (simulating ETL with trigger)'
\echo '────────────────────────────────────────────────────────────────'

-- Insert 50 test facts to simulate incremental ETL
BEGIN;

-- Note: This WILL be slow with trigger enabled!
DO $$
DECLARE
  i INTEGER;
  start_time TIMESTAMP;
  end_time TIMESTAMP;
BEGIN
  start_time := clock_timestamp();

  FOR i IN 1..50 LOOP
    INSERT INTO dwh.facts (
      id_note, sequence_action, dimension_id_country, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week, action_dimension_id_user,
      opened_dimension_id_date, opened_dimension_id_hour_of_week, opened_dimension_id_user,
      recent_opened_dimension_id_date
    ) VALUES (
      9999999,
      i,
      57,
      CURRENT_TIMESTAMP,
      CASE (i % 3) WHEN 0 THEN 'commented' WHEN 1 THEN 'reopened' ELSE 'opened' END::note_event_enum,
      20250101,
      0,
      1,
      20250101,
      0,
      1,
      20250101
    );
  END LOOP;

  end_time := clock_timestamp();

  RAISE NOTICE 'Inserted 50 rows in: % milliseconds',
    EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
  RAISE NOTICE 'Average per row: % milliseconds',
    (EXTRACT(EPOCH FROM (end_time - start_time)) * 1000) / 50;
END $$;

ROLLBACK;

\echo ''

-- ============================================================================
-- Method 4: How to measure WITHOUT trigger (for comparison)
-- ============================================================================

\echo '════════════════════════════════════════════════════════════════'
\echo '  TO MEASURE WITHOUT TRIGGER:'
\echo '════════════════════════════════════════════════════════════════'
\echo ''
\echo '1. Disable trigger temporarily:'
\echo '   ALTER TABLE dwh.facts DISABLE TRIGGER calculate_note_activity_metrics_trigger;'
\echo ''
\echo '2. Run the same INSERT queries above'
\echo ''
\echo '3. Compare execution times'
\echo ''
\echo '4. Re-enable trigger:'
\echo '   ALTER TABLE dwh.facts ENABLE TRIGGER calculate_note_activity_metrics_trigger;'
\echo ''

\echo '════════════════════════════════════════════════════════════════'
\echo '  RECOMMENDATIONS'
\echo '════════════════════════════════════════════════════════════════'
\echo ''
\echo 'If trigger adds > 50ms per INSERT or > 10% to total ETL time:'
\echo ''
\echo 'OPTION 1: Calculate in ETL before INSERT'
\echo '  - Compute metrics in Staging_*.sql procedures'
\echo '  - Insert pre-calculated values'
\echo '  - No trigger needed'
\echo ''
\echo 'OPTION 2: Use materialized view'
\echo '  - Store metrics in separate table'
\echo '  - Refresh periodically instead of real-time'
\echo ''
\echo 'OPTION 3: Calculate on query'
\echo '  - Don''t store at INSERT time'
\echo '  - Calculate when querying datamarts'
\echo '  - Trade-off: slower queries vs faster ETL'
\echo ''

\timing off


-- Test and Validation Script for Hashtag Metrics Implementation
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-24
--
-- This script validates the hashtag metrics implementation

-- Test 1: Verify table structure
SELECT 'Test 1: Table Structure' AS test_name;

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'dwh'
  AND table_name = 'fact_hashtags'
  AND column_name IN ('used_in_action', 'is_opening_hashtag', 'is_resolution_hashtag')
ORDER BY column_name;

-- Test 2: Verify data population
SELECT 'Test 2: Data Population' AS test_name;

SELECT
  used_in_action,
  COUNT(*) as count,
  COUNT(*) FILTER (WHERE is_opening_hashtag = TRUE) as opening_count,
  COUNT(*) FILTER (WHERE is_resolution_hashtag = TRUE) as resolution_count
FROM dwh.fact_hashtags
GROUP BY used_in_action
ORDER BY used_in_action;

-- Test 3: Verify views exist and work
SELECT 'Test 3: Views Functionality' AS test_name;

-- Test opening hashtags view
SELECT COUNT(*) as opening_view_count
FROM dwh.v_hashtags_opening;

-- Test resolution hashtags view
SELECT COUNT(*) as resolution_view_count
FROM dwh.v_hashtags_resolution;

-- Test comments hashtags view
SELECT COUNT(*) as comments_view_count
FROM dwh.v_hashtags_comments;

-- Test overall hashtags view
SELECT COUNT(*) as overall_view_count
FROM dwh.v_hashtags_top_overall;

-- Test 4: Verify functions exist
SELECT 'Test 4: Functions Existence' AS test_name;

SELECT
  routine_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'dwh'
  AND routine_name IN (
    'calculate_country_hashtag_metrics',
    'calculate_user_hashtag_metrics',
    'update_country_hashtag_metrics',
    'update_user_hashtag_metrics',
    'monitor_hashtag_index_usage'
  )
ORDER BY routine_name;

-- Test 5: Test country hashtag metrics function
SELECT 'Test 5: Country Hashtag Metrics Function' AS test_name;

-- Test with a sample country (if data exists)
DO $$
DECLARE
  v_test_country_id INTEGER;
  v_result RECORD;
BEGIN
  -- Get first country with hashtag data
  SELECT f.dimension_id_country INTO v_test_country_id
  FROM dwh.facts f
  JOIN dwh.fact_hashtags fh ON f.fact_id = fh.fact_id
  LIMIT 1;

  IF v_test_country_id IS NOT NULL THEN
    SELECT * INTO v_result
    FROM dwh.calculate_country_hashtag_metrics(v_test_country_id);

    RAISE NOTICE 'Country % hashtag metrics:', v_test_country_id;
    RAISE NOTICE '  Opening hashtags: %', v_result.hashtags_opening;
    RAISE NOTICE '  Resolution hashtags: %', v_result.hashtags_resolution;
    RAISE NOTICE '  Comments hashtags: %', v_result.hashtags_comments;
    RAISE NOTICE '  Top opening hashtag: %', v_result.top_opening_hashtag;
    RAISE NOTICE '  Top resolution hashtag: %', v_result.top_resolution_hashtag;
    RAISE NOTICE '  Opening count: %', v_result.opening_hashtag_count;
    RAISE NOTICE '  Resolution count: %', v_result.resolution_hashtag_count;
  ELSE
    RAISE NOTICE 'No country data found for testing';
  END IF;
END $$;

-- Test 6: Test user hashtag metrics function
SELECT 'Test 6: User Hashtag Metrics Function' AS test_name;

-- Test with a sample user (if data exists)
DO $$
DECLARE
  v_test_user_id INTEGER;
  v_result RECORD;
BEGIN
  -- Get first user with hashtag data
  SELECT f.opened_dimension_id_user INTO v_test_user_id
  FROM dwh.facts f
  JOIN dwh.fact_hashtags fh ON f.fact_id = fh.fact_id
  WHERE f.opened_dimension_id_user IS NOT NULL
  LIMIT 1;

  IF v_test_user_id IS NOT NULL THEN
    SELECT * INTO v_result
    FROM dwh.calculate_user_hashtag_metrics(v_test_user_id);

    RAISE NOTICE 'User % hashtag metrics:', v_test_user_id;
    RAISE NOTICE '  Opening hashtags: %', v_result.hashtags_opening;
    RAISE NOTICE '  Resolution hashtags: %', v_result.hashtags_resolution;
    RAISE NOTICE '  Comments hashtags: %', v_result.hashtags_comments;
    RAISE NOTICE '  Favorite opening hashtag: %', v_result.favorite_opening_hashtag;
    RAISE NOTICE '  Favorite resolution hashtag: %', v_result.favorite_resolution_hashtag;
    RAISE NOTICE '  Opening count: %', v_result.opening_hashtag_count;
    RAISE NOTICE '  Resolution count: %', v_result.resolution_hashtag_count;
  ELSE
    RAISE NOTICE 'No user data found for testing';
  END IF;
END $$;

-- Test 7: Verify indexes exist
SELECT 'Test 7: Index Verification' AS test_name;

SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'dwh'
  AND indexname LIKE '%hashtag%'
ORDER BY indexname;

-- Test 8: Performance test - compare query execution times
SELECT 'Test 8: Performance Test' AS test_name;

-- Test query performance for opening hashtags
EXPLAIN (ANALYZE, BUFFERS)
SELECT
  h.description,
  COUNT(*) as usage_count
FROM dwh.fact_hashtags fh
JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
WHERE fh.is_opening_hashtag = TRUE
GROUP BY h.description
ORDER BY usage_count DESC
LIMIT 10;

-- Test 9: Verify datamart enhancements
SELECT 'Test 9: Datamart Enhancements' AS test_name;

-- Check if new columns exist in datamartCountries
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'dwh'
  AND table_name = 'datamartCountries'
  AND column_name LIKE '%hashtag%'
ORDER BY column_name;

-- Check if new columns exist in datamartUsers
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'dwh'
  AND table_name = 'datamartUsers'
  AND column_name LIKE '%hashtag%'
ORDER BY column_name;

-- Test 10: Sample analytics queries
SELECT 'Test 10: Sample Analytics Queries' AS test_name;

-- Query 1: Top hashtags by action type
SELECT
  'Top Opening Hashtags' as analysis_type,
  hashtag,
  usage_count
FROM dwh.v_hashtags_opening
LIMIT 5

UNION ALL

SELECT
  'Top Resolution Hashtags' as analysis_type,
  hashtag,
  usage_count
FROM dwh.v_hashtags_resolution
LIMIT 5

UNION ALL

SELECT
  'Top Comment Hashtags' as analysis_type,
  hashtag,
  usage_count
FROM dwh.v_hashtags_comments
LIMIT 5;

-- Query 2: Hashtag effectiveness analysis
SELECT
  h.description as hashtag,
  COUNT(*) FILTER (WHERE fh.is_opening_hashtag = TRUE) as opening_usage,
  COUNT(*) FILTER (WHERE fh.is_resolution_hashtag = TRUE) as resolution_usage,
  ROUND(
    COUNT(*) FILTER (WHERE fh.is_resolution_hashtag = TRUE)::DECIMAL /
    NULLIF(COUNT(*) FILTER (WHERE fh.is_opening_hashtag = TRUE), 0) * 100, 2
  ) as resolution_rate_percent,
  AVG(f.days_to_resolution) FILTER (WHERE fh.is_resolution_hashtag = TRUE) as avg_resolution_days
FROM dwh.fact_hashtags fh
JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
JOIN dwh.facts f ON fh.fact_id = f.fact_id
GROUP BY h.description
HAVING COUNT(*) >= 10  -- Only hashtags with sufficient sample
ORDER BY resolution_rate_percent DESC
LIMIT 10;

-- Test 11: Index usage monitoring
SELECT 'Test 11: Index Usage Monitoring' AS test_name;

SELECT * FROM dwh.monitor_hashtag_index_usage();

-- Test 12: Final validation summary
SELECT 'Test 12: Implementation Summary' AS test_name;

SELECT
  'Implementation Status' as metric,
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'dwh' AND table_name = 'fact_hashtags' AND column_name = 'used_in_action')
    THEN 'COMPLETED'
    ELSE 'MISSING'
  END as status

UNION ALL

SELECT
  'Views Created' as metric,
  CAST(COUNT(*) as TEXT) as status
FROM information_schema.views
WHERE table_schema = 'dwh'
  AND table_name LIKE 'v_hashtags%'

UNION ALL

SELECT
  'Functions Created' as metric,
  CAST(COUNT(*) as TEXT) as status
FROM information_schema.routines
WHERE routine_schema = 'dwh'
  AND routine_name LIKE '%hashtag%'

UNION ALL

SELECT
  'Indexes Created' as metric,
  CAST(COUNT(*) as TEXT) as status
FROM pg_indexes
WHERE schemaname = 'dwh'
  AND indexname LIKE '%hashtag%'

UNION ALL

SELECT
  'Data Records' as metric,
  CAST(COUNT(*) as TEXT) as status
FROM dwh.fact_hashtags;

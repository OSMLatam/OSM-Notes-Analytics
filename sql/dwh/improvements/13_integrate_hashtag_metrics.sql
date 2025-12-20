-- Integration Script for Hashtag Metrics Enhancement
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-20
--
-- This script integrates all hashtag metrics enhancements into the DWH
-- Run this after the basic DWH is set up

-- Step 1: Enhance datamarts with hashtag metrics
\echo 'Step 1: Enhancing datamarts with hashtag metrics...'
\i sql/dwh/improvements/13_enhance_datamarts_hashtags.sql

-- Step 2: Create specialized indexes (SKIPPED - heavy operation, run manually if needed)
-- \echo 'Step 2: Creating specialized indexes...'
-- \i sql/dwh/improvements/13_create_hashtag_indexes.sql
\echo 'Step 2: Creating specialized indexes - SKIPPED (heavy operation)'
\echo 'Run sql/dwh/improvements/13_create_hashtag_indexes.sql manually if needed'

-- Step 3: Run validation tests
\echo 'Step 3: Running validation tests...'
\i sql/dwh/improvements/13_test_hashtag_implementation.sql

-- Step 4: Update existing datamart data (if any exists)
\echo 'Step 4: Updating existing datamart data...'

-- Update country hashtag metrics for all countries
DO $$
DECLARE
  v_country_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_country_count
  FROM dwh.dimension_countries
  WHERE modified = TRUE;

  IF v_country_count > 0 THEN
    CALL dwh.update_country_hashtag_metrics();
    RAISE NOTICE 'Updated hashtag metrics for % countries', v_country_count;
  ELSE
    RAISE NOTICE 'No countries marked as modified - skipping country update';
  END IF;
END $$;

-- Update user hashtag metrics for all users
DO $$
DECLARE
  v_user_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_user_count
  FROM dwh.dimension_users
  WHERE modified = TRUE AND is_current = TRUE;

  IF v_user_count > 0 THEN
    CALL dwh.update_user_hashtag_metrics();
    RAISE NOTICE 'Updated hashtag metrics for % users', v_user_count;
  ELSE
    RAISE NOTICE 'No users marked as modified - skipping user update';
  END IF;
END $$;

-- Step 5: Final summary
\echo 'Step 5: Implementation Summary'

SELECT
  'Hashtag Metrics Enhancement' as feature,
  'COMPLETED' as status,
  NOW() as completed_at

UNION ALL

SELECT
  'Datamart Enhancements' as feature,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'dwh'
        AND table_name = 'datamartCountries'
        AND column_name = 'hashtags_opening'
    )
    THEN 'COMPLETED'
    ELSE 'FAILED'
  END as status,
  NOW() as completed_at

UNION ALL

SELECT
  'Specialized Indexes' as feature,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'dwh'
        AND indexname = 'idx_fact_hashtags_opening'
    )
    THEN 'COMPLETED'
    ELSE 'FAILED'
  END as status,
  NOW() as completed_at

UNION ALL

SELECT
  'Analytics Views' as feature,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM information_schema.views
      WHERE table_schema = 'dwh'
        AND table_name = 'v_hashtags_opening'
    )
    THEN 'COMPLETED'
    ELSE 'FAILED'
  END as status,
  NOW() as completed_at;

-- Step 6: Usage examples
\echo 'Step 6: Usage Examples'

\echo 'Example 1: Top hashtags by action type'
SELECT
  'Opening' as action_type,
  hashtag,
  usage_count
FROM dwh.v_hashtags_opening
LIMIT 3

UNION ALL

SELECT
  'Resolution' as action_type,
  hashtag,
  usage_count
FROM dwh.v_hashtags_resolution
LIMIT 3;

\echo 'Example 2: Hashtag effectiveness analysis'
SELECT
  h.description as hashtag,
  COUNT(*) FILTER (WHERE fh.is_opening_hashtag = TRUE) as opening_usage,
  COUNT(*) FILTER (WHERE fh.is_resolution_hashtag = TRUE) as resolution_usage,
  CASE
    WHEN COUNT(*) FILTER (WHERE fh.is_opening_hashtag = TRUE) > 0
    THEN ROUND(
      COUNT(*) FILTER (WHERE fh.is_resolution_hashtag = TRUE)::DECIMAL /
      COUNT(*) FILTER (WHERE fh.is_opening_hashtag = TRUE) * 100, 2
    )
    ELSE 0
  END as resolution_rate_percent
FROM dwh.fact_hashtags fh
JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
GROUP BY h.description
HAVING COUNT(*) >= 5
ORDER BY resolution_rate_percent DESC
LIMIT 5;

\echo 'Example 3: Country hashtag patterns'
SELECT
  c.country_name,
  COUNT(*) FILTER (WHERE fh.is_opening_hashtag = TRUE) as opening_hashtags,
  COUNT(*) FILTER (WHERE fh.is_resolution_hashtag = TRUE) as resolution_hashtags,
  COUNT(DISTINCT fh.dimension_hashtag_id) as unique_hashtags
FROM dwh.fact_hashtags fh
JOIN dwh.facts f ON fh.fact_id = f.fact_id
JOIN dwh.dimension_countries c ON f.dimension_id_country = c.dimension_country_id
GROUP BY c.country_name
ORDER BY opening_hashtags DESC
LIMIT 5;

\echo 'Hashtag Metrics Enhancement Implementation Complete!'
\echo 'You can now use the enhanced views and functions for detailed hashtag analytics.'

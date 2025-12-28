-- Check prerequisites for ML training
-- This script verifies that all required tables/views exist and have data
--
-- Author: OSM Notes Analytics Project
-- Date: 2025-12-27
-- Purpose: Verify ML training prerequisites

-- ============================================================================
-- 1. Check Core Tables (Required)
-- ============================================================================

SELECT 'Core Tables Check' as check_type;

-- Check facts table
SELECT 
  'dwh.facts' as table_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'facts')
    THEN 'EXISTS'
    ELSE 'MISSING'
  END as status,
  (SELECT COUNT(*) FROM dwh.facts WHERE action_comment = 'opened' AND closed_dimension_id_date IS NOT NULL) as training_samples
FROM information_schema.tables
WHERE table_schema = 'dwh' AND table_name = 'facts'
LIMIT 1;

-- Check dimension tables
SELECT 
  'dwh.dimension_days' as table_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_days')
    THEN 'EXISTS'
    ELSE 'MISSING'
  END as status,
  (SELECT COUNT(*) FROM dwh.dimension_days) as row_count
FROM information_schema.tables
WHERE table_schema = 'dwh' AND table_name = 'dimension_days'
LIMIT 1;

SELECT 
  'dwh.dimension_applications' as table_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_applications')
    THEN 'EXISTS'
    ELSE 'MISSING'
  END as status,
  (SELECT COUNT(*) FROM dwh.dimension_applications) as row_count
FROM information_schema.tables
WHERE table_schema = 'dwh' AND table_name = 'dimension_applications'
LIMIT 1;

-- ============================================================================
-- 2. Check Datamarts (Optional but Recommended)
-- ============================================================================

SELECT 'Datamarts Check' as check_type;

-- Check datamartCountries
SELECT 
  'dwh.datamartCountries' as table_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'datamartcountries')
    THEN 'EXISTS'
    ELSE 'MISSING'
  END as status,
  (SELECT COUNT(*) FROM dwh.datamartcountries) as row_count,
  (SELECT COUNT(*) FROM dwh.datamartcountries WHERE resolution_rate IS NOT NULL) as rows_with_data
FROM information_schema.tables
WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
LIMIT 1;

-- Check datamartUsers
SELECT 
  'dwh.datamartUsers' as table_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'datamartusers')
    THEN 'EXISTS'
    ELSE 'MISSING'
  END as status,
  (SELECT COUNT(*) FROM dwh.datamartusers) as row_count,
  (SELECT COUNT(*) FROM dwh.datamartusers WHERE user_response_time IS NOT NULL) as rows_with_data
FROM information_schema.tables
WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
LIMIT 1;

-- ============================================================================
-- 3. Check Hashtag Features View (Optional but Recommended)
-- ============================================================================

SELECT 'Hashtag Features Check' as check_type;

SELECT 
  'dwh.v_note_hashtag_features' as view_name,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'dwh' AND table_name = 'v_note_hashtag_features')
    THEN 'EXISTS'
    ELSE 'MISSING'
  END as status,
  (SELECT COUNT(*) FROM dwh.v_note_hashtag_features) as row_count
FROM information_schema.views
WHERE table_schema = 'dwh' AND table_name = 'v_note_hashtag_features'
LIMIT 1;

-- ============================================================================
-- 4. Check Training Data Availability
-- ============================================================================

SELECT 'Training Data Check' as check_type;

-- Check if training view can be created/queried
SELECT 
  'Training samples available' as metric,
  COUNT(*) as total_notes,
  COUNT(DISTINCT main_category) as categories,
  COUNT(DISTINCT specific_type) as types,
  COUNT(DISTINCT recommended_action) as actions
FROM (
  SELECT
    f.id_note,
    -- Level 1: Main Category
    CASE
      WHEN f.closed_dimension_id_date IS NOT NULL AND
           (SELECT COUNT(*)
            FROM dwh.facts f2
            WHERE f2.id_note = f.id_note
              AND f2.action_comment = 'commented'
              AND f2.action_at < f.closed_dimension_id_date) > 0
      THEN 'contributes_with_change'
      WHEN f.closed_dimension_id_date IS NOT NULL
      THEN 'doesnt_contribute'
      ELSE NULL
    END as main_category,
    -- Level 2: Specific Type (simplified)
    CASE
      WHEN f.comment_length < 10 THEN 'empty'
      WHEN f.comment_length < 50 AND f.total_comments_on_note > 2 THEN 'lack_of_precision'
      WHEN f.comment_length > 200 AND f.has_url = TRUE THEN 'advertising'
      WHEN f.closed_dimension_id_date IS NULL AND
           EXTRACT(DAY FROM CURRENT_DATE - d.date_id) > 180 THEN 'obsolete'
      WHEN a.application_name IN ('Maps.me', 'StreetComplete', 'OrganicMaps', 'OnOSM.org')
           AND f.comment_length > 30 THEN 'adds_to_map'
      ELSE 'other'
    END as specific_type,
    -- Level 3: Action Recommendation
    CASE
      WHEN f.closed_dimension_id_date IS NOT NULL AND
           (SELECT COUNT(*)
            FROM dwh.facts f2
            WHERE f2.id_note = f.id_note
              AND f2.action_comment = 'commented'
              AND f2.action_at < f.closed_dimension_id_date) > 0
      THEN 'process'
      WHEN f.closed_dimension_id_date IS NOT NULL
      THEN 'close'
      WHEN f.comment_length < 50 AND f.total_comments_on_note > 2
      THEN 'needs_more_data'
      ELSE NULL
    END as recommended_action
  FROM dwh.facts f
  LEFT JOIN dwh.dimension_days d ON f.opened_dimension_id_date = d.dimension_day_id
  LEFT JOIN dwh.dimension_applications a ON f.dimension_application_creation = a.dimension_application_id
  WHERE f.action_comment = 'opened'
    AND f.closed_dimension_id_date IS NOT NULL
    AND f.comment_length > 0
) training_data
WHERE main_category IS NOT NULL;

-- ============================================================================
-- 5. Summary and Recommendations
-- ============================================================================

SELECT 'Summary' as check_type;

SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'facts')
     AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_days')
     AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_applications')
    THEN '✅ READY: Core tables exist. Can train with basic features.'
    ELSE '❌ NOT READY: Missing core tables. Run ETL first.'
  END as core_status,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'datamartcountries')
     AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'datamartusers')
     AND (SELECT COUNT(*) FROM dwh.datamartcountries) > 0
     AND (SELECT COUNT(*) FROM dwh.datamartusers) > 0
    THEN '✅ OPTIMAL: Datamarts populated. Will use enhanced features.'
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'datamartcountries')
     AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'datamartusers')
    THEN '⚠️  PARTIAL: Datamarts exist but may be empty. Training will use default values (0).'
    ELSE '⚠️  BASIC: Datamarts missing. Training will use default values (0). Consider running datamart scripts for better accuracy.'
  END as datamart_status;

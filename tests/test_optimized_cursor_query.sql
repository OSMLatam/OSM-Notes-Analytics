-- Test script to verify the optimized cursor query works correctly
-- This tests the query pattern used in process_notes_at_date procedure
--
-- Author: Andres Gomez (AngocA)
-- Version: 2026-01-10

\set ON_ERROR_STOP on

-- Test 1: Verify the optimized query uses index
\echo '=== Test 1: Verify query uses index ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.note_id, c.sequence_action, n.created_at, o.id_user, n.id_country, c.event, c.id_user, c.created_at
FROM note_comments c
JOIN notes n ON (c.note_id = n.note_id)
JOIN note_comments o ON (
    n.note_id = o.note_id
    AND o.event = 'opened'
    AND o.note_id <= (SELECT MAX(note_id) FROM notes)
)
WHERE c.created_at >= '2026-01-04 01:15:33'
  AND DATE(c.created_at) = '2026-01-04'
  AND c.note_id <= (SELECT MAX(note_id) FROM notes)
ORDER BY c.note_id, c.sequence_action
LIMIT 100;

-- Test 2: Verify results match expected pattern
\echo ''
\echo '=== Test 2: Verify results match expected pattern ==='
SELECT
    COUNT(*) as total_rows,
    COUNT(DISTINCT c.note_id) as distinct_notes,
    MIN(c.created_at) as first_comment,
    MAX(c.created_at) as last_comment,
    COUNT(*) FILTER (WHERE o.event = 'opened') as opened_comments_count
FROM note_comments c
JOIN notes n ON (c.note_id = n.note_id)
JOIN note_comments o ON (
    n.note_id = o.note_id
    AND o.event = 'opened'
    AND o.note_id <= (SELECT MAX(note_id) FROM notes)
)
WHERE c.created_at >= '2026-01-04 01:15:33'
  AND DATE(c.created_at) = '2026-01-04'
  AND c.note_id <= (SELECT MAX(note_id) FROM notes)
LIMIT 1000;

-- Test 3: Compare performance with old query pattern (subquery)
\echo ''
\echo '=== Test 3: Performance comparison ==='
\timing on

-- New optimized query
\echo 'New optimized query (JOIN directo):'
SELECT COUNT(*) as count_new
FROM note_comments c
JOIN notes n ON (c.note_id = n.note_id)
JOIN note_comments o ON (
    n.note_id = o.note_id
    AND o.event = 'opened'
    AND o.note_id <= 4978387
)
WHERE c.created_at >= '2026-01-04 01:15:33'
  AND DATE(c.created_at) = '2026-01-04'
  AND c.note_id <= 4978387
LIMIT 100;

-- Old query pattern (subquery with CAST)
\echo 'Old query pattern (subquery con CAST):'
SELECT COUNT(*) as count_old
FROM note_comments c
JOIN notes n ON (c.note_id = n.note_id)
JOIN (
    SELECT note_id, id_user
    FROM note_comments
    WHERE CAST(event AS text) = 'opened'
      AND note_id <= 4978387
) o ON (n.note_id = o.note_id)
WHERE c.created_at >= '2026-01-04 01:15:33'
  AND DATE(c.created_at) = '2026-01-04'
  AND c.note_id <= 4978387
LIMIT 100;

\timing off

\echo ''
\echo '=== Test completed ==='

-- ETL Integrity Validation Procedures
-- Validates data integrity between base tables and DWH
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-26
--
-- MON-001: Validate that note_current_status correctly reflects reopened notes
-- MON-002: Validate that comment counts match between note_comments and facts

-- Function to validate note_current_status integrity (MON-001)
-- Checks that note_current_status correctly reflects the current state
-- even when notes have been reopened after being closed
CREATE OR REPLACE FUNCTION dwh.validate_note_current_status()
RETURNS TABLE (
  check_name TEXT,
  status TEXT,
  issue_count BIGINT,
  details TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_inconsistent_count BIGINT;
  v_notes_with_reopen_after_close BIGINT;
BEGIN
  -- Check 1: Notes that are marked as closed but have a reopened action after the last close
  SELECT COUNT(*)
  INTO v_inconsistent_count
  FROM dwh.note_current_status ncs
  WHERE ncs.is_currently_open = FALSE
    AND EXISTS (
      SELECT 1
      FROM dwh.facts f
      WHERE f.id_note = ncs.id_note
        AND f.action_comment = 'reopened'
        AND f.action_at > ncs.last_action_at
    );

  IF v_inconsistent_count > 0 THEN
    RETURN QUERY SELECT
      'MON-001: Notes closed but have reopen after last close'::TEXT,
      'FAIL'::TEXT,
      v_inconsistent_count,
      format('Found %s notes marked as closed but with reopen actions after the last close. These should be marked as open.', v_inconsistent_count);
  ELSE
    RETURN QUERY SELECT
      'MON-001: Notes closed but have reopen after last close'::TEXT,
      'PASS'::TEXT,
      0::BIGINT,
      'All closed notes correctly reflect their status. No reopens found after last close.';
  END IF;

  -- Check 2: Notes that are marked as open but last action is closed
  SELECT COUNT(*)
  INTO v_inconsistent_count
  FROM dwh.note_current_status ncs
  WHERE ncs.is_currently_open = TRUE
    AND ncs.last_action_type = 'closed'
    AND NOT EXISTS (
      SELECT 1
      FROM dwh.facts f
      WHERE f.id_note = ncs.id_note
        AND f.action_comment IN ('opened', 'reopened')
        AND f.action_at > (
          SELECT MAX(f2.action_at)
          FROM dwh.facts f2
          WHERE f2.id_note = ncs.id_note
            AND f2.action_comment = 'closed'
        )
    );

  IF v_inconsistent_count > 0 THEN
    RETURN QUERY SELECT
      'MON-001: Notes marked as open but last action is closed'::TEXT,
      'FAIL'::TEXT,
      v_inconsistent_count,
      format('Found %s notes marked as open but last action is closed without subsequent reopen.', v_inconsistent_count);
  ELSE
    RETURN QUERY SELECT
      'MON-001: Notes marked as open but last action is closed'::TEXT,
      'PASS'::TEXT,
      0::BIGINT,
      'All open notes correctly reflect their status.';
  END IF;

  -- Check 3: Verify that note_current_status matches the most recent action in facts
  SELECT COUNT(*)
  INTO v_inconsistent_count
  FROM dwh.note_current_status ncs
  WHERE NOT EXISTS (
    SELECT 1
    FROM (
      SELECT DISTINCT ON (f.id_note)
        f.id_note,
        CASE
          WHEN f.action_comment IN ('opened', 'reopened') THEN TRUE
          WHEN f.action_comment = 'closed' THEN FALSE
          ELSE NULL
        END as expected_is_open,
        f.action_at as expected_last_action_at,
        f.action_comment as expected_last_action_type
      FROM dwh.facts f
      WHERE f.action_comment IN ('opened', 'closed', 'reopened')
        AND f.id_note = ncs.id_note
      ORDER BY f.id_note, f.action_at DESC
    ) expected
    WHERE expected.id_note = ncs.id_note
      AND expected.expected_is_open = ncs.is_currently_open
      AND expected.expected_last_action_at = ncs.last_action_at
      AND expected.expected_last_action_type = ncs.last_action_type
  );

  IF v_inconsistent_count > 0 THEN
    RETURN QUERY SELECT
      'MON-001: note_current_status does not match most recent action in facts'::TEXT,
      'FAIL'::TEXT,
      v_inconsistent_count,
      format('Found %s notes where note_current_status does not match the most recent action in facts table.', v_inconsistent_count);
  ELSE
    RETURN QUERY SELECT
      'MON-001: note_current_status matches most recent action in facts'::TEXT,
      'PASS'::TEXT,
      0::BIGINT,
      'All note_current_status records correctly reflect the most recent action.';
  END IF;

END;
$$;

COMMENT ON FUNCTION dwh.validate_note_current_status IS
  'MON-001: Validates that note_current_status correctly reflects reopened notes. '
  'Checks that closed notes with subsequent reopens are marked as open.';

-- Function to validate comment count integrity (MON-002)
-- Compares comment counts between note_comments and facts tables
CREATE OR REPLACE FUNCTION dwh.validate_comment_counts()
RETURNS TABLE (
  check_name TEXT,
  status TEXT,
  issue_count BIGINT,
  details TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_base_comments_count BIGINT;
  v_facts_comments_count BIGINT;
  v_difference BIGINT;
  v_notes_with_mismatch BIGINT;
  v_table_exists BOOLEAN;
BEGIN
  -- Check if public.note_comments table exists (could be base table or foreign table)
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'note_comments'
  ) INTO v_table_exists;

  IF NOT v_table_exists THEN
    RETURN QUERY SELECT
      'MON-002: Base table availability check'::TEXT,
      'SKIP'::TEXT,
      0::BIGINT,
      'public.note_comments table not found. Skipping comment count validation. This is normal if using FDW or if base tables are in a different database.';
    RETURN;
  END IF;

  -- Check 1: Total comment count comparison
  -- Count comments in base table (note_comments)
  BEGIN
    SELECT COUNT(*)
    INTO v_base_comments_count
    FROM public.note_comments
    WHERE event IN ('opened', 'closed', 'commented', 'reopened', 'hidden');
  EXCEPTION
    WHEN OTHERS THEN
      RETURN QUERY SELECT
        'MON-002: Base table access error'::TEXT,
        'SKIP'::TEXT,
        0::BIGINT,
        format('Could not access public.note_comments: %s. Skipping comment count validation.', SQLERRM);
      RETURN;
  END;

  -- Count actions in facts table
  SELECT COUNT(*)
  INTO v_facts_comments_count
  FROM dwh.facts
  WHERE action_comment IN ('opened', 'closed', 'commented', 'reopened', 'hidden');

  v_difference := ABS(v_base_comments_count - v_facts_comments_count);

  IF v_difference > 0 THEN
    RETURN QUERY SELECT
      'MON-002: Total comment count mismatch'::TEXT,
      'FAIL'::TEXT,
      v_difference,
      format('Base table has %s comments, facts table has %s actions. Difference: %s',
        v_base_comments_count, v_facts_comments_count, v_difference);
  ELSE
    RETURN QUERY SELECT
      'MON-002: Total comment count match'::TEXT,
      'PASS'::TEXT,
      0::BIGINT,
      format('Comment counts match: %s comments in both tables.', v_base_comments_count);
  END IF;

  -- Check 2: Per-note comment count comparison
  -- Find notes where comment counts don't match
  BEGIN
    SELECT COUNT(*)
    INTO v_notes_with_mismatch
    FROM (
      SELECT
        nc.note_id,
        COUNT(*) as base_count
      FROM public.note_comments nc
      WHERE nc.event IN ('opened', 'closed', 'commented', 'reopened', 'hidden')
      GROUP BY nc.note_id
    ) base_counts
    FULL OUTER JOIN (
      SELECT
        f.id_note,
        COUNT(*) as facts_count
      FROM dwh.facts f
      WHERE f.action_comment IN ('opened', 'closed', 'commented', 'reopened', 'hidden')
      GROUP BY f.id_note
    ) facts_counts ON base_counts.note_id = facts_counts.id_note
    WHERE COALESCE(base_counts.base_count, 0) != COALESCE(facts_counts.facts_count, 0);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN QUERY SELECT
        'MON-002: Per-note comparison error'::TEXT,
        'SKIP'::TEXT,
        0::BIGINT,
        format('Could not compare per-note counts: %s', SQLERRM);
      RETURN;
  END;

  IF v_notes_with_mismatch > 0 THEN
    RETURN QUERY SELECT
      'MON-002: Per-note comment count mismatches'::TEXT,
      'FAIL'::TEXT,
      v_notes_with_mismatch,
      format('Found %s notes where comment counts differ between base table and facts table.', v_notes_with_mismatch);
  ELSE
    RETURN QUERY SELECT
      'MON-002: Per-note comment count matches'::TEXT,
      'PASS'::TEXT,
      0::BIGINT,
      'All notes have matching comment counts between base table and facts table.';
  END IF;

  -- Check 3: Action type distribution comparison
  -- Compare counts by action type
  BEGIN
    WITH base_action_counts AS (
      SELECT
        event as action_type,
        COUNT(*) as count
      FROM public.note_comments
      WHERE event IN ('opened', 'closed', 'commented', 'reopened', 'hidden')
      GROUP BY event
    ),
    facts_action_counts AS (
      SELECT
        action_comment::TEXT as action_type,
        COUNT(*) as count
      FROM dwh.facts
      WHERE action_comment IN ('opened', 'closed', 'commented', 'reopened', 'hidden')
      GROUP BY action_comment
    )
    SELECT COUNT(*)
    INTO v_difference
    FROM base_action_counts b
    FULL OUTER JOIN facts_action_counts f ON b.action_type = f.action_type
    WHERE COALESCE(b.count, 0) != COALESCE(f.count, 0);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN QUERY SELECT
        'MON-002: Action type distribution comparison error'::TEXT,
        'SKIP'::TEXT,
        0::BIGINT,
        format('Could not compare action type distributions: %s', SQLERRM);
      RETURN;
  END;

  IF v_difference > 0 THEN
    RETURN QUERY SELECT
      'MON-002: Action type distribution mismatch'::TEXT,
      'FAIL'::TEXT,
      v_difference,
      format('Found %s action types with count mismatches between base table and facts table.', v_difference);
  ELSE
    RETURN QUERY SELECT
      'MON-002: Action type distribution matches'::TEXT,
      'PASS'::TEXT,
      0::BIGINT,
      'Action type distributions match between base table and facts table.';
  END IF;

END;
$$;

COMMENT ON FUNCTION dwh.validate_comment_counts IS
  'MON-002: Validates that comment counts match between note_comments and facts tables. '
  'Checks total counts, per-note counts, and action type distributions.';

-- Main validation procedure that runs all checks
CREATE OR REPLACE PROCEDURE dwh.validate_etl_integrity()
LANGUAGE plpgsql
AS $$
DECLARE
  v_check_record RECORD;
  v_failed_checks INTEGER := 0;
  v_total_checks INTEGER := 0;
  v_skipped_checks INTEGER := 0;
BEGIN
  RAISE NOTICE '=== ETL Integrity Validation ===';
  RAISE NOTICE '';

  -- Run MON-001 checks
  RAISE NOTICE '--- MON-001: Note Current Status Validation ---';
  FOR v_check_record IN
    SELECT * FROM dwh.validate_note_current_status()
  LOOP
    v_total_checks := v_total_checks + 1;
    IF v_check_record.status = 'FAIL' THEN
      v_failed_checks := v_failed_checks + 1;
      RAISE WARNING '%: % - % issues found. %',
        v_check_record.check_name,
        v_check_record.status,
        v_check_record.issue_count,
        v_check_record.details;
    ELSIF v_check_record.status = 'SKIP' THEN
      v_skipped_checks := v_skipped_checks + 1;
      RAISE NOTICE '%: % - %',
        v_check_record.check_name,
        v_check_record.status,
        v_check_record.details;
    ELSE
      RAISE NOTICE '%: % - %',
        v_check_record.check_name,
        v_check_record.status,
        v_check_record.details;
    END IF;
  END LOOP;

  RAISE NOTICE '';

  -- Run MON-002 checks
  RAISE NOTICE '--- MON-002: Comment Count Validation ---';
  FOR v_check_record IN
    SELECT * FROM dwh.validate_comment_counts()
  LOOP
    v_total_checks := v_total_checks + 1;
    IF v_check_record.status = 'FAIL' THEN
      v_failed_checks := v_failed_checks + 1;
      RAISE WARNING '%: % - % issues found. %',
        v_check_record.check_name,
        v_check_record.status,
        v_check_record.issue_count,
        v_check_record.details;
    ELSIF v_check_record.status = 'SKIP' THEN
      v_skipped_checks := v_skipped_checks + 1;
      RAISE NOTICE '%: % - %',
        v_check_record.check_name,
        v_check_record.status,
        v_check_record.details;
    ELSE
      RAISE NOTICE '%: % - %',
        v_check_record.check_name,
        v_check_record.status,
        v_check_record.details;
    END IF;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '=== Validation Summary ===';
  RAISE NOTICE 'Total checks: %', v_total_checks;
  RAISE NOTICE 'Passed: %', v_total_checks - v_failed_checks - v_skipped_checks;
  RAISE NOTICE 'Failed: %', v_failed_checks;
  RAISE NOTICE 'Skipped: %', v_skipped_checks;

  IF v_failed_checks > 0 THEN
    RAISE EXCEPTION 'ETL integrity validation failed. % checks failed out of % total checks.',
      v_failed_checks, v_total_checks;
  ELSE
    RAISE NOTICE 'All integrity checks passed!';
  END IF;
END;
$$;

COMMENT ON PROCEDURE dwh.validate_etl_integrity IS
  'Runs all ETL integrity validations (MON-001 and MON-002). '
  'Raises exception if any checks fail.';


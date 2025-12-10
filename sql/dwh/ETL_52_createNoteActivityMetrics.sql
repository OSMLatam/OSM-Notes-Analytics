-- Create Note Activity Metrics Trigger
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-09
--
-- This trigger calculates accumulated historical metrics for each note action
-- BEFORE inserting a new row into dwh.facts. It populates three columns:
--   - total_comments_on_note: Number of comments on this note UP TO this action
--   - total_reopenings_count: Number of reopenings on this note UP TO this action
--   - total_actions_on_note: Total actions on this note UP TO this action
--
-- PERFORMANCE WARNING:
--   - When enabled: Adds 1 SELECT COUNT(*) per INSERT (5-15% slower ETL)
--   - When disabled: No overhead, but metrics are NULL
--   - The ETL automatically disables it during initial bulk load for performance
--
-- For complete documentation, see: docs/NOTE_ACTIVITY_METRICS_TRIGGER.md

CREATE OR REPLACE FUNCTION dwh.calculate_note_activity_metrics()
RETURNS TRIGGER AS $$
DECLARE
  v_comments_count INTEGER := 0;
  v_reopenings_count INTEGER := 0;
  v_actions_count INTEGER := 0;
BEGIN
  -- Calculate accumulated metrics UP TO this action (not including current)
  -- Only considers previous rows (fact_id < NEW.fact_id) for historical accuracy
  SELECT
    COUNT(*) FILTER (WHERE action_comment = 'commented'),
    COUNT(*) FILTER (WHERE action_comment = 'reopened'),
    COUNT(*)
  INTO
    v_comments_count,
    v_reopenings_count,
    v_actions_count
  FROM dwh.facts
  WHERE id_note = NEW.id_note
    AND fact_id < NEW.fact_id;

  -- Set accumulated metrics on NEW row (does not update existing rows)
  NEW.total_comments_on_note := v_comments_count;
  NEW.total_reopenings_count := v_reopenings_count;
  NEW.total_actions_on_note := v_actions_count;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION dwh.calculate_note_activity_metrics() IS
  'Calculate accumulated note activity metrics up to current action. '
  'Called BEFORE INSERT on dwh.facts. Performance: 1 SELECT per insert.';

-- Drop trigger if exists before creating it
DROP TRIGGER IF EXISTS calculate_note_activity_metrics_trigger ON dwh.facts;

-- Create trigger on all partitions
CREATE TRIGGER calculate_note_activity_metrics_trigger
  BEFORE INSERT ON dwh.facts
  FOR EACH ROW
  EXECUTE FUNCTION dwh.calculate_note_activity_metrics();

COMMENT ON TRIGGER calculate_note_activity_metrics_trigger ON dwh.facts IS
  'Trigger to calculate total_comments_on_note, total_reopenings_count, '
  'and total_actions_on_note before each INSERT. '
  'Performance impact: Execute 1 SELECT COUNT(*) per row inserted. '
  'Monitor execution time in production. '
  'Can be disabled for bulk loads: ALTER TABLE dwh.facts DISABLE TRIGGER calculate_note_activity_metrics_trigger;';

-- Utility functions to enable/disable the trigger for performance control
CREATE OR REPLACE FUNCTION dwh.enable_note_activity_metrics_trigger()
RETURNS TEXT AS $$
BEGIN
  ALTER TABLE dwh.facts ENABLE TRIGGER calculate_note_activity_metrics_trigger;
  RETURN 'Trigger calculate_note_activity_metrics_trigger ENABLED';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION dwh.enable_note_activity_metrics_trigger() IS
  'Enable the note activity metrics trigger. '
  'When enabled: Calculates total_comments_on_note, total_reopenings_count, '
  'and total_actions_on_note for each INSERT. '
  'Performance impact: Adds 1 SELECT COUNT(*) per INSERT (5-15% slower ETL). '
  'Use this to re-enable metrics calculation after bulk loads. '
  'The ETL automatically enables this trigger after initial load.';

CREATE OR REPLACE FUNCTION dwh.disable_note_activity_metrics_trigger()
RETURNS TEXT AS $$
BEGIN
  ALTER TABLE dwh.facts DISABLE TRIGGER calculate_note_activity_metrics_trigger;
  RETURN 'Trigger calculate_note_activity_metrics_trigger DISABLED';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION dwh.disable_note_activity_metrics_trigger() IS
  'Disable the note activity metrics trigger for performance optimization. '
  'When disabled: No metrics are calculated, columns are set to NULL. '
  'Performance benefit: 5-15% faster ETL during bulk loads. '
  'WARNING: Metrics (total_comments_on_note, total_reopenings_count, '
  'total_actions_on_note) will be NULL for ALL rows inserted while disabled. '
  'These NULL values are permanent and will affect analytics queries. '
  'The ETL automatically disables this trigger before initial bulk load. '
  'Re-enable with: SELECT dwh.enable_note_activity_metrics_trigger();';

-- Function to check trigger status
CREATE OR REPLACE FUNCTION dwh.get_note_activity_metrics_trigger_status()
RETURNS TABLE(
  trigger_name TEXT,
  enabled BOOLEAN,
  event_manipulation TEXT,
  action_timing TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    pt.tgname::TEXT AS trigger_name,
    pt.tgenabled != 'D' AS enabled,  -- 'D' = disabled, 'O'/'A' = enabled
    CASE
      WHEN pt.tgtype & 2 = 2 THEN 'INSERT'
      WHEN pt.tgtype & 4 = 4 THEN 'DELETE'
      WHEN pt.tgtype & 8 = 8 THEN 'UPDATE'
      ELSE 'UNKNOWN'
    END::TEXT AS event_manipulation,
    CASE
      WHEN pt.tgtype & 16 = 16 THEN 'BEFORE'
      WHEN pt.tgtype & 64 = 64 THEN 'INSTEAD OF'
      ELSE 'AFTER'
    END::TEXT AS action_timing
  FROM pg_trigger pt
  JOIN pg_class pc ON pc.oid = pt.tgrelid
  JOIN pg_namespace pn ON pn.oid = pc.relnamespace
  WHERE pn.nspname = 'dwh'
    AND pc.relname = 'facts'
    AND pt.tgname = 'calculate_note_activity_metrics_trigger'
    AND NOT pt.tgisinternal;  -- Exclude internal triggers
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION dwh.get_note_activity_metrics_trigger_status() IS
  'DIAGNOSTIC FUNCTION: Check if the note activity metrics trigger is enabled or disabled. '
  'Returns: trigger_name, enabled (boolean), event_manipulation (INSERT/UPDATE/DELETE), '
  'and action_timing (BEFORE/AFTER). '
  'Use this to verify trigger state when troubleshooting ETL performance or data quality issues. '
  'Use cases: '
  '- Verify trigger is enabled after ETL completes '
  '- Debug why metrics are NULL in query results '
  '- Confirm trigger state before/after manual operations '
  '- Monitor trigger status in monitoring scripts.';



-- Create Note Activity Metrics Trigger
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-24
--
-- PERFORMANCE WARNING:
-- This trigger performs a SELECT COUNT(*) query for each INSERT into dwh.facts.
-- The query scans previous rows of the same note to calculate accumulated metrics.
-- Performance impact:
-- - 1 additional SELECT per fact row inserted
-- - Query uses index on (id_note, fact_id) - MUST be created before this trigger
-- - Monitor performance in production and consider alternatives if degradation occurs
--
-- See: ToDo/DWH_Improvements_Plan.md > TAREA 12 for performance notes

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

-- Create trigger on all partitions
CREATE TRIGGER calculate_note_activity_metrics_trigger
  BEFORE INSERT ON dwh.facts
  FOR EACH ROW
  EXECUTE FUNCTION dwh.calculate_note_activity_metrics();

COMMENT ON TRIGGER calculate_note_activity_metrics_trigger ON dwh.facts IS
  'Trigger to calculate total_comments_on_note, total_reopenings_count, '
  'and total_actions_on_note before each INSERT. '
  'Performance impact: Execute 1 SELECT COUNT(*) per row inserted. '
  'Monitor execution time in production.';


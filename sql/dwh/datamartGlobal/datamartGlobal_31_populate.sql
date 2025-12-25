-- Populates the global datamart with aggregated statistics.
-- Computes metrics for all notes globally.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-20

DO /* Notes-datamartGlobal-processGlobal */
$$
DECLARE
  m_max_date DATE;
  m_last_year_activity CHAR(371) := '0';
  m_top_countries JSON;
  m_applications_used JSON;
  r RECORD;
BEGIN
  -- Get max processed date
  SELECT COALESCE(date, '1970-01-01'::DATE)
   INTO m_max_date
  FROM dwh.max_date_global_processed;

  IF (m_max_date < CURRENT_DATE) THEN
   RAISE NOTICE 'Moving activities.';

   -- Update last year activity
   SELECT last_year_activity
    INTO m_last_year_activity
   FROM dwh.datamartGlobal
   WHERE dimension_global_id = 1;

   UPDATE dwh.datamartGlobal
    SET last_year_activity = dwh.move_day(COALESCE(last_year_activity, '0'))
   WHERE dimension_global_id = 1;

   UPDATE dwh.max_date_global_processed
    SET date = CURRENT_DATE;
  END IF;

  RAISE NOTICE 'Processing global statistics.';

  -- Update global statistics
  UPDATE dwh.datamartGlobal
  SET
   -- Static values (date_starting_creating_notes)
   date_starting_creating_notes = (
    SELECT /* Notes-datamartGlobal */ date_id
    FROM dwh.dimension_days
    WHERE dimension_day_id = (
     SELECT /* Notes-datamartGlobal */ MIN(opened_dimension_id_date)
     FROM dwh.facts
    )
   ),

   -- date_starting_solving_notes
   date_starting_solving_notes = (
    SELECT /* Notes-datamartGlobal */ date_id
    FROM dwh.dimension_days
    WHERE dimension_day_id = (
     SELECT /* Notes-datamartGlobal */ MIN(closed_dimension_id_date)
     FROM dwh.facts
     WHERE closed_dimension_id_date IS NOT NULL
    )
   ),

   -- first_open_note_id
   first_open_note_id = (
    SELECT /* Notes-datamartGlobal */ id_note
    FROM dwh.facts
    WHERE fact_id = (
     SELECT /* Notes-datamartGlobal */ MIN(fact_id)
     FROM dwh.facts
     WHERE action_comment = 'opened'
    )
   ),

   -- first_closed_note_id
   first_closed_note_id = (
    SELECT /* Notes-datamartGlobal */ id_note
    FROM dwh.facts
    WHERE fact_id = (
     SELECT /* Notes-datamartGlobal */ MIN(fact_id)
     FROM dwh.facts
     WHERE action_comment = 'closed'
    )
   ),

   -- first_reopened_note_id
   first_reopened_note_id = (
    SELECT /* Notes-datamartGlobal */ id_note
    FROM dwh.facts
    WHERE fact_id = (
     SELECT /* Notes-datamartGlobal */ MIN(fact_id)
     FROM dwh.facts
     WHERE action_comment = 'reopened'
    )
   ),

   -- latest_open_note_id
   latest_open_note_id = (
    SELECT /* Notes-datamartGlobal */ id_note
    FROM dwh.facts
    WHERE fact_id = (
     SELECT /* Notes-datamartGlobal */ MAX(fact_id)
     FROM dwh.facts
     WHERE action_comment = 'opened'
    )
   ),

   -- latest_closed_note_id
   latest_closed_note_id = (
    SELECT /* Notes-datamartGlobal */ id_note
    FROM dwh.facts
    WHERE fact_id = (
     SELECT /* Notes-datamartGlobal */ MAX(fact_id)
     FROM dwh.facts
     WHERE action_comment = 'closed'
    )
   ),

   -- latest_reopened_note_id
   latest_reopened_note_id = (
    SELECT /* Notes-datamartGlobal */ id_note
    FROM dwh.facts
    WHERE fact_id = (
     SELECT /* Notes-datamartGlobal */ MAX(fact_id)
     FROM dwh.facts
     WHERE action_comment = 'reopened'
    )
   ),

   -- Historical totals
   history_whole_open = (
    SELECT /* Notes-datamartGlobal */ COUNT(*)
    FROM dwh.facts
    WHERE action_comment = 'opened'
   ),
   history_whole_commented = (
    SELECT /* Notes-datamartGlobal */ COUNT(*)
    FROM dwh.facts
    WHERE action_comment = 'commented'
   ),
   history_whole_closed = (
    SELECT /* Notes-datamartGlobal */ COUNT(*)
    FROM dwh.facts
    WHERE action_comment = 'closed'
   ),
   history_whole_closed_with_comment = (
    SELECT /* Notes-datamartGlobal */ COUNT(*)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.closed_dimension_id_date = dd.dimension_day_id)
    WHERE f.action_comment = 'closed'
     AND EXISTS (
      SELECT 1
      FROM dwh.facts f2
      WHERE f2.id_note = f.id_note
       AND f2.action_comment = 'commented'
       AND f2.sequence_action < f.sequence_action
     )
   ),
   history_whole_reopened = (
    SELECT /* Notes-datamartGlobal */ COUNT(*)
    FROM dwh.facts
    WHERE action_comment = 'reopened'
   ),

   -- Current year totals
   history_year_open = (
    SELECT /* Notes-datamartGlobal */ COUNT(*)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.action_dimension_id_date = dd.dimension_day_id)
    WHERE f.action_comment = 'opened'
     AND EXTRACT(YEAR FROM dd.date_id) = EXTRACT(YEAR FROM CURRENT_DATE)
   ),
   history_year_commented = (
    SELECT /* Notes-datamartGlobal */ COUNT(*)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.action_dimension_id_date = dd.dimension_day_id)
    WHERE f.action_comment = 'commented'
     AND EXTRACT(YEAR FROM dd.date_id) = EXTRACT(YEAR FROM CURRENT_DATE)
   ),
   history_year_closed = (
    SELECT /* Notes-datamartGlobal */ COUNT(*)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.action_dimension_id_date = dd.dimension_day_id)
    WHERE f.action_comment = 'closed'
     AND EXTRACT(YEAR FROM dd.date_id) = EXTRACT(YEAR FROM CURRENT_DATE)
   ),
   history_year_closed_with_comment = (
    SELECT /* Notes-datamartGlobal */ COUNT(*)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.action_dimension_id_date = dd.dimension_day_id)
    WHERE f.action_comment = 'closed'
     AND EXTRACT(YEAR FROM dd.date_id) = EXTRACT(YEAR FROM CURRENT_DATE)
     AND EXISTS (
      SELECT 1
      FROM dwh.facts f2
      WHERE f2.id_note = f.id_note
       AND f2.action_comment = 'commented'
       AND f2.sequence_action < f.sequence_action
     )
   ),
   history_year_reopened = (
    SELECT /* Notes-datamartGlobal */ COUNT(*)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.action_dimension_id_date = dd.dimension_day_id)
    WHERE f.action_comment = 'reopened'
     AND EXTRACT(YEAR FROM dd.date_id) = EXTRACT(YEAR FROM CURRENT_DATE)
   ),

   -- Current status
   currently_open_count = (
    SELECT /* Notes-datamartGlobal */ COUNT(DISTINCT id_note)
    FROM dwh.facts
    WHERE id_note NOT IN (
     SELECT DISTINCT id_note
     FROM dwh.facts
     WHERE action_comment = 'closed'
      AND fact_id IN (
       SELECT /* Notes-datamartGlobal */ MAX(fact_id)
       FROM dwh.facts
       GROUP BY id_note
      )
    )
   ),
   currently_closed_count = (
    SELECT /* Notes-datamartGlobal */ COUNT(DISTINCT id_note)
    FROM dwh.facts
    WHERE id_note IN (
     SELECT DISTINCT f.id_note
     FROM dwh.facts f
     WHERE f.action_comment = 'closed'
      AND f.fact_id = (
       SELECT /* Notes-datamartGlobal */ MAX(f2.fact_id)
       FROM dwh.facts f2
       WHERE f2.id_note = f.id_note
      )
    )
   ),
   notes_created_last_30_days = (
    SELECT /* Notes-datamartGlobal */ COUNT(DISTINCT id_note)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.opened_dimension_id_date = dd.dimension_day_id)
    WHERE f.action_comment = 'opened'
     AND dd.date_id >= CURRENT_DATE - INTERVAL '30 days'
   ),
   notes_resolved_last_30_days = (
    SELECT /* Notes-datamartGlobal */ COUNT(DISTINCT id_note)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.action_dimension_id_date = dd.dimension_day_id)
    WHERE f.action_comment = 'closed'
     AND dd.date_id >= CURRENT_DATE - INTERVAL '30 days'
   ),
   notes_backlog_size = (
    SELECT /* Notes-datamartGlobal */ COUNT(DISTINCT id_note)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.opened_dimension_id_date = dd.dimension_day_id)
    WHERE f.action_comment = 'opened'
     AND dd.date_id < CURRENT_DATE - INTERVAL '7 days'
     AND id_note NOT IN (
      SELECT id_note
      FROM dwh.facts
      WHERE action_comment = 'closed'
       AND fact_id IN (
        SELECT /* Notes-datamartGlobal */ MAX(fact_id)
        FROM dwh.facts
        GROUP BY id_note
       )
     )
   ),

   -- Resolution metrics
   avg_days_to_resolution = (
    SELECT /* Notes-datamartGlobal */ AVG(days_to_resolution)::DECIMAL(10,2)
    FROM dwh.facts
    WHERE days_to_resolution IS NOT NULL
     AND days_to_resolution > 0
   ),
   median_days_to_resolution = (
    SELECT /* Notes-datamartGlobal */ PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_resolution)::DECIMAL(10,2)
    FROM dwh.facts
    WHERE days_to_resolution IS NOT NULL
     AND days_to_resolution > 0
   ),
   avg_days_to_resolution_current_year = (
    SELECT /* Notes-datamartGlobal */ AVG(f.days_to_resolution)::DECIMAL(10,2)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.opened_dimension_id_date = dd.dimension_day_id)
    WHERE f.days_to_resolution IS NOT NULL
     AND f.days_to_resolution > 0
     AND EXTRACT(YEAR FROM dd.date_id) = EXTRACT(YEAR FROM CURRENT_DATE)
   ),
   median_days_to_resolution_current_year = (
    SELECT /* Notes-datamartGlobal */ PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.days_to_resolution)::DECIMAL(10,2)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.opened_dimension_id_date = dd.dimension_day_id)
    WHERE f.days_to_resolution IS NOT NULL
     AND f.days_to_resolution > 0
     AND EXTRACT(YEAR FROM dd.date_id) = EXTRACT(YEAR FROM CURRENT_DATE)
   ),
   notes_resolved_count = (
    SELECT /* Notes-datamartGlobal */ COUNT(DISTINCT id_note)
    FROM dwh.facts
    WHERE action_comment = 'closed'
   ),
   resolution_rate = (
    SELECT /* Notes-datamartGlobal */
     CASE
      WHEN COUNT(DISTINCT CASE WHEN action_comment = 'opened' THEN id_note END) > 0
      THEN (COUNT(DISTINCT CASE WHEN action_comment = 'closed' THEN id_note END)::DECIMAL
            / COUNT(DISTINCT CASE WHEN action_comment = 'opened' THEN id_note END)::DECIMAL
            * 100)
      ELSE 0
     END
    FROM dwh.facts
   ),

   -- Additional metrics
   active_users_count = (
    SELECT /* Notes-datamartGlobal */ COUNT(DISTINCT action_dimension_id_user)
    FROM dwh.facts f
    JOIN dwh.dimension_days dd
    ON (f.action_dimension_id_date = dd.dimension_day_id)
    WHERE dd.date_id >= CURRENT_DATE - INTERVAL '30 days'
   ),
   applications_used = (
    SELECT /* Notes-datamartGlobal */
     JSON_AGG(jsonb_build_object(
      'application_id', app.dimension_application_id,
      'application_name', app.application_name,
      'usage_count', app.usage_count
     ) ORDER BY app.usage_count DESC)
    FROM (
     SELECT da.dimension_application_id, da.application_name, COUNT(*) as usage_count
     FROM dwh.facts f
     JOIN dwh.dimension_applications da
     ON (f.dimension_application_creation = da.dimension_application_id)
     WHERE f.dimension_application_creation IS NOT NULL
      AND f.action_comment = 'opened'
     GROUP BY da.dimension_application_id, da.application_name
     ORDER BY usage_count DESC
     LIMIT 10
    ) app
   ),
   most_used_application_id = (
    SELECT /* Notes-datamartGlobal */ dimension_application_id
    FROM (
     SELECT f.dimension_application_creation as dimension_application_id, COUNT(*) as usage_count
     FROM dwh.facts f
     WHERE f.dimension_application_creation IS NOT NULL
      AND f.action_comment = 'opened'
     GROUP BY f.dimension_application_creation
     ORDER BY usage_count DESC
     LIMIT 1
    ) app
   ),
   mobile_apps_count = (
    SELECT /* Notes-datamartGlobal */ COUNT(DISTINCT f.dimension_application_creation)
    FROM dwh.facts f
    JOIN dwh.dimension_applications da
    ON (f.dimension_application_creation = da.dimension_application_id)
    WHERE f.action_comment = 'opened'
     AND (da.platform LIKE '%android%' OR da.platform LIKE '%ios%')
   ),
   desktop_apps_count = (
    SELECT /* Notes-datamartGlobal */ COUNT(DISTINCT f.dimension_application_creation)
    FROM dwh.facts f
    JOIN dwh.dimension_applications da
    ON (f.dimension_application_creation = da.dimension_application_id)
    WHERE f.action_comment = 'opened'
     AND (da.platform LIKE '%desktop%' OR da.platform LIKE '%web%')
   ),
   avg_comment_length = (
    SELECT /* Notes-datamartGlobal */ AVG(comment_length)::DECIMAL(10,2)
    FROM dwh.facts
    WHERE comment_length IS NOT NULL
   ),
   comments_with_url_pct = (
    SELECT /* Notes-datamartGlobal */
     CASE
      WHEN COUNT(*) > 0
      THEN (COUNT(CASE WHEN has_url THEN 1 END)::DECIMAL / COUNT(*)::DECIMAL * 100)
      ELSE 0
     END
    FROM dwh.facts
    WHERE has_url IS NOT NULL
   ),
   comments_with_mention_pct = (
    SELECT /* Notes-datamartGlobal */
     CASE
      WHEN COUNT(*) > 0
      THEN (COUNT(CASE WHEN has_mention THEN 1 END)::DECIMAL / COUNT(*)::DECIMAL * 100)
      ELSE 0
     END
    FROM dwh.facts
    WHERE has_mention IS NOT NULL
   ),
   avg_comments_per_note = (
    SELECT /* Notes-datamartGlobal */ AVG(total_comments_on_note)::DECIMAL(10,2)
    FROM (
     SELECT id_note, MAX(total_comments_on_note) as total_comments_on_note
     FROM dwh.facts
     WHERE total_comments_on_note IS NOT NULL
     GROUP BY id_note
    ) notes
   )
  WHERE dimension_global_id = 1;

  -- Top countries
  SELECT JSON_AGG(jsonb_build_object(
    'country_id', c.country_id,
    'country_name', c.country_name,
    'total_actions', c.total_actions
   ) ORDER BY c.total_actions DESC)
  INTO m_top_countries
  FROM (
   SELECT dc.country_id, dc.country_name, COUNT(*) as total_actions
   FROM dwh.facts f
   JOIN dwh.dimension_countries dc
   ON (f.dimension_id_country = dc.dimension_country_id)
   GROUP BY dc.country_id, dc.country_name
   ORDER BY total_actions DESC
   LIMIT 10
  ) c;

  UPDATE dwh.datamartGlobal
  SET top_countries = m_top_countries
  WHERE dimension_global_id = 1;

  -- Notes age distribution
  UPDATE dwh.datamartGlobal
  SET notes_age_distribution = (
    SELECT /* Notes-datamartGlobal */ jsonb_build_object(
     '0-7_days', COUNT(CASE WHEN age_days BETWEEN 0 AND 7 THEN 1 END),
     '8-30_days', COUNT(CASE WHEN age_days BETWEEN 8 AND 30 THEN 1 END),
     '31-90_days', COUNT(CASE WHEN age_days BETWEEN 31 AND 90 THEN 1 END),
     '90_plus_days', COUNT(CASE WHEN age_days > 90 THEN 1 END)
    )
    FROM (
     SELECT f.id_note,
      CURRENT_DATE - dd.date_id AS age_days
     FROM dwh.facts f
     JOIN dwh.dimension_days dd
     ON (f.opened_dimension_id_date = dd.dimension_day_id)
     WHERE f.action_comment = 'opened'
      AND f.id_note NOT IN (
       SELECT id_note
       FROM dwh.facts
       WHERE action_comment = 'closed'
        AND fact_id IN (
         SELECT /* Notes-datamartGlobal */ MAX(fact_id)
         FROM dwh.facts
         GROUP BY id_note
        )
      )
    ) open_notes
  )
  WHERE dimension_global_id = 1;

  RAISE NOTICE 'Global statistics updated successfully.';
END
$$;



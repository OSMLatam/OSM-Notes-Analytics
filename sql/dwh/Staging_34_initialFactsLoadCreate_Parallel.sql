-- Create procedure for parallel initial load by year (Phase 1).
-- This loads all facts without recent_opened_dimension_id_date
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-22

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Creating parallel initial load procedure for year ${YEAR}' AS Task;

/**
 * Phase 1: Loads all facts for a specific year WITHOUT recent_opened_dimension_id_date
 * This allows parallel processing by year
 */
CREATE OR REPLACE PROCEDURE staging.process_initial_load_by_year_${YEAR}()
LANGUAGE plpgsql
AS $$
DECLARE
  m_dimension_country_id INTEGER;
  m_dimension_user_open INTEGER;
  m_dimension_user_close INTEGER;
  m_dimension_user_action INTEGER;
  m_opened_id_date INTEGER;
  m_opened_id_hour_of_week INTEGER;
  m_closed_id_date INTEGER;
  m_closed_id_hour_of_week INTEGER;
  m_action_id_date INTEGER;
  m_action_id_hour_of_week INTEGER;
  m_application INTEGER;
  m_application_version INTEGER;
  m_hashtag_id_1 INTEGER;
  m_hashtag_id_2 INTEGER;
  m_hashtag_id_3 INTEGER;
  m_hashtag_id_4 INTEGER;
  m_hashtag_id_5 INTEGER;
  m_hashtag_number INTEGER;
  m_text_comment TEXT;
  m_hashtag_name TEXT;
  m_timezone_id INTEGER;
  m_local_action_id_date INTEGER;
  m_local_action_id_hour_of_week INTEGER;
  m_season_id SMALLINT;
  m_latitude DECIMAL;
  m_longitude DECIMAL;
  rec_note_action RECORD;
  notes_cursor REFCURSOR;
  m_count INTEGER := 0;
BEGIN
  RAISE NOTICE 'Starting Phase 1 load for year ${YEAR}...';

  -- Open cursor for all notes of this year, ordered by note_id and sequence_action
  OPEN notes_cursor FOR
   SELECT /* Notes-staging */
    c.note_id id_note, c.sequence_action sequence_action,
    n.created_at created_at, o.id_user created_id_user, n.id_country id_country,
    c.sequence_action seq, c.event action_comment, c.id_user action_id_user,
    c.created_at action_at, t.body
   FROM note_comments c
    JOIN notes n
    ON (c.note_id = n.note_id)
    JOIN note_comments o
    ON (n.note_id = o.note_id AND o.event = 'opened')
    LEFT JOIN note_comments_text t
    ON (c.note_id = t.note_id AND c.sequence_action = t.sequence_action)
   WHERE EXTRACT(YEAR FROM c.created_at) = ${YEAR}
   ORDER BY c.note_id, c.sequence_action;

  LOOP
   FETCH notes_cursor INTO rec_note_action;
   EXIT WHEN NOT FOUND;

   -- Get country dimension
   SELECT /* Notes-staging */ dimension_country_id
    INTO m_dimension_country_id
   FROM dwh.dimension_countries
   WHERE country_id = rec_note_action.id_country;
   IF (m_dimension_country_id IS NULL) THEN
    m_dimension_country_id := 1;
   END IF;

   -- Get user dimensions
   SELECT /* Notes-staging */ dimension_user_id
    INTO m_dimension_user_open
   FROM dwh.dimension_users
   WHERE user_id = rec_note_action.created_id_user AND is_current;

   SELECT /* Notes-staging */ dimension_user_id
    INTO m_dimension_user_action
   FROM dwh.dimension_users
   WHERE user_id = rec_note_action.action_id_user AND is_current;

   m_dimension_user_close := m_dimension_user_action;

   -- Get date and time dimensions
   m_opened_id_date := dwh.get_date_id(rec_note_action.created_at);
   m_opened_id_hour_of_week := dwh.get_hour_of_week_id(rec_note_action.created_at);
   m_action_id_date := dwh.get_date_id(rec_note_action.action_at);
   m_action_id_hour_of_week := dwh.get_hour_of_week_id(rec_note_action.action_at);

   -- Initialize closed dimensions
   m_closed_id_date := NULL;
   m_closed_id_hour_of_week := NULL;

   -- Get application info if present
   m_text_comment := rec_note_action.body;
   IF (m_text_comment LIKE '%iD%' OR m_text_comment LIKE '%JOSM%' OR m_text_comment LIKE '%Potlatch%') THEN
    m_application := staging.get_application(m_text_comment);
    -- Try to parse version simple pattern N.N or N.N.N
    IF (m_text_comment ~* '\\d+\\.\\d+(\\.\\d+)?') THEN
     m_application_version := dwh.get_application_version_id(
       m_application,
       (SELECT regexp_match(m_text_comment, '(\\d+\\.\\d+(?:\\.\\d+)?)')::text)
     );
    END IF;
   ELSE
    m_application := NULL;
    m_application_version := NULL;
   END IF;

   -- Get hashtags
   m_hashtag_id_1 := NULL;
   m_hashtag_id_2 := NULL;
   m_hashtag_id_3 := NULL;
   m_hashtag_id_4 := NULL;
   m_hashtag_id_5 := NULL;
   m_hashtag_number := 0;

   IF (rec_note_action.body LIKE '%#%') THEN
    m_text_comment := rec_note_action.body;
    CALL staging.get_hashtag(m_text_comment, m_hashtag_name);
    m_hashtag_id_1 := staging.get_hashtag_id(m_hashtag_name);
    m_hashtag_number := 1;

    -- Get additional hashtags
    WHILE (m_text_comment LIKE '%#%') LOOP
     CALL staging.get_hashtag(m_text_comment, m_hashtag_name);
     m_hashtag_number := m_hashtag_number + 1;

     CASE m_hashtag_number
      WHEN 2 THEN m_hashtag_id_2 := staging.get_hashtag_id(m_hashtag_name);
      WHEN 3 THEN m_hashtag_id_3 := staging.get_hashtag_id(m_hashtag_name);
      WHEN 4 THEN m_hashtag_id_4 := staging.get_hashtag_id(m_hashtag_name);
      WHEN 5 THEN m_hashtag_id_5 := staging.get_hashtag_id(m_hashtag_name);
      ELSE
       -- More than 5 hashtags, ignore them
       NULL;
     END CASE;
    END LOOP;
   END IF;

   -- Get timezone and local time info
   SELECT n.latitude, n.longitude INTO m_latitude, m_longitude
   FROM notes n WHERE n.note_id = rec_note_action.id_note;
   m_timezone_id := dwh.get_timezone_id_by_lonlat(m_longitude, m_latitude);
   m_local_action_id_date := dwh.get_local_date_id(rec_note_action.action_at, m_timezone_id);
   m_local_action_id_hour_of_week := dwh.get_local_hour_of_week_id(rec_note_action.action_at, m_timezone_id);
   m_season_id := dwh.get_season_id(rec_note_action.action_at, m_latitude);

   -- Insert the fact WITHOUT recent_opened_dimension_id_date (will be set in Phase 2)
   INSERT INTO dwh.facts (
     id_note, dimension_id_country,
     action_at, action_comment, action_dimension_id_date,
     action_dimension_id_hour_of_week, action_dimension_id_user,
     opened_dimension_id_date, opened_dimension_id_hour_of_week,
     opened_dimension_id_user,
     closed_dimension_id_date, closed_dimension_id_hour_of_week,
     closed_dimension_id_user, dimension_application_creation,
     dimension_application_version,
     recent_opened_dimension_id_date, hashtag_1, hashtag_2, hashtag_3,
     hashtag_4, hashtag_5, hashtag_number,
     action_timezone_id, local_action_dimension_id_date,
     local_action_dimension_id_hour_of_week, action_dimension_id_season
    ) VALUES (
     rec_note_action.id_note, m_dimension_country_id,
     rec_note_action.action_at, rec_note_action.action_comment,
     m_action_id_date, m_action_id_hour_of_week, m_dimension_user_action,
     m_opened_id_date, m_opened_id_hour_of_week, m_dimension_user_open,
     m_closed_id_date, m_closed_id_hour_of_week, m_dimension_user_close,
     m_application, m_application_version,
     NULL, -- recent_opened_dimension_id_date will be set in Phase 2
     m_hashtag_id_1, m_hashtag_id_2, m_hashtag_id_3, m_hashtag_id_4, m_hashtag_id_5,
     m_hashtag_number, m_timezone_id, m_local_action_id_date,
     m_local_action_id_hour_of_week, m_season_id
    );

  m_count := m_count + 1;
  IF (MOD(m_count, 10000) = 0) THEN
   RAISE NOTICE '%: % processed facts for year ${YEAR} until %.', CLOCK_TIMESTAMP(), m_count,
    rec_note_action.action_at;
  END IF;

  END LOOP;

  CLOSE notes_cursor;

  RAISE NOTICE 'Phase 1 completed for year ${YEAR} with % facts processed.', m_count;
END
$$;

COMMENT ON PROCEDURE staging.process_initial_load_by_year_${YEAR} IS
  'Phase 1: Loads all facts for year ${YEAR} without recent_opened_dimension_id_date for parallel processing';

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Parallel initial load procedure for year ${YEAR} created' AS Task;

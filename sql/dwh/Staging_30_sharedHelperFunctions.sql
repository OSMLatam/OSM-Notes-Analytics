-- Shared helper functions for staging procedures
-- These functions factorize common logic used by both CREATE (incremental) and INITIAL load procedures
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-26

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Creating shared helper functions for staging' AS Task;

-- Function to get or create country dimension ID
-- Returns the dimension_country_id for a given country_id, creating it if necessary
CREATE OR REPLACE FUNCTION staging.get_or_create_country_dimension(
  p_country_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_dimension_country_id INTEGER;
BEGIN
  -- Try to get existing country dimension
  SELECT /* Notes-staging */ dimension_country_id
   INTO v_dimension_country_id
  FROM dwh.dimension_countries
  WHERE country_id = p_country_id;

  -- If found, return it
  IF v_dimension_country_id IS NOT NULL THEN
    RETURN v_dimension_country_id;
  END IF;

  -- Try to insert the country if it exists in base table
  INSERT INTO dwh.dimension_countries
   (country_id, country_name, country_name_es, country_name_en, modified)
  SELECT /* Notes-staging */ c.country_id, c.country_name, c.country_name_es, c.country_name_en, TRUE
  FROM countries c
  WHERE c.country_id = p_country_id
   AND c.country_id NOT IN (SELECT country_id FROM dwh.dimension_countries)
  ON CONFLICT (country_id) DO UPDATE SET
    modified = TRUE,
    country_name = EXCLUDED.country_name,
    country_name_es = EXCLUDED.country_name_es,
    country_name_en = EXCLUDED.country_name_en
  RETURNING dimension_country_id INTO v_dimension_country_id;

  -- If still NULL (country not in base table or insert failed), use fallback
  IF v_dimension_country_id IS NULL THEN
   -- Use fallback country (dimension_country_id = 1, country_id = -1)
   SELECT /* Notes-staging */ dimension_country_id
    INTO v_dimension_country_id
   FROM dwh.dimension_countries
   WHERE country_id = -1;

   -- If fallback doesn't exist, create it
   IF v_dimension_country_id IS NULL THEN
    INSERT INTO dwh.dimension_countries
     (country_id, country_name, country_name_es, country_name_en, modified)
    VALUES (-1, 'Unknown - International waters',
     'Desconocido - Aguas internacionales', 'Unknown - International waters', TRUE)
    ON CONFLICT (country_id) DO NOTHING
    RETURNING dimension_country_id INTO v_dimension_country_id;

    -- If still NULL after conflict, select it
    IF v_dimension_country_id IS NULL THEN
     SELECT /* Notes-staging */ dimension_country_id
      INTO v_dimension_country_id
     FROM dwh.dimension_countries
     WHERE country_id = -1;
    END IF;
   END IF;
  END IF;

  RETURN v_dimension_country_id;
END;
$$;

COMMENT ON FUNCTION staging.get_or_create_country_dimension IS
  'Gets or creates a country dimension ID for a given country_id';

-- Function to process hashtags from a comment body
-- Returns a record with hashtag_number and hashtag_ids array
CREATE OR REPLACE FUNCTION staging.process_hashtags(
  p_body TEXT,
  OUT p_hashtag_number INTEGER,
  OUT p_hashtag_ids INTEGER[]
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_text_comment TEXT;
  v_hashtag_name TEXT;
  v_hashtag_id INTEGER;
BEGIN
  p_hashtag_number := 0;
  p_hashtag_ids := ARRAY[]::INTEGER[];

  IF p_body IS NULL OR p_body NOT LIKE '%#%' THEN
    RETURN;
  END IF;

  v_text_comment := p_body;

  -- Process ALL hashtags using WHILE loop (no limit)
  WHILE v_text_comment LIKE '%#%' LOOP
    CALL staging.get_hashtag(v_text_comment, v_hashtag_name);
    p_hashtag_number := p_hashtag_number + 1;

    -- Get hashtag ID and store in array
    v_hashtag_id := staging.get_hashtag_id(v_hashtag_name);
    p_hashtag_ids := array_append(p_hashtag_ids, v_hashtag_id);
  END LOOP;
END;
$$;

COMMENT ON FUNCTION staging.process_hashtags IS
  'Processes hashtags from a comment body and returns count and array of hashtag IDs';

-- Function to calculate comment metrics
-- Returns a record with comment_length, has_url, and has_mention
CREATE OR REPLACE FUNCTION staging.calculate_comment_metrics(
  p_body TEXT,
  OUT p_comment_length INTEGER,
  OUT p_has_url BOOLEAN,
  OUT p_has_mention BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
  p_comment_length := COALESCE(LENGTH(p_body), 0);
  p_has_url := (p_body ~ 'https?://');
  p_has_mention := (p_body ~ '@\w+');
END;
$$;

COMMENT ON FUNCTION staging.calculate_comment_metrics IS
  'Calculates comment metrics: length, has_url, has_mention';

-- Function to get timezone and local date/hour/season from note coordinates
-- Returns a record with timezone_id, local_action_id_date, local_action_id_hour_of_week, season_id
CREATE OR REPLACE FUNCTION staging.get_timezone_and_local_metrics(
  p_note_id INTEGER,
  p_action_at TIMESTAMP,
  OUT p_timezone_id INTEGER,
  OUT p_local_action_id_date INTEGER,
  OUT p_local_action_id_hour_of_week INTEGER,
  OUT p_season_id SMALLINT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_latitude DECIMAL;
  v_longitude DECIMAL;
BEGIN
  -- Get note coordinates
  SELECT n.latitude, n.longitude INTO v_latitude, v_longitude
  FROM notes n WHERE n.note_id = p_note_id;

  -- Calculate timezone and local metrics
  p_timezone_id := dwh.get_timezone_id_by_lonlat(v_longitude, v_latitude);
  p_local_action_id_date := dwh.get_local_date_id(p_action_at, p_timezone_id);
  p_local_action_id_hour_of_week := dwh.get_local_hour_of_week_id(p_action_at, p_timezone_id);
  p_season_id := dwh.get_season_id(p_action_at, v_latitude);
END;
$$;

COMMENT ON FUNCTION staging.get_timezone_and_local_metrics IS
  'Gets timezone and local date/hour/season metrics from note coordinates';

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Shared helper functions created' AS Task;


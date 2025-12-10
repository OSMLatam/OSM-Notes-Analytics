-- Enhance Datamarts with Specific Hashtag Metrics
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-24
--
-- This script enhances the existing datamarts with specific hashtag metrics
-- by action type (opening, resolution, comments)
-- Note: Column definitions are now in CREATE TABLE statements (datamartCountries_12 and datamartUsers_12)
-- This script only creates the functions and procedures to calculate and update these metrics

-- Create function to calculate hashtag metrics for countries
CREATE OR REPLACE FUNCTION dwh.calculate_country_hashtag_metrics(
  p_dimension_country_id INTEGER
) RETURNS TABLE (
  hashtags_opening JSON,
  hashtags_resolution JSON,
  hashtags_comments JSON,
  top_opening_hashtag VARCHAR(50),
  top_resolution_hashtag VARCHAR(50),
  opening_hashtag_count INTEGER,
  resolution_hashtag_count INTEGER
) AS $$
DECLARE
  v_hashtags_opening JSON;
  v_hashtags_resolution JSON;
  v_hashtags_comments JSON;
  v_top_opening_hashtag VARCHAR(50);
  v_top_resolution_hashtag VARCHAR(50);
  v_opening_count INTEGER;
  v_resolution_count INTEGER;
BEGIN
  -- Calculate opening hashtags
  SELECT
    JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'hashtag', hashtag, 'count', count)),
    MAX(hashtag) FILTER (WHERE rank = 1),
    SUM(count)
  INTO v_hashtags_opening, v_top_opening_hashtag, v_opening_count
  FROM (
    SELECT
      RANK() OVER (ORDER BY COUNT(*) DESC) AS rank,
      h.description AS hashtag,
      COUNT(*) AS count
    FROM dwh.fact_hashtags fh
    JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
    JOIN dwh.facts f ON fh.fact_id = f.fact_id
    WHERE f.dimension_id_country = p_dimension_country_id
      AND fh.is_opening_hashtag = TRUE
    GROUP BY h.description
    ORDER BY COUNT(*) DESC
    LIMIT 10
  ) opening_stats;

  -- Calculate resolution hashtags
  SELECT
    JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'hashtag', hashtag, 'count', count)),
    MAX(hashtag) FILTER (WHERE rank = 1),
    SUM(count)
  INTO v_hashtags_resolution, v_top_resolution_hashtag, v_resolution_count
  FROM (
    SELECT
      RANK() OVER (ORDER BY COUNT(*) DESC) AS rank,
      h.description AS hashtag,
      COUNT(*) AS count
    FROM dwh.fact_hashtags fh
    JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
    JOIN dwh.facts f ON fh.fact_id = f.fact_id
    WHERE f.dimension_id_country = p_dimension_country_id
      AND fh.is_resolution_hashtag = TRUE
    GROUP BY h.description
    ORDER BY COUNT(*) DESC
    LIMIT 10
  ) resolution_stats;

  -- Calculate comment hashtags
  SELECT JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'hashtag', hashtag, 'count', count))
  INTO v_hashtags_comments
  FROM (
    SELECT
      RANK() OVER (ORDER BY COUNT(*) DESC) AS rank,
      h.description AS hashtag,
      COUNT(*) AS count
    FROM dwh.fact_hashtags fh
    JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
    JOIN dwh.facts f ON fh.fact_id = f.fact_id
    WHERE f.dimension_id_country = p_dimension_country_id
      AND fh.used_in_action = 'commented'
    GROUP BY h.description
    ORDER BY COUNT(*) DESC
    LIMIT 10
  ) comment_stats;

  RETURN QUERY SELECT
    COALESCE(v_hashtags_opening, '[]'::JSON),
    COALESCE(v_hashtags_resolution, '[]'::JSON),
    COALESCE(v_hashtags_comments, '[]'::JSON),
    v_top_opening_hashtag,
    v_top_resolution_hashtag,
    COALESCE(v_opening_count, 0),
    COALESCE(v_resolution_count, 0);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION dwh.calculate_country_hashtag_metrics IS 'Calculate specific hashtag metrics for a country by action type';

-- Create function to calculate hashtag metrics for users
CREATE OR REPLACE FUNCTION dwh.calculate_user_hashtag_metrics(
  p_dimension_user_id INTEGER
) RETURNS TABLE (
  hashtags_opening JSON,
  hashtags_resolution JSON,
  hashtags_comments JSON,
  favorite_opening_hashtag VARCHAR(50),
  favorite_resolution_hashtag VARCHAR(50),
  opening_hashtag_count INTEGER,
  resolution_hashtag_count INTEGER
) AS $$
DECLARE
  v_hashtags_opening JSON;
  v_hashtags_resolution JSON;
  v_hashtags_comments JSON;
  v_favorite_opening_hashtag VARCHAR(50);
  v_favorite_resolution_hashtag VARCHAR(50);
  v_opening_count INTEGER;
  v_resolution_count INTEGER;
BEGIN
  -- Calculate opening hashtags
  SELECT
    JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'hashtag', hashtag, 'count', count)),
    MAX(hashtag) FILTER (WHERE rank = 1),
    SUM(count)
  INTO v_hashtags_opening, v_favorite_opening_hashtag, v_opening_count
  FROM (
    SELECT
      RANK() OVER (ORDER BY COUNT(*) DESC) AS rank,
      h.description AS hashtag,
      COUNT(*) AS count
    FROM dwh.fact_hashtags fh
    JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
    JOIN dwh.facts f ON fh.fact_id = f.fact_id
    WHERE f.opened_dimension_id_user = p_dimension_user_id
      AND fh.is_opening_hashtag = TRUE
    GROUP BY h.description
    ORDER BY COUNT(*) DESC
    LIMIT 10
  ) opening_stats;

  -- Calculate resolution hashtags
  SELECT
    JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'hashtag', hashtag, 'count', count)),
    MAX(hashtag) FILTER (WHERE rank = 1),
    SUM(count)
  INTO v_hashtags_resolution, v_favorite_resolution_hashtag, v_resolution_count
  FROM (
    SELECT
      RANK() OVER (ORDER BY COUNT(*) DESC) AS rank,
      h.description AS hashtag,
      COUNT(*) AS count
    FROM dwh.fact_hashtags fh
    JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
    JOIN dwh.facts f ON fh.fact_id = f.fact_id
    WHERE f.closed_dimension_id_user = p_dimension_user_id
      AND fh.is_resolution_hashtag = TRUE
    GROUP BY h.description
    ORDER BY COUNT(*) DESC
    LIMIT 10
  ) resolution_stats;

  -- Calculate comment hashtags
  SELECT JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'hashtag', hashtag, 'count', count))
  INTO v_hashtags_comments
  FROM (
    SELECT
      RANK() OVER (ORDER BY COUNT(*) DESC) AS rank,
      h.description AS hashtag,
      COUNT(*) AS count
    FROM dwh.fact_hashtags fh
    JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
    JOIN dwh.facts f ON fh.fact_id = f.fact_id
    WHERE f.action_dimension_id_user = p_dimension_user_id
      AND fh.used_in_action = 'commented'
    GROUP BY h.description
    ORDER BY COUNT(*) DESC
    LIMIT 10
  ) comment_stats;

  RETURN QUERY SELECT
    COALESCE(v_hashtags_opening, '[]'::JSON),
    COALESCE(v_hashtags_resolution, '[]'::JSON),
    COALESCE(v_hashtags_comments, '[]'::JSON),
    v_favorite_opening_hashtag,
    v_favorite_resolution_hashtag,
    COALESCE(v_opening_count, 0),
    COALESCE(v_resolution_count, 0);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION dwh.calculate_user_hashtag_metrics IS 'Calculate specific hashtag metrics for a user by action type';

-- Create procedure to update hashtag metrics for modified countries
CREATE OR REPLACE PROCEDURE dwh.update_country_hashtag_metrics() AS $$
DECLARE
  v_country RECORD;
  v_metrics RECORD;
BEGIN
  FOR v_country IN
    SELECT dimension_country_id
    FROM dwh.dimension_countries
    WHERE modified = TRUE
  LOOP
    SELECT * INTO v_metrics
    FROM dwh.calculate_country_hashtag_metrics(v_country.dimension_country_id);

    UPDATE dwh.datamartCountries SET
      hashtags_opening = v_metrics.hashtags_opening,
      hashtags_resolution = v_metrics.hashtags_resolution,
      hashtags_comments = v_metrics.hashtags_comments,
      top_opening_hashtag = v_metrics.top_opening_hashtag,
      top_resolution_hashtag = v_metrics.top_resolution_hashtag,
      opening_hashtag_count = v_metrics.opening_hashtag_count,
      resolution_hashtag_count = v_metrics.resolution_hashtag_count
    WHERE dimension_country_id = v_country.dimension_country_id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON PROCEDURE dwh.update_country_hashtag_metrics IS 'Update hashtag metrics for all modified countries';

-- Create procedure to update hashtag metrics for modified users
CREATE OR REPLACE PROCEDURE dwh.update_user_hashtag_metrics() AS $$
DECLARE
  v_user RECORD;
  v_metrics RECORD;
BEGIN
  FOR v_user IN
    SELECT dimension_user_id
    FROM dwh.dimension_users
    WHERE modified = TRUE AND is_current = TRUE
  LOOP
    SELECT * INTO v_metrics
    FROM dwh.calculate_user_hashtag_metrics(v_user.dimension_user_id);

    UPDATE dwh.datamartUsers SET
      hashtags_opening = v_metrics.hashtags_opening,
      hashtags_resolution = v_metrics.hashtags_resolution,
      hashtags_comments = v_metrics.hashtags_comments,
      favorite_opening_hashtag = v_metrics.favorite_opening_hashtag,
      favorite_resolution_hashtag = v_metrics.favorite_resolution_hashtag,
      opening_hashtag_count = v_metrics.opening_hashtag_count,
      resolution_hashtag_count = v_metrics.resolution_hashtag_count
    WHERE dimension_user_id = v_user.dimension_user_id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON PROCEDURE dwh.update_user_hashtag_metrics IS 'Update hashtag metrics for all modified users';

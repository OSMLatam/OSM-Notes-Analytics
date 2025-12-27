-- Enhance hashtag queries to include sequence_action information (DM-003)
-- This improves hashtag analysis by relating hashtags to comment sequence
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-27

-- Enhanced function to calculate country hashtag metrics with sequence information
CREATE OR REPLACE FUNCTION dwh.calculate_country_hashtag_metrics_with_sequence(
  p_dimension_country_id INTEGER
)
RETURNS TABLE (
  hashtags_opening JSON,
  hashtags_resolution JSON,
  hashtags_comments JSON,
  hashtags_by_sequence JSON,
  top_opening_hashtag VARCHAR(50),
  top_resolution_hashtag VARCHAR(50),
  opening_hashtag_count INTEGER,
  resolution_hashtag_count INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_hashtags_opening JSON;
  v_hashtags_resolution JSON;
  v_hashtags_comments JSON;
  v_hashtags_by_sequence JSON;
  v_top_opening_hashtag VARCHAR(50);
  v_top_resolution_hashtag VARCHAR(50);
  v_opening_count INTEGER;
  v_resolution_count INTEGER;
BEGIN
  -- Calculate opening hashtags (same as before)
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

  -- Calculate resolution hashtags (same as before)
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

  -- Calculate comment hashtags (same as before)
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

  -- DM-003: NEW - Hashtags by sequence position
  -- Group hashtags by their sequence_action position (first comment, second, etc.)
  SELECT json_object_agg(
    sequence_range::TEXT,
    json_build_object(
      'hashtag', hashtag,
      'count', count,
      'avg_sequence', avg_sequence
    )
    ORDER BY count DESC
  )
  INTO v_hashtags_by_sequence
  FROM (
    SELECT
      CASE
        WHEN f.sequence_action = 1 THEN 'first_comment'
        WHEN f.sequence_action = 2 THEN 'second_comment'
        WHEN f.sequence_action BETWEEN 3 AND 5 THEN 'early_comments'
        WHEN f.sequence_action BETWEEN 6 AND 10 THEN 'mid_comments'
        ELSE 'late_comments'
      END as sequence_range,
      h.description AS hashtag,
      COUNT(*) AS count,
      AVG(f.sequence_action)::INTEGER AS avg_sequence
    FROM dwh.fact_hashtags fh
    JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
    JOIN dwh.facts f ON fh.fact_id = f.fact_id
    WHERE f.dimension_id_country = p_dimension_country_id
      AND f.sequence_action IS NOT NULL
      AND fh.used_in_action = 'commented'
    GROUP BY sequence_range, h.description
    ORDER BY sequence_range, COUNT(*) DESC
  ) sequence_stats;

  RETURN QUERY SELECT
    COALESCE(v_hashtags_opening, '[]'::JSON),
    COALESCE(v_hashtags_resolution, '[]'::JSON),
    COALESCE(v_hashtags_comments, '[]'::JSON),
    COALESCE(v_hashtags_by_sequence, '{}'::JSON),
    v_top_opening_hashtag,
    v_top_resolution_hashtag,
    COALESCE(v_opening_count, 0),
    COALESCE(v_resolution_count, 0);
END;
$$;

COMMENT ON FUNCTION dwh.calculate_country_hashtag_metrics_with_sequence IS
  'DM-003: Enhanced hashtag metrics with sequence_action information. Includes hashtags grouped by comment sequence position.';

-- Enhanced function to calculate user hashtag metrics with sequence information
CREATE OR REPLACE FUNCTION dwh.calculate_user_hashtag_metrics_with_sequence(
  p_dimension_user_id INTEGER
)
RETURNS TABLE (
  hashtags_opening JSON,
  hashtags_resolution JSON,
  hashtags_comments JSON,
  hashtags_by_sequence JSON,
  favorite_opening_hashtag VARCHAR(50),
  favorite_resolution_hashtag VARCHAR(50),
  opening_hashtag_count INTEGER,
  resolution_hashtag_count INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_hashtags_opening JSON;
  v_hashtags_resolution JSON;
  v_hashtags_comments JSON;
  v_hashtags_by_sequence JSON;
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

  -- DM-003: NEW - Hashtags by sequence position for user comments
  SELECT json_object_agg(
    sequence_range::TEXT,
    json_build_object(
      'hashtag', hashtag,
      'count', count,
      'avg_sequence', avg_sequence
    )
    ORDER BY count DESC
  )
  INTO v_hashtags_by_sequence
  FROM (
    SELECT
      CASE
        WHEN f.sequence_action = 1 THEN 'first_comment'
        WHEN f.sequence_action = 2 THEN 'second_comment'
        WHEN f.sequence_action BETWEEN 3 AND 5 THEN 'early_comments'
        WHEN f.sequence_action BETWEEN 6 AND 10 THEN 'mid_comments'
        ELSE 'late_comments'
      END as sequence_range,
      h.description AS hashtag,
      COUNT(*) AS count,
      AVG(f.sequence_action)::INTEGER AS avg_sequence
    FROM dwh.fact_hashtags fh
    JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
    JOIN dwh.facts f ON fh.fact_id = f.fact_id
    WHERE f.action_dimension_id_user = p_dimension_user_id
      AND f.sequence_action IS NOT NULL
      AND fh.used_in_action = 'commented'
    GROUP BY sequence_range, h.description
    ORDER BY sequence_range, COUNT(*) DESC
  ) sequence_stats;

  RETURN QUERY SELECT
    COALESCE(v_hashtags_opening, '[]'::JSON),
    COALESCE(v_hashtags_resolution, '[]'::JSON),
    COALESCE(v_hashtags_comments, '[]'::JSON),
    COALESCE(v_hashtags_by_sequence, '{}'::JSON),
    v_favorite_opening_hashtag,
    v_favorite_resolution_hashtag,
    COALESCE(v_opening_count, 0),
    COALESCE(v_resolution_count, 0);
END;
$$;

COMMENT ON FUNCTION dwh.calculate_user_hashtag_metrics_with_sequence IS
  'DM-003: Enhanced hashtag metrics with sequence_action information for users. Includes hashtags grouped by comment sequence position.';

-- Note: These enhanced functions can be used to replace the existing hashtag calculation functions
-- in datamart procedures. The new functions add sequence-based analysis while maintaining
-- backward compatibility with existing metrics.


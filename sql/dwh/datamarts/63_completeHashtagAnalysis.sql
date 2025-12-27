-- Complete Hashtag Analysis Implementation (DM-002)
-- Adds calculation of hashtags_opening, hashtags_resolution, hashtags_comments
-- and creates functions to filter notes by hashtags
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-27

-- Function to get notes filtered by hashtag for a user
CREATE OR REPLACE FUNCTION dwh.get_notes_by_hashtag_for_user(
  p_dimension_user_id INTEGER,
  p_hashtag TEXT,
  p_action_type note_event_enum DEFAULT NULL,
  p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
  note_id INTEGER,
  action_type note_event_enum,
  action_at TIMESTAMP,
  comment_text TEXT,
  sequence_action INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT
    f.id_note,
    f.action_comment,
    f.action_at,
    f.comment_text,
    f.sequence_action
  FROM dwh.facts f
  JOIN dwh.fact_hashtags fh ON f.fact_id = fh.fact_id
  JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
  WHERE (
    f.opened_dimension_id_user = p_dimension_user_id
    OR f.action_dimension_id_user = p_dimension_user_id
    OR f.closed_dimension_id_user = p_dimension_user_id
  )
    AND LOWER(h.description) = LOWER(p_hashtag)
    AND (p_action_type IS NULL OR f.action_comment = p_action_type)
  ORDER BY f.action_at DESC
  LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION dwh.get_notes_by_hashtag_for_user IS
  'DM-002: Returns notes filtered by hashtag for a specific user. Can filter by action type.';

-- Function to get notes filtered by hashtag for a country
CREATE OR REPLACE FUNCTION dwh.get_notes_by_hashtag_for_country(
  p_dimension_country_id INTEGER,
  p_hashtag TEXT,
  p_action_type note_event_enum DEFAULT NULL,
  p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
  note_id INTEGER,
  action_type note_event_enum,
  action_at TIMESTAMP,
  comment_text TEXT,
  sequence_action INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT
    f.id_note,
    f.action_comment,
    f.action_at,
    f.comment_text,
    f.sequence_action
  FROM dwh.facts f
  JOIN dwh.fact_hashtags fh ON f.fact_id = fh.fact_id
  JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
  WHERE f.dimension_id_country = p_dimension_country_id
    AND LOWER(h.description) = LOWER(p_hashtag)
    AND (p_action_type IS NULL OR f.action_comment = p_action_type)
  ORDER BY f.action_at DESC
  LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION dwh.get_notes_by_hashtag_for_country IS
  'DM-002: Returns notes filtered by hashtag for a specific country. Can filter by action type.';

-- Function to get top hashtags globally
CREATE OR REPLACE FUNCTION dwh.get_top_hashtags_globally(
  p_limit INTEGER DEFAULT 50,
  p_action_type note_event_enum DEFAULT NULL
)
RETURNS TABLE (
  rank BIGINT,
  hashtag TEXT,
  usage_count BIGINT,
  notes_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    RANK() OVER (ORDER BY COUNT(DISTINCT fh.fact_id) DESC) AS rank,
    h.description AS hashtag,
    COUNT(DISTINCT fh.fact_id) AS usage_count,
    COUNT(DISTINCT f.id_note) AS notes_count
  FROM dwh.fact_hashtags fh
  JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
  JOIN dwh.facts f ON fh.fact_id = f.fact_id
  WHERE (p_action_type IS NULL OR f.action_comment = p_action_type)
  GROUP BY h.description
  ORDER BY usage_count DESC, hashtag ASC
  LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION dwh.get_top_hashtags_globally IS
  'DM-002: Returns top hashtags globally, optionally filtered by action type.';

-- Function to get hashtag usage statistics for a user
CREATE OR REPLACE FUNCTION dwh.get_user_hashtag_statistics(
  p_dimension_user_id INTEGER
)
RETURNS TABLE (
  hashtag TEXT,
  total_uses BIGINT,
  opening_uses BIGINT,
  resolution_uses BIGINT,
  comment_uses BIGINT,
  notes_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    h.description AS hashtag,
    COUNT(DISTINCT fh.fact_id) AS total_uses,
    COUNT(DISTINCT fh.fact_id) FILTER (WHERE fh.is_opening_hashtag = TRUE) AS opening_uses,
    COUNT(DISTINCT fh.fact_id) FILTER (WHERE fh.is_resolution_hashtag = TRUE) AS resolution_uses,
    COUNT(DISTINCT fh.fact_id) FILTER (WHERE fh.used_in_action = 'commented') AS comment_uses,
    COUNT(DISTINCT f.id_note) AS notes_count
  FROM dwh.fact_hashtags fh
  JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
  JOIN dwh.facts f ON fh.fact_id = f.fact_id
  WHERE (
    f.opened_dimension_id_user = p_dimension_user_id
    OR f.action_dimension_id_user = p_dimension_user_id
    OR f.closed_dimension_id_user = p_dimension_user_id
  )
  GROUP BY h.description
  ORDER BY total_uses DESC, hashtag ASC;
END;
$$;

COMMENT ON FUNCTION dwh.get_user_hashtag_statistics IS
  'DM-002: Returns detailed hashtag usage statistics for a user, broken down by action type.';

-- Function to get hashtag usage statistics for a country
CREATE OR REPLACE FUNCTION dwh.get_country_hashtag_statistics(
  p_dimension_country_id INTEGER
)
RETURNS TABLE (
  hashtag TEXT,
  total_uses BIGINT,
  opening_uses BIGINT,
  resolution_uses BIGINT,
  comment_uses BIGINT,
  notes_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    h.description AS hashtag,
    COUNT(DISTINCT fh.fact_id) AS total_uses,
    COUNT(DISTINCT fh.fact_id) FILTER (WHERE fh.is_opening_hashtag = TRUE) AS opening_uses,
    COUNT(DISTINCT fh.fact_id) FILTER (WHERE fh.is_resolution_hashtag = TRUE) AS resolution_uses,
    COUNT(DISTINCT fh.fact_id) FILTER (WHERE fh.used_in_action = 'commented') AS comment_uses,
    COUNT(DISTINCT f.id_note) AS notes_count
  FROM dwh.fact_hashtags fh
  JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
  JOIN dwh.facts f ON fh.fact_id = f.fact_id
  WHERE f.dimension_id_country = p_dimension_country_id
  GROUP BY h.description
  ORDER BY total_uses DESC, hashtag ASC;
END;
$$;

COMMENT ON FUNCTION dwh.get_country_hashtag_statistics IS
  'DM-002: Returns detailed hashtag usage statistics for a country, broken down by action type.';


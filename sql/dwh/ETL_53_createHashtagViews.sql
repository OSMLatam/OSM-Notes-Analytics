-- Create Hashtag Analysis Views
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-24
--
-- Views for analyzing hashtag usage patterns by action type

-- View for hashtags most used in note opening
CREATE OR REPLACE VIEW dwh.v_hashtags_opening AS
SELECT
  h.dimension_hashtag_id,
  h.description as hashtag,
  COUNT(*) as usage_count,
  COUNT(DISTINCT f.dimension_id_country) as countries_count,
  COUNT(DISTINCT f.opened_dimension_id_user) as users_count
FROM dwh.fact_hashtags fh
JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
JOIN dwh.facts f ON fh.fact_id = f.fact_id
WHERE fh.is_opening_hashtag = TRUE
GROUP BY h.dimension_hashtag_id, h.description
ORDER BY usage_count DESC;

COMMENT ON VIEW dwh.v_hashtags_opening IS
  'Most used hashtags in note opening actions with usage statistics';

-- View for hashtags used in note resolution/closure
CREATE OR REPLACE VIEW dwh.v_hashtags_resolution AS
SELECT
  h.dimension_hashtag_id,
  h.description as hashtag,
  COUNT(*) as usage_count,
  AVG(f.days_to_resolution) as avg_resolution_days,
  COUNT(DISTINCT f.dimension_id_country) as countries_count,
  COUNT(DISTINCT f.closed_dimension_id_user) as users_count
FROM dwh.fact_hashtags fh
JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
JOIN dwh.facts f ON fh.fact_id = f.fact_id
WHERE fh.is_resolution_hashtag = TRUE
GROUP BY h.dimension_hashtag_id, h.description
ORDER BY usage_count DESC;

COMMENT ON VIEW dwh.v_hashtags_resolution IS
  'Most used hashtags in note resolution/closure actions with resolution metrics';

-- View for hashtags used in comments
CREATE OR REPLACE VIEW dwh.v_hashtags_comments AS
SELECT
  h.dimension_hashtag_id,
  h.description as hashtag,
  COUNT(*) as usage_count,
  COUNT(DISTINCT f.dimension_id_country) as countries_count,
  COUNT(DISTINCT f.action_dimension_id_user) as users_count,
  AVG(f.comment_length) as avg_comment_length
FROM dwh.fact_hashtags fh
JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
JOIN dwh.facts f ON fh.fact_id = f.fact_id
WHERE fh.used_in_action = 'commented'
GROUP BY h.dimension_hashtag_id, h.description
ORDER BY usage_count DESC;

COMMENT ON VIEW dwh.v_hashtags_comments IS
  'Most used hashtags in comment actions with engagement metrics';

-- View for hashtag usage by action type
CREATE OR REPLACE VIEW dwh.v_hashtags_by_action AS
SELECT
  h.dimension_hashtag_id,
  h.description as hashtag,
  fh.used_in_action,
  COUNT(*) as usage_count,
  COUNT(DISTINCT f.dimension_id_country) as countries_count,
  COUNT(DISTINCT f.action_dimension_id_user) as users_count
FROM dwh.fact_hashtags fh
JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
JOIN dwh.facts f ON fh.fact_id = f.fact_id
GROUP BY h.dimension_hashtag_id, h.description, fh.used_in_action
ORDER BY h.description, fh.used_in_action, usage_count DESC;

COMMENT ON VIEW dwh.v_hashtags_by_action IS
  'Hashtag usage breakdown by action type (opened/commented/closed/etc)';

-- View for top hashtags overall with action breakdown
CREATE OR REPLACE VIEW dwh.v_hashtags_top_overall AS
SELECT
  h.dimension_hashtag_id,
  h.description as hashtag,
  COUNT(*) as total_usage,
  COUNT(*) FILTER (WHERE fh.used_in_action = 'opened') as opening_usage,
  COUNT(*) FILTER (WHERE fh.used_in_action = 'commented') as comment_usage,
  COUNT(*) FILTER (WHERE fh.used_in_action = 'closed') as closure_usage,
  COUNT(*) FILTER (WHERE fh.used_in_action = 'reopened') as reopening_usage,
  COUNT(DISTINCT f.dimension_id_country) as countries_count,
  COUNT(DISTINCT f.action_dimension_id_user) as users_count
FROM dwh.fact_hashtags fh
JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
JOIN dwh.facts f ON fh.fact_id = f.fact_id
GROUP BY h.dimension_hashtag_id, h.description
ORDER BY total_usage DESC;

COMMENT ON VIEW dwh.v_hashtags_top_overall IS
  'Top hashtags overall with breakdown by action type and geographic/user distribution';


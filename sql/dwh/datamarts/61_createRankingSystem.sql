-- Create Ranking System (DM-012, DM-013, DM-014)
-- Creates views and functions for various rankings
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-27

-- DM-012: Rankings table/view structure
-- Top 100 users/countries by various metrics (historical, last year, last month, today)

-- View: Top users by notes opened (all time)
CREATE OR REPLACE VIEW dwh.v_ranking_users_opened_all_time AS
SELECT
  u.user_id,
  u.username,
  COUNT(DISTINCT f.id_note) as notes_opened,
  RANK() OVER (ORDER BY COUNT(DISTINCT f.id_note) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_users u ON f.opened_dimension_id_user = u.dimension_user_id
WHERE f.action_comment = 'opened'
  AND u.user_id IS NOT NULL
GROUP BY u.user_id, u.username
ORDER BY notes_opened DESC
LIMIT 100;

COMMENT ON VIEW dwh.v_ranking_users_opened_all_time IS
  'DM-012: Top 100 users by notes opened (all time historical)';

-- View: Top users by notes closed (all time)
CREATE OR REPLACE VIEW dwh.v_ranking_users_closed_all_time AS
SELECT
  u.user_id,
  u.username,
  COUNT(DISTINCT f.id_note) as notes_closed,
  RANK() OVER (ORDER BY COUNT(DISTINCT f.id_note) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_users u ON f.closed_dimension_id_user = u.dimension_user_id
WHERE f.action_comment = 'closed'
  AND u.user_id IS NOT NULL
GROUP BY u.user_id, u.username
ORDER BY notes_closed DESC
LIMIT 100;

COMMENT ON VIEW dwh.v_ranking_users_closed_all_time IS
  'DM-012: Top 100 users by notes closed (all time historical)';

-- View: Top users by comments (all time)
CREATE OR REPLACE VIEW dwh.v_ranking_users_commented_all_time AS
SELECT
  u.user_id,
  u.username,
  COUNT(*) as comments_count,
  RANK() OVER (ORDER BY COUNT(*) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_users u ON f.action_dimension_id_user = u.dimension_user_id
WHERE f.action_comment = 'commented'
  AND u.user_id IS NOT NULL
GROUP BY u.user_id, u.username
ORDER BY comments_count DESC
LIMIT 100;

COMMENT ON VIEW dwh.v_ranking_users_commented_all_time IS
  'DM-012: Top 100 users by comments (all time historical)';

-- View: Top users by reopenings (all time)
CREATE OR REPLACE VIEW dwh.v_ranking_users_reopened_all_time AS
SELECT
  u.user_id,
  u.username,
  COUNT(DISTINCT f.id_note) as notes_reopened,
  RANK() OVER (ORDER BY COUNT(DISTINCT f.id_note) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_users u ON f.action_dimension_id_user = u.dimension_user_id
WHERE f.action_comment = 'reopened'
  AND u.user_id IS NOT NULL
GROUP BY u.user_id, u.username
ORDER BY notes_reopened DESC
LIMIT 100;

COMMENT ON VIEW dwh.v_ranking_users_reopened_all_time IS
  'DM-012: Top 100 users by notes reopened (all time historical)';

-- View: Top users by notes opened (current year)
CREATE OR REPLACE VIEW dwh.v_ranking_users_opened_current_year AS
SELECT
  u.user_id,
  u.username,
  COUNT(DISTINCT f.id_note) as notes_opened,
  RANK() OVER (ORDER BY COUNT(DISTINCT f.id_note) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_users u ON f.opened_dimension_id_user = u.dimension_user_id
JOIN dwh.dimension_days dd ON f.opened_dimension_id_date = dd.dimension_day_id
WHERE f.action_comment = 'opened'
  AND u.user_id IS NOT NULL
  AND EXTRACT(YEAR FROM dd.date_id) = EXTRACT(YEAR FROM CURRENT_DATE)
GROUP BY u.user_id, u.username
ORDER BY notes_opened DESC
LIMIT 100;

COMMENT ON VIEW dwh.v_ranking_users_opened_current_year IS
  'DM-012: Top 100 users by notes opened (current year)';

-- View: Top users by notes opened (current month)
CREATE OR REPLACE VIEW dwh.v_ranking_users_opened_current_month AS
SELECT
  u.user_id,
  u.username,
  COUNT(DISTINCT f.id_note) as notes_opened,
  RANK() OVER (ORDER BY COUNT(DISTINCT f.id_note) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_users u ON f.opened_dimension_id_user = u.dimension_user_id
JOIN dwh.dimension_days dd ON f.opened_dimension_id_date = dd.dimension_day_id
WHERE f.action_comment = 'opened'
  AND u.user_id IS NOT NULL
  AND EXTRACT(YEAR FROM dd.date_id) = EXTRACT(YEAR FROM CURRENT_DATE)
  AND EXTRACT(MONTH FROM dd.date_id) = EXTRACT(MONTH FROM CURRENT_DATE)
GROUP BY u.user_id, u.username
ORDER BY notes_opened DESC
LIMIT 100;

COMMENT ON VIEW dwh.v_ranking_users_opened_current_month IS
  'DM-012: Top 100 users by notes opened (current month)';

-- View: Top users by notes opened (today)
CREATE OR REPLACE VIEW dwh.v_ranking_users_opened_today AS
SELECT
  u.user_id,
  u.username,
  COUNT(DISTINCT f.id_note) as notes_opened,
  RANK() OVER (ORDER BY COUNT(DISTINCT f.id_note) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_users u ON f.opened_dimension_id_user = u.dimension_user_id
JOIN dwh.dimension_days dd ON f.opened_dimension_id_date = dd.dimension_day_id
WHERE f.action_comment = 'opened'
  AND u.user_id IS NOT NULL
  AND dd.date_id = CURRENT_DATE
GROUP BY u.user_id, u.username
ORDER BY notes_opened DESC
LIMIT 100;

COMMENT ON VIEW dwh.v_ranking_users_opened_today IS
  'DM-012: Top 100 users by notes opened (today)';

-- DM-013: Ranking of countries
-- View: Top countries by notes opened
CREATE OR REPLACE VIEW dwh.v_ranking_countries_opened AS
SELECT
  c.country_id,
  c.country_name_en,
  c.country_name_es,
  COUNT(DISTINCT f.id_note) as notes_opened,
  RANK() OVER (ORDER BY COUNT(DISTINCT f.id_note) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_countries c ON f.dimension_id_country = c.dimension_country_id
WHERE f.action_comment = 'opened'
GROUP BY c.country_id, c.country_name_en, c.country_name_es
ORDER BY notes_opened DESC;

COMMENT ON VIEW dwh.v_ranking_countries_opened IS
  'DM-013: Ranking of countries by notes opened';

-- View: Top countries by notes closed
CREATE OR REPLACE VIEW dwh.v_ranking_countries_closed AS
SELECT
  c.country_id,
  c.country_name_en,
  c.country_name_es,
  COUNT(DISTINCT f.id_note) as notes_closed,
  RANK() OVER (ORDER BY COUNT(DISTINCT f.id_note) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_countries c ON f.dimension_id_country = c.dimension_country_id
WHERE f.action_comment = 'closed'
GROUP BY c.country_id, c.country_name_en, c.country_name_es
ORDER BY notes_closed DESC;

COMMENT ON VIEW dwh.v_ranking_countries_closed IS
  'DM-013: Ranking of countries by notes closed';

-- View: Top countries by currently open notes
CREATE OR REPLACE VIEW dwh.v_ranking_countries_currently_open AS
SELECT
  c.country_id,
  c.country_name_en,
  c.country_name_es,
  COUNT(*) as currently_open_count,
  RANK() OVER (ORDER BY COUNT(*) DESC) as rank_position
FROM dwh.note_current_status ncs
JOIN dwh.dimension_countries c ON ncs.dimension_id_country = c.dimension_country_id
WHERE ncs.is_currently_open = TRUE
GROUP BY c.country_id, c.country_name_en, c.country_name_es
ORDER BY currently_open_count DESC;

COMMENT ON VIEW dwh.v_ranking_countries_currently_open IS
  'DM-013: Ranking of countries by currently open notes';

-- View: Top countries by resolution rate
CREATE OR REPLACE VIEW dwh.v_ranking_countries_resolution_rate AS
SELECT
  c.country_id,
  c.country_name_en,
  c.country_name_es,
  COALESCE(dc.resolution_rate, 0) as resolution_rate,
  RANK() OVER (ORDER BY COALESCE(dc.resolution_rate, 0) DESC) as rank_position
FROM dwh.dimension_countries c
LEFT JOIN dwh.datamartcountries dc ON c.dimension_country_id = dc.dimension_country_id
WHERE dc.resolution_rate IS NOT NULL
ORDER BY resolution_rate DESC;

COMMENT ON VIEW dwh.v_ranking_countries_resolution_rate IS
  'DM-013: Ranking of countries by resolution rate';

-- DM-014: Ranking of users globally (top opened/closed)
-- View: Top users globally by notes opened
CREATE OR REPLACE VIEW dwh.v_ranking_users_global_opened AS
SELECT
  u.user_id,
  u.username,
  COUNT(DISTINCT f.id_note) as notes_opened,
  RANK() OVER (ORDER BY COUNT(DISTINCT f.id_note) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_users u ON f.opened_dimension_id_user = u.dimension_user_id
WHERE f.action_comment = 'opened'
  AND u.user_id IS NOT NULL
GROUP BY u.user_id, u.username
ORDER BY notes_opened DESC
LIMIT 100;

COMMENT ON VIEW dwh.v_ranking_users_global_opened IS
  'DM-014: Top 100 users globally by notes opened';

-- View: Top users globally by notes closed
CREATE OR REPLACE VIEW dwh.v_ranking_users_global_closed AS
SELECT
  u.user_id,
  u.username,
  COUNT(DISTINCT f.id_note) as notes_closed,
  RANK() OVER (ORDER BY COUNT(DISTINCT f.id_note) DESC) as rank_position
FROM dwh.facts f
JOIN dwh.dimension_users u ON f.closed_dimension_id_user = u.dimension_user_id
WHERE f.action_comment = 'closed'
  AND u.user_id IS NOT NULL
GROUP BY u.user_id, u.username
ORDER BY notes_closed DESC
LIMIT 100;

COMMENT ON VIEW dwh.v_ranking_users_global_closed IS
  'DM-014: Top 100 users globally by notes closed';

-- Function to get rankings as JSON for easy consumption
CREATE OR REPLACE FUNCTION dwh.get_user_rankings(
  p_period TEXT DEFAULT 'all_time' -- 'all_time', 'current_year', 'current_month', 'today'
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
  v_result JSON;
BEGIN
  CASE p_period
    WHEN 'all_time' THEN
      SELECT json_agg(
        json_build_object(
          'rank', rank_position,
          'user_id', user_id,
          'username', username,
          'notes_opened', notes_opened,
          'notes_closed', (SELECT notes_closed FROM dwh.v_ranking_users_closed_all_time WHERE user_id = u.user_id LIMIT 1),
          'comments', (SELECT comments_count FROM dwh.v_ranking_users_commented_all_time WHERE user_id = u.user_id LIMIT 1),
          'reopened', (SELECT notes_reopened FROM dwh.v_ranking_users_reopened_all_time WHERE user_id = u.user_id LIMIT 1)
        ) ORDER BY rank_position
      )
      INTO v_result
      FROM dwh.v_ranking_users_opened_all_time u
      LIMIT 100;
    WHEN 'current_year' THEN
      SELECT json_agg(
        json_build_object(
          'rank', rank_position,
          'user_id', user_id,
          'username', username,
          'notes_opened', notes_opened
        ) ORDER BY rank_position
      )
      INTO v_result
      FROM dwh.v_ranking_users_opened_current_year
      LIMIT 100;
    WHEN 'current_month' THEN
      SELECT json_agg(
        json_build_object(
          'rank', rank_position,
          'user_id', user_id,
          'username', username,
          'notes_opened', notes_opened
        ) ORDER BY rank_position
      )
      INTO v_result
      FROM dwh.v_ranking_users_opened_current_month
      LIMIT 100;
    WHEN 'today' THEN
      SELECT json_agg(
        json_build_object(
          'rank', rank_position,
          'user_id', user_id,
          'username', username,
          'notes_opened', notes_opened
        ) ORDER BY rank_position
      )
      INTO v_result
      FROM dwh.v_ranking_users_opened_today
      LIMIT 100;
    ELSE
      RAISE EXCEPTION 'Invalid period: %. Use: all_time, current_year, current_month, today', p_period;
  END CASE;

  RETURN COALESCE(v_result, '[]'::JSON);
END;
$$;

COMMENT ON FUNCTION dwh.get_user_rankings IS
  'DM-012: Get user rankings as JSON for specified period (all_time, current_year, current_month, today)';

-- Function to get country rankings as JSON
CREATE OR REPLACE FUNCTION dwh.get_country_rankings()
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_agg(
    json_build_object(
      'rank', rank_position,
      'country_id', country_id,
      'country_name_en', country_name_en,
      'country_name_es', country_name_es,
      'notes_opened', notes_opened,
      'notes_closed', (SELECT notes_closed FROM dwh.v_ranking_countries_closed WHERE country_id = c.country_id LIMIT 1),
      'currently_open', (SELECT currently_open_count FROM dwh.v_ranking_countries_currently_open WHERE country_id = c.country_id LIMIT 1),
      'resolution_rate', (SELECT resolution_rate FROM dwh.v_ranking_countries_resolution_rate WHERE country_id = c.country_id LIMIT 1)
    ) ORDER BY rank_position
  )
  INTO v_result
  FROM dwh.v_ranking_countries_opened c
  LIMIT 100;

  RETURN COALESCE(v_result, '[]'::JSON);
END;
$$;

COMMENT ON FUNCTION dwh.get_country_rankings IS
  'DM-013: Get country rankings as JSON with opened, closed, currently open, and resolution rate';


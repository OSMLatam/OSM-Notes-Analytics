-- Export closed notes by country to CSV
-- This query exports closed notes with all relevant information for AI context
-- Comments are cleaned: multiple lines converted to spaces, quotes normalized, length limited
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-XX
--
-- Column order optimized for AI context:
-- 1. Basic info: note_id, country, location, dates
-- 2. Problem: opening_comment (what was reported)
-- 3. Solution: closing_comment (how it was resolved), who closed it
-- 4. Context: resolution time, comment count, reopen status
--
-- Columns exported:
-- - note_id: OSM note ID
-- - country_name: Country name
-- - latitude: Note latitude
-- - longitude: Note longitude
-- - opened_at: Date and time when note was opened
-- - closed_at: Date and time when note was closed
-- - days_to_resolution: Days from open to close
-- - opened_by_username: Username who opened the note
-- - opening_comment: Initial comment (cleaned, max 2000 chars)
-- - total_comments: Total number of comments on the note
-- - was_reopened: Whether note was reopened before final close (0/1)
-- - closed_by_username: Username who closed the note
-- - closing_comment: Comment when note was closed (cleaned, max 2000 chars)
--
-- Usage:
--   This SQL is used by bin/dwh/exportAndPushCSVToGitHub.sh
--   The script replaces :country_id with actual country ID before execution

\set ON_ERROR_STOP on

-- Helper function to clean comment text for CSV export
-- - Replaces multiple newlines/tabs with single space
-- - Converts double quotes to single quotes
-- - Truncates to max length (2000 chars)
-- - Removes leading/trailing whitespace
WITH cleaned_comments AS (
  SELECT
    closed_fact.id_note,
    -- Clean opening comment
    LEFT(
      TRIM(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            COALESCE(opening_text.body, ''),
            E'[\\n\\r\\t]+', ' ', 'g'  -- Replace newlines/tabs with space
          ),
          '"', '''', 'g'  -- Replace double quotes with single quotes
        )
      ),
      2000  -- Limit to 2000 characters
    ) AS opening_comment_cleaned,
    -- Clean closing comment
    LEFT(
      TRIM(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            COALESCE(closing_text.body, ''),
            E'[\\n\\r\\t]+', ' ', 'g'  -- Replace newlines/tabs with space
          ),
          '"', '''', 'g'  -- Replace double quotes with single quotes
        )
      ),
      2000  -- Limit to 2000 characters
    ) AS closing_comment_cleaned,
    -- Count total comments on note
    (
      SELECT COUNT(*)
      FROM dwh.facts
      WHERE id_note = closed_fact.id_note
        AND action_comment IN ('commented', 'opened', 'closed', 'reopened')
    ) AS total_comments,
    -- Check if note was reopened
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM dwh.facts
        WHERE id_note = closed_fact.id_note
          AND action_comment = 'reopened'
      ) THEN 1
      ELSE 0
    END AS was_reopened
  FROM dwh.facts closed_fact
    -- Filter by country early for efficiency
    JOIN dwh.dimension_countries dc
      ON closed_fact.dimension_id_country = dc.dimension_country_id
    -- Get opening comment text
    LEFT JOIN (
      SELECT DISTINCT ON (nc.note_id)
        nc.note_id,
        nct.body
      FROM public.note_comments nc
        JOIN public.note_comments_text nct
          ON nc.note_id = nct.note_id
          AND nc.sequence_action = nct.sequence_action
      WHERE nc.event = 'opened'
      ORDER BY nc.note_id, nc.sequence_action ASC
    ) opening_text
      ON closed_fact.id_note = opening_text.note_id
    -- Get closing comment text
    LEFT JOIN (
      SELECT DISTINCT ON (nc.note_id)
        nc.note_id,
        nct.body
      FROM public.note_comments nc
        JOIN public.note_comments_text nct
          ON nc.note_id = nct.note_id
          AND nc.sequence_action = nct.sequence_action
      WHERE nc.event = 'closed'
      ORDER BY nc.note_id, nc.sequence_action DESC
    ) closing_text
      ON closed_fact.id_note = closing_text.note_id
  WHERE closed_fact.action_comment = 'closed'
    -- Filter by country (variable :country_id will be replaced by bash script)
    AND dc.country_id = :country_id
    -- Only get the most recent close for each note
    AND closed_fact.fact_id = (
      SELECT MAX(fact_id)
      FROM dwh.facts
      WHERE id_note = closed_fact.id_note
        AND action_comment = 'closed'
    )
)
-- Main query with cleaned comments and optimized column order for AI context
SELECT
  -- 1. Basic identification and location
  closed_fact.id_note AS note_id,
  COALESCE(c.country_name, 'Unknown') AS country_name,
  n.latitude,
  n.longitude,
  -- 2. Timeline
  -- Get opened_at from dimension_days using opened_dimension_id_date
  TO_CHAR(opened_date.date_id, 'YYYY-MM-DD HH24:MI:SS') AS opened_at,
  TO_CHAR(closed_fact.action_at, 'YYYY-MM-DD HH24:MI:SS') AS closed_at,
  COALESCE(closed_fact.days_to_resolution, 0) AS days_to_resolution,
  -- 3. Problem context (what was reported)
  COALESCE(u_opened.username, 'Unknown') AS opened_by_username,
  COALESCE(cc.opening_comment_cleaned, '') AS opening_comment,
  cc.total_comments,
  cc.was_reopened,
  -- 4. Solution context (how it was resolved)
  COALESCE(u_closed.username, 'Unknown') AS closed_by_username,
  COALESCE(cc.closing_comment_cleaned, '') AS closing_comment
FROM dwh.facts closed_fact
  -- Get cleaned comments and metadata
  JOIN cleaned_comments cc
    ON closed_fact.id_note = cc.id_note
  -- Get country information
  JOIN dwh.dimension_countries dc
    ON closed_fact.dimension_id_country = dc.dimension_country_id
  LEFT JOIN public.countries c
    ON dc.country_id = c.country_id
  -- Get note coordinates
  LEFT JOIN public.notes n
    ON closed_fact.id_note = n.note_id
  -- Get opened date from dimension_days
  LEFT JOIN dwh.dimension_days opened_date
    ON closed_fact.opened_dimension_id_date = opened_date.dimension_day_id
  -- Get user who opened the note
  LEFT JOIN dwh.dimension_users du_opened
    ON closed_fact.opened_dimension_id_user = du_opened.dimension_user_id
  LEFT JOIN public.users u_opened
    ON du_opened.user_id = u_opened.user_id
  -- Get user who closed the note
  LEFT JOIN dwh.dimension_users du_closed
    ON closed_fact.closed_dimension_id_user = du_closed.dimension_user_id
  LEFT JOIN public.users u_closed
    ON du_closed.user_id = u_closed.user_id
WHERE closed_fact.action_comment = 'closed'
  -- Country filter already applied in CTE
  -- Only get the most recent close for each note (already filtered in CTE)
  AND closed_fact.fact_id = (
    SELECT MAX(fact_id)
    FROM dwh.facts
    WHERE id_note = closed_fact.id_note
      AND action_comment = 'closed'
  )
ORDER BY
  COALESCE(c.country_name, 'Unknown'),
  closed_fact.action_at DESC;


-- ============================================================================
-- Consolidation: Dates Metrics (dates_most_open, dates_most_closed)
-- ============================================================================
-- This function consolidates 2 separate queries that scan facts table
-- to get top dates for opening and closing notes.
--
-- Original queries:
--   - dates_most_open: Groups by opened_dimension_id_date
--   - dates_most_closed: Groups by closed_dimension_id_date
--
-- Consolidated approach: Single scan with conditional aggregation
-- ============================================================================

CREATE OR REPLACE FUNCTION dwh.get_country_dates_metrics_consolidated(
  p_dimension_country_id INTEGER
) RETURNS TABLE (
  dates_most_open JSON,
  dates_most_closed JSON
) AS $$
BEGIN
  RETURN QUERY
  WITH country_facts AS (
    SELECT
      f.opened_dimension_id_date,
      f.closed_dimension_id_date,
      d_opened.date_id AS opened_date,
      d_closed.date_id AS closed_date
    FROM dwh.facts f
    LEFT JOIN dwh.dimension_days d_opened ON f.opened_dimension_id_date = d_opened.dimension_day_id
    LEFT JOIN dwh.dimension_days d_closed ON f.closed_dimension_id_date = d_closed.dimension_day_id
    WHERE f.dimension_id_country = p_dimension_country_id
  ),
  opened_dates AS (
    SELECT
      opened_date AS date,
      COUNT(*) AS quantity
    FROM country_facts
    WHERE opened_date IS NOT NULL
    GROUP BY opened_date
    ORDER BY quantity DESC
    LIMIT 50
  ),
  closed_dates AS (
    SELECT
      closed_date AS date,
      COUNT(*) AS quantity
    FROM country_facts
    WHERE closed_date IS NOT NULL
    GROUP BY closed_date
    ORDER BY quantity DESC
    LIMIT 50
  ),
  aggregated_metrics AS (
    SELECT
      (SELECT JSON_AGG(JSON_BUILD_OBJECT('date', date, 'quantity', quantity))
       FROM opened_dates) AS dates_most_open,
      (SELECT JSON_AGG(JSON_BUILD_OBJECT('date', date, 'quantity', quantity))
       FROM closed_dates) AS dates_most_closed
  )
  SELECT
    aggregated_metrics.dates_most_open,
    aggregated_metrics.dates_most_closed
  FROM aggregated_metrics;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION dwh.get_country_dates_metrics_consolidated(INTEGER) IS
'Consolidates dates_most_open and dates_most_closed metrics into a single query. Returns top 50 dates for opening and closing notes.';

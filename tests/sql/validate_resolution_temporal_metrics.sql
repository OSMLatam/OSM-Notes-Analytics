-- Validate resolution_by_year and resolution_by_month columns are populated
-- and JSON structure contains expected keys.

-- Countries: sample 5 records
SELECT dimension_country_id,
       (resolution_by_year IS NOT NULL) AS has_year,
       (resolution_by_month IS NOT NULL) AS has_month
FROM dwh.datamartCountries
ORDER BY dimension_country_id
LIMIT 5;

-- Users: sample 5 records
SELECT dimension_user_id,
       (resolution_by_year IS NOT NULL) AS has_year,
       (resolution_by_month IS NOT NULL) AS has_month
FROM dwh.datamartUsers
ORDER BY dimension_user_id
LIMIT 5;

-- Inspect one JSON entry example (replace :country_id)
-- SELECT jsonb_pretty(resolution_by_year::jsonb)
-- FROM dwh.datamartCountries WHERE dimension_country_id = :country_id;




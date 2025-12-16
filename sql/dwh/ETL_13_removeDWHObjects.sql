-- Drop data warehouse objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-14

DROP TRIGGER IF EXISTS update_days_to_resolution ON dwh.facts;

DROP FUNCTION IF EXISTS dwh.update_days_to_resolution;

DROP FUNCTION IF EXISTS dwh.get_country_region;

DROP FUNCTION IF EXISTS dwh.get_hour_of_week_id;

DROP FUNCTION IF EXISTS dwh.get_date_id;

DROP FUNCTION IF EXISTS dwh.get_application_version_id;

DROP FUNCTION IF EXISTS dwh.get_timezone_id_by_lonlat;

DROP FUNCTION IF EXISTS dwh.get_local_date_id;

DROP FUNCTION IF EXISTS dwh.get_local_hour_of_week_id;

DROP FUNCTION IF EXISTS dwh.get_season_id;

DROP TABLE IF EXISTS dwh.properties;

DROP TABLE IF EXISTS dwh.facts CASCADE;

DROP TABLE IF EXISTS dwh.fact_hashtags CASCADE;

DROP TABLE IF EXISTS dwh.dimension_hours_of_week;

DROP TABLE IF EXISTS dwh.dimension_time_of_week CASCADE;

DROP TABLE IF EXISTS dwh.dimension_days CASCADE;

DROP TABLE IF EXISTS dwh.dimension_countries CASCADE;

DROP TABLE IF EXISTS dwh.dimension_regions CASCADE;

DROP TABLE IF EXISTS dwh.dimension_continents CASCADE;

DROP TABLE IF EXISTS dwh.dimension_users CASCADE;

DROP TABLE IF EXISTS dwh.dimension_applications CASCADE;

DROP TABLE IF EXISTS dwh.dimension_application_versions CASCADE;

DROP TABLE IF EXISTS dwh.dimension_hashtags CASCADE;

DROP TABLE IF EXISTS dwh.dimension_timezones CASCADE;

DROP TABLE IF EXISTS dwh.dimension_seasons CASCADE;

DROP TABLE IF EXISTS dwh.dimension_automation_level CASCADE;

DROP TABLE IF EXISTS dwh.dimension_experience_levels CASCADE;

DROP TABLE IF EXISTS dwh.iso_country_codes;

DROP SCHEMA IF EXISTS dwh CASCADE;


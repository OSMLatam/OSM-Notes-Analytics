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

DROP TABLE IF EXISTS dwh.facts;

DROP TABLE IF EXISTS dwh.fact_hashtags;

DROP TABLE IF EXISTS dwh.dimension_hours_of_week;

DROP TABLE IF EXISTS dwh.dimension_time_of_week;

DROP TABLE IF EXISTS dwh.dimension_days;

DROP TABLE IF EXISTS dwh.dimension_countries;

DROP TABLE IF EXISTS dwh.dimension_regions;

DROP TABLE IF EXISTS dwh.dimension_continents;

DROP TABLE IF EXISTS dwh.dimension_users;

DROP TABLE IF EXISTS dwh.dimension_applications;

DROP TABLE IF EXISTS dwh.dimension_application_versions;

DROP TABLE IF EXISTS dwh.dimension_hashtags;

DROP TABLE IF EXISTS dwh.dimension_timezones;

DROP TABLE IF EXISTS dwh.dimension_seasons;

DROP TABLE IF EXISTS dwh.iso_country_codes;

DROP SCHEMA IF EXISTS dwh;


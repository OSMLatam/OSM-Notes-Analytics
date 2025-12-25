-- Drop data warehouse objects.
-- This script drops ALL objects in the dwh schema: functions, procedures,
-- triggers, views, tables, and the schema itself.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-24

-- Drop all triggers first (they depend on tables)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT trigger_name, event_object_table, event_object_schema
            FROM information_schema.triggers
            WHERE trigger_schema = 'dwh') LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I CASCADE',
                   r.trigger_name, r.event_object_schema, r.event_object_table);
  END LOOP;
END $$;

-- Drop all views (they may depend on tables/functions)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT table_name
            FROM information_schema.views
            WHERE table_schema = 'dwh') LOOP
    EXECUTE format('DROP VIEW IF EXISTS dwh.%I CASCADE', r.table_name);
  END LOOP;
END $$;

-- Drop all stored procedures
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT proname, oidvectortypes(proargtypes) as argtypes
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'dwh'
            AND p.prokind = 'p') LOOP
    EXECUTE format('DROP PROCEDURE IF EXISTS dwh.%I(%s) CASCADE', r.proname, r.argtypes);
  END LOOP;
END $$;

-- Drop all functions
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT proname, oidvectortypes(proargtypes) as argtypes
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'dwh'
            AND p.prokind = 'f') LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS dwh.%I(%s) CASCADE', r.proname, r.argtypes);
  END LOOP;
END $$;

-- Drop specific known functions (in case the dynamic drop missed any)
DROP FUNCTION IF EXISTS dwh.update_days_to_resolution CASCADE;
DROP FUNCTION IF EXISTS dwh.get_country_region CASCADE;
DROP FUNCTION IF EXISTS dwh.get_hour_of_week_id CASCADE;
DROP FUNCTION IF EXISTS dwh.get_date_id CASCADE;
DROP FUNCTION IF EXISTS dwh.get_application_version_id CASCADE;
DROP FUNCTION IF EXISTS dwh.get_timezone_id_by_lonlat CASCADE;
DROP FUNCTION IF EXISTS dwh.get_local_date_id CASCADE;
DROP FUNCTION IF EXISTS dwh.get_local_hour_of_week_id CASCADE;
DROP FUNCTION IF EXISTS dwh.get_season_id CASCADE;

-- Drop all tables (CASCADE will drop dependent objects)
DROP TABLE IF EXISTS dwh.properties CASCADE;
DROP TABLE IF EXISTS dwh.facts CASCADE;
DROP TABLE IF EXISTS dwh.fact_hashtags CASCADE;
DROP TABLE IF EXISTS dwh.dimension_hours_of_week CASCADE;
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
DROP TABLE IF EXISTS dwh.iso_country_codes CASCADE;
DROP TABLE IF EXISTS dwh.datamart_performance_log CASCADE;

-- Drop the entire schema (this will remove anything that remains)
DROP SCHEMA IF EXISTS dwh CASCADE;


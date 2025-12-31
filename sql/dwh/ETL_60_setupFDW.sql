-- Setup Foreign Data Wrappers for incremental ETL processing.
-- This script creates foreign tables pointing to the Ingestion database.
-- These foreign tables are only used for incremental processing, not for initial load.
--
-- For initial load, tables are copied locally (see copyBaseTables.sh).
-- For incremental processing, foreign tables provide access to latest data.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-13

SELECT /* Notes-ETL-FDW */ clock_timestamp() AS Processing,
 'Setting up Foreign Data Wrappers for incremental processing' AS Task;

-- Create extension if not exists
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Drop existing server and user mapping if they exist (for idempotency)
DROP SERVER IF EXISTS ingestion_server CASCADE;

-- Create server (pointing to Ingestion DB)
-- Note: Configuration should be set via environment variables or properties
-- Default values assume same machine, adjust as needed
CREATE SERVER ingestion_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (
  host '${FDW_INGESTION_HOST}',
  dbname '${FDW_INGESTION_DBNAME}',
  port '${FDW_INGESTION_PORT}',
  fetch_size '10000',
  use_remote_estimate 'false'
);

-- Create user mapping
-- Note: Password should be set via environment variable or .pgpass file
-- If password is empty, PostgreSQL will use .pgpass or peer authentication
-- Use FDW_INGESTION_PASSWORD_VALUE to avoid readonly variable issues
DO $$
BEGIN
  -- Drop existing user mapping if it exists
  DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER ingestion_server;

  -- Create user mapping with or without password
  IF '${FDW_INGESTION_PASSWORD_VALUE}' = '' THEN
    -- No password provided - PostgreSQL will use .pgpass or peer authentication
    EXECUTE format('CREATE USER MAPPING FOR CURRENT_USER SERVER ingestion_server OPTIONS (user %L)', '${FDW_INGESTION_USER}');
  ELSE
    -- Password provided - include it in the user mapping
    EXECUTE format('CREATE USER MAPPING FOR CURRENT_USER SERVER ingestion_server OPTIONS (user %L, password %L)', '${FDW_INGESTION_USER}', '${FDW_INGESTION_PASSWORD_VALUE}');
  END IF;
END $$;

-- Drop existing foreign tables if they exist (for idempotency)
-- Use DO block to handle errors gracefully if tables are not foreign tables
DO $$
BEGIN
 -- Drop foreign tables only if they exist as foreign tables
 IF EXISTS (SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'note_comments') THEN
  DROP FOREIGN TABLE IF EXISTS public.note_comments CASCADE;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'notes') THEN
  DROP FOREIGN TABLE IF EXISTS public.notes CASCADE;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'note_comments_text') THEN
  DROP FOREIGN TABLE IF EXISTS public.note_comments_text CASCADE;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'users') THEN
  DROP FOREIGN TABLE IF EXISTS public.users CASCADE;
 END IF;
 IF EXISTS (SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'countries') THEN
  DROP FOREIGN TABLE IF EXISTS public.countries CASCADE;
 END IF;
END $$;

-- Create foreign table: note_comments
-- This is the most important table for ETL processing
-- Note: event is note_event_enum in source, but FDW maps it as TEXT for compatibility
CREATE FOREIGN TABLE public.note_comments (
  id INTEGER,
  note_id INTEGER,
  sequence_action INTEGER,
  event TEXT,
  processing_time TIMESTAMP WITHOUT TIME ZONE,
  created_at TIMESTAMP WITHOUT TIME ZONE,
  id_user INTEGER
) SERVER ingestion_server
OPTIONS (schema_name 'public', table_name 'note_comments');

COMMENT ON FOREIGN TABLE public.note_comments IS
  'Foreign table pointing to note_comments in Ingestion DB. Used for incremental ETL processing.';

-- Create foreign table: notes
CREATE FOREIGN TABLE public.notes (
  note_id INTEGER,
  latitude NUMERIC,
  longitude NUMERIC,
  created_at TIMESTAMP WITHOUT TIME ZONE,
  status TEXT,
  closed_at TIMESTAMP WITHOUT TIME ZONE,
  id_country INTEGER,
  insert_time TIMESTAMP WITHOUT TIME ZONE,
  update_time TIMESTAMP WITHOUT TIME ZONE
) SERVER ingestion_server
OPTIONS (schema_name 'public', table_name 'notes');

COMMENT ON FOREIGN TABLE public.notes IS
  'Foreign table pointing to notes in Ingestion DB. Used for incremental ETL processing.';

-- Create foreign table: note_comments_text
CREATE FOREIGN TABLE public.note_comments_text (
  id INTEGER,
  note_id INTEGER,
  sequence_action INTEGER,
  processing_time TIMESTAMP WITHOUT TIME ZONE,
  body TEXT
) SERVER ingestion_server
OPTIONS (schema_name 'public', table_name 'note_comments_text');

COMMENT ON FOREIGN TABLE public.note_comments_text IS
  'Foreign table pointing to note_comments_text in Ingestion DB. Used for incremental ETL processing.';

-- Create foreign table: users
CREATE FOREIGN TABLE public.users (
  user_id INTEGER,
  username VARCHAR(256)
) SERVER ingestion_server
OPTIONS (schema_name 'public', table_name 'users');

COMMENT ON FOREIGN TABLE public.users IS
  'Foreign table pointing to users in Ingestion DB. Used for incremental ETL processing.';

-- Create foreign table: countries
CREATE FOREIGN TABLE public.countries (
  country_id INTEGER,
  country_name VARCHAR(100),
  country_name_es VARCHAR(100),
  country_name_en VARCHAR(100)
) SERVER ingestion_server
OPTIONS (schema_name 'public', table_name 'countries');

COMMENT ON FOREIGN TABLE public.countries IS
  'Foreign table pointing to countries in Ingestion DB. Used for incremental ETL processing.';

-- Analyze foreign tables for better query planning
-- This helps PostgreSQL optimizer make better decisions
SELECT /* Notes-ETL-FDW */ clock_timestamp() AS Processing,
 'Analyzing foreign tables for query optimization' AS Task;

ANALYZE public.note_comments;
ANALYZE public.notes;
ANALYZE public.note_comments_text;
ANALYZE public.users;
ANALYZE public.countries;

SELECT /* Notes-ETL-FDW */ clock_timestamp() AS Processing,
 'Foreign Data Wrappers setup completed' AS Task;

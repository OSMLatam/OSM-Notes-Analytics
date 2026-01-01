-- Setup Foreign Data Wrappers for incremental ETL processing.
-- This script creates foreign tables pointing to the Ingestion database.
-- These foreign tables are only used for incremental processing, not for initial load.
--
-- For initial load, tables are copied locally (see copyBaseTables.sh).
-- For incremental processing, foreign tables provide access to latest data.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-31

SELECT /* Notes-ETL-FDW */ clock_timestamp() AS Processing,
 'Setting up Foreign Data Wrappers for incremental processing' AS Task;

-- Create extension if not exists
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Setup or update foreign server (only recreate if necessary)
-- Check if server exists and has correct configuration
DO $$
DECLARE
  server_exists BOOLEAN;
  needs_recreate BOOLEAN := FALSE;
  current_host TEXT;
  current_dbname TEXT;
  current_port TEXT;
  current_use_remote_estimate TEXT;
  expected_host TEXT := '${FDW_INGESTION_HOST}';
  expected_dbname TEXT := '${FDW_INGESTION_DBNAME}';
  expected_port TEXT := '${FDW_INGESTION_PORT}';
  expected_use_remote_estimate TEXT := 'false';
BEGIN
  -- Check if server exists
  SELECT EXISTS (
    SELECT 1 FROM pg_foreign_server WHERE srvname = 'ingestion_server'
  ) INTO server_exists;

  IF server_exists THEN
    -- Get current server options
    SELECT
      (SELECT option_value FROM pg_options_to_table(s.srvoptions) WHERE option_name = 'host'),
      (SELECT option_value FROM pg_options_to_table(s.srvoptions) WHERE option_name = 'dbname'),
      (SELECT option_value FROM pg_options_to_table(s.srvoptions) WHERE option_name = 'port'),
      (SELECT option_value FROM pg_options_to_table(s.srvoptions) WHERE option_name = 'use_remote_estimate')
    INTO current_host, current_dbname, current_port, current_use_remote_estimate
    FROM pg_foreign_server s
    WHERE srvname = 'ingestion_server';

    -- Check if configuration matches expected values
    -- Only check critical options that affect functionality
    IF current_host IS DISTINCT FROM expected_host OR
       current_dbname IS DISTINCT FROM expected_dbname OR
       current_port IS DISTINCT FROM expected_port OR
       current_use_remote_estimate IS DISTINCT FROM expected_use_remote_estimate THEN
      needs_recreate := TRUE;
      RAISE NOTICE 'Server configuration mismatch. Recreating server.';
    ELSE
      RAISE NOTICE 'Server exists with correct configuration. Skipping recreation.';
    END IF;
  ELSE
    needs_recreate := TRUE;
    RAISE NOTICE 'Server does not exist. Creating server.';
  END IF;

  -- Recreate server only if necessary
  IF needs_recreate THEN
    -- Drop existing server if it exists (will cascade to user mappings and foreign tables)
    DROP SERVER IF EXISTS ingestion_server CASCADE;

    -- Create server with correct configuration
    EXECUTE format('CREATE SERVER ingestion_server FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host %L, dbname %L, port %L, fetch_size ''10000'', use_remote_estimate %L)',
      expected_host, expected_dbname, expected_port, expected_use_remote_estimate);
  ELSE
    -- Server exists and is correct, but ensure use_remote_estimate is set correctly
    -- Use ALTER SERVER to update if needed (more efficient than recreating)
    IF current_use_remote_estimate IS DISTINCT FROM expected_use_remote_estimate THEN
      EXECUTE format('ALTER SERVER ingestion_server OPTIONS (SET use_remote_estimate %L)', expected_use_remote_estimate);
      RAISE NOTICE 'Updated use_remote_estimate option on existing server.';
    END IF;
  END IF;
END $$;

-- Create or update user mapping (only recreate if necessary)
-- Note: Password should be set via environment variable or .pgpass file
-- If password is empty, PostgreSQL will use .pgpass or peer authentication
-- Use FDW_INGESTION_PASSWORD_VALUE to avoid readonly variable issues
DO $$
DECLARE
  mapping_exists BOOLEAN;
  needs_recreate BOOLEAN := FALSE;
  current_user_option TEXT;
  current_password_option TEXT;
  expected_user TEXT := '${FDW_INGESTION_USER}';
  expected_password TEXT := '${FDW_INGESTION_PASSWORD_VALUE}';
BEGIN
  -- Check if user mapping exists for current user
  SELECT EXISTS (
    SELECT 1 FROM pg_user_mappings
    WHERE srvname = 'ingestion_server' AND usename = CURRENT_USER
  ) INTO mapping_exists;

  IF mapping_exists THEN
    -- Get current mapping options
    -- umoptions is text[] format: {'key=value', 'key2=value2'}
    SELECT
      MAX(CASE WHEN opt LIKE 'user=%' THEN substring(opt FROM '^user=(.*)$') END),
      MAX(CASE WHEN opt LIKE 'password=%' THEN substring(opt FROM '^password=(.*)$') END)
    INTO current_user_option, current_password_option
    FROM pg_user_mappings, unnest(umoptions) AS opt
    WHERE srvname = 'ingestion_server' AND usename = CURRENT_USER;

    -- Check if configuration matches expected values
    IF current_user_option IS DISTINCT FROM expected_user OR
       (expected_password = '' AND current_password_option IS NOT NULL) OR
       (expected_password != '' AND current_password_option IS DISTINCT FROM expected_password) THEN
      needs_recreate := TRUE;
      RAISE NOTICE 'User mapping configuration mismatch. Recreating user mapping.';
    ELSE
      RAISE NOTICE 'User mapping exists with correct configuration. Skipping recreation.';
    END IF;
  ELSE
    needs_recreate := TRUE;
    RAISE NOTICE 'User mapping does not exist. Creating user mapping.';
  END IF;

  -- Recreate user mapping only if necessary
  IF needs_recreate THEN
    -- Drop existing user mapping if it exists
    DROP USER MAPPING IF EXISTS FOR CURRENT_USER SERVER ingestion_server;

    -- Create user mapping with or without password
    IF expected_password = '' THEN
      -- No password provided - PostgreSQL will use .pgpass or peer authentication
      EXECUTE format('CREATE USER MAPPING FOR CURRENT_USER SERVER ingestion_server OPTIONS (user %L)', expected_user);
    ELSE
      -- Password provided - include it in the user mapping
      EXECUTE format('CREATE USER MAPPING FOR CURRENT_USER SERVER ingestion_server OPTIONS (user %L, password %L)', expected_user, expected_password);
    END IF;
  END IF;
END $$;

-- Create or update foreign tables (only recreate if server was recreated or tables don't exist)
-- If server was recreated, tables were dropped by CASCADE, so we need to recreate them
-- If server exists, check if tables exist and only create if missing
DO $$
DECLARE
  server_was_recreated BOOLEAN := FALSE;
  table_exists BOOLEAN;
  current_event_type TEXT;
BEGIN
  -- Check if foreign tables exist (if server was recreated, they won't exist)
  -- We'll recreate them only if they don't exist
  -- Note: If server was recreated, CASCADE already dropped the tables, so we need to recreate them

  -- Check note_comments
  SELECT EXISTS (
    SELECT 1 FROM information_schema.foreign_tables
    WHERE foreign_table_schema = 'public' AND foreign_table_name = 'note_comments'
  ) INTO table_exists;

  -- Check if event column type needs to be updated (from TEXT to note_event_enum)
  IF table_exists THEN
    SELECT udt_name INTO current_event_type
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'note_comments' AND column_name = 'event';
    
    -- If event column is TEXT instead of note_event_enum, recreate the foreign table
    IF current_event_type = 'text' THEN
      RAISE NOTICE 'Foreign table public.note_comments exists but event column is TEXT. Recreating with note_event_enum type.';
      EXECUTE 'DROP FOREIGN TABLE IF EXISTS public.note_comments CASCADE';
      table_exists := FALSE;
    ELSE
      RAISE NOTICE 'Foreign table public.note_comments already exists with correct type. Skipping recreation.';
    END IF;
  END IF;

  IF NOT table_exists THEN
    EXECUTE 'CREATE FOREIGN TABLE public.note_comments (
      id INTEGER,
      note_id INTEGER,
      sequence_action INTEGER,
      event note_event_enum,
      processing_time TIMESTAMP WITHOUT TIME ZONE,
      created_at TIMESTAMP WITHOUT TIME ZONE,
      id_user INTEGER
    ) SERVER ingestion_server OPTIONS (schema_name ''public'', table_name ''note_comments'')';
    EXECUTE 'COMMENT ON FOREIGN TABLE public.note_comments IS ''Foreign table pointing to note_comments in Ingestion DB. Used for incremental ETL processing.''';
    RAISE NOTICE 'Created foreign table: public.note_comments';
  END IF;

  -- Check notes
  SELECT EXISTS (
    SELECT 1 FROM information_schema.foreign_tables
    WHERE foreign_table_schema = 'public' AND foreign_table_name = 'notes'
  ) INTO table_exists;

  IF NOT table_exists THEN
    EXECUTE 'CREATE FOREIGN TABLE public.notes (
      note_id INTEGER,
      latitude NUMERIC,
      longitude NUMERIC,
      created_at TIMESTAMP WITHOUT TIME ZONE,
      status TEXT,
      closed_at TIMESTAMP WITHOUT TIME ZONE,
      id_country INTEGER,
      insert_time TIMESTAMP WITHOUT TIME ZONE,
      update_time TIMESTAMP WITHOUT TIME ZONE
    ) SERVER ingestion_server OPTIONS (schema_name ''public'', table_name ''notes'')';
    EXECUTE 'COMMENT ON FOREIGN TABLE public.notes IS ''Foreign table pointing to notes in Ingestion DB. Used for incremental ETL processing.''';
    RAISE NOTICE 'Created foreign table: public.notes';
  ELSE
    RAISE NOTICE 'Foreign table public.notes already exists. Skipping creation.';
  END IF;

  -- Check note_comments_text
  SELECT EXISTS (
    SELECT 1 FROM information_schema.foreign_tables
    WHERE foreign_table_schema = 'public' AND foreign_table_name = 'note_comments_text'
  ) INTO table_exists;

  IF NOT table_exists THEN
    EXECUTE 'CREATE FOREIGN TABLE public.note_comments_text (
      id INTEGER,
      note_id INTEGER,
      sequence_action INTEGER,
      processing_time TIMESTAMP WITHOUT TIME ZONE,
      body TEXT
    ) SERVER ingestion_server OPTIONS (schema_name ''public'', table_name ''note_comments_text'')';
    EXECUTE 'COMMENT ON FOREIGN TABLE public.note_comments_text IS ''Foreign table pointing to note_comments_text in Ingestion DB. Used for incremental ETL processing.''';
    RAISE NOTICE 'Created foreign table: public.note_comments_text';
  ELSE
    RAISE NOTICE 'Foreign table public.note_comments_text already exists. Skipping creation.';
  END IF;

  -- Check users
  SELECT EXISTS (
    SELECT 1 FROM information_schema.foreign_tables
    WHERE foreign_table_schema = 'public' AND foreign_table_name = 'users'
  ) INTO table_exists;

  IF NOT table_exists THEN
    EXECUTE 'CREATE FOREIGN TABLE public.users (
      user_id INTEGER,
      username VARCHAR(256)
    ) SERVER ingestion_server OPTIONS (schema_name ''public'', table_name ''users'')';
    EXECUTE 'COMMENT ON FOREIGN TABLE public.users IS ''Foreign table pointing to users in Ingestion DB. Used for incremental ETL processing.''';
    RAISE NOTICE 'Created foreign table: public.users';
  ELSE
    RAISE NOTICE 'Foreign table public.users already exists. Skipping creation.';
  END IF;

  -- Check countries
  SELECT EXISTS (
    SELECT 1 FROM information_schema.foreign_tables
    WHERE foreign_table_schema = 'public' AND foreign_table_name = 'countries'
  ) INTO table_exists;

  IF NOT table_exists THEN
    EXECUTE 'CREATE FOREIGN TABLE public.countries (
      country_id INTEGER,
      country_name VARCHAR(100),
      country_name_es VARCHAR(100),
      country_name_en VARCHAR(100)
    ) SERVER ingestion_server OPTIONS (schema_name ''public'', table_name ''countries'')';
    EXECUTE 'COMMENT ON FOREIGN TABLE public.countries IS ''Foreign table pointing to countries in Ingestion DB. Used for incremental ETL processing.''';
    RAISE NOTICE 'Created foreign table: public.countries';
  ELSE
    RAISE NOTICE 'Foreign table public.countries already exists. Skipping creation.';
  END IF;
END $$;

-- Foreign tables are now created conditionally in the DO block above
-- This avoids unnecessary DROP/CREATE operations when tables already exist

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

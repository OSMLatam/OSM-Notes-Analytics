-- Setup Foreign Data Wrappers for incremental ETL processing.
-- This script creates foreign tables pointing to the Ingestion database.
-- These foreign tables are only used for incremental processing, not for initial load.
--
-- For initial load, tables are copied locally (see copyBaseTables.sh).
-- For incremental processing, foreign tables provide access to latest data.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-27

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
  host '${FDW_INGESTION_HOST:-localhost}',
  dbname '${FDW_INGESTION_DBNAME:-osm_notes}',
  port '${FDW_INGESTION_PORT:-5432}',
  fetch_size '10000',
  use_remote_estimate 'true'
);

-- Create user mapping
-- Note: Password should be set via environment variable or .pgpass file
CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
SERVER ingestion_server
OPTIONS (
  user '${FDW_INGESTION_USER:-analytics_readonly}',
  password '${FDW_INGESTION_PASSWORD:-}'
);

-- Drop existing foreign tables if they exist (for idempotency)
DROP FOREIGN TABLE IF EXISTS public.note_comments CASCADE;
DROP FOREIGN TABLE IF EXISTS public.notes CASCADE;
DROP FOREIGN TABLE IF EXISTS public.note_comments_text CASCADE;
DROP FOREIGN TABLE IF EXISTS public.users CASCADE;
DROP FOREIGN TABLE IF EXISTS public.countries CASCADE;

-- Create foreign table: note_comments
-- This is the most important table for ETL processing
CREATE FOREIGN TABLE public.note_comments (
  note_id BIGINT,
  sequence_action INTEGER,
  event TEXT,
  id_user BIGINT,
  created_at TIMESTAMP WITH TIME ZONE
) SERVER ingestion_server
OPTIONS (schema_name 'public', table_name 'note_comments');

COMMENT ON FOREIGN TABLE public.note_comments IS
  'Foreign table pointing to note_comments in Ingestion DB. Used for incremental ETL processing.';

-- Create foreign table: notes
CREATE FOREIGN TABLE public.notes (
  note_id BIGINT,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  created_at TIMESTAMP WITH TIME ZONE,
  id_country INTEGER,
  id_user BIGINT
) SERVER ingestion_server
OPTIONS (schema_name 'public', table_name 'notes');

COMMENT ON FOREIGN TABLE public.notes IS
  'Foreign table pointing to notes in Ingestion DB. Used for incremental ETL processing.';

-- Create foreign table: note_comments_text
CREATE FOREIGN TABLE public.note_comments_text (
  note_id BIGINT,
  sequence_action INTEGER,
  body TEXT
) SERVER ingestion_server
OPTIONS (schema_name 'public', table_name 'note_comments_text');

COMMENT ON FOREIGN TABLE public.note_comments_text IS
  'Foreign table pointing to note_comments_text in Ingestion DB. Used for incremental ETL processing.';

-- Create foreign table: users
CREATE FOREIGN TABLE public.users (
  user_id BIGINT,
  username TEXT
) SERVER ingestion_server
OPTIONS (schema_name 'public', table_name 'users');

COMMENT ON FOREIGN TABLE public.users IS
  'Foreign table pointing to users in Ingestion DB. Used for incremental ETL processing.';

-- Create foreign table: countries
CREATE FOREIGN TABLE public.countries (
  country_id INTEGER,
  country_name TEXT,
  country_name_es TEXT,
  country_name_en TEXT
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

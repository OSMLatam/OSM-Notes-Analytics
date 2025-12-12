#!/usr/bin/env bats

# Tests for hybrid strategy: copy base tables for initial load, FDW for incremental
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-27

load "../../test_helper.bash"

# Test configuration
TEST_INGESTION_DB="osm_notes_test_ingestion"
TEST_ANALYTICS_DB="osm_notes_test_analytics"

setup() {
 # Setup test databases
 create_test_ingestion_db
 create_test_analytics_db
 populate_test_ingestion_data
}

teardown() {
 # Cleanup test databases
 drop_test_db "${TEST_INGESTION_DB}" || true
 drop_test_db "${TEST_ANALYTICS_DB}" || true
}

# Helper: Create test ingestion database
create_test_ingestion_db() {
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_INGESTION_DB};" 2>/dev/null || true
 psql -d postgres -c "CREATE DATABASE ${TEST_INGESTION_DB};" || skip "Cannot create test ingestion DB"

 # Create base tables in ingestion DB
 psql -d "${TEST_INGESTION_DB}" << 'EOF'
  CREATE TABLE public.notes (
   note_id BIGINT PRIMARY KEY,
   latitude DECIMAL(10, 8),
   longitude DECIMAL(11, 8),
   created_at TIMESTAMP WITH TIME ZONE,
   id_country INTEGER,
   id_user BIGINT
  );

  CREATE TABLE public.note_comments (
   note_id BIGINT,
   sequence_action INTEGER,
   event TEXT,
   id_user BIGINT,
   created_at TIMESTAMP WITH TIME ZONE,
   PRIMARY KEY (note_id, sequence_action)
  );

  CREATE TABLE public.note_comments_text (
   note_id BIGINT,
   sequence_action INTEGER,
   body TEXT,
   PRIMARY KEY (note_id, sequence_action)
  );

  CREATE TABLE public.users (
   user_id BIGINT PRIMARY KEY,
   username TEXT
  );

  CREATE TABLE public.countries (
   country_id INTEGER PRIMARY KEY,
   country_name TEXT,
   country_name_es TEXT,
   country_name_en TEXT
  );
EOF
}

# Helper: Create test analytics database
create_test_analytics_db() {
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_ANALYTICS_DB};" 2>/dev/null || true
 psql -d postgres -c "CREATE DATABASE ${TEST_ANALYTICS_DB};" || skip "Cannot create test analytics DB"

 # Create dwh schema
 psql -d "${TEST_ANALYTICS_DB}" -c "CREATE SCHEMA IF NOT EXISTS dwh;" || true
}

# Helper: Populate test data in ingestion DB
populate_test_ingestion_data() {
 psql -d "${TEST_INGESTION_DB}" << 'EOF'
  -- Insert test countries
  INSERT INTO public.countries (country_id, country_name, country_name_en) VALUES
   (1, 'Colombia', 'Colombia'),
   (2, 'Estados Unidos', 'United States');

  -- Insert test users
  INSERT INTO public.users (user_id, username) VALUES
   (100, 'testuser1'),
   (200, 'testuser2');

  -- Insert test notes
  INSERT INTO public.notes (note_id, latitude, longitude, created_at, id_country, id_user) VALUES
   (1, 4.6097, -74.0817, '2024-01-01 10:00:00+00', 1, 100),
   (2, 40.7128, -74.0060, '2024-01-02 11:00:00+00', 2, 200);

  -- Insert test note_comments
  INSERT INTO public.note_comments (note_id, sequence_action, event, id_user, created_at) VALUES
   (1, 1, 'opened', 100, '2024-01-01 10:00:00+00'),
   (1, 2, 'commented', 200, '2024-01-01 11:00:00+00'),
   (1, 3, 'closed', 100, '2024-01-01 12:00:00+00'),
   (2, 1, 'opened', 200, '2024-01-02 11:00:00+00');

  -- Insert test note_comments_text
  INSERT INTO public.note_comments_text (note_id, sequence_action, body) VALUES
   (1, 1, 'Opening note'),
   (1, 2, 'Comment on note'),
   (1, 3, 'Closing note'),
   (2, 1, 'Opening note 2');
EOF
}

# Test: copyBaseTables.sh copies all tables correctly
@test "copyBaseTables.sh copies all base tables" {
 # Set environment variables for script
 export DBNAME_INGESTION="${TEST_INGESTION_DB}"
 export DBNAME_DWH="${TEST_ANALYTICS_DB}"
 export DB_USER_INGESTION="postgres"
 export DB_USER_DWH="postgres"

 # Run copy script
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/dwh/copyBaseTables.sh"
 [ "${status}" -eq 0 ]

 # Verify all tables were copied
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('notes', 'note_comments', 'note_comments_text', 'users', 'countries');"
 [ "${output}" = "5" ]

 # Verify row counts match
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM public.notes;"
 local analytics_count="${output// /}"
 run psql -d "${TEST_INGESTION_DB}" -t -c "SELECT COUNT(*) FROM public.notes;"
 local ingestion_count="${output// /}"
 [ "${analytics_count}" = "${ingestion_count}" ]
}

# Test: copyBaseTables.sh handles missing tables gracefully
@test "copyBaseTables.sh handles missing source tables" {
 # Set environment variables
 export DBNAME_INGESTION="${TEST_INGESTION_DB}"
 export DBNAME_DWH="${TEST_ANALYTICS_DB}"
 export DB_USER_INGESTION="postgres"
 export DB_USER_DWH="postgres"

 # Drop one table from source
 psql -d "${TEST_INGESTION_DB}" -c "DROP TABLE IF EXISTS public.note_comments_text;"

 # Run copy script (should continue with other tables)
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/dwh/copyBaseTables.sh"
 [ "${status}" -eq 0 ]

 # Verify other tables were still copied
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('notes', 'note_comments', 'users', 'countries');"
 [ "${output}" = "4" ]
}

# Test: dropCopiedBaseTables.sh drops all copied tables
@test "dropCopiedBaseTables.sh drops all copied tables" {
 # First copy tables
 export DBNAME_INGESTION="${TEST_INGESTION_DB}"
 export DBNAME_DWH="${TEST_ANALYTICS_DB}"
 export DB_USER_INGESTION="postgres"
 export DB_USER_DWH="postgres"

 bash "${SCRIPT_BASE_DIRECTORY}/bin/dwh/copyBaseTables.sh"

 # Verify tables exist
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('notes', 'note_comments', 'note_comments_text', 'users', 'countries');"
 [ "${output}" = "5" ]

 # Run drop script
 run bash "${SCRIPT_BASE_DIRECTORY}/bin/dwh/dropCopiedBaseTables.sh"
 [ "${status}" -eq 0 ]

 # Verify all tables were dropped
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('notes', 'note_comments', 'note_comments_text', 'users', 'countries');"
 [ "${output}" = "0" ]
}

# Test: FDW setup creates foreign tables correctly
@test "ETL_60_setupFDW.sql creates foreign tables" {
 # Setup requires ingestion DB to exist
 export FDW_INGESTION_HOST="localhost"
 export FDW_INGESTION_DBNAME="${TEST_INGESTION_DB}"
 export FDW_INGESTION_PORT="5432"
 export FDW_INGESTION_USER="postgres"
 export FDW_INGESTION_PASSWORD=""

 # Run FDW setup
 envsubst < "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_60_setupFDW.sql" | \
  psql -d "${TEST_ANALYTICS_DB}" -v ON_ERROR_STOP=1

 # Verify foreign tables were created
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name IN ('notes', 'note_comments', 'note_comments_text', 'users', 'countries');"
 [ "${output}" = "5" ]

 # Verify foreign server exists
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM pg_foreign_server WHERE srvname = 'ingestion_server';"
 [ "${output}" = "1" ]
}

# Test: Foreign tables can query data from ingestion DB
@test "Foreign tables can query data from ingestion DB" {
 # Setup FDW
 export FDW_INGESTION_HOST="localhost"
 export FDW_INGESTION_DBNAME="${TEST_INGESTION_DB}"
 export FDW_INGESTION_PORT="5432"
 export FDW_INGESTION_USER="postgres"
 export FDW_INGESTION_PASSWORD=""

 envsubst < "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_60_setupFDW.sql" | \
  psql -d "${TEST_ANALYTICS_DB}" -v ON_ERROR_STOP=1

 # Query foreign table
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM public.notes;"
 local foreign_count="${output// /}"

 # Verify count matches source
 run psql -d "${TEST_INGESTION_DB}" -t -c "SELECT COUNT(*) FROM public.notes;"
 local source_count="${output// /}"

 [ "${foreign_count}" = "${source_count}" ]
}

# Test: Initial load uses copied tables (not FDW)
@test "Initial load uses copied local tables" {
 # Copy tables first
 export DBNAME_INGESTION="${TEST_INGESTION_DB}"
 export DBNAME_DWH="${TEST_ANALYTICS_DB}"
 export DB_USER_INGESTION="postgres"
 export DB_USER_DWH="postgres"

 bash "${SCRIPT_BASE_DIRECTORY}/bin/dwh/copyBaseTables.sh"

 # Verify tables are local (not foreign)
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notes' AND table_type = 'BASE TABLE';"
 [ "${output}" = "1" ]

 # Verify no foreign tables exist yet
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public';"
 [ "${output}" = "0" ]
}

# Test: Incremental load uses FDW (not local tables)
@test "Incremental load uses foreign tables" {
 # Setup FDW for incremental
 export FDW_INGESTION_HOST="localhost"
 export FDW_INGESTION_DBNAME="${TEST_INGESTION_DB}"
 export FDW_INGESTION_PORT="5432"
 export FDW_INGESTION_USER="postgres"
 export FDW_INGESTION_PASSWORD=""

 envsubst < "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_60_setupFDW.sql" | \
  psql -d "${TEST_ANALYTICS_DB}" -v ON_ERROR_STOP=1

 # Verify foreign tables exist
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'note_comments';"
 [ "${output}" = "1" ]

 # Verify can query foreign table
 run psql -d "${TEST_ANALYTICS_DB}" -t -c "SELECT COUNT(*) FROM public.note_comments;"
 [ "${status}" -eq 0 ]
 [ -n "${output}" ]
}

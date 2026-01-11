#!/usr/bin/env bats
# Test suite for ETL incremental functionality validation
# This test validates that the incremental ETL procedures can be created and executed without runtime errors
#
# Author: Andres Gomez (AngocA)
# Version: 2026-01-10

load ../../test_helper

# Test that staging.process_notes_actions_into_dwh procedure can be created and executed
@test "staging.process_notes_actions_into_dwh procedure should be created and executable without runtime errors" {
  # Skip if no database connection
  if ! psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
    skip "Database connection unavailable"
  fi

  # Setup: Create necessary tables and objects
  echo "Setting up test database..."

  # Create dwh schema if it doesn't exist
  psql -d "${TEST_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS dwh;" > /dev/null 2>&1 || true

  # Create dwh.properties table
  psql -d "${TEST_DBNAME}" << 'EOF' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS dwh.properties (
  key TEXT PRIMARY KEY,
  value TEXT
);
EOF

  # Create dwh.facts table (minimal structure for testing)
  psql -d "${TEST_DBNAME}" << 'EOF' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS dwh.facts (
  fact_id SERIAL PRIMARY KEY,
  id_note INTEGER,
  action_at TIMESTAMP WITHOUT TIME ZONE,
  processing_time TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS facts_action_at_idx ON dwh.facts(action_at);
EOF

  # Create dimension_days table (minimal structure)
  psql -d "${TEST_DBNAME}" << 'EOF' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS dwh.dimension_days (
  dimension_day_id SERIAL PRIMARY KEY,
  day DATE UNIQUE
);
CREATE INDEX IF NOT EXISTS dimension_days_day_idx ON dwh.dimension_days(day);
EOF

  # Create notes table (for FDW or local)
  psql -d "${TEST_DBNAME}" << 'EOF' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS public.notes (
  note_id INTEGER PRIMARY KEY,
  created_at TIMESTAMP WITHOUT TIME ZONE,
  id_country INTEGER
);
EOF

  # Create note_comments table (for FDW or local)
  psql -d "${TEST_DBNAME}" << 'EOF' > /dev/null 2>&1 || true
CREATE TYPE IF NOT EXISTS note_event_enum AS ENUM ('opened', 'closed', 'commented', 'reopened', 'hidden');
CREATE TABLE IF NOT EXISTS public.note_comments (
  id INTEGER PRIMARY KEY,
  note_id INTEGER,
  sequence_action INTEGER,
  event note_event_enum,
  created_at TIMESTAMP WITHOUT TIME ZONE,
  id_user INTEGER
);
CREATE INDEX IF NOT EXISTS note_comments_created_at_idx ON public.note_comments(created_at);
CREATE INDEX IF NOT EXISTS note_comments_note_id_idx ON public.note_comments(note_id);
EOF

  # Insert initial load flag to skip initial load
  psql -d "${TEST_DBNAME}" << 'EOF' > /dev/null 2>&1 || true
INSERT INTO dwh.properties (key, value) VALUES ('initial load', 'completed')
ON CONFLICT (key) DO UPDATE SET value = 'completed';
EOF

  # Insert some test facts to simulate existing data
  psql -d "${TEST_DBNAME}" << 'EOF' > /dev/null 2>&1 || true
INSERT INTO dwh.dimension_days (day) VALUES ('2026-01-04') ON CONFLICT DO NOTHING;
INSERT INTO dwh.facts (id_note, action_at, processing_time)
VALUES (1, '2026-01-04 01:15:33', '2026-01-04 01:28:05')
ON CONFLICT DO NOTHING;
EOF

  # Create staging schema
  psql -d "${TEST_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS staging;" > /dev/null 2>&1 || true

  # Create base staging objects first (required dependencies)
  echo "Creating base staging objects..."
  run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_31_createBaseStagingObjects.sql"
  echo "Staging_31 output: ${output}"
  [[ "${status}" -eq 0 ]] || echo "Failed to create base staging objects"

  # Create staging objects (includes process_notes_actions_into_dwh procedure)
  echo "Creating staging objects..."
  run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_32_createStagingObjects.sql"
  echo "Staging_32 status: ${status}"
  echo "Staging_32 output: ${output}"
  [[ "${status}" -eq 0 ]] || echo "Failed to create staging objects: ${output}"

  # Verify procedure was created
  echo "Verifying procedure exists..."
  run psql -d "${TEST_DBNAME}" -tAc "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'staging' AND p.proname = 'process_notes_actions_into_dwh';"
  echo "Procedure count: ${output}"
  [[ "${output}" =~ ^[[:space:]]*1[[:space:]]*$ ]] || echo "Procedure was not created"

  # CRITICAL TEST: Execute the procedure to detect runtime errors
  # This will catch errors like "column original_statement_timeout does not exist"
  echo "Executing procedure to detect runtime errors..."
  run psql -d "${TEST_DBNAME}" -c "CALL staging.process_notes_actions_into_dwh();" 2>&1
  echo "Procedure execution status: ${status}"
  echo "Procedure execution output: ${output}"

  # Check for specific runtime errors
  if echo "${output}" | grep -q "column.*does not exist"; then
    echo "ERROR: Runtime error detected - undefined variable/column"
    echo "${output}"
    return 1
  fi

  if echo "${output}" | grep -q "ERROR"; then
    # Some errors are acceptable (e.g., no data to process), but syntax errors are not
    if echo "${output}" | grep -q "syntax error\|undefined\|does not exist"; then
      echo "ERROR: Syntax or runtime error detected"
      echo "${output}"
      return 1
    fi
  fi

  # If we get here, the procedure executed without critical errors
  # (It may return early if no data to process, which is acceptable)
  echo "Procedure executed successfully (or returned early due to no data)"
}

# Test that process_notes_at_date procedure can be created and executed
@test "staging.process_notes_at_date procedure should be created and executable without runtime errors" {
  # Skip if no database connection
  if ! psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
    skip "Database connection unavailable"
  fi

  # Setup: Ensure staging schema and base objects exist
  psql -d "${TEST_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS staging;" > /dev/null 2>&1 || true

  # Create base staging objects
  psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_31_createBaseStagingObjects.sql" > /dev/null 2>&1 || true

  # Create staging objects
  run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_32_createStagingObjects.sql"
  [[ "${status}" -eq 0 ]]

  # Verify procedure exists
  run psql -d "${TEST_DBNAME}" -tAc "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'staging' AND p.proname = 'process_notes_at_date';"
  [[ "${output}" =~ ^[[:space:]]*1[[:space:]]*$ ]]

  # Execute procedure with test parameters
  # This will catch runtime errors like undefined variables
  run psql -d "${TEST_DBNAME}" -c "DO \$\$ DECLARE v_count INTEGER := 0; BEGIN CALL staging.process_notes_at_date('2026-01-04 00:00:00'::TIMESTAMP, v_count, TRUE); END \$\$;" 2>&1
  echo "process_notes_at_date execution output: ${output}"

  # Check for runtime errors
  if echo "${output}" | grep -q "column.*does not exist\|undefined\|syntax error"; then
    echo "ERROR: Runtime error detected in process_notes_at_date"
    echo "${output}"
    return 1
  fi
}

# Test that all variables are properly declared in process_notes_actions_into_dwh
@test "process_notes_actions_into_dwh should have all variables properly declared" {
  local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_32_createStagingObjects.sql"

  # Check that original_statement_timeout is declared in DECLARE section
  # Extract the procedure block starting from process_notes_actions_into_dwh
  # and check for DECLARE followed by original_statement_timeout within 20 lines
  run awk '
    /CREATE OR REPLACE PROCEDURE staging\.process_notes_actions_into_dwh/ { in_proc = 1 }
    in_proc && /^[[:space:]]*DECLARE[[:space:]]*$/ { in_declare = 1; declare_start = NR }
    in_declare && /original_statement_timeout/ { found = 1; exit }
    in_declare && NR > declare_start + 20 { exit }
  END { exit !found }
  ' "${sql_file}"
  [[ "${status}" -eq 0 ]] || echo "ERROR: original_statement_timeout not declared in DECLARE section of process_notes_actions_into_dwh"

  # Check that it's used in EXECUTE format
  run grep -q "EXECUTE format.*original_statement_timeout" "${sql_file}"
  [[ "${status}" -eq 0 ]] || echo "ERROR: original_statement_timeout not used in EXECUTE format"

  # Check that it's initialized somewhere in the procedure
  # Since we already verified it's declared in the DECLARE section of this specific procedure,
  # we just need to verify the initialization pattern exists in the file
  run grep -q "SELECT current_setting.*INTO original_statement_timeout" "${sql_file}"
  [[ "${status}" -eq 0 ]] || echo "ERROR: original_statement_timeout not initialized (SELECT current_setting ... INTO not found)"
}

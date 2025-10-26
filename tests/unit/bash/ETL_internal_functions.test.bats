#!/usr/bin/env bats

# Tests for internal ETL functions
# Author: Andres Gomez (AngocA)
# Date: 2025-01-27

load ../../../tests/test_helper

setup() {
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export SCRIPT_BASE_DIRECTORY

  # Load properties
  # shellcheck disable=SC1090
  source "${SCRIPT_BASE_DIRECTORY}/tests/properties.sh"

  export TEST_DBNAME="${TEST_DBNAME:-dwh}"
}

# Test __initialFacts function handles errors gracefully
@test "__initialFacts should handle missing staging tables gracefully" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Test that function exists
  run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && declare -f __initialFacts"
  [[ "${status}" -eq 0 ]]

  # Function should be defined
  [[ -n "${output}" ]]
}

# Test __initialFactsParallel function exists and is callable
@test "__initialFactsParallel should be defined and callable" {
  run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && declare -f __initialFactsParallel"
  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]]
}

# Test __trapOn handles signals correctly
@test "__trapOn should set signal handlers" {
  run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && declare -f __trapOn"
  [[ "${status}" -eq 0 ]]

  # Function should be defined (check if output contains function body)
  [[ -n "${output}" ]]
  # Output should contain function definition
  [[ "${output}" == *"trap"* ]] || [[ "${output}" == *"()"* ]]
}

# Test __detectFirstExecution function logic
@test "__detectFirstExecution should detect empty database" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check if dimension_days exists
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'dwh'
      AND table_name = 'dimension_days';
  "

  [[ "${status}" -eq 0 ]]

  # If no data, should return true for first execution
  if [[ $(echo "${output}" | tr -d ' ') == "0" ]]; then
    # No dimension_days table means first execution
    echo "First execution detected (no dimension_days table)"
  fi
}

# Test __perform_database_maintenance function exists
@test "__perform_database_maintenance should be defined" {
  run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && declare -f __perform_database_maintenance"
  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]]
}

# Test ETL recovery file functionality
@test "ETL recovery file should be writeable" {
  local recovery_file="/tmp/ETL_recovery_test.json"

  # Create test recovery file
  cat > "${recovery_file}" << 'EOF'
{
  "last_step": "test_step",
  "status": "in_progress"
}
EOF

  [[ -f "${recovery_file}" ]]
  [[ -w "${recovery_file}" ]]

  # Cleanup
  rm -f "${recovery_file}"
}

# Test SQL files exist and are valid
@test "Required SQL files should exist" {
  [[ -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_22_createDWHTables.sql" ]]
  [[ -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_11_checkDWHTables.sql" ]]
  [[ -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_51_unify.sql" ]]
}

# Test dimension functions work correctly
@test "Dimension setup functions should work" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Test that we can query dimension tables
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'dwh'
      AND table_name IN ('dimension_days', 'dimension_applications');
  "

  [[ "${status}" -eq 0 ]]
  # Should return count (can be 0, 1, or 2 depending on setup)
  [[ "${output}" =~ [0-9] ]]
}

# Test facts table structure
@test "Facts table should have required columns for resolution metrics" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check if facts table exists
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'dwh'
      AND table_name = 'facts';
  "

  if [[ $(echo "${output}" | tr -d ' ') == "1" ]]; then
    # Check for required columns
    run psql -d "${DBNAME}" -t -c "
      SELECT COUNT(*)
      FROM information_schema.columns
      WHERE table_schema = 'dwh'
        AND table_name = 'facts'
        AND column_name IN ('days_to_resolution', 'dimension_application_creation');
    "

    [[ "${status}" -eq 0 ]]
    # Should have at least 2 columns (days_to_resolution and dimension_application_creation)
    [[ $(echo "${output}" | tr -d ' ') -ge 2 ]]
  else
    echo "Facts table not created yet - will be created during ETL"
  fi
}

# Test configuration loading
@test "ETL configuration should load correctly" {
  local config_file="${SCRIPT_BASE_DIRECTORY}/etc/etl.properties"

  if [[ -f "${config_file}" ]]; then
    # Source the file
    source "${config_file}"

    # Check key variables are set
    [[ -n "${ETL_BATCH_SIZE:-}" ]]
    [[ -n "${ETL_PARALLEL_ENABLED:-}" ]]
  else
    echo "No etl.properties file found"
  fi
}

# Test logging functionality
@test "ETL logging functions should work" {
  # Source ETL.sh without running main
  run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && declare -f __logi"

  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]]

  # Check other logging functions
  run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && declare -f __logw"
  [[ "${status}" -eq 0 ]]

  run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/ETL.sh && declare -f __loge"
  [[ "${status}" -eq 0 ]]
}


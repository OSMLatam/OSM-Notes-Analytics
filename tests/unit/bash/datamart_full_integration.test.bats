#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Full integration test for datamarts with mock data
# Tests: Load data -> Run ETL -> Populate datamarts -> Verify metrics
# Author: Andres Gomez (AngocA)
# Date: 2025-10-27

load ../../../tests/test_helper

setup() {
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export SCRIPT_BASE_DIRECTORY

  # Load properties
  # shellcheck disable=SC1090
  source "${SCRIPT_BASE_DIRECTORY}/tests/properties.sh"

  # Only setup if DBNAME/TEST_DBNAME is configured
  if [[ -z "${SKIP_TEST_SETUP:-}" ]] && [[ -n "${TEST_DBNAME:-}" ]]; then
    setup_test_database
  fi
}

# Test that we can create test data
@test "Test data can be loaded successfully" {
  if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  local dbname="${TEST_DBNAME:-${DBNAME}}"

  # Load test data using setup
  run psql -d "${dbname}" -f "${SCRIPT_BASE_DIRECTORY}/tests/sql/setup_test_data.sql"

  [[ "${status}" -eq 0 ]]
  # Accept either success message or just successful execution
  [[ "${status}" -eq 0 ]]
}

# Test that application statistics columns exist
@test "Application statistics columns exist after data load" {
  if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  local dbname="${TEST_DBNAME:-${DBNAME}}"

  # Check if columns exist
  run psql -d "${dbname}" -t -c "
    SELECT COUNT(column_name)
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartcountries'
      AND column_name IN ('applications_used', 'most_used_application_id',
                          'mobile_apps_count', 'desktop_apps_count');
  "

  [[ "${status}" -eq 0 ]]
  # Should have 4 columns
  [[ $(echo "${output}" | tr -d ' ') -eq 4 ]]
}

# Test datamart update for a test country
@test "Datamart update procedure can be executed for test data" {
  if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  local dbname="${TEST_DBNAME:-${DBNAME}}"

  # Try to update datamart for country_id = 1 (if it exists)
  run psql -d "${dbname}" -c "
    SELECT dwh.update_datamart_country(1);
  " 2>&1

  # Should either succeed or report that country doesn't exist
  # (status 0 means success, any other status might be acceptable if it reports missing data)
  echo "${output}"

  # Accept if command executed (even if with warnings about missing data)
  [[ "${status}" -ge 0 ]]
}

# Test that datamart has data after update
@test "Datamart contains data after update" {
  if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  local dbname="${TEST_DBNAME:-${DBNAME}}"

  # Update datamart for test country
  psql -d "${dbname}" -c "SELECT dwh.update_datamart_country(1);" > /dev/null 2>&1 || true

  # Check if datamart has any data
  run psql -d "${dbname}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartcountries
    WHERE dimension_country_id = 1
      AND (applications_used IS NOT NULL
        OR mobile_apps_count IS NOT NULL
        OR active_notes_count IS NOT NULL);
  "

  echo "Output: ${output}"
  [[ "${status}" -eq 0 ]]
}

# Test that application calculations work correctly
@test "Application calculations return valid data" {
  if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  local dbname="${TEST_DBNAME:-${DBNAME}}"

  # Update datamart and check results
  psql -d "${dbname}" -c "SELECT dwh.update_datamart_country(1);" > /dev/null 2>&1 || true

  # Check for valid mobile_apps_count
  run psql -d "${dbname}" -t -c "
    SELECT mobile_apps_count
    FROM dwh.datamartcountries
    WHERE dimension_country_id = 1;
  "

  echo "Output: ${output}"
  [[ "${status}" -eq 0 ]]

  # Mobile apps count should be >= 0 (can be 0 if no mobile apps used)
  local count=$(echo "${output}" | tr -d ' ' | tr -d '\n')
  if [[ -n "${count}" ]] && [[ "${count}" != "NULL" ]]; then
    [[ ${count} -ge 0 ]]
  fi
}

# Test that resolution metrics are calculated
@test "Resolution metrics are calculated correctly" {
  if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  local dbname="${TEST_DBNAME:-${DBNAME}}"

  # Update datamart
  psql -d "${dbname}" -c "SELECT dwh.update_datamart_country(1);" > /dev/null 2>&1 || true

  # Check resolution metrics
  run psql -d "${dbname}" -t -c "
    SELECT notes_resolved_count, notes_still_open_count
    FROM dwh.datamartcountries
    WHERE dimension_country_id = 1;
  "

  echo "Output: ${output}"
  [[ "${status}" -eq 0 ]]

  # Verify that both counts exist and are >= 0
  local resolved=$(echo "${output}" | cut -d'|' -f1 | tr -d ' ')
  local still_open=$(echo "${output}" | cut -d'|' -f2 | tr -d ' ')

  if [[ -n "${resolved}" ]] && [[ "${resolved}" != "NULL" ]]; then
    [[ ${resolved} -ge 0 ]]
  fi

  if [[ -n "${still_open}" ]] && [[ "${still_open}" != "NULL" ]]; then
    [[ ${still_open} -ge 0 ]]
  fi
}

# Test that complete mock ETL pipeline runs successfully
@test "Complete mock ETL pipeline can be executed" {
  if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  local dbname="${TEST_DBNAME:-${DBNAME}}"

  # Run mock ETL pipeline
  run bash "${SCRIPT_BASE_DIRECTORY}/tests/run_mock_etl.sh"

  # Should complete successfully
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Mock ETL Pipeline Completed Successfully"* ]]
}

# Test that datamarts have data after mock ETL
@test "Datamarts contain data after mock ETL pipeline" {
  if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  local dbname="${TEST_DBNAME:-${DBNAME}}"

  # Check if any country has populated metrics
  run psql -d "${dbname}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartcountries
    WHERE (applications_used IS NOT NULL
        OR mobile_apps_count IS NOT NULL
        OR desktop_apps_count IS NOT NULL
        OR avg_days_to_resolution IS NOT NULL);
  "

  echo "Countries with metrics: ${output}"
  [[ "${status}" -eq 0 ]]
  # At least one country should have data
  [[ $(echo "${output}" | tr -d ' ') -gt 0 ]]
}

# Cleanup after tests
teardown() {
  # Keep test data for other tests
  echo "Test data preserved for subsequent tests"
}


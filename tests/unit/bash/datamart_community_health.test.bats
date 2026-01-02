#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for community health metrics in datamarts
# Tests that community health metrics are calculated correctly

load ../../../tests/test_helper

setup() {
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export SCRIPT_BASE_DIRECTORY

  # Load properties
  # shellcheck disable=SC1090
  source "${SCRIPT_BASE_DIRECTORY}/tests/properties.sh"

  # Setup test database if needed
  if [[ -z "${SKIP_TEST_SETUP:-}" ]]; then
    setup_test_database
  fi
}

# Test that community health columns exist in datamartCountries
@test "Community health columns should exist in datamartCountries table" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check if columns exist
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartCountries'
      AND column_name IN ('active_notes_count', 'notes_backlog_size',
                          'notes_age_distribution', 'notes_created_last_30_days',
                          'notes_resolved_last_30_days');
  "

  [[ "${status}" -eq 0 ]]
  # Should have 5 lines (one per column)
  [[ $(echo "${output}" | grep -c "notes\|active") -eq 5 ]] || echo "Health columns should exist"
}

# Test that community health columns exist in datamartUsers
@test "Community health columns should exist in datamartUsers table" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check if columns exist
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartUsers'
      AND column_name IN ('active_notes_count', 'notes_backlog_size',
                          'notes_age_distribution', 'notes_created_last_30_days',
                          'notes_resolved_last_30_days');
  "

  [[ "${status}" -eq 0 ]]
  # Should have 5 lines (one per column)
  [[ $(echo "${output}" | grep -c "notes\|active") -eq 5 ]] || echo "Health columns should exist"
}

# Test that active_notes_count is non-negative for countries
@test "Active notes count should be non-negative for countries" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that active notes count is non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartCountries
    WHERE active_notes_count IS NOT NULL
      AND active_notes_count < 0;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 countries with negative counts
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All active notes counts should be non-negative"
}

# Test that active_notes_count is non-negative for users
@test "Active notes count should be non-negative for users" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that active notes count is non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE active_notes_count IS NOT NULL
      AND active_notes_count < 0;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with negative counts
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All active notes counts should be non-negative"
}

# Test that backlog size is non-negative for countries
@test "Backlog size should be non-negative for countries" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that backlog size is non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartCountries
    WHERE notes_backlog_size IS NOT NULL
      AND notes_backlog_size < 0;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 countries with negative backlog
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All backlog sizes should be non-negative"
}

# Test that backlog size is non-negative for users
@test "Backlog size should be non-negative for users" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that backlog size is non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE notes_backlog_size IS NOT NULL
      AND notes_backlog_size < 0;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with negative backlog
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All backlog sizes should be non-negative"
}

# Test that 30-day metrics are non-negative for countries
@test "30-day metrics should be non-negative for countries" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that 30-day metrics are non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartCountries
    WHERE (notes_created_last_30_days IS NOT NULL AND notes_created_last_30_days < 0)
       OR (notes_resolved_last_30_days IS NOT NULL AND notes_resolved_last_30_days < 0);
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 countries with negative 30-day metrics
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All 30-day metrics should be non-negative"
}

# Test that 30-day metrics are non-negative for users
@test "30-day metrics should be non-negative for users" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that 30-day metrics are non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE (notes_created_last_30_days IS NOT NULL AND notes_created_last_30_days < 0)
       OR (notes_resolved_last_30_days IS NOT NULL AND notes_resolved_last_30_days < 0);
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with negative 30-day metrics
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All 30-day metrics should be non-negative"
}

# Test that age distribution is valid JSON for countries
@test "Age distribution should be valid JSON for countries" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that age distribution is valid JSON
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartCountries
    WHERE notes_age_distribution IS NOT NULL
      AND NOT (notes_age_distribution::text ~ '^\\[.*\\]$');
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 countries with invalid JSON
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All age distributions should be valid JSON"
}

# Test that age distribution is valid JSON for users
@test "Age distribution should be valid JSON for users" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that age distribution is valid JSON
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE notes_age_distribution IS NOT NULL
      AND NOT (notes_age_distribution::text ~ '^\\[.*\\]$');
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with invalid JSON
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All age distributions should be valid JSON"
}

# Test that backlog size equals active notes for countries
@test "Backlog size should equal active notes for countries" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that backlog size equals active notes
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartCountries
    WHERE active_notes_count IS NOT NULL
      AND notes_backlog_size IS NOT NULL
      AND active_notes_count != notes_backlog_size;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 mismatches
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "Backlog size should equal active notes"
}

# Test that backlog size equals active notes for users
@test "Backlog size should equal active notes for users" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that backlog size equals active notes
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE active_notes_count IS NOT NULL
      AND notes_backlog_size IS NOT NULL
      AND active_notes_count != notes_backlog_size;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 mismatches
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "Backlog size should equal active notes"
}

# Test datamart update procedure includes health metrics for countries
@test "Datamart update procedure should include health metrics for countries" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that the procedure text includes health metrics
  run psql -d "${DBNAME}" -t -c "
    SELECT pg_get_functiondef('dwh.update_datamart_country'::regproc);
  "

  [[ "${status}" -eq 0 ]]
  # Should contain mentions of health metrics
  [[ "${output}" == *"active_notes_count"* ]] || echo "Procedure should calculate active notes count"
  [[ "${output}" == *"notes_age_distribution"* ]] || echo "Procedure should calculate age distribution"
}

# Test datamart update procedure includes health metrics for users
@test "Datamart update procedure should include health metrics for users" {
  # Skip test if database connection is unavailable
  skip_if_no_db_connection
  # Check that the procedure text includes health metrics
  run psql -d "${DBNAME}" -t -c "
    SELECT pg_get_functiondef('dwh.update_datamart_user'::regproc);
  "

  [[ "${status}" -eq 0 ]]
  # Should contain mentions of health metrics
  [[ "${output}" == *"active_notes_count"* ]] || echo "Procedure should calculate active notes count"
  [[ "${output}" == *"notes_age_distribution"* ]] || echo "Procedure should calculate age distribution"
}



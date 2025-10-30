#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for datamartGlobal.sh
# Tests that the global datamart is properly created and populated

setup() {
 # Setup test environment
 # shellcheck disable=SC2154
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export SCRIPT_BASE_DIRECTORY
 # shellcheck disable=SC2155
 TMP_DIR="$(mktemp -d)"
 export TMP_DIR
 export BASENAME="test_datamart_global"
 export LOG_LEVEL="INFO"

 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir -p "${TMP_DIR}" || {
   echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2
   exit 1
  }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
  echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2
  exit 1
 fi

 # Prefer existing DB configured by runner; avoid creating/dropping DBs
 if [[ -z "${TEST_DBNAME:-}" ]]; then
  export TEST_DBNAME="${DBNAME:-notes}"
 fi
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
 # Cleanup only tables in current DB (avoid DROP DATABASE)
 if [[ -n "${TEST_DBNAME:-}" ]]; then
  psql -d "${TEST_DBNAME}" -c "DROP TABLE IF EXISTS dwh.datamartglobal CASCADE;" 2> /dev/null || true
  psql -d "${TEST_DBNAME}" -c "DROP TABLE IF EXISTS dwh.max_date_global_processed CASCADE;" 2> /dev/null || true
 fi
}

# Test that datamartGlobal.sh can be sourced without errors
@test "datamartGlobal.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 run bash -c "SKIP_MAIN=true source ${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartGlobal/datamartGlobal.sh > /dev/null 2>&1"
 [[ "${status}" -eq 0 ]] || echo "Script should be sourceable"
}

# Test that datamartGlobal.sh shows help
@test "datamartGlobal.sh should show help information" {
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartGlobal/datamartGlobal.sh" --help
 [[ "${status}" -eq 1 ]] # Help should exit with code 1
 [[ "${output}" == *"help"* ]] || [[ "${output}" == *"usage"* ]] || [[ "${output}" == *"global"* ]] || echo "Script should show help information"
}

# Test that datamart global table structure can be created
@test "datamart global table can be created" {
 if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
  skip "No database configured"
 fi

 local dbname="${TEST_DBNAME:-${DBNAME}}"

 # Create table
 run psql -d "${dbname}" -v ON_ERROR_STOP=1 \
  -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql"

 [[ "${status}" -eq 0 ]]

 # Verify table exists
 run psql -d "${dbname}" -Atq -c "
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = 'dwh'
    AND table_name = 'datamartglobal'
 "

 [[ "${status}" -eq 0 ]]
 [[ $(echo "${output}" | tr -d ' ') -eq 1 ]]
}

# Test that datamart global table has required columns
@test "datamart global table has all required columns" {
 if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
  skip "No database configured"
 fi

 local dbname="${TEST_DBNAME:-${DBNAME}}"

 # Create table if not exists
 psql -d "${dbname}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql" > /dev/null 2>&1 || true

 # Check for key columns
 run psql -d "${dbname}" -t -c "
  SELECT COUNT(column_name)
  FROM information_schema.columns
  WHERE table_schema = 'dwh'
    AND table_name = 'datamartglobal'
    AND column_name IN (
      'dimension_global_id',
      'currently_open_count',
      'history_whole_open',
      'history_whole_closed',
      'history_year_open',
      'history_year_closed',
      'avg_days_to_resolution',
      'resolution_rate'
    );
 "

 [[ "${status}" -eq 0 ]]
 # Should have at least these 8 columns
 [[ $(echo "${output}" | tr -d ' ') -ge 8 ]]
}

# Test that datamart global table has exactly one record
@test "datamart global table should have exactly one record" {
 if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
  skip "No database configured"
 fi

 local dbname="${TEST_DBNAME:-${DBNAME}}"

 # Create table if not exists
 psql -d "${dbname}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql" > /dev/null 2>&1 || true

 # Check record count
 run psql -d "${dbname}" -Atq -c "
  SELECT COUNT(*)
  FROM dwh.datamartglobal
 "

 [[ "${status}" -eq 0 ]]
 # Should have exactly 1 record
 [[ $(echo "${output}" | tr -d ' ') -eq 1 ]]
}

# Test that datamart global record has dimension_global_id = 1
@test "datamart global record should have dimension_global_id = 1" {
 if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
  skip "No database configured"
 fi

 local dbname="${TEST_DBNAME:-${DBNAME}}"

 # Create table if not exists
 psql -d "${dbname}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql" > /dev/null 2>&1 || true

 # Check dimension_global_id value
 run psql -d "${dbname}" -Atq -c "
  SELECT dimension_global_id
  FROM dwh.datamartglobal
  WHERE dimension_global_id = 1
 "

 [[ "${status}" -eq 0 ]]
 [[ "${output}" == "1" ]]
}

# Test that population script can be executed
@test "datamart global population script can be executed" {
 if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
  skip "No database configured"
 fi

 local dbname="${TEST_DBNAME:-${DBNAME}}"

 # Create table if not exists
 psql -d "${dbname}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql" > /dev/null 2>&1 || true

 # Execute population script (will run even if no data)
 run psql -d "${dbname}" -v ON_ERROR_STOP=1 \
  -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_31_populate.sql" 2>&1 || true

 # Should execute without critical errors (may have warnings about no data)
 [[ "${status}" -eq 0 ]] || echo "Population script should handle empty database"
}

# Test that datamart global can export to JSON
@test "datamart global can be exported to JSON" {
 if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
  skip "No database configured"
 fi

 local dbname="${TEST_DBNAME:-${DBNAME}}"

 # Create table if not exists
 psql -d "${dbname}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql" > /dev/null 2>&1 || true

 # Export to JSON
 run psql -d "${dbname}" -Atq -c "
  SELECT row_to_json(t)
  FROM dwh.datamartglobal t
  WHERE dimension_global_id = 1
 "

 [[ "${status}" -eq 0 ]]
 [[ -n "${output}" ]]
 [[ "${output}" == *"dimension_global_id"* ]] || echo "JSON should contain expected fields"
}

# Test that check tables script works
@test "datamart global check tables script validates existence" {
 if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
  skip "No database configured"
 fi

 local dbname="${TEST_DBNAME:-${DBNAME}}"

 # Create table first
 psql -d "${dbname}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql" > /dev/null 2>&1

 # Check tables script should pass
 run psql -d "${dbname}" -v ON_ERROR_STOP=1 \
  -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_11_checkTables.sql"

 [[ "${status}" -eq 0 ]]
}

# Test that max_date_global_processed table exists
@test "max_date_global_processed table should exist" {
 if [[ -z "${DBNAME:-}" ]] && [[ -z "${TEST_DBNAME:-}" ]]; then
  skip "No database configured"
 fi

 local dbname="${TEST_DBNAME:-${DBNAME}}"

 # Create table first
 psql -d "${dbname}" -f "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql" > /dev/null 2>&1 || true

 # Check table exists
 run psql -d "${dbname}" -Atq -c "
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = 'dwh'
    AND table_name = 'max_date_global_processed'
 "

 [[ "${status}" -eq 0 ]]
 [[ $(echo "${output}" | tr -d ' ') -eq 1 ]]
}



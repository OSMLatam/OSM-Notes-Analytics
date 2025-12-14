#!/bin/bash

# Script to run processAPINotes.sh in hybrid mode and execute ETL after each execution
# This script executes processAPINotes 4 times (1 planet + 3 API) and runs ETL after each execution
# to test the complete data pipeline with valid data structure.
#
# The script:
# 1. Sets up hybrid environment (real DB, mocked downloads)
# 2. Executes processAPINotes.sh 4 times:
#    - Execution 1: Drops base tables, triggering processPlanetNotes.sh --base
#    - Execution 2: Base tables exist, uses 5 notes for sequential processing
#    - Execution 3: Uses 20 notes for parallel processing
#    - Execution 4: No new notes (empty response)
# 3. After EACH execution, runs ETL to test data warehouse update
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-24

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() {
 echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
ANALYTICS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly ANALYTICS_ROOT
INGESTION_ROOT="$(cd "${ANALYTICS_ROOT}/../OSM-Notes-Ingestion" && pwd)"
readonly INGESTION_ROOT

# ETL script path
ETL_SCRIPT="${ANALYTICS_ROOT}/bin/dwh/ETL.sh"
readonly ETL_SCRIPT

# ProcessAPINotes script path
PROCESS_API_SCRIPT="${INGESTION_ROOT}/bin/process/processAPINotes.sh"
readonly PROCESS_API_SCRIPT

# Function to show help
show_help() {
 cat << 'EOF'
Script to run processAPINotes.sh with ETL after each execution

This script executes processAPINotes.sh 4 times:
  1. First execution: Drops base tables, triggering processPlanetNotes.sh --base
  2. Second execution: Base tables exist, uses 5 notes for sequential processing (< 10)
  3. Third execution: Uses 20 notes for parallel processing (>= 10)
  4. Fourth execution: No new notes (empty response) - tests handling of no updates

After EACH execution (planet or API), the ETL script is executed to test the data warehouse update.

Usage:
  ./run_processAPINotes_with_etl.sh [OPTIONS]

Options:
  --help, -h     Show this help message

Environment variables:
  LOG_LEVEL      Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
                 Default: INFO
  CLEAN          Clean temporary files after execution (true/false)
                 Default: false
  DBNAME         Database name
  DB_USER        Database user
  DB_HOST        Database host
  DB_PORT        Database port (default: 5432)

Examples:
  # Run with default settings
  ./run_processAPINotes_with_etl.sh

  # Run with custom database
  DBNAME=my_test_db ./run_processAPINotes_with_etl.sh

  # Run with debug logging
  LOG_LEVEL=DEBUG ./run_processAPINotes_with_etl.sh
EOF
}

# Function to check prerequisites
check_prerequisites() {
 log_info "Checking prerequisites..."

 # Check if ingestion root exists
 if [[ ! -d "${INGESTION_ROOT}" ]]; then
  log_error "OSM-Notes-Ingestion directory not found at: ${INGESTION_ROOT}"
  log_error "Expected location: ${ANALYTICS_ROOT}/../OSM-Notes-Ingestion"
  return 1
 fi

 # Check if ETL script exists
 if [[ ! -f "${ETL_SCRIPT}" ]]; then
  log_error "ETL script not found: ${ETL_SCRIPT}"
  return 1
 fi

 # Make ETL script executable
 chmod +x "${ETL_SCRIPT}"

 log_success "Prerequisites check passed"
 return 0
}

# Function to ensure real psql is used (not mock)
# This function ensures psql is real while keeping aria2c and wget mocks active
ensure_real_psql() {
 log_info "Ensuring real PostgreSQL client is used..."

 local mock_commands_dir="${INGESTION_ROOT}/tests/mock_commands"

 # Remove mock commands directory from PATH temporarily to find real psql
 local temp_path
 temp_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "${mock_commands_dir}" | tr '\n' ':' | sed 's/:$//')

 # Find real psql path
 local real_psql_path
 real_psql_path=""
 while IFS= read -r dir; do
  if [[ -f "${dir}/psql" ]] && [[ "${dir}" != "${mock_commands_dir}" ]]; then
   real_psql_path="${dir}/psql"
   break
  fi
 done <<< "$(echo "${temp_path}" | tr ':' '\n')"

 if [[ -z "${real_psql_path}" ]]; then
  log_error "Real psql command not found in PATH"
  return 1
 fi

 # Get real psql directory
 local real_psql_dir
 real_psql_dir=$(dirname "${real_psql_path}")

 # Rebuild PATH: Remove ALL mock directories to ensure real commands are used
 local clean_path
 clean_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "${mock_commands_dir}" | grep -v "mock_commands" | grep -v "^${real_psql_dir}$" | tr '\n' ':' | sed 's/:$//')

 # Create a custom mock directory that only contains aria2c, wget, pgrep, ogr2ogr (not psql)
 local hybrid_mock_dir
 hybrid_mock_dir="/tmp/hybrid_mock_commands_$$"
 mkdir -p "${hybrid_mock_dir}"

 # Store the directory path for cleanup
 export HYBRID_MOCK_DIR="${hybrid_mock_dir}"

 # Copy only the mocks we want (aria2c, wget, pgrep, ogr2ogr)
 if [[ -f "${mock_commands_dir}/aria2c" ]]; then
  cp "${mock_commands_dir}/aria2c" "${hybrid_mock_dir}/aria2c"
  chmod +x "${hybrid_mock_dir}/aria2c"
 fi
 if [[ -f "${mock_commands_dir}/wget" ]]; then
  cp "${mock_commands_dir}/wget" "${hybrid_mock_dir}/wget"
  chmod +x "${hybrid_mock_dir}/wget"
 fi
 if [[ -f "${mock_commands_dir}/pgrep" ]]; then
  cp "${mock_commands_dir}/pgrep" "${hybrid_mock_dir}/pgrep"
  chmod +x "${hybrid_mock_dir}/pgrep"
 fi
 # Copy ogr2ogr mock if it exists
 if [[ -f "${mock_commands_dir}/ogr2ogr" ]]; then
  cp "${mock_commands_dir}/ogr2ogr" "${hybrid_mock_dir}/ogr2ogr"
  chmod +x "${hybrid_mock_dir}/ogr2ogr"
 fi

 # Set PATH: hybrid mock dir first (for aria2c/wget/ogr2ogr), then real psql dir, then system paths for real commands (gdalinfo, etc), then rest
 # Add /usr/bin and /usr/local/bin to ensure real commands like gdalinfo are available
 local system_paths="/usr/bin:/usr/local/bin:/bin"
 export PATH="${hybrid_mock_dir}:${real_psql_dir}:${system_paths}:${clean_path}"
 hash -r 2> /dev/null || true

 # Export MOCK_COMMANDS_DIR so mock ogr2ogr can find real ogr2ogr if needed
 export MOCK_COMMANDS_DIR="${mock_commands_dir}"

 # Verify we're using real psql
 local current_psql
 current_psql=$(command -v psql)
 if [[ "${current_psql}" == "${mock_commands_dir}/psql" ]] || [[ "${current_psql}" == "${hybrid_mock_dir}/psql" ]]; then
  log_error "Mock psql is being used instead of real psql"
  return 1
 fi
 if [[ -z "${current_psql}" ]]; then
  log_error "psql not found in PATH"
  return 1
 fi

 log_success "Using real psql from: ${current_psql}"

 # Verify mock aria2c is being used (should be from hybrid_mock_dir)
 local current_aria2c
 current_aria2c=$(command -v aria2c 2> /dev/null || true)
 if [[ -n "${current_aria2c}" ]]; then
  log_success "Using mock aria2c from: ${current_aria2c}"
 fi

 return 0
}

# Function to setup hybrid environment
setup_hybrid_environment() {
 log_info "Setting up hybrid environment..."

 local setup_hybrid_script="${INGESTION_ROOT}/tests/setup_hybrid_mock_environment.sh"

 if [[ ! -f "${setup_hybrid_script}" ]]; then
  log_error "Hybrid setup script not found: ${setup_hybrid_script}"
  return 1
 fi

 # Source the setup script to get functions
 # Temporarily disable set -e and set -u to avoid exiting on errors in sourced script
 set +eu
 # shellcheck disable=SC1090
 source "${setup_hybrid_script}" 2> /dev/null || true
 set -eu

 # Create mock commands if they don't exist
 local mock_commands_dir="${INGESTION_ROOT}/tests/mock_commands"
 if [[ ! -f "${mock_commands_dir}/wget" ]] \
  || [[ ! -f "${mock_commands_dir}/aria2c" ]]; then
  log_info "Creating mock commands..."
  bash "${setup_hybrid_script}" setup
 fi

 # Ensure real psql is used (not mock)
 if ! ensure_real_psql; then
  log_error "Failed to ensure real psql is used"
  return 1
 fi

 # Setup test properties (replace etc/properties.sh with properties_test.sh)
 local properties_file="${INGESTION_ROOT}/etc/properties.sh"
 local test_properties_file="${INGESTION_ROOT}/etc/properties_test.sh"
 local properties_backup="${INGESTION_ROOT}/etc/properties.sh.backup"

 if [[ ! -f "${test_properties_file}" ]]; then
  log_error "Test properties file not found: ${test_properties_file}"
  return 1
 fi

 # Backup original properties file if it exists and backup doesn't exist
 if [[ -f "${properties_file}" ]] && [[ ! -f "${properties_backup}" ]]; then
  log_info "Backing up original properties file..."
  cp "${properties_file}" "${properties_backup}"
 fi

 # Replace properties.sh with properties_test.sh
 log_info "Replacing properties.sh with test properties..."
 cp "${test_properties_file}" "${properties_file}"

 # Setup environment variables
 export LOG_LEVEL="${LOG_LEVEL:-INFO}"
 export CLEAN="${CLEAN:-false}"
 export HYBRID_MOCK_MODE=true
 export TEST_MODE=true
 export SEND_ALERT_EMAIL="${SEND_ALERT_EMAIL:-false}"
 export SCRIPT_BASE_DIRECTORY="${INGESTION_ROOT}"
 export MOCK_FIXTURES_DIR="${INGESTION_ROOT}/tests/fixtures/command/extra"
 export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"

 log_success "Hybrid environment activated"
 return 0
}

# Function to cleanup environment
# This function is called from trap (EXIT, SIGINT, SIGTERM), so shellcheck may report
# SC2317 warnings for unreachable code. These warnings can be ignored as the function
# is invoked indirectly via trap.
# shellcheck disable=SC2317
cleanup_environment() {
 log_info "Cleaning up environment..."

 # Restore original properties file
 local properties_file="${INGESTION_ROOT}/etc/properties.sh"
 local properties_backup="${INGESTION_ROOT}/etc/properties.sh.backup"

 if [[ -f "${properties_backup}" ]]; then
  log_info "Restoring original properties file..."
  mv "${properties_backup}" "${properties_file}"
  log_success "Original properties restored"
 fi

 # Cleanup lock files
 rm -f /tmp/processAPINotes.lock
 rm -f /tmp/processAPINotes_failed_execution
 rm -f /tmp/processPlanetNotes.lock
 rm -f /tmp/processPlanetNotes_failed_execution
 rm -f /tmp/updateCountries.lock
 rm -f /tmp/updateCountries_failed_execution

 # Remove mock commands from PATH
 local new_path
 new_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "mock_commands" | grep -v "hybrid_mock_commands" | tr '\n' ':' | sed 's/:$//')
 export PATH="${new_path}"
 hash -r 2> /dev/null || true

 # Clean up hybrid mock directory if it exists
 if [[ -n "${HYBRID_MOCK_DIR:-}" ]] && [[ -d "${HYBRID_MOCK_DIR}" ]]; then
  log_info "Cleaning up hybrid mock directory: ${HYBRID_MOCK_DIR}"
  rm -rf "${HYBRID_MOCK_DIR}" 2> /dev/null || true
 fi

 # Unset environment variables
 unset TEST_MODE 2> /dev/null || true
 unset HYBRID_MOCK_MODE 2> /dev/null || true
 unset HYBRID_MOCK_DIR 2> /dev/null || true

 log_success "Cleanup completed"
}

# Function to drop base tables
drop_base_tables() {
 log_info "Dropping base tables to trigger processPlanetNotes.sh --base..."

 # Load DBNAME from properties file
 # shellcheck disable=SC1090
 source "${INGESTION_ROOT}/etc/properties.sh"

 local psql_cmd="psql"
 if [[ -n "${DB_HOST:-}" ]]; then
  psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
 fi

 # Check if base tables exist
 local tables_exist
 tables_exist=$(${psql_cmd} -d "${DBNAME}" -tAqc \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('countries', 'notes', 'note_comments', 'logs', 'tries');" 2> /dev/null | grep -E '^[0-9]+$' | head -1 || echo "0")

 if [[ "${tables_exist}" -gt 0 ]]; then
  log_info "Base tables exist, dropping them..."
  # Drop base tables
  ${psql_cmd} -d "${DBNAME}" -f "${INGESTION_ROOT}/sql/process/processPlanetNotes_13_dropBaseTables.sql" > /dev/null 2>&1 || true
  # Drop country tables
  ${psql_cmd} -d "${DBNAME}" -c "DROP TABLE IF EXISTS countries CASCADE;" > /dev/null 2>&1 || true
  log_success "Base tables dropped"
 else
  log_info "Base tables don't exist (already clean)"
 fi
}

# Function to run processAPINotes directly
run_processAPINotes() {
 local execution_number="${1:-1}"
 log_info "Running processAPINotes.sh (execution #${execution_number})..."

 if [[ ! -f "${PROCESS_API_SCRIPT}" ]]; then
  log_error "processAPINotes.sh not found: ${PROCESS_API_SCRIPT}"
  return 1
 fi

 # Make script executable
 chmod +x "${PROCESS_API_SCRIPT}"

 # Set MOCK_NOTES_COUNT and prepare base tables based on execution number
 case "${execution_number}" in
 1)
  # First execution: drop tables (will call processPlanetNotes.sh --base)
  log_info "=== EXECUTION #1: Setting up for processPlanetNotes.sh --base ==="
  drop_base_tables

  unset MOCK_NOTES_COUNT
  export MOCK_NOTES_COUNT=""
  log_info "Execution #1: Will load processPlanetNotes.sh --base (MOCK_NOTES_COUNT unset)"
  ;;
 2)
  # Second execution: 5 notes for sequential processing (base tables already exist)
  log_info "=== EXECUTION #2: API with 5 notes (sequential processing) ==="
  export MOCK_NOTES_COUNT="5"
  log_info "Execution #2: Using ${MOCK_NOTES_COUNT} notes for sequential processing"
  ;;
 3)
  # Third execution: 20 notes for parallel processing (base tables already exist)
  log_info "=== EXECUTION #3: API with 20 notes (parallel processing) ==="
  export MOCK_NOTES_COUNT="20"
  log_info "Execution #3: Using ${MOCK_NOTES_COUNT} notes for parallel processing"
  ;;
 4)
  # Fourth execution: 0 notes (no new notes) (base tables already exist)
  log_info "=== EXECUTION #4: API with 0 notes (no new notes scenario) ==="
  export MOCK_NOTES_COUNT="0"
  log_info "Execution #4: Using ${MOCK_NOTES_COUNT} notes (no new notes scenario)"
  ;;
 *)
  log_error "Invalid execution number: ${execution_number}"
  return 1
  ;;
 esac

 # Cleanup lock files before execution
 rm -f /tmp/processAPINotes.lock
 rm -f /tmp/processAPINotes_failed_execution
 rm -f /tmp/processPlanetNotes.lock
 rm -f /tmp/processPlanetNotes_failed_execution
 rm -f /tmp/updateCountries.lock
 rm -f /tmp/updateCountries_failed_execution

 # Change to ingestion root directory
 cd "${INGESTION_ROOT}"

 # Run the script and capture output
 log_info "Executing: ${PROCESS_API_SCRIPT}"
 local output_file="/tmp/processAPINotes_output_${execution_number}_$$.log"
 if "${PROCESS_API_SCRIPT}" > "${output_file}" 2>&1; then
  log_success "processAPINotes.sh completed successfully (execution #${execution_number})"
  rm -f "${output_file}" 2>/dev/null || true
  return 0
 else
  local exit_code=$?
  log_error "processAPINotes.sh exited with code: ${exit_code} (execution #${execution_number})"

  # Show error context based on exit code
  case ${exit_code} in
  248)
   log_error "Error code 248: Error executing Planet dump (processPlanetNotes.sh --base failed)"
   ;;
  238)
   log_error "Error code 238: Previous execution failed (check for /tmp/processAPINotes_failed_execution)"
   ;;
  241)
   log_error "Error code 241: Library or utility missing"
   ;;
  245)
   log_error "Error code 245: No last update (run processPlanetNotes.sh --base first)"
   ;;
  246)
   log_error "Error code 246: Planet process is currently running"
   ;;
  esac

  # Show last 50 lines of output for debugging
  if [[ -f "${output_file}" ]]; then
   log_error "Last 50 lines of processAPINotes.sh output:"
   tail -50 "${output_file}" | while IFS= read -r line; do
    log_error "  ${line}"
   done

   # Also check for log files
   local latest_log_dir
   latest_log_dir=$(find /tmp -maxdepth 1 -type d -name 'processAPINotes_*' -printf '%T@\t%p\n' 2>/dev/null | sort -n | tail -1 | cut -f2- || echo "")
   if [[ -n "${latest_log_dir}" ]] && [[ -f "${latest_log_dir}/processAPINotes.log" ]]; then
    log_error "Last 30 lines of processAPINotes.log:"
    tail -30 "${latest_log_dir}/processAPINotes.log" | while IFS= read -r line; do
     log_error "  ${line}"
    done
   fi

   # Clean up temp file
   rm -f "${output_file}" 2>/dev/null || true
  fi

  return ${exit_code}
 fi
}

# Function to run ETL
run_etl() {
 local execution_number="${1:-1}"
 local source_type="${2:-unknown}"
 log_info "Running ETL after ${source_type} execution #${execution_number}..."

 # Change to analytics root directory
 cd "${ANALYTICS_ROOT}"

 # Load DBNAME from ingestion properties to ensure ETL uses the same database
 # In hybrid test mode, both Ingestion and Analytics use the same database
 # shellcheck disable=SC1090
 source "${INGESTION_ROOT}/etc/properties.sh"
 local ingestion_dbname="${DBNAME:-notes}"

 # Export database configuration for ETL
 # In hybrid test mode, both databases are the same
 export DBNAME="${ingestion_dbname}"
 export DBNAME_INGESTION="${ingestion_dbname}"
 export DBNAME_DWH="${ingestion_dbname}"

 # Set logging level if not already set
 export LOG_LEVEL="${LOG_LEVEL:-INFO}"

 log_info "ETL will use database: ${DBNAME}"
 log_info "Configuration: DBNAME_INGESTION='${DBNAME_INGESTION}', DBNAME_DWH='${DBNAME_DWH}'"

 # Run ETL in incremental mode (it will auto-detect if it's first execution)
 log_info "Executing: ${ETL_SCRIPT}"
 if "${ETL_SCRIPT}"; then
  log_success "ETL completed successfully after ${source_type} execution #${execution_number}"
  return 0
 else
  local exit_code=$?
  log_error "ETL failed with exit code: ${exit_code} after ${source_type} execution #${execution_number}"
  return ${exit_code}
 fi
}

# Function to execute one processAPINotes run and then ETL
# This function will be called 4 times with different configurations
execute_processAPINotes_and_etl() {
 local execution_number="${1:-1}"
 local exit_code=0

 log_info ""
 log_info "=========================================="
 log_info "=== EXECUTION #${execution_number} ==="
 log_info "=========================================="
 log_info ""

 # Determine source type
 local source_type
 if [[ ${execution_number} -eq 1 ]]; then
  source_type="planet"
  log_info "Source: PLANET (processPlanetNotes.sh --base will be called)"
 else
  source_type="api"
  log_info "Source: API (only processAPINotes.sh, no planet)"
 fi

 # Run processAPINotes
 log_info "--- Step 1: Running processAPINotes.sh (${source_type}) ---"
 if ! run_processAPINotes "${execution_number}"; then
  log_error "processAPINotes (${source_type}) execution #${execution_number} failed"
  return 1
 fi

 log_success "processAPINotes (${source_type}) execution #${execution_number} completed"

 # Wait a moment before running ETL
 log_info "Waiting 2 seconds before running ETL..."
 sleep 2

 # Run ETL after processAPINotes
 log_info "--- Step 2: Running ETL after ${source_type} execution #${execution_number} ---"
 if ! run_etl "${execution_number}" "${source_type}"; then
  log_error "ETL failed after ${source_type} execution #${execution_number}"
  exit_code=1
 fi

 log_success "ETL completed after ${source_type} execution #${execution_number}"

 # Wait a moment before next execution
 log_info "Waiting 2 seconds before next execution..."
 sleep 2
 log_info ""

 return ${exit_code}
}

# Main function
main() {
 local exit_code=0

 # Parse arguments
 case "${1:-}" in
 --help | -h)
  show_help
  exit 0
  ;;
 "")
  # No arguments, continue
  ;;
 *)
  log_error "Unknown option: $1"
  show_help
  exit 1
  ;;
 esac

 log_info "=========================================="
 log_info "Starting processAPINotes with ETL integration"
 log_info "=========================================="
 log_info "Total executions: 4"
 log_info ""
 log_info "Expected sequence:"
 log_info "  1. processAPINotes (planet/base) → ETL"
 log_info "  2. processAPINotes (API, 5 notes) → ETL"
 log_info "  3. processAPINotes (API, 20 notes) → ETL"
 log_info "  4. processAPINotes (API, 0 notes) → ETL"
 log_info ""

 # Setup trap for cleanup
 trap cleanup_environment EXIT SIGINT SIGTERM

 # Check prerequisites
 if ! check_prerequisites; then
  log_error "Prerequisites check failed"
  exit 1
 fi

 # Setup hybrid environment
 if ! setup_hybrid_environment; then
  log_error "Failed to setup hybrid environment"
  exit 1
 fi

 # Setup environment variables
 export LOG_LEVEL="${LOG_LEVEL:-INFO}"
 export CLEAN="${CLEAN:-false}"

 # Execute 4 times: 1 planet + 3 API
 for i in 1 2 3 4; do
  if ! execute_processAPINotes_and_etl "${i}"; then
   log_error "Execution #${i} failed"
   exit_code=1
   # Execution #1 (planet/base) is critical - stop if it fails
   # Other executions can continue for testing purposes
   if [[ ${i} -eq 1 ]]; then
    log_error "Execution #1 (planet/base) failed - this is critical, stopping execution"
    log_error "Subsequent executions depend on base data from execution #1"
    break
   else
    log_error "Execution #${i} failed, but continuing with next execution..."
   fi
  fi
 done

 if [[ ${exit_code} -eq 0 ]]; then
  log_success "All executions completed successfully"
 else
  log_error "Some executions failed"
 fi

 # Cleanup will be done by trap
 exit ${exit_code}
}

# Run main function
main "$@"

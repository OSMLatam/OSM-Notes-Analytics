#!/bin/bash

# Script to run processAPINotes.sh in hybrid mode and execute ETL after each execution
# This script provides step-by-step control over the execution
#
# Usage:
#   ./run_processAPINotes_with_etl_controlled.sh [step]
#
# Steps:
#   1 - Drop base tables and run processAPINotes.sh (planet/base)
#   2 - Run ETL after step 1
#   3 - Run processAPINotes.sh (API, 5 notes)
#   4 - Run ETL after step 3
#   5 - Run processAPINotes.sh (API, 20 notes)
#   6 - Run ETL after step 5
#   7 - Run processAPINotes.sh (API, 0 notes)
#   8 - Run ETL after step 7
#   all - Run all steps sequentially
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-20

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
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

log_warn() {
 echo -e "${YELLOW}[WARN]${NC} $1"
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
Script to run processAPINotes.sh with ETL after each execution (controlled mode)

This script provides step-by-step control over the execution:
  1 - Drop base tables and run processAPINotes.sh (planet/base)
  2 - Run ETL after step 1
  3 - Run processAPINotes.sh (API, 5 notes)
  4 - Run ETL after step 3
  5 - Run processAPINotes.sh (API, 20 notes)
  6 - Run ETL after step 5
  7 - Run processAPINotes.sh (API, 0 notes)
  8 - Run ETL after step 7
  all - Run all steps sequentially

Usage:
  ./run_processAPINotes_with_etl_controlled.sh [step]

Examples:
  # Run step 1 only
  ./run_processAPINotes_with_etl_controlled.sh 1

  # Run all steps
  ./run_processAPINotes_with_etl_controlled.sh all

  # Run steps 3 and 4
  ./run_processAPINotes_with_etl_controlled.sh 3
  ./run_processAPINotes_with_etl_controlled.sh 4
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

# Function to ensure real psql is used (not mock)
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
 log_success "Using mock aria2c from: ${hybrid_mock_dir}/aria2c"
 return 0
}

# Function to cleanup environment
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

# Function to ensure countries are loaded
ensure_countries_loaded() {
 log_info "Ensuring countries are loaded in database..."

 # Load DBNAME from properties file
 # shellcheck disable=SC1090
 source "${INGESTION_ROOT}/etc/properties.sh"

 local psql_cmd="psql"
 if [[ -n "${DB_HOST:-}" ]]; then
  psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
 fi

 # Check if countries exist
 local countries_count
 countries_count=$(${psql_cmd} -d "${DBNAME}" -tAqc \
  "SELECT COUNT(*) FROM countries;" 2> /dev/null | grep -E '^[0-9]+$' | head -1 || echo "0")

 if [[ "${countries_count:-0}" -eq 0 ]]; then
  log_info "No countries found, loading them with updateCountries.sh..."

  # Ensure environment variables are exported for updateCountries.sh
  export SCRIPT_BASE_DIRECTORY="${INGESTION_ROOT}"
  export MOCK_FIXTURES_DIR="${INGESTION_ROOT}/tests/fixtures/command/extra"
  export HYBRID_MOCK_MODE=true
  export TEST_MODE=true

  # Change to ingestion root
  cd "${INGESTION_ROOT}"

  # Run updateCountries.sh --base
  if "${INGESTION_ROOT}/bin/process/updateCountries.sh" --base; then
   log_success "Countries loaded successfully"
  else
   log_error "Failed to load countries, but continuing anyway..."
   # Don't fail the entire process if countries loading fails
   # The ETL can work without countries (though with limited functionality)
  fi
 else
  log_info "Countries already loaded (${countries_count} countries found)"
 fi
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
  # Drop base tables (but keep countries table)
  ${psql_cmd} -d "${DBNAME}" -f "${INGESTION_ROOT}/sql/process/processPlanetNotes_13_dropBaseTables.sql" > /dev/null 2>&1 || true
  # Note: We don't drop countries table to avoid needing to reload them
  log_success "Base tables dropped (countries table preserved)"
 else
  log_info "Base tables don't exist (already clean)"
 fi
}

# Function to run processAPINotes directly
run_processAPINotes() {
 local execution_number="${1:-1}"
 local notes_count="${2:-}"
 log_info "Running processAPINotes.sh (execution #${execution_number})..."

 if [[ ! -f "${PROCESS_API_SCRIPT}" ]]; then
  log_error "processAPINotes.sh not found: ${PROCESS_API_SCRIPT}"
  return 1
 fi

 # Make script executable
 chmod +x "${PROCESS_API_SCRIPT}"

 # Set MOCK_NOTES_COUNT based on execution number
 case "${execution_number}" in
 1)
  # First execution: drop tables (will call processPlanetNotes.sh --base)
  log_info "=== EXECUTION #1: Setting up for processPlanetNotes.sh --base ==="
  # Ensure countries are loaded before dropping tables
  ensure_countries_loaded
  drop_base_tables
  unset MOCK_NOTES_COUNT
  export MOCK_NOTES_COUNT=""
  log_info "Execution #1: Will load processPlanetNotes.sh --base (MOCK_NOTES_COUNT unset)"
  ;;
 3)
  # Third execution: 5 notes for sequential processing
  log_info "=== EXECUTION #3: API with 5 notes (sequential processing) ==="
  # Ensure countries are loaded before processing
  ensure_countries_loaded
  export MOCK_NOTES_COUNT="5"
  log_info "Execution #3: Using ${MOCK_NOTES_COUNT} notes for sequential processing"
  ;;
 5)
  # Fifth execution: 20 notes for parallel processing
  log_info "=== EXECUTION #5: API with 20 notes (parallel processing) ==="
  export MOCK_NOTES_COUNT="20"
  log_info "Execution #5: Using ${MOCK_NOTES_COUNT} notes for parallel processing"
  ;;
 7)
  # Seventh execution: 0 notes (no new notes)
  log_info "=== EXECUTION #7: API with 0 notes (no new notes scenario) ==="
  export MOCK_NOTES_COUNT="0"
  log_info "Execution #7: Using ${MOCK_NOTES_COUNT} notes (no new notes scenario)"
  ;;
 *)
  if [[ -n "${notes_count}" ]]; then
   export MOCK_NOTES_COUNT="${notes_count}"
   log_info "Using ${MOCK_NOTES_COUNT} notes"
  fi
  ;;
 esac

 # Cleanup lock files before execution
 rm -f /tmp/processAPINotes.lock
 rm -f /tmp/processAPINotes_failed_execution
 rm -f /tmp/processPlanetNotes.lock
 rm -f /tmp/processPlanetNotes_failed_execution
 rm -f /tmp/updateCountries.lock
 rm -f /tmp/updateCountries_failed_execution

 # Ensure SCRIPT_BASE_DIRECTORY is exported for mock commands
 export SCRIPT_BASE_DIRECTORY="${INGESTION_ROOT}"

 # Change to ingestion root directory
 cd "${INGESTION_ROOT}"

 # Verify mock aria2c is in PATH and accessible
 local current_aria2c
 current_aria2c=$(command -v aria2c 2> /dev/null || true)
 if [[ -z "${current_aria2c}" ]]; then
  log_error "aria2c not found in PATH. Hybrid mock setup may have failed."
  return 1
 fi
 log_info "Using aria2c from: ${current_aria2c}"

 # Run the script
 log_info "Executing: ${PROCESS_API_SCRIPT}"
 # Capture output to see what's happening
 local output_file="/tmp/processAPINotes_output_${execution_number}.log"
 # Also capture stderr separately for better debugging
 if "${PROCESS_API_SCRIPT}" > "${output_file}" 2>&1; then
  log_success "processAPINotes.sh completed successfully (execution #${execution_number})"
  return 0
 else
  local exit_code=$?
  log_error "processAPINotes.sh exited with code: ${exit_code} (execution #${execution_number})"
  log_error "Last 50 lines of output:"
  tail -50 "${output_file}" | while IFS= read -r line; do
   log_error "  $line"
  done
  return ${exit_code}
 fi
}

# Function to run ETL
run_etl() {
 local execution_number="${1:-1}"
 log_info "Running ETL after execution #${execution_number}..."

 # Change to analytics root directory
 cd "${ANALYTICS_ROOT}"

 # Load DBNAME from ingestion properties to ensure ETL uses the same database
 # shellcheck disable=SC1090
 source "${INGESTION_ROOT}/etc/properties.sh"
 export DBNAME="${DBNAME:-osm_notes}"

 # Set logging level if not already set
 export LOG_LEVEL="${LOG_LEVEL:-INFO}"

 log_info "ETL will use database: ${DBNAME}"

 # Ensure required columns exist (for existing DWH that was created before these columns were added)
 # This is a one-time migration for existing databases
 local psql_cmd="psql"
 if [[ -n "${DB_HOST:-}" ]]; then
  psql_cmd="${psql_cmd} -h ${DB_HOST} -p ${DB_PORT}"
 fi

 log_info "Ensuring required columns exist in DWH tables..."
 ${psql_cmd} -d "${DBNAME}" -v ON_ERROR_STOP=0 -c "
 DO \$\$
 BEGIN
  -- Add action_comment to facts if it doesn't exist
  IF NOT EXISTS (
   SELECT 1 FROM information_schema.columns
   WHERE table_schema = 'dwh' AND table_name = 'facts' AND column_name = 'action_comment'
  ) THEN
   ALTER TABLE dwh.facts ADD COLUMN action_comment note_event_enum;
  END IF;

  -- Add used_in_action to fact_hashtags if it doesn't exist
  IF NOT EXISTS (
   SELECT 1 FROM information_schema.columns
   WHERE table_schema = 'dwh' AND table_name = 'fact_hashtags' AND column_name = 'used_in_action'
  ) THEN
   ALTER TABLE dwh.fact_hashtags ADD COLUMN used_in_action note_event_enum;
  END IF;
 END \$\$;
 " > /dev/null 2>&1 || true

 # Run ETL in auto-detect mode (it will auto-detect if it's first execution)
 log_info "Executing: ${ETL_SCRIPT}"
 if "${ETL_SCRIPT}"; then
  log_success "ETL completed successfully after execution #${execution_number}"
  return 0
 else
  local exit_code=$?
  log_error "ETL failed with exit code: ${exit_code} after execution #${execution_number}"
  return ${exit_code}
 fi
}

# Function to run a specific step
run_step() {
 local step="${1}"
 local exit_code=0

 case "${step}" in
 1)
  log_info "=== STEP 1: Drop base tables and run processAPINotes.sh (planet/base) ==="
  if ! run_processAPINotes 1; then
   log_error "Step 1 failed"
   return 1
  fi
  log_success "Step 1 completed"
  ;;
 2)
  log_info "=== STEP 2: Run ETL after step 1 ==="
  if ! run_etl 1; then
   log_error "Step 2 failed"
   return 1
  fi
  log_success "Step 2 completed"
  ;;
 3)
  log_info "=== STEP 3: Run processAPINotes.sh (API, 5 notes) ==="
  if ! run_processAPINotes 3; then
   log_error "Step 3 failed"
   return 1
  fi
  log_success "Step 3 completed"
  ;;
 4)
  log_info "=== STEP 4: Run ETL after step 3 ==="
  if ! run_etl 3; then
   log_error "Step 4 failed"
   return 1
  fi
  log_success "Step 4 completed"
  ;;
 5)
  log_info "=== STEP 5: Run processAPINotes.sh (API, 20 notes) ==="
  if ! run_processAPINotes 5; then
   log_error "Step 5 failed"
   return 1
  fi
  log_success "Step 5 completed"
  ;;
 6)
  log_info "=== STEP 6: Run ETL after step 5 ==="
  if ! run_etl 5; then
   log_error "Step 6 failed"
   return 1
  fi
  log_success "Step 6 completed"
  ;;
 7)
  log_info "=== STEP 7: Run processAPINotes.sh (API, 0 notes) ==="
  if ! run_processAPINotes 7; then
   log_error "Step 7 failed"
   return 1
  fi
  log_success "Step 7 completed"
  ;;
 8)
  log_info "=== STEP 8: Run ETL after step 7 ==="
  if ! run_etl 7; then
   log_error "Step 8 failed"
   return 1
  fi
  log_success "Step 8 completed"
  ;;
 all)
  log_info "=== Running all steps sequentially ==="
  for step_num in 1 2 3 4 5 6 7 8; do
   log_info ""
   log_info "=========================================="
   if ! run_step "${step_num}"; then
    log_error "Failed at step ${step_num}"
    return 1
   fi
   log_info "Waiting 2 seconds before next step..."
   sleep 2
  done
  log_success "All steps completed successfully"
  ;;
 *)
  log_error "Invalid step: ${step}"
  show_help
  return 1
  ;;
 esac

 return ${exit_code}
}

# Main function
main() {
 local step="${1:-help}"

 # Parse arguments
 case "${step}" in
 --help | -h | help)
  show_help
  exit 0
  ;;
 esac

 # Check prerequisites
 if ! check_prerequisites; then
  log_error "Prerequisites check failed"
  exit 1
 fi

 # Setup trap for cleanup
 trap cleanup_environment EXIT SIGINT SIGTERM

 # Setup hybrid environment
 if ! setup_hybrid_environment; then
  log_error "Failed to setup hybrid environment"
  exit 1
 fi

 # Run the requested step
 if ! run_step "${step}"; then
  log_error "Step ${step} failed"
  exit 1
 fi

 log_success "All operations completed successfully"
}

# Run main function
main "$@"

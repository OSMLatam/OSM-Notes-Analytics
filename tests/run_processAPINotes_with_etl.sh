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
# Version: 2025-12-20

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

# Database names for hybrid test with separate databases
readonly ANALYTICS_DBNAME="osm_notes_analytics_remote_test"

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
  DBNAME         Ingestion database name (from properties.sh)
  DB_USER_INGESTION  Database user for Ingestion database
  DB_USER_DWH    Database user for Analytics database
  DB_HOST        Database host
  DB_PORT        Database port (default: 5432)

  Note: DB_USER is NOT used in this project (it's only valid in OSM-Notes-Ingestion project)

Note: This script uses TWO separate databases:
  - Ingestion DB: Uses DBNAME from properties.sh (default: osm_notes)
  - Analytics DB: osm_notes_analytics_remote_test (created automatically)

This configuration enables testing of Foreign Data Wrappers (FDW) functionality.

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

# Function to setup analytics database
# Creates the analytics database if it doesn't exist and ensures it's ready for ETL
setup_analytics_database() {
 log_info "Setting up analytics database: ${ANALYTICS_DBNAME}..."

 # Load database connection parameters from ingestion properties
 # shellcheck disable=SC1090
 source "${INGESTION_ROOT}/etc/properties.sh"

 local PSQL_CMD="psql"
 if [[ -n "${DB_HOST:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -h ${DB_HOST} -p ${DB_PORT:-5432}"
 fi
 # Use DB_USER_INGESTION if available, otherwise use current user for peer auth
 if [[ -n "${DB_USER_INGESTION:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER_INGESTION}"
 fi

 # Check if analytics database exists
 if ! ${PSQL_CMD} -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '${ANALYTICS_DBNAME}';" 2> /dev/null | grep -q 1; then
  log_info "Creating analytics database: ${ANALYTICS_DBNAME}..."
  if ! ${PSQL_CMD} -d postgres -c "CREATE DATABASE ${ANALYTICS_DBNAME};" 2>&1; then
   log_error "Failed to create analytics database: ${ANALYTICS_DBNAME}"
   return 1
  fi
  log_success "Analytics database created successfully"
 else
  log_info "Analytics database already exists: ${ANALYTICS_DBNAME}"
 fi

 # Ensure dwh schema exists in analytics database
 log_info "Ensuring dwh schema exists in analytics database..."
 if ! ${PSQL_CMD} -d "${ANALYTICS_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS dwh;" 2>&1; then
  log_error "Failed to create dwh schema in analytics database"
  return 1
 fi

 # Clean dwh schema to start from scratch
 log_info "Cleaning dwh schema in analytics database..."
 # Force disconnect any active connections
 ${PSQL_CMD} -d "${ANALYTICS_DBNAME}" -c "
  SELECT pg_terminate_backend(pg_stat_activity.pid)
  FROM pg_stat_activity
  WHERE pg_stat_activity.datname = '${ANALYTICS_DBNAME}'
   AND pid <> pg_backend_pid()
   AND state = 'active';
 " > /dev/null 2>&1 || true

 # Drop the schema
 ${PSQL_CMD} -d "${ANALYTICS_DBNAME}" -c "DROP SCHEMA IF EXISTS dwh CASCADE;" > /dev/null 2>&1 || true
 ${PSQL_CMD} -d "${ANALYTICS_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS dwh;" > /dev/null 2>&1 || true

 log_success "Analytics database ready: ${ANALYTICS_DBNAME}"
 return 0
}

# Function to ensure real psql is used (not mock)
# This function ensures psql is real while keeping aria2c and wget mocks active
ensure_real_psql() {
 log_info "Ensuring real PostgreSQL client is used..."

 local MOCK_COMMANDS_DIR="${INGESTION_ROOT}/tests/mock_commands"

 # Remove mock commands directory from PATH temporarily to find real psql
 local TEMP_PATH
 TEMP_PATH=$(echo "${PATH}" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | tr '\n' ':' | sed 's/:$//')

 # Find real psql path
 local REAL_PSQL_PATH
 REAL_PSQL_PATH=""
 while IFS= read -r DIR; do
  if [[ -f "${DIR}/psql" ]] && [[ "${DIR}" != "${MOCK_COMMANDS_DIR}" ]]; then
   REAL_PSQL_PATH="${DIR}/psql"
   break
  fi
 done <<< "$(echo "${TEMP_PATH}" | tr ':' '\n')"

 if [[ -z "${REAL_PSQL_PATH}" ]]; then
  log_error "Real psql command not found in PATH"
  return 1
 fi

 # Get real psql directory
 local REAL_PSQL_DIR
 REAL_PSQL_DIR=$(dirname "${REAL_PSQL_PATH}")

 # Rebuild PATH: Remove ALL mock directories to ensure real commands are used
 local CLEAN_PATH
 CLEAN_PATH=$(echo "${PATH}" | tr ':' '\n' | grep -v "${MOCK_COMMANDS_DIR}" | grep -v "mock_commands" | grep -v "^${REAL_PSQL_DIR}$" | tr '\n' ':' | sed 's/:$//')

 # Create a custom mock directory that only contains aria2c, wget, curl, pgrep, ogr2ogr (not psql)
 # Use a stable directory name that persists across all executions in the same script run
 # This directory is in /tmp and in .gitignore, so it's safe to keep it during execution
 local HYBRID_MOCK_DIR_LOCAL
 HYBRID_MOCK_DIR_LOCAL="/tmp/hybrid_mock_commands_$$"

 # If directory already exists (from previous execution in same script run), reuse it
 if [[ ! -d "${HYBRID_MOCK_DIR_LOCAL}" ]]; then
  mkdir -p "${HYBRID_MOCK_DIR_LOCAL}"
 fi

 # Store the directory path for cleanup (only at script exit)
 export HYBRID_MOCK_DIR="${HYBRID_MOCK_DIR_LOCAL}"

 # Copy only the mocks we want (aria2c, wget, curl, pgrep, ogr2ogr)
 # Always copy to ensure mocks are up-to-date (they may have been regenerated)
 if [[ -f "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
  cp "${MOCK_COMMANDS_DIR}/aria2c" "${HYBRID_MOCK_DIR_LOCAL}/aria2c"
  chmod +x "${HYBRID_MOCK_DIR_LOCAL}/aria2c"
 fi
 if [[ -f "${MOCK_COMMANDS_DIR}/wget" ]]; then
  cp "${MOCK_COMMANDS_DIR}/wget" "${HYBRID_MOCK_DIR_LOCAL}/wget"
  chmod +x "${HYBRID_MOCK_DIR_LOCAL}/wget"
 fi
 if [[ -f "${MOCK_COMMANDS_DIR}/curl" ]]; then
  cp "${MOCK_COMMANDS_DIR}/curl" "${HYBRID_MOCK_DIR_LOCAL}/curl"
  chmod +x "${HYBRID_MOCK_DIR_LOCAL}/curl"
 fi
 if [[ -f "${MOCK_COMMANDS_DIR}/pgrep" ]]; then
  cp "${MOCK_COMMANDS_DIR}/pgrep" "${HYBRID_MOCK_DIR_LOCAL}/pgrep"
  chmod +x "${HYBRID_MOCK_DIR_LOCAL}/pgrep"
 fi
 # Copy ogr2ogr mock if it exists
 if [[ -f "${MOCK_COMMANDS_DIR}/ogr2ogr" ]]; then
  cp "${MOCK_COMMANDS_DIR}/ogr2ogr" "${HYBRID_MOCK_DIR_LOCAL}/ogr2ogr"
  chmod +x "${HYBRID_MOCK_DIR_LOCAL}/ogr2ogr"
 fi

 # Set PATH: hybrid mock dir first (for aria2c/wget/curl/ogr2ogr), then real psql dir, then system paths for real commands (gdalinfo, etc), then rest
 # Add /usr/bin and /usr/local/bin to ensure real commands like gdalinfo are available
 local SYSTEM_PATHS="/usr/bin:/usr/local/bin:/bin"
 export PATH="${HYBRID_MOCK_DIR_LOCAL}:${REAL_PSQL_DIR}:${SYSTEM_PATHS}:${CLEAN_PATH}"
 hash -r 2> /dev/null || true

 # Export MOCK_COMMANDS_DIR so mock ogr2ogr can find real ogr2ogr if needed
 export MOCK_COMMANDS_DIR="${MOCK_COMMANDS_DIR}"

 # Verify we're using real psql
 local CURRENT_PSQL
 CURRENT_PSQL=$(command -v psql)
 if [[ "${CURRENT_PSQL}" == "${MOCK_COMMANDS_DIR}/psql" ]] || [[ "${CURRENT_PSQL}" == "${HYBRID_MOCK_DIR_LOCAL}/psql" ]]; then
  log_error "Mock psql is being used instead of real psql"
  return 1
 fi
 if [[ -z "${CURRENT_PSQL}" ]]; then
  log_error "psql not found in PATH"
  return 1
 fi

 log_success "Using real psql from: ${CURRENT_PSQL}"

 # Verify mock aria2c is being used (should be from hybrid_mock_dir)
 local CURRENT_ARIA2C
 CURRENT_ARIA2C=$(command -v aria2c 2> /dev/null || true)
 if [[ -n "${CURRENT_ARIA2C}" ]]; then
  log_success "Using mock aria2c from: ${CURRENT_ARIA2C}"
 fi

 # Verify mock curl is being used (should be from hybrid_mock_dir)
 local CURRENT_CURL
 CURRENT_CURL=$(command -v curl 2> /dev/null || true)
 if [[ -n "${CURRENT_CURL}" ]]; then
  log_success "Using mock curl from: ${CURRENT_CURL}"
 fi

 return 0
}

# Function to setup hybrid environment
setup_hybrid_environment() {
 log_info "Setting up hybrid environment..."

 local SETUP_HYBRID_SCRIPT="${INGESTION_ROOT}/tests/setup_hybrid_mock_environment.sh"

 if [[ ! -f "${SETUP_HYBRID_SCRIPT}" ]]; then
  log_error "Hybrid setup script not found: ${SETUP_HYBRID_SCRIPT}"
  return 1
 fi

 # Source the setup script to get functions
 # Temporarily disable set -e and set -u to avoid exiting on errors in sourced script
 set +eu
 # shellcheck disable=SC1090
 source "${SETUP_HYBRID_SCRIPT}" 2> /dev/null || true
 set -eu

 # Always regenerate mock commands to ensure they are up-to-date with latest changes
 # This ensures that any changes to the mock generator script are immediately reflected
 local MOCK_COMMANDS_DIR="${INGESTION_ROOT}/tests/mock_commands"
 log_info "Regenerating mock commands to ensure they are up-to-date..."
 bash "${SETUP_HYBRID_SCRIPT}" setup

 # Ensure real psql is used (not mock)
 if ! ensure_real_psql; then
  log_error "Failed to ensure real psql is used"
  return 1
 fi

 # Setup test properties (replace etc/properties.sh with properties_test.sh)
 local PROPERTIES_FILE="${INGESTION_ROOT}/etc/properties.sh"
 local TEST_PROPERTIES_FILE="${INGESTION_ROOT}/etc/properties_test.sh"
 local PROPERTIES_BACKUP="${INGESTION_ROOT}/etc/properties.sh.backup"

 if [[ ! -f "${TEST_PROPERTIES_FILE}" ]]; then
  log_error "Test properties file not found: ${TEST_PROPERTIES_FILE}"
  return 1
 fi

 # Backup original properties file if it exists and backup doesn't exist
 if [[ -f "${PROPERTIES_FILE}" ]] && [[ ! -f "${PROPERTIES_BACKUP}" ]]; then
  log_info "Backing up original properties file..."
  cp "${PROPERTIES_FILE}" "${PROPERTIES_BACKUP}"
 fi

 # Replace properties.sh with properties_test.sh
 log_info "Replacing properties.sh with test properties..."
 cp "${TEST_PROPERTIES_FILE}" "${PROPERTIES_FILE}"

 # Setup environment variables
 export LOG_LEVEL="${LOG_LEVEL:-INFO}"
 export CLEAN="${CLEAN:-false}"
 export HYBRID_MOCK_MODE=true
 export TEST_MODE=true
 export SEND_ALERT_EMAIL="${SEND_ALERT_EMAIL:-false}"
 # Set SCRIPT_BASE_DIRECTORY for ingestion scripts (processAPINotes.sh)
 export SCRIPT_BASE_DIRECTORY="${INGESTION_ROOT}"
 export MOCK_FIXTURES_DIR="${INGESTION_ROOT}/tests/fixtures/command/extra"
 export SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"
 export FORCE_SWAP_ON_WARNING="${FORCE_SWAP_ON_WARNING:-true}"

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
 local PROPERTIES_FILE="${INGESTION_ROOT}/etc/properties.sh"
 local PROPERTIES_BACKUP="${INGESTION_ROOT}/etc/properties.sh.backup"

 if [[ -f "${PROPERTIES_BACKUP}" ]]; then
  log_info "Restoring original properties file..."
  mv "${PROPERTIES_BACKUP}" "${PROPERTIES_FILE}"
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
 local NEW_PATH
 NEW_PATH=$(echo "${PATH}" | tr ':' '\n' | grep -v "mock_commands" | grep -v "hybrid_mock_commands" | tr '\n' ':' | sed 's/:$//')
 export PATH="${NEW_PATH}"
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

 local PSQL_CMD="psql"
 if [[ -n "${DB_HOST:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -h ${DB_HOST} -p ${DB_PORT}"
 fi

 # Always drop base tables to ensure clean state
 # This prevents duplicate key errors from residual data
 log_info "Dropping base tables to ensure clean state..."
 # Drop base tables
 ${PSQL_CMD} -d "${DBNAME}" -f "${INGESTION_ROOT}/sql/process/processPlanetNotes_13_dropBaseTables.sql" > /dev/null 2>&1 || true
 # Drop country tables
 ${PSQL_CMD} -d "${DBNAME}" -c "DROP TABLE IF EXISTS countries CASCADE;" > /dev/null 2>&1 || true
 # Drop any remaining ingestion-related tables
 ${PSQL_CMD} -d "${DBNAME}" -c "DROP TABLE IF EXISTS note_comments_api CASCADE;" > /dev/null 2>&1 || true
 ${PSQL_CMD} -d "${DBNAME}" -c "DROP TABLE IF EXISTS notes_api CASCADE;" > /dev/null 2>&1 || true
 ${PSQL_CMD} -d "${DBNAME}" -c "DROP TABLE IF EXISTS note_comments_text_api CASCADE;" > /dev/null 2>&1 || true
 # Drop sync tables (used during planet load)
 ${PSQL_CMD} -d "${DBNAME}" -c "DROP TABLE IF EXISTS note_comments_sync CASCADE;" > /dev/null 2>&1 || true
 ${PSQL_CMD} -d "${DBNAME}" -c "DROP TABLE IF EXISTS note_comments_text_sync CASCADE;" > /dev/null 2>&1 || true
 ${PSQL_CMD} -d "${DBNAME}" -c "DROP TABLE IF EXISTS notes_sync CASCADE;" > /dev/null 2>&1 || true
 # Drop temporary diff tables
 ${PSQL_CMD} -d "${DBNAME}" -c "DROP TABLE IF EXISTS temp_diff_notes_id CASCADE;" > /dev/null 2>&1 || true
 ${PSQL_CMD} -d "${DBNAME}" -c "DROP TABLE IF EXISTS temp_diff_text_comments_id CASCADE;" > /dev/null 2>&1 || true

 # Reset sequences to prevent ID conflicts
 # This prevents duplicate key errors when processPlanetNotes.sh inserts data
 log_info "Resetting sequences to prevent ID conflicts..."
 ${PSQL_CMD} -d "${DBNAME}" -c "
  DO \$\$
  BEGIN
   -- Reset note_comments sequence
   IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'note_comments_id_seq') THEN
    PERFORM setval('note_comments_id_seq', 1, false);
   END IF;

   -- Reset notes sequence
   IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'notes_id_seq') THEN
    PERFORM setval('notes_id_seq', 1, false);
   END IF;

   -- Reset note_comments_text sequence
   IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'note_comments_text_id_seq') THEN
    PERFORM setval('note_comments_text_id_seq', 1, false);
   END IF;

   -- Reset users sequence (if exists)
   IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'users_id_seq') THEN
    PERFORM setval('users_id_seq', 1, false);
   END IF;

   -- Reset sync table sequences (if they exist)
   IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'note_comments_sync_id_seq') THEN
    PERFORM setval('note_comments_sync_id_seq', 1, false);
   END IF;
   IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'note_comments_text_sync_id_seq') THEN
    PERFORM setval('note_comments_text_sync_id_seq', 1, false);
   END IF;
  END \$\$;
 " > /dev/null 2>&1 || true

 log_success "Base tables and sequences cleaned"
}

# Function to run processAPINotes directly
run_processAPINotes() {
 local EXECUTION_NUMBER="${1:-1}"
 log_info "Running processAPINotes.sh (execution #${EXECUTION_NUMBER})..."

 if [[ ! -f "${PROCESS_API_SCRIPT}" ]]; then
  log_error "processAPINotes.sh not found: ${PROCESS_API_SCRIPT}"
  return 1
 fi

 # Make script executable
 chmod +x "${PROCESS_API_SCRIPT}"

 # Set MOCK_NOTES_COUNT and prepare base tables based on execution number
 case "${EXECUTION_NUMBER}" in
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
  # Verify MOCK_NOTES_COUNT is set correctly before execution
  log_info "Verifying MOCK_NOTES_COUNT=${MOCK_NOTES_COUNT} is exported correctly"
  ;;
 *)
  log_error "Invalid execution number: ${EXECUTION_NUMBER}"
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

 # For Execution #1 (planet mode), ensure tables are completely empty
 # This prevents duplicate key errors from residual data
 if [[ ${EXECUTION_NUMBER} -eq 1 ]]; then
  log_info "Ensuring base tables are completely empty before planet load..."
  # Load DBNAME from properties file
  # shellcheck disable=SC1090
  source "${INGESTION_ROOT}/etc/properties.sh"
  local PSQL_CMD="psql"
  if [[ -n "${DB_HOST:-}" ]]; then
   PSQL_CMD="${PSQL_CMD} -h ${DB_HOST} -p ${DB_PORT}"
  fi

  # Truncate tables if they exist (more aggressive than DROP)
  ${PSQL_CMD} -d "${DBNAME}" -c "
   TRUNCATE TABLE IF EXISTS note_comments CASCADE;
   TRUNCATE TABLE IF EXISTS note_comments_text CASCADE;
   TRUNCATE TABLE IF EXISTS notes CASCADE;
   TRUNCATE TABLE IF EXISTS users CASCADE;
   TRUNCATE TABLE IF EXISTS note_comments_api CASCADE;
   TRUNCATE TABLE IF EXISTS notes_api CASCADE;
   TRUNCATE TABLE IF EXISTS note_comments_text_api CASCADE;
   TRUNCATE TABLE IF EXISTS note_comments_sync CASCADE;
   TRUNCATE TABLE IF EXISTS note_comments_text_sync CASCADE;
   TRUNCATE TABLE IF EXISTS notes_sync CASCADE;
   TRUNCATE TABLE IF EXISTS temp_diff_notes_id CASCADE;
   TRUNCATE TABLE IF EXISTS temp_diff_text_comments_id CASCADE;
  " > /dev/null 2>&1 || true

  # Reset sequences after truncate
  ${PSQL_CMD} -d "${DBNAME}" -c "
   DO \$\$
   BEGIN
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'note_comments_id_seq') THEN
     PERFORM setval('note_comments_id_seq', 1, false);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'notes_id_seq') THEN
     PERFORM setval('notes_id_seq', 1, false);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'note_comments_text_id_seq') THEN
     PERFORM setval('note_comments_text_id_seq', 1, false);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'users_id_seq') THEN
     PERFORM setval('users_id_seq', 1, false);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'note_comments_sync_id_seq') THEN
     PERFORM setval('note_comments_sync_id_seq', 1, false);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'note_comments_text_sync_id_seq') THEN
     PERFORM setval('note_comments_text_sync_id_seq', 1, false);
    END IF;
   END \$\$;
  " > /dev/null 2>&1 || true

  log_success "Base tables truncated and sequences reset"
 fi

 # Cleanup any residual XML files from previous executions (especially for execution #4 with 0 notes)
 # This prevents counting stale notes from previous API calls
 if [[ ${EXECUTION_NUMBER} -eq 4 ]] && [[ "${MOCK_NOTES_COUNT:-}" == "0" ]]; then
  log_info "Cleaning up residual XML files before execution #4 (0 notes scenario)..."
  find /tmp -maxdepth 2 -name "OSM-notes-API.xml" -type f -mmin +5 -delete 2> /dev/null || true
  find /tmp -maxdepth 2 -type d -name "processAPINotes_*" -mmin +5 -exec rm -rf {} \; 2> /dev/null || true
 fi

 # Ensure PATH still has hybrid mock directory (should persist, but verify)
 if [[ -n "${HYBRID_MOCK_DIR:-}" ]] && [[ -d "${HYBRID_MOCK_DIR}" ]]; then
  # Verify mock commands are still available
  if [[ ! "${PATH}" == *"${HYBRID_MOCK_DIR}"* ]]; then
   log_info "Restoring hybrid mock directory to PATH..."
   local SYSTEM_PATHS="/usr/bin:/usr/local/bin:/bin"
   local REAL_PSQL_DIR
   REAL_PSQL_DIR=$(dirname "$(command -v psql)")
   export PATH="${HYBRID_MOCK_DIR}:${REAL_PSQL_DIR}:${SYSTEM_PATHS}:${PATH}"
   hash -r 2> /dev/null || true
  fi
 fi

 # Debug: Verify MOCK_NOTES_COUNT is available to child processes
 if [[ -n "${MOCK_NOTES_COUNT:-}" ]]; then
  log_info "DEBUG: MOCK_NOTES_COUNT=${MOCK_NOTES_COUNT} will be passed to processAPINotes.sh"
 else
  log_info "DEBUG: MOCK_NOTES_COUNT is not set (will use default behavior)"
 fi

 # Restore SCRIPT_BASE_DIRECTORY for ingestion scripts (processAPINotes.sh)
 # This is necessary because run_etl() changes it to ANALYTICS_ROOT
 export SCRIPT_BASE_DIRECTORY="${INGESTION_ROOT}"

 # Change to ingestion root directory
 cd "${INGESTION_ROOT}"

 # Run the script and capture output
 log_info "Executing: ${PROCESS_API_SCRIPT}"
 local OUTPUT_FILE="/tmp/processAPINotes_output_${EXECUTION_NUMBER}_$$.log"
 if "${PROCESS_API_SCRIPT}" > "${OUTPUT_FILE}" 2>&1; then
  log_success "processAPINotes.sh completed successfully (execution #${EXECUTION_NUMBER})"
  rm -f "${OUTPUT_FILE}" 2> /dev/null || true
  return 0
 else
  local EXIT_CODE=$?
  log_error "processAPINotes.sh exited with code: ${EXIT_CODE} (execution #${EXECUTION_NUMBER})"

  # Show error context based on exit code
  case ${EXIT_CODE} in
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
  if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
   log_error "Last 50 lines of processAPINotes.sh output:"
   tail -50 "${OUTPUT_FILE}" | while IFS= read -r LINE; do
    log_error "  ${LINE}"
   done
  fi

  # Also check for log files in multiple locations
  local PROCESS_API_LOG=""

  # Check in ingestion logs directory
  if [[ -f "/tmp/osm-notes-ingestion/logs/processing/processAPINotes.log" ]]; then
   PROCESS_API_LOG="/tmp/osm-notes-ingestion/logs/processing/processAPINotes.log"
  fi

  # Check in latest processAPINotes directory
  if [[ -z "${PROCESS_API_LOG}" ]]; then
   local LATEST_LOG_DIR
   LATEST_LOG_DIR=$(find /tmp -maxdepth 1 -type d -name 'processAPINotes_*' -printf '%T@\t%p\n' 2> /dev/null | sort -n | tail -1 | cut -f2- || echo "")
   if [[ -n "${LATEST_LOG_DIR}" ]] && [[ -f "${LATEST_LOG_DIR}/processAPINotes.log" ]]; then
    PROCESS_API_LOG="${LATEST_LOG_DIR}/processAPINotes.log"
   fi
  fi

  if [[ -n "${PROCESS_API_LOG}" ]] && [[ -f "${PROCESS_API_LOG}" ]]; then
   log_error "Last 50 lines of processAPINotes.log (${PROCESS_API_LOG}):"
   tail -50 "${PROCESS_API_LOG}" | while IFS= read -r LINE; do
    log_error "  ${LINE}"
   done

   # Also show errors specifically
   log_error "Errors and warnings from processAPINotes.log:"
   grep -iE "error|fatal|failed|exit code" "${PROCESS_API_LOG}" | tail -20 | while IFS= read -r LINE; do
    log_error "  ${LINE}"
   done || true
  fi

  # Clean up temp file
  rm -f "${OUTPUT_FILE}" 2> /dev/null || true

  return ${EXIT_CODE}
 fi
}

# Function to run ETL
run_etl() {
 local EXECUTION_NUMBER="${1:-1}"
 local SOURCE_TYPE="${2:-unknown}"
 log_info "Running ETL after ${SOURCE_TYPE} execution #${EXECUTION_NUMBER}..."

 # Change to analytics root directory
 cd "${ANALYTICS_ROOT}"

 # Set SCRIPT_BASE_DIRECTORY for ETL to point to analytics root
 # This ensures ETL finds SQL files in the correct location
 export SCRIPT_BASE_DIRECTORY="${ANALYTICS_ROOT}"

 # Load DBNAME from ingestion properties to get ingestion database name
 # shellcheck disable=SC1090
 source "${INGESTION_ROOT}/etc/properties.sh"
 local INGESTION_DBNAME="${DBNAME:-osm_notes}"

 # Export database configuration for ETL
 # In hybrid test mode with separate databases:
 # - Ingestion uses the database from properties.sh
 # - Analytics uses a separate database for testing FDW functionality
 export DBNAME="${INGESTION_DBNAME}"
 export DBNAME_INGESTION="${INGESTION_DBNAME}"
 export DBNAME_DWH="${ANALYTICS_DBNAME}"

 # Export FDW configuration variables if needed
 # These are used by ETL_60_setupFDW.sql when databases are different
 # Use 127.0.0.1 instead of localhost to avoid IPv6 issues with FDW
 export FDW_INGESTION_HOST="${DB_HOST:-127.0.0.1}"
 export FDW_INGESTION_DBNAME="${INGESTION_DBNAME}"
 export FDW_INGESTION_PORT="${DB_PORT:-5432}"
 # For hybrid test, use dedicated FDW user with password
 # This user was created specifically for FDW connections in test environment
 # User: osm_notes_test_remote_user, Password: osm_notes_test_remote_user
 export FDW_INGESTION_USER="${FDW_INGESTION_USER:-osm_notes_test_remote_user}"
 export FDW_INGESTION_PASSWORD_VALUE="${FDW_INGESTION_PASSWORD_VALUE:-osm_notes_test_remote_user}"

 # Set logging level if not already set
 export LOG_LEVEL="${LOG_LEVEL:-INFO}"

 log_info "ETL configuration:"
 log_info "  Ingestion database: ${DBNAME_INGESTION}"
 log_info "  Analytics database: ${DBNAME_DWH}"
 log_info "  FDW will be configured to connect ingestion → analytics"

 # Create directory to save ETL logs permanently
 local TIMESTAMP
 TIMESTAMP=$(date +%Y%m%d_%H%M%S)
 local ETL_LOGS_DIR="${ANALYTICS_ROOT}/tests/logs/etl_execution_${EXECUTION_NUMBER}_${TIMESTAMP}"
 mkdir -p "${ETL_LOGS_DIR}"
 log_info "ETL logs will be saved to: ${ETL_LOGS_DIR}"

 # Get timestamp before ETL execution to find the correct log directory
 local PRE_ETL_TIMESTAMP
 PRE_ETL_TIMESTAMP=$(date +%s)

 # Run ETL in incremental mode (it will auto-detect if it's first execution)
 log_info "Executing: ${ETL_SCRIPT}"

 # Capture ETL output and save it
 # Use PIPESTATUS to capture the actual exit code of ETL_SCRIPT, not tee
 # IMPORTANT: PIPESTATUS resets after each command, so capture it immediately
 # on the same line as the pipeline (using semicolon) before it resets
 "${ETL_SCRIPT}" 2>&1 | tee "${ETL_LOGS_DIR}/ETL_output.log"
 local ETL_EXIT_CODE=${PIPESTATUS[0]}

 # Find and copy ETL log directory created after PRE_ETL_TIMESTAMP
 # ETL creates logs in /tmp/ETL_* directories
 local ETL_LOG_DIR
 ETL_LOG_DIR=$(find /tmp -maxdepth 1 -type d -name "ETL_*" -newermt "@${PRE_ETL_TIMESTAMP}" -print0 2> /dev/null | xargs -0 ls -td 2> /dev/null | head -1)
 if [[ -n "${ETL_LOG_DIR}" ]] && [[ -d "${ETL_LOG_DIR}" ]]; then
  log_info "Copying ETL log directory from ${ETL_LOG_DIR} to ${ETL_LOGS_DIR}..."
  cp -r "${ETL_LOG_DIR}"/* "${ETL_LOGS_DIR}/" 2> /dev/null || true
  log_success "ETL logs saved to: ${ETL_LOGS_DIR}"
 else
  # Fallback: try to find the most recent ETL log directory
  log_info "Could not find ETL log directory by timestamp, trying most recent..."
  ETL_LOG_DIR=$(find /tmp -maxdepth 1 -type d -name "ETL_*" -print0 2> /dev/null | xargs -0 ls -td 2> /dev/null | head -1)
  if [[ -n "${ETL_LOG_DIR}" ]] && [[ -d "${ETL_LOG_DIR}" ]]; then
   log_info "Copying most recent ETL log directory from ${ETL_LOG_DIR} to ${ETL_LOGS_DIR}..."
   cp -r "${ETL_LOG_DIR}"/* "${ETL_LOGS_DIR}/" 2> /dev/null || true
   log_success "ETL logs saved to: ${ETL_LOGS_DIR}"
  fi
 fi

 # Also try to find and copy datamart logs created after PRE_ETL_TIMESTAMP
 find /tmp -maxdepth 1 -type d -name "datamart*" -newermt "@${PRE_ETL_TIMESTAMP}" 2> /dev/null | while read -r DATAMART_LOG_DIR; do
  if [[ -n "${DATAMART_LOG_DIR}" ]] && [[ -d "${DATAMART_LOG_DIR}" ]]; then
   log_info "Copying datamart log directory from ${DATAMART_LOG_DIR} to ${ETL_LOGS_DIR}..."
   cp -r "${DATAMART_LOG_DIR}" "${ETL_LOGS_DIR}/" 2> /dev/null || true
  fi
 done

 if [[ ${ETL_EXIT_CODE} -eq 0 ]]; then
  log_success "ETL completed successfully after ${SOURCE_TYPE} execution #${EXECUTION_NUMBER}"
  return 0
 else
  log_error "ETL failed with exit code: ${ETL_EXIT_CODE} after ${SOURCE_TYPE} execution #${EXECUTION_NUMBER}"
  return "${ETL_EXIT_CODE}"
 fi
}

# Function to execute one processAPINotes run and then ETL
# This function will be called 4 times with different configurations
execute_processAPINotes_and_etl() {
 local EXECUTION_NUMBER="${1:-1}"
 local EXIT_CODE=0
 local EXECUTION_START_TIME
 EXECUTION_START_TIME=$(date +%s)

 log_info ""
 log_info "=========================================="
 log_info "=== EXECUTION #${EXECUTION_NUMBER} ==="
 log_info "=========================================="
 log_info ""

 # Determine source type
 local SOURCE_TYPE
 if [[ ${EXECUTION_NUMBER} -eq 1 ]]; then
  SOURCE_TYPE="planet"
  log_info "Source: PLANET (processPlanetNotes.sh --base will be called)"
 else
  SOURCE_TYPE="api"
  log_info "Source: API (only processAPINotes.sh, no planet)"
 fi

 # Run processAPINotes
 log_info "--- Step 1: Running processAPINotes.sh (${SOURCE_TYPE}) ---"
 local PROCESS_START_TIME
 PROCESS_START_TIME=$(date +%s)
 if ! run_processAPINotes "${EXECUTION_NUMBER}"; then
  log_error "processAPINotes (${SOURCE_TYPE}) execution #${EXECUTION_NUMBER} failed"
  return 1
 fi
 local PROCESS_END_TIME
 PROCESS_END_TIME=$(date +%s)
 local PROCESS_DURATION=$((PROCESS_END_TIME - PROCESS_START_TIME))
 log_success "processAPINotes (${SOURCE_TYPE}) execution #${EXECUTION_NUMBER} completed"
 log_info "⏱️  TIME: processAPINotes took ${PROCESS_DURATION} seconds ($(date -d "@${PROCESS_START_TIME}" +%H:%M:%S) - $(date -d "@${PROCESS_END_TIME}" +%H:%M:%S))"

 # Wait a moment before running ETL
 log_info "Waiting 2 seconds before running ETL..."
 sleep 2

 # For execution #1 (planet/base), clean dwh schema before ETL
 # Run ETL after processAPINotes
 # Clean dwh schema JUST BEFORE ETL to ensure INITIAL LOAD is executed
 # This must be done right before the ETL to prevent any process from recreating the schema
 if [[ ${EXECUTION_NUMBER} -eq 1 ]]; then
  log_info "Cleaning dwh schema JUST BEFORE ETL #1 to ensure INITIAL LOAD..."
  # Load DB connection parameters from properties file
  # shellcheck disable=SC1090
  source "${INGESTION_ROOT}/etc/properties.sh"
  local PSQL_CMD="psql"
  if [[ -n "${DB_HOST:-}" ]]; then
   PSQL_CMD="${PSQL_CMD} -h ${DB_HOST} -p ${DB_PORT:-5432}"
  fi
  # Use DB_USER_DWH if available (for analytics DB), otherwise DB_USER_INGESTION
  if [[ -n "${DB_USER_DWH:-}" ]]; then
   PSQL_CMD="${PSQL_CMD} -U ${DB_USER_DWH}"
  elif [[ -n "${DB_USER_INGESTION:-}" ]]; then
   PSQL_CMD="${PSQL_CMD} -U ${DB_USER_INGESTION}"
  fi
  # Use analytics database (where dwh schema exists)
  # Force disconnect any active connections
  ${PSQL_CMD} -d "${ANALYTICS_DBNAME}" -c "
   SELECT pg_terminate_backend(pg_stat_activity.pid)
   FROM pg_stat_activity
   WHERE pg_stat_activity.datname = '${ANALYTICS_DBNAME}'
    AND pid <> pg_backend_pid()
    AND state = 'active';
  " > /dev/null 2>&1 || true
  # Drop the schema (CASCADE will also drop dwh.properties)
  # First, verify schema exists
  local SCHEMA_EXISTS_BEFORE
  SCHEMA_EXISTS_BEFORE=$(${PSQL_CMD} -d "${ANALYTICS_DBNAME}" -tAqc "
   SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'dwh';
  " 2> /dev/null || echo "0")
  if [[ "${SCHEMA_EXISTS_BEFORE}" != "0" ]]; then
   log_info "dwh schema exists in analytics database, dropping it..."
   # Drop the schema with explicit error handling
   if ! ${PSQL_CMD} -d "${ANALYTICS_DBNAME}" -c "DROP SCHEMA dwh CASCADE;" 2>&1; then
    log_error "Failed to drop dwh schema, trying again after terminating connections..."
    # Terminate all connections again
    ${PSQL_CMD} -d "${ANALYTICS_DBNAME}" -c "
     SELECT pg_terminate_backend(pg_stat_activity.pid)
     FROM pg_stat_activity
     WHERE pg_stat_activity.datname = '${ANALYTICS_DBNAME}'
      AND pid <> pg_backend_pid();
    " > /dev/null 2>&1 || true
    sleep 1
    ${PSQL_CMD} -d "${ANALYTICS_DBNAME}" -c "DROP SCHEMA dwh CASCADE;" > /dev/null 2>&1 || true
   fi
  fi
  # Verify the schema was actually dropped
  local SCHEMA_EXISTS_AFTER
  SCHEMA_EXISTS_AFTER=$(${PSQL_CMD} -d "${ANALYTICS_DBNAME}" -tAqc "
   SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'dwh';
  " 2> /dev/null || echo "1")
  if [[ "${SCHEMA_EXISTS_AFTER}" != "0" ]]; then
   log_error "dwh schema still exists after DROP (count: ${SCHEMA_EXISTS_AFTER})"
   log_error "This may prevent INITIAL LOAD from executing"
  else
   log_success "dwh schema successfully dropped from analytics database"
  fi
  log_success "dwh schema cleaned before ETL #1"
 fi
 log_info "--- Step 2: Running ETL after ${SOURCE_TYPE} execution #${EXECUTION_NUMBER} ---"
 local ETL_START_TIME
 ETL_START_TIME=$(date +%s)
 if ! run_etl "${EXECUTION_NUMBER}" "${SOURCE_TYPE}"; then
  log_error "ETL failed after ${SOURCE_TYPE} execution #${EXECUTION_NUMBER}"
  EXIT_CODE=1
 fi
 local ETL_END_TIME
 ETL_END_TIME=$(date +%s)
 local ETL_DURATION=$((ETL_END_TIME - ETL_START_TIME))
 log_success "ETL completed after ${SOURCE_TYPE} execution #${EXECUTION_NUMBER}"
 log_info "⏱️  TIME: ETL took ${ETL_DURATION} seconds ($(date -d "@${ETL_START_TIME}" +%H:%M:%S) - $(date -d "@${ETL_END_TIME}" +%H:%M:%S))"

 # Calculate total execution time
 local EXECUTION_END_TIME
 EXECUTION_END_TIME=$(date +%s)
 local EXECUTION_DURATION=$((EXECUTION_END_TIME - EXECUTION_START_TIME))
 log_info "⏱️  TIME: Total execution #${EXECUTION_NUMBER} took ${EXECUTION_DURATION} seconds ($(date -d "@${EXECUTION_START_TIME}" +%H:%M:%S) - $(date -d "@${EXECUTION_END_TIME}" +%H:%M:%S))"

 # Wait a moment before next execution
 log_info "Waiting 2 seconds before next execution..."
 sleep 2
 log_info ""

 return ${EXIT_CODE}
}

# Main function
main() {
 local EXIT_CODE=0
 local MAIN_START_TIME
 MAIN_START_TIME=$(date +%s)

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
 log_info "Database configuration:"
 log_info "  Ingestion DB: Uses DBNAME from properties.sh"
 log_info "  Analytics DB: ${ANALYTICS_DBNAME} (separate database)"
 log_info "  FDW: Enabled (databases are different)"
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

 # Load DBNAME from ingestion properties to ensure we use the correct database
 # shellcheck disable=SC1090
 source "${INGESTION_ROOT}/etc/properties.sh"
 local INGESTION_DBNAME="${DBNAME:-osm_notes}"

 # Ensure required extensions are installed in ingestion database
 # These are required by processAPINotes.sh (from OSM-Notes-Ingestion system)
 # Note: The ETL itself does NOT need these extensions as it only copies necessary columns (without geom)
 log_info "Ensuring required extensions are installed in ingestion database (required by processAPINotes.sh)..."
 local PSQL_CMD="psql"
 if [[ -n "${DB_HOST:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -h ${DB_HOST} -p ${DB_PORT:-5432}"
 fi
 # Use DB_USER_INGESTION if available
 if [[ -n "${DB_USER_INGESTION:-}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U ${DB_USER_INGESTION}"
 fi

 # Install PostGIS extension if not already installed
 if ! ${PSQL_CMD} -d "${INGESTION_DBNAME}" -tAc "SELECT 1 FROM pg_extension WHERE extname = 'postgis';" 2> /dev/null | grep -q 1; then
  log_info "Installing PostGIS extension in ${INGESTION_DBNAME}..."
  if ${PSQL_CMD} -d "${INGESTION_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" > /dev/null 2>&1; then
   log_success "PostGIS extension installed successfully"
  else
   log_error "Failed to install PostGIS extension"
   exit 1
  fi
 else
  log_success "PostGIS extension already installed"
 fi

 # Install btree_gist extension if not already installed
 if ! ${PSQL_CMD} -d "${INGESTION_DBNAME}" -tAc "SELECT 1 FROM pg_extension WHERE extname = 'btree_gist';" 2> /dev/null | grep -q 1; then
  log_info "Installing btree_gist extension in ${INGESTION_DBNAME}..."
  if ${PSQL_CMD} -d "${INGESTION_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS btree_gist;" > /dev/null 2>&1; then
   log_success "btree_gist extension installed successfully"
  else
   log_error "Failed to install btree_gist extension"
   exit 1
  fi
 else
  log_success "btree_gist extension already installed"
 fi

 # Setup analytics database (separate from ingestion database)
 # This enables testing of FDW functionality
 log_info "Setting up separate analytics database for hybrid test..."
 if ! setup_analytics_database; then
  log_error "Failed to setup analytics database"
  exit 1
 fi

 # Clean ingestion base tables to start from scratch
 # This ensures no residual data from previous failed executions
 log_info "Cleaning ingestion base tables to start from scratch..."
 drop_base_tables

 # Setup environment variables
 export LOG_LEVEL="${LOG_LEVEL:-INFO}"
 export CLEAN="${CLEAN:-false}"

 # Execute 4 times: 1 planet + 3 API
 for I in 1 2 3 4; do
  if ! execute_processAPINotes_and_etl "${I}"; then
   log_error "Execution #${I} failed"
   EXIT_CODE=1
   # Execution #1 (planet/base) is critical - stop if it fails
   # Other executions can continue for testing purposes
   if [[ ${I} -eq 1 ]]; then
    log_error "Execution #1 (planet/base) failed - this is critical, stopping execution"
    log_error "Subsequent executions depend on base data from execution #1"
    break
   else
    log_error "Execution #${I} failed, but continuing with next execution..."
   fi
  fi
 done

 local MAIN_END_TIME
 MAIN_END_TIME=$(date +%s)
 local MAIN_DURATION=$((MAIN_END_TIME - MAIN_START_TIME))

 if [[ ${EXIT_CODE} -eq 0 ]]; then
  log_success "All executions completed successfully"
 else
  log_error "Some executions failed"
 fi

 log_info ""
 log_info "═══════════════════════════════════════════════════════════"
 log_info "  TIMING SUMMARY"
 log_info "═══════════════════════════════════════════════════════════"
 log_info "⏱️  Total time: ${MAIN_DURATION} seconds ($(date -d "@${MAIN_START_TIME}" +%H:%M:%S) - $(date -d "@${MAIN_END_TIME}" +%H:%M:%S))"
 log_info "   ($((MAIN_DURATION / 60)) minutes and $((MAIN_DURATION % 60)) seconds)"
 log_info ""

 # Cleanup will be done by trap
 exit ${EXIT_CODE}
}

# Run main function
main "$@"

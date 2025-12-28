#!/bin/bash

# Cleanup script for OSM-Notes-Analytics DWH components.
# This script removes data warehouse objects from the database and temporary files.
#
# IMPORTANT: Default behavior removes ALL data warehouse data AND temporary files!
# Use --dry-run first to see what will be removed.
# Use --remove-temp-files for safe cleanup of temporary files only.
#
# Usage examples:
# * ./cleanupDWH.sh                    # Full cleanup - REMOVES ALL DATA!
# * ./cleanupDWH.sh --remove-all-data  # Remove DWH schema and data only
# * ./cleanupDWH.sh --remove-temp-files # Remove only temporary files (/tmp)
# * ./cleanupDWH.sh --dry-run          # Show what would be done (safe)
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
#
# For contributing, please execute these commands before submitting:
# * shellcheck -x -o all cleanupDWH.sh
# * shfmt -w -i 1 -sr -bn cleanupDWH.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-14
VERSION="2025-10-14"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with a non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Validate that we're in the correct project directory
if [[ ! -d "${SCRIPT_BASE_DIRECTORY}/lib/osm-common" ]]; then
 echo "ERROR: Cannot find project directory structure." >&2
 echo "Expected directory: ${SCRIPT_BASE_DIRECTORY}/lib/osm-common" >&2
 echo "Current script location: ${BASH_SOURCE[0]}" >&2
 echo "Please ensure you're running this script from the correct project directory." >&2
 exit 1
fi

# Loads the global properties.
# shellcheck disable=SC1091
if [[ ! -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh" ]]; then
 echo "ERROR: Required file not found: ${SCRIPT_BASE_DIRECTORY}/etc/properties.sh" >&2
 echo "Please ensure you're running this script from the correct project directory." >&2
 exit 1
fi
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
# Load local properties if they exist (overrides global settings)
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local" ]]; then
 # shellcheck disable=SC1091
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local"
fi

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME

# Temporary directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"

# Cleanup mode
declare CLEANUP_MODE="${1:-all}"

# Load common functions
# shellcheck disable=SC1091
if [[ ! -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" ]]; then
 echo "ERROR: Required file not found: ${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" >&2
 echo "Please ensure you're running this script from the correct project directory." >&2
 exit 1
fi
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
if [[ ! -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh" ]]; then
 echo "ERROR: Required file not found: ${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh" >&2
 echo "Please ensure you're running this script from the correct project directory." >&2
 exit 1
fi
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
if [[ ! -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh" ]]; then
 echo "ERROR: Required file not found: ${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh" >&2
 echo "Please ensure you're running this script from the correct project directory." >&2
 exit 1
fi
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"

# Initialize logger
__start_logger

# SQL script files for cleanup
declare -r SQL_REMOVE_STAGING="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_removeStagingObjects.sql"
declare -r SQL_REMOVE_DATAMARTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_12_removeDatamartObjects.sql"
declare -r SQL_REMOVE_DWH="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_13_removeDWHObjects.sql"

###########
# FUNCTIONS

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This script removes data warehouse components from the database and temporary files."
 echo
 echo "Usage:"
 echo "  ${0} [OPTIONS]"
 echo
 echo "Options:"
 echo "  --remove-all-data   Remove DWH schema, tables, functions, and data (DESTRUCTIVE)"
 echo "  --remove-temp-files Remove only temporary files from /tmp (SAFE)"
 echo "  --dry-run           Show what would be done without executing (SAFE)"
 echo "  --all, -a           Full cleanup - REMOVES ALL DATA! (same as default)"
 echo "  --help, -h          Show this help"
 echo
 echo "Examples:"
 echo "  ${0}                           # Full cleanup - REMOVES ALL DATA!"
 echo "  ${0} --all                     # Full cleanup - REMOVES ALL DATA!"
 echo "  ${0} -a                        # Full cleanup - REMOVES ALL DATA!"
 echo "  ${0} --remove-all-data         # Remove DWH schema and data only"
 echo "  ${0} --remove-temp-files       # Remove temp files only (safe)"
 echo "  ${0} --dry-run                 # Show what would be done (safe)"
 echo
 echo "Database configuration from etc/properties.sh:"
 echo "  Database: ${DBNAME_DWH:-${DBNAME:-not set}}"
 echo "  User: ${DB_USER:-not set}"
 echo
 echo "WARNING: Default behavior removes ALL data warehouse data AND temporary files!"
 echo "Use --dry-run first to see what will be removed."
 echo "Use --remove-temp-files for safe cleanup of temporary files only."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Asks for confirmation before destructive operations.
function __confirm_destructive_operation {
 __log_start
 local operation="${1}"
 local target_db="${2}"

 __logi "Performing destructive operation: ${operation} on database: ${target_db}"
 __logi "Skipping confirmation (non-interactive mode)"
 __log_finish
}

# Checks if database exists.
function __check_database {
 __log_start
 local target_db="${1}"

 __logi "Checking if database exists: ${target_db}"

 if psql -lqt | cut -d \| -f 1 | grep -qw "${target_db}"; then
  __logi "Database ${target_db} exists"
  __log_finish
  return 0
 else
  __loge "Database ${target_db} does not exist"
  __log_finish
  return 1
 fi
}

# Executes a SQL cleanup script.
function __execute_cleanup_script {
 __log_start
 local target_db="${1}"
 local script_path="${2}"
 local script_name="${3}"

 __logi "Executing ${script_name}: ${script_path}"

 if [[ ! -f "${script_path}" ]]; then
  __logw "Script not found: ${script_path} - Skipping"
  __log_finish
  return 0
 fi

 # Validate SQL script structure
 if ! __validate_sql_structure "${script_path}"; then
  __loge "ERROR: SQL script validation failed: ${script_path}"
  __log_finish
  return 1
 fi

 if psql -d "${target_db}" -f "${script_path}" 2>&1; then
  __logi "SUCCESS: ${script_name} completed"
  __log_finish
  return 0
 else
  __loge "FAILED: ${script_name} failed"
  __log_finish
  return 1
 fi
}

# Removes DWH schema and all objects.
function __cleanup_dwh_schema {
 __log_start
 local target_db="${1}"

 __logi "=== REMOVING DWH SCHEMA AND OBJECTS ==="

 # Remove staging objects
 __logi "Step 1: Removing staging schema"
 __execute_cleanup_script "${target_db}" "${SQL_REMOVE_STAGING}" "Staging Schema"

 # Remove datamart objects
 __logi "Step 2: Removing datamart objects"
 __execute_cleanup_script "${target_db}" "${SQL_REMOVE_DATAMARTS}" "Datamart Objects"

 # Remove DWH objects
 __logi "Step 3: Removing DWH schema"
 __execute_cleanup_script "${target_db}" "${SQL_REMOVE_DWH}" "DWH Schema"

 __logi "=== DWH CLEANUP COMPLETED ==="
 __log_finish
}

# Removes temporary files.
function __cleanup_temp_files {
 __log_start
 __logi "=== CLEANING UP TEMPORARY FILES ==="

 local TEMP_PATTERNS=(
  "ETL_*"
  "datamartCountries_*"
  "datamartUsers_*"
  "profile_*"
  "cleanupDWH_*"
 )

 local REMOVED_COUNT=0

 for PATTERN in "${TEMP_PATTERNS[@]}"; do
  if [[ -d "/tmp" ]]; then
   # Find and remove matching directories
   while IFS= read -r -d '' DIR; do
    __logd "Removing: ${DIR}"
    rm -rf "${DIR}"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
   done < <(find /tmp -maxdepth 1 -name "${PATTERN}" -type d -print0 2> /dev/null)
  fi
 done

 if [[ ${REMOVED_COUNT} -gt 0 ]]; then
  __logi "Removed ${REMOVED_COUNT} temporary directories"
 else
  __logi "No temporary directories found"
 fi

 __logi "=== TEMP FILES CLEANUP COMPLETED ==="
 __log_finish
}

# Dry run - shows what would be done.
function __dry_run {
 __log_start
 local target_db="${1}"
 local mode="${2}"

 __logi "=== DRY RUN MODE - No changes will be made ==="
 __logi "Database: ${target_db}"
 __logi "Cleanup mode: ${mode}"
 echo
 echo "Would execute the following operations:"
 echo

 if [[ "${mode}" == "all" ]] || [[ "${mode}" == "dwh" ]]; then
  echo "⚠️  DESTRUCTIVE OPERATIONS (requires confirmation):"
  echo "1. Check if database '${target_db}' exists"
  echo "2. Ask for user confirmation before proceeding"
  echo "3. Remove staging schema (${SQL_REMOVE_STAGING})"
  echo "4. Remove datamart objects (${SQL_REMOVE_DATAMARTS})"
  echo "5. Remove DWH schema and ALL DATA (${SQL_REMOVE_DWH})"
  echo "   - Tables: facts, dimension_*, iso_country_codes"
  echo "   - Functions: get_*, update_*, refresh_*"
  echo "   - Triggers: update_days_to_resolution"
  echo
 fi

 if [[ "${mode}" == "all" ]] || [[ "${mode}" == "temp" ]]; then
  echo "✅ SAFE OPERATIONS (no confirmation needed):"
  echo "6. Remove temporary files from /tmp:"
  echo "   - /tmp/ETL_*"
  echo "   - /tmp/datamartCountries_*"
  echo "   - /tmp/datamartUsers_*"
  echo "   - /tmp/profile_*"
  echo "   - /tmp/cleanupDWH_*"
  echo
 fi

 echo "💡 RECOMMENDATIONS:"
 echo "   - Use --remove-temp-files for safe cleanup of temporary files only"
 echo "   - Use --remove-all-data to remove only DWH data (still destructive)"
 echo "   - Always backup your data before running destructive operations"
 echo
 __logi "=== DRY RUN COMPLETED ==="
 __log_finish
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 __logi "=== CHECKING PREREQUISITES ==="

 __checkPrereqsCommands

 # Validate SQL script files
 local SQL_FILES=(
  "${SQL_REMOVE_STAGING}"
  "${SQL_REMOVE_DATAMARTS}"
  "${SQL_REMOVE_DWH}"
 )

 for SQL_FILE in "${SQL_FILES[@]}"; do
  if [[ -f "${SQL_FILE}" ]]; then
   if ! __validate_sql_structure "${SQL_FILE}"; then
    __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
    exit "${ERROR_MISSING_LIBRARY}"
   fi
  else
   __logw "SQL file not found: ${SQL_FILE}"
  fi
 done

 __logi "=== PREREQUISITES CHECK COMPLETED ==="
 __log_finish
}

# Function that activates the error trap.
function __trapOn() {
 __log_start
 trap '{
  local ERROR_LINE="${LINENO}"
  local ERROR_COMMAND="${BASH_COMMAND}"
  local ERROR_EXIT_CODE="$?"

  if [[ "${ERROR_EXIT_CODE}" -ne 0 ]]; then
   local MAIN_SCRIPT_NAME
   MAIN_SCRIPT_NAME=$(basename "${0}" .sh)

   printf "%s ERROR: The script %s did not finish correctly. Temporary directory: ${TMP_DIR:-} - Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}" "${ERROR_LINE}";
   printf "ERROR: Failed command: %s (exit code: %d)\n" "${ERROR_COMMAND}" "${ERROR_EXIT_CODE}";
   exit "${ERROR_EXIT_CODE}";
  fi;
 }' ERR
 trap '{
  local MAIN_SCRIPT_NAME
  MAIN_SCRIPT_NAME=$(basename "${0}" .sh)

  printf "%s WARN: The script %s was terminated. Temporary directory: ${TMP_DIR:-}\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}";
  exit "${ERROR_GENERAL}";
 }' SIGINT SIGTERM
 __log_finish
}

######
# MAIN

function main() {
 __log_start
 __logi "Preparing cleanup environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Cleanup mode: ${CLEANUP_MODE}."

 if [[ "${CLEANUP_MODE}" == "-h" ]] || [[ "${CLEANUP_MODE}" == "--help" ]]; then
  __show_help
 fi

 __checkPrereqs

 # Parse mode from CLEANUP_MODE (first argument)
 # Use DBNAME_DWH if set, otherwise fallback to DBNAME
 local TARGET_DB="${DBNAME_DWH:-${DBNAME:-notes_dwh}}"
 local MODE="all"

 if [[ "${CLEANUP_MODE}" == "--dry-run" ]]; then
  MODE="dry-run"
 elif [[ "${CLEANUP_MODE}" == "--remove-all-data" ]]; then
  MODE="dwh"
 elif [[ "${CLEANUP_MODE}" == "--remove-temp-files" ]]; then
  MODE="temp"
 elif [[ "${CLEANUP_MODE}" == "--all" ]] || [[ "${CLEANUP_MODE}" == "all" ]] || [[ "${CLEANUP_MODE}" == "-a" ]]; then
  MODE="all"
 elif [[ "${CLEANUP_MODE}" != "" ]]; then
  echo "ERROR: Invalid parameter: ${CLEANUP_MODE}"
  echo "Valid options: --remove-all-data, --remove-temp-files, --dry-run, --all, -a, --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi

 __logi "Target database: ${TARGET_DB}"
 __logi "Cleanup mode: ${MODE}"

 # Handle dry-run mode
 if [[ "${MODE}" == "dry-run" ]]; then
  __dry_run "${TARGET_DB}" "all"
  __log_finish
  return 0
 fi

 # Handle temp-only mode
 if [[ "${MODE}" == "temp" ]]; then
  __cleanup_temp_files
  __log_finish
  return 0
 fi

 # Check database exists for DWH cleanup
 if [[ "${MODE}" == "all" ]] || [[ "${MODE}" == "dwh" ]]; then
  if ! __check_database "${TARGET_DB}"; then
   __loge "ERROR: Database ${TARGET_DB} does not exist. Cannot cleanup DWH objects."
   __loge "Use --remove-temp-files to clean only temporary files."
   exit 1
  fi
 fi

 # Set up error trap
 __trapOn

 # Execute cleanup based on mode
 if [[ "${MODE}" == "all" ]] || [[ "${MODE}" == "dwh" ]]; then
  __confirm_destructive_operation "Remove DWH schema and data" "${TARGET_DB}"
  __cleanup_dwh_schema "${TARGET_DB}"
 fi

 if [[ "${MODE}" == "all" ]]; then
  __logi "Proceeding to clean temporary files..."
  __cleanup_temp_files
 fi

 __logi "Cleanup completed successfully."
 __log_finish
}

# Allows other users to read the directory.
chmod go+x "${TMP_DIR}"

# Execute main function
main "${1:-}"

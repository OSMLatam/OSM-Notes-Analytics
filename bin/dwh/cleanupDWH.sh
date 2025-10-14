#!/bin/bash

# Cleanup script for OSM-Notes-Analytics DWH components.
# This script removes all data warehouse objects from the database.
#
# Usage examples:
# * ./cleanupDWH.sh                    # Full cleanup (default database)
# * ./cleanupDWH.sh osm_notes          # Full cleanup (specific database)
# * ./cleanupDWH.sh --dwh-only         # Remove only DWH schema
# * ./cleanupDWH.sh --temp-only        # Remove only temporary files
# * ./cleanupDWH.sh --dry-run          # Show what would be done
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

# Loads the global properties.
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME

# Temporary directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"

# Log file for output.
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Cleanup mode
declare CLEANUP_MODE="${1:-all}"

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
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
 echo "This script removes all data warehouse components from the database."
 echo
 echo "Usage:"
 echo "  ${0} [OPTIONS] [database_name]"
 echo
 echo "Options:"
 echo "  --all               Remove all DWH components (default)"
 echo "  --dwh-only          Remove only DWH schema and objects"
 echo "  --temp-only         Remove only temporary files"
 echo "  --dry-run           Show what would be done without executing"
 echo "  --help, -h          Show this help"
 echo
 echo "Examples:"
 echo "  ${0}                      # Full cleanup (default database)"
 echo "  ${0} osm_notes            # Full cleanup (specific database)"
 echo "  ${0} --dwh-only           # Remove DWH schema only"
 echo "  ${0} --temp-only          # Remove temp files only"
 echo "  ${0} --dry-run osm_notes  # Show what would be done"
 echo
 echo "Database configuration from etc/properties.sh:"
 echo "  Database: ${DBNAME:-not set}"
 echo "  User: ${DB_USER:-not set}"
 echo
 echo "WARNING: This will permanently remove all data warehouse data!"
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks if database exists.
function __check_database {
 __log_start
 local TARGET_DB="${1}"

 __logi "Checking if database exists: ${TARGET_DB}"

 if psql -lqt | cut -d \| -f 1 | grep -qw "${TARGET_DB}"; then
  __logi "Database ${TARGET_DB} exists"
  __log_finish
  return 0
 else
  __loge "Database ${TARGET_DB} does not exist"
  __log_finish
  return 1
 fi
}

# Executes a SQL cleanup script.
function __execute_cleanup_script {
 __log_start
 local TARGET_DB="${1}"
 local SCRIPT_PATH="${2}"
 local SCRIPT_NAME="${3}"

 __logi "Executing ${SCRIPT_NAME}: ${SCRIPT_PATH}"

 if [[ ! -f "${SCRIPT_PATH}" ]]; then
  __logw "Script not found: ${SCRIPT_PATH} - Skipping"
  __log_finish
  return 0
 fi

 # Validate SQL script structure
 if ! __validate_sql_structure "${SCRIPT_PATH}"; then
  __loge "ERROR: SQL script validation failed: ${SCRIPT_PATH}"
  __log_finish
  return 1
 fi

 if psql -d "${TARGET_DB}" -f "${SCRIPT_PATH}" 2>&1; then
  __logi "SUCCESS: ${SCRIPT_NAME} completed"
  __log_finish
  return 0
 else
  __loge "FAILED: ${SCRIPT_NAME} failed"
  __log_finish
  return 1
 fi
}

# Removes DWH schema and all objects.
function __cleanup_dwh_schema {
 __log_start
 local TARGET_DB="${1}"

 __logi "=== REMOVING DWH SCHEMA AND OBJECTS ==="

 # Remove staging objects
 __logi "Step 1: Removing staging schema"
 __execute_cleanup_script "${TARGET_DB}" "${SQL_REMOVE_STAGING}" "Staging Schema"

 # Remove datamart objects
 __logi "Step 2: Removing datamart objects"
 __execute_cleanup_script "${TARGET_DB}" "${SQL_REMOVE_DATAMARTS}" "Datamart Objects"

 # Remove DWH objects
 __logi "Step 3: Removing DWH schema"
 __execute_cleanup_script "${TARGET_DB}" "${SQL_REMOVE_DWH}" "DWH Schema"

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
 local TARGET_DB="${1}"
 local MODE="${2}"

 __logi "=== DRY RUN MODE - No changes will be made ==="
 __logi "Database: ${TARGET_DB}"
 __logi "Cleanup mode: ${MODE}"
 echo
 echo "Would execute the following operations:"
 echo

 if [[ "${MODE}" == "all" ]] || [[ "${MODE}" == "dwh" ]]; then
  echo "1. Check if database '${TARGET_DB}' exists"
  echo "2. Remove staging schema (${SQL_REMOVE_STAGING})"
  echo "3. Remove datamart objects (${SQL_REMOVE_DATAMARTS})"
  echo "4. Remove DWH schema (${SQL_REMOVE_DWH})"
 fi

 if [[ "${MODE}" == "all" ]] || [[ "${MODE}" == "temp" ]]; then
  echo "5. Remove temporary files:"
  echo "   - /tmp/ETL_*"
  echo "   - /tmp/datamartCountries_*"
  echo "   - /tmp/datamartUsers_*"
  echo "   - /tmp/profile_*"
  echo "   - /tmp/cleanupDWH_*"
 fi

 echo
 __logi "=== DRY RUN COMPLETED ==="
 __log_finish
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 __logi "=== CHECKING PREREQUISITES ==="

 if [[ "${CLEANUP_MODE}" != "" ]] \
  && [[ "${CLEANUP_MODE}" != "--all" ]] \
  && [[ "${CLEANUP_MODE}" != "--dwh-only" ]] \
  && [[ "${CLEANUP_MODE}" != "--temp-only" ]] \
  && [[ "${CLEANUP_MODE}" != "--dry-run" ]] \
  && [[ "${CLEANUP_MODE}" != "--help" ]] \
  && [[ "${CLEANUP_MODE}" != "-h" ]] \
  && [[ "${CLEANUP_MODE}" != "all" ]]; then
  # Could be a database name
  if ! psql -lqt | cut -d \| -f 1 | grep -qw "${CLEANUP_MODE}"; then
   echo "ERROR: Invalid parameter: ${CLEANUP_MODE}"
   echo "Valid options: --all, --dwh-only, --temp-only, --dry-run, --help"
   echo "Or provide a database name"
   exit "${ERROR_INVALID_ARGUMENT}"
  fi
 fi

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
  exit ${ERROR_GENERAL};
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
 local TARGET_DB=""
 local MODE="all"
 local SECOND_ARG="${1:-}"

 if [[ "${CLEANUP_MODE}" == "--dry-run" ]]; then
  MODE="dry-run"
  TARGET_DB="${SECOND_ARG:-${DBNAME}}"
 elif [[ "${CLEANUP_MODE}" == "--dwh-only" ]]; then
  MODE="dwh"
  TARGET_DB="${SECOND_ARG:-${DBNAME}}"
 elif [[ "${CLEANUP_MODE}" == "--temp-only" ]]; then
  MODE="temp"
  TARGET_DB="${SECOND_ARG:-${DBNAME}}"
 elif [[ "${CLEANUP_MODE}" == "--all" ]] || [[ "${CLEANUP_MODE}" == "all" ]]; then
  MODE="all"
  TARGET_DB="${SECOND_ARG:-${DBNAME}}"
 else
  # Assume it's a database name
  TARGET_DB="${CLEANUP_MODE}"
  MODE="all"
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
   __loge "Use --temp-only to clean only temporary files."
   exit 1
  fi
 fi

 # Set up error trap
 __trapOn

 # Execute cleanup based on mode
 if [[ "${MODE}" == "all" ]] || [[ "${MODE}" == "dwh" ]]; then
  __cleanup_dwh_schema "${TARGET_DB}"
 fi

 if [[ "${MODE}" == "all" ]]; then
  __cleanup_temp_files
 fi

 __logi "Cleanup completed successfully."
 __log_finish
}

# Allows other users to read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILENAME}"
 main "${2:-}" >> "${LOG_FILENAME}"
 if [[ "${CLEAN:-true}" == true ]]; then
  if [[ -f "${LOG_FILENAME}" ]]; then
   mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
  fi
  if [[ -d "${TMP_DIR}" ]]; then
   rmdir "${TMP_DIR}" 2> /dev/null || true
  fi
 fi
else
 main "${2:-}"
fi

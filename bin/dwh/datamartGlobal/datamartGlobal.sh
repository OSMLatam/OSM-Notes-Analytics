#!/bin/bash

# Creates a datamart for global data with pre-computed analytics.
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/datamartGlobal_* | tail -1)/datamartGlobal.log
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
#
# For contributing, please execute these commands at the end:
# * shellcheck -x -o all datamartGlobal.sh
# * shfmt -w -i 1 -sr -bn datamartGlobal.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-20
VERSION="2025-01-20"

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
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." \
 &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Loads the global properties.
# shellcheck disable=SC1091
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
# Log file for output.
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Lock file for single execution.
declare LOCK
LOCK="${TMP_DIR}/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
if [[ -z "${PROCESS_TYPE:-}" ]]; then
 declare -r PROCESS_TYPE=${1:-}
fi

# Name of the SQL script that contains the objects to create in the DB.
declare -r CHECK_OBJECTS_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_11_checkTables.sql"

# Name of the SQL script that contains the tables to create in the DB.
declare -r CREATE_TABLES_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql"

# Name of the SQL script that contains the ETL process.
declare -r POPULATE_FILE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartGlobal/datamartGlobal_31_populate.sql"

###########
# FUNCTIONS

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This script populates the global datamart with pre-computed analytics."
 echo "The datamart aggregates note statistics globally from the fact table."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi

 __checkPrereqsCommands

 ## Validate SQL script files using centralized validation
 __logi "Validating SQL script files..."

 # Create array of SQL files to validate
 local SQL_FILES=(
  "${CHECK_OBJECTS_FILE}"
  "${CREATE_TABLES_FILE}"
  "${POPULATE_FILE}"
 )

 # Validate each SQL file
 for SQL_FILE in "${SQL_FILES[@]}"; do
  if ! __validate_sql_structure "${SQL_FILE}"; then
   __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 done

 __log_finish
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CREATE_TABLES_FILE}"
 __log_finish
}

# Checks the tables are created.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${CHECK_OBJECTS_FILE}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __logw "Creating datamart global tables."
  __createBaseTables
  __logw "Datamart global tables created."
 fi
 __log_finish
}

# Processes the global statistics.
function __processGlobalStats {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POPULATE_FILE}" 2>&1
 __log_finish
}

# Function that activates the error trap.
function __trapOn() {
 __log_start
 trap '{
  local ERROR_LINE="${LINENO}"
  local ERROR_COMMAND="${BASH_COMMAND}"
  local ERROR_EXIT_CODE="$?"

  # Only report actual errors, not successful returns
  if [[ "${ERROR_EXIT_CODE}" -ne 0 ]]; then
   # Get the main script name (the one that was executed, not the library)
   local MAIN_SCRIPT_NAME
   MAIN_SCRIPT_NAME=$(basename "${0}" .sh)

   printf "%s ERROR: The script %s did not finish correctly. Temporary directory: ${TMP_DIR:-} - Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}" "${ERROR_LINE}";
   printf "ERROR: Failed command: %s (exit code: %d)\n" "${ERROR_COMMAND}" "${ERROR_EXIT_CODE}";
   if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
    {
     echo "Error occurred at $(date +%Y%m%d_%H:%M:%S)"
     echo "Script: ${MAIN_SCRIPT_NAME}"
     echo "Line number: ${ERROR_LINE}"
     echo "Failed command: ${ERROR_COMMAND}"
     echo "Exit code: ${ERROR_EXIT_CODE}"
     echo "Temporary directory: ${TMP_DIR:-unknown}"
     echo "Process ID: $$"
    } > "${FAILED_EXECUTION_FILE}"
   fi;
   exit ${ERROR_EXIT_CODE};
  fi;
 }' ERR
 trap '{
  # Get the main script name (the one that was executed, not the library)
  local MAIN_SCRIPT_NAME
  MAIN_SCRIPT_NAME=$(basename "${0}" .sh)

  printf "%s WARN: The script %s was terminated. Temporary directory: ${TMP_DIR:-}\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}";
  if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
   {
    echo "Script terminated at $(date +%Y%m%d_%H:%M:%S)"
    echo "Script: ${MAIN_SCRIPT_NAME}"
    echo "Temporary directory: ${TMP_DIR:-unknown}"
    echo "Process ID: $$"
    echo "Signal: SIGTERM/SIGINT"
   } > "${FAILED_EXECUTION_FILE}"
  fi;
  exit ${ERROR_GENERAL};
 }' SIGINT SIGTERM
 __log_finish
}

######
# MAIN

function main() {
 __log_start
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Processing: ${PROCESS_TYPE}."

 if [[ "${PROCESS_TYPE}" == "-h" ]] \
  || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi

 # If no parameters provided, show help and return error
 if [[ -z "${PROCESS_TYPE}" ]]; then
  __loge "No process type specified."
  echo "${0} version ${VERSION}"
  echo "This script requires a process type parameter."
  echo ""
  echo "Usage:"
  echo "  ${0} [OPTIONS]"
  echo ""
  echo "Run with --help for more information."
  return 1
 fi

 __checkPrereqs

 __logw "Starting process."
 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 __logw "Validating single execution."
 # shellcheck disable=SC2034
 ONLY_EXECUTION="no"
 flock -n 7
 # shellcheck disable=SC2034
 ONLY_EXECUTION="yes"

 set +E
 __checkBaseTables
 set -E
 __processGlobalStats

 __logw "Ending process."
 __log_finish
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ "${SKIP_MAIN:-}" != "true" ]]; then
 if [[ ! -t 1 ]]; then
  __set_log_file "${LOG_FILENAME}"
  main >> "${LOG_FILENAME}"
  EXIT_CODE=$?
  if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
   mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S \
    || true).log"
   rmdir "${TMP_DIR}"
  fi
  exit "${EXIT_CODE}"
 else
  main
  EXIT_CODE=$?
  exit "${EXIT_CODE}"
 fi
fi

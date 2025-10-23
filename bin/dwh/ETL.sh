#!/bin/bash

# ETL process that transforms notes and comments from base tables into a star
# schema data warehouse with facts and dimensions.
# This ETL runs independently from the ingestion process that retrieves notes
# from Planet and API. This separation allows for longer execution times than
# the periodic ingestion polls.
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/ETL_* | tail -1)/ETL.log
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
#
# For contributing, please execute these commands before submitting:
# * shellcheck -x -o all ETL.sh
# * shfmt -w -i 1 -sr -bn ETL.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-22
VERSION="2025-10-22"

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

# Lock file for single execution.
declare LOCK
LOCK="${TMP_DIR}/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
if [[ -z "${PROCESS_TYPE:-}" ]]; then
 declare -r PROCESS_TYPE=${1:-}
fi

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

# PostgreSQL SQL script files.
# Check ingestion base tables.
declare -r POSTGRES_10_CHECK_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_10_checkBaseTables.sql"
# Check DWH base tables.
declare -r POSTGRES_11_CHECK_DWH_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_11_checkDWHTables.sql"
# Drop datamart objects.
declare -r POSTGRES_12_DROP_DATAMART_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_12_removeDatamartObjects.sql"
# Drop DWH objects.
declare -r POSTGRES_13_DROP_DWH_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_13_removeDWHObjects.sql"

# Create DWH tables.
declare -r POSTGRES_22_CREATE_DWH_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_22_createDWHTables.sql"
# Create fact partitions.
declare -r POSTGRES_22A_CREATE_FACT_PARTITIONS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_22a_createFactPartitions.sql"
# Populates regions per country.
declare -r POSTGRES_23_GET_WORLD_REGIONS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_23_getWorldRegion.sql"
# Add functions.
declare -r POSTGRES_24_ADD_FUNCTIONS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_24_addFunctions.sql"
# Populate ISO country codes.
declare -r POSTGRES_24A_POPULATE_ISO_CODES="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_24a_populateISOCodes.sql"
# Populate dimension tables.
declare -r POSTGRES_25_POPULATE_DIMENSIONS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_25_populateDimensionTables.sql"
# Update dimension tables.
declare -r POSTGRES_26_UPDATE_DIMENSIONS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_26_updateDimensionTables.sql"

# Staging SQL script files.
# Create base staging objects.
declare -r POSTGRES_31_CREATE_BASE_STAGING_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_31_createBaseStagingObjects.sql"
# Create staging objects.
declare -r POSTGRES_32_CREATE_STAGING_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_32_createStagingObjects.sql"
# Create initial facts base objects.
declare -r POSTGRES_33_CREATE_FACTS_BASE_OBJECTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_33_initialFactsBaseObjects.sql"
# Create initial facts load.
declare -r POSTGRES_34_CREATE_FACTS_YEAR_LOAD="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_34_initialFactsLoadCreate.sql"
# Execute initial facts load.
declare -r POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_35_initialFactsLoadExecute.sql"
# Drop initial facts load.
declare -r POSTGRES_36_DROP_FACTS_YEAR_LOAD="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_36_initialFactsLoadDrop.sql"
# Add constraints, indexes and triggers.
declare -r POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql"
# Unify facts.
declare -r POSTGRES_51_UNIFY_FACTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_51_unify.sql"

# Load notes staging.
declare -r POSTGRES_61_LOAD_NOTES_STAGING="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_61_loadNotes.sql"

# Datamart script files.
declare -r DATAMART_COUNTRIES_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartCountries/datamartCountries.sh"
declare -r DATAMART_USERS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartUsers/datamartUsers.sh"

###########
# FUNCTIONS

# ETL Configuration file.
declare -r ETL_CONFIG_FILE="${SCRIPT_BASE_DIRECTORY}/etc/etl.properties"

# ETL Recovery and monitoring variables.

# Load ETL configuration if available.
if [[ -f "${ETL_CONFIG_FILE}" ]]; then
 # shellcheck disable=SC1090
 source "${ETL_CONFIG_FILE}"
 __logi "Loaded ETL configuration from ${ETL_CONFIG_FILE}"
else
 __logw "ETL configuration file not found, using defaults"
fi

# Set default values for ETL configuration if not defined.
declare -r ETL_BATCH_SIZE="${ETL_BATCH_SIZE:-1000}"
declare -r ETL_COMMIT_INTERVAL="${ETL_COMMIT_INTERVAL:-100}"
declare -r ETL_VACUUM_AFTER_LOAD="${ETL_VACUUM_AFTER_LOAD:-true}"
declare -r ETL_ANALYZE_AFTER_LOAD="${ETL_ANALYZE_AFTER_LOAD:-true}"
declare -r MAX_MEMORY_USAGE="${MAX_MEMORY_USAGE:-80}"
declare -r MAX_DISK_USAGE="${MAX_DISK_USAGE:-90}"
declare -r ETL_TIMEOUT="${ETL_TIMEOUT:-7200}"
declare -r ETL_RECOVERY_ENABLED="${ETL_RECOVERY_ENABLED:-true}"
declare -r ETL_RECOVERY_FILE="${ETL_RECOVERY_FILE:-${TMP_DIR}/ETL_recovery.json}"
declare -r ETL_VALIDATE_INTEGRITY="${ETL_VALIDATE_INTEGRITY:-true}"
declare -r ETL_VALIDATE_DIMENSIONS="${ETL_VALIDATE_DIMENSIONS:-true}"
declare -r ETL_VALIDATE_FACTS="${ETL_VALIDATE_FACTS:-true}"
declare -r ETL_PARALLEL_ENABLED="${ETL_PARALLEL_ENABLED:-true}"
declare -r ETL_MAX_PARALLEL_JOBS="${ETL_MAX_PARALLEL_JOBS:-4}"
declare -r ETL_MONITOR_RESOURCES="${ETL_MONITOR_RESOURCES:-true}"
declare -r ETL_MONITOR_INTERVAL="${ETL_MONITOR_INTERVAL:-30}"

# Set default value for CLEAN if not defined
declare CLEAN="${CLEAN:-true}"

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This ETL process transforms data from base tables into a star schema"
 echo "data warehouse with fact and dimension tables."
 echo
 echo "Usage:"
 echo "  ${0} [OPTIONS]"
 echo
 echo "Options:"
 echo "  --create          Create initial data warehouse (first time setup)"
 echo "  --incremental     Run incremental update (production mode)"
 echo "  --help, -h        Show this help"
 echo
 echo "Environment variables:"
 echo "  ETL_BATCH_SIZE       Records per batch (default: 1000)"
 echo "  ETL_COMMIT_INTERVAL  Commit every N records (default: 100)"
 echo "  CLEAN                Clean temporary files (default: true)"
 echo "  LOG_LEVEL            Logging level (default: ERROR)"
 echo
 echo "Examples:"
 echo "  ${0} --create       # First time setup"
 echo "  ${0} --incremental  # Regular updates (use in crontab)"
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 __logi "=== STARTING ETL PREREQUISITES CHECK ==="
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--create" ]] \
  && [[ "${PROCESS_TYPE}" != "--incremental" ]] \
  && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing (same as --incremental)"
  echo " * --create"
  echo " * --incremental"
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 __checkPrereqsCommands

 ## Validate SQL script files using centralized validation
 __logi "Validating SQL script files..."

 # Create array of SQL files to validate
 local SQL_FILES=(
  "${POSTGRES_10_CHECK_BASE_TABLES}"
  "${POSTGRES_11_CHECK_DWH_BASE_TABLES}"
  "${POSTGRES_12_DROP_DATAMART_OBJECTS}"
  "${POSTGRES_13_DROP_DWH_OBJECTS}"
  "${POSTGRES_22_CREATE_DWH_TABLES}"
  "${POSTGRES_22A_CREATE_FACT_PARTITIONS}"
  "${POSTGRES_23_GET_WORLD_REGIONS}"
  "${POSTGRES_24_ADD_FUNCTIONS}"
  "${POSTGRES_24A_POPULATE_ISO_CODES}"
  "${POSTGRES_25_POPULATE_DIMENSIONS}"
  "${POSTGRES_26_UPDATE_DIMENSIONS}"
  "${POSTGRES_31_CREATE_BASE_STAGING_OBJECTS}"
  "${POSTGRES_32_CREATE_STAGING_OBJECTS}"
  "${POSTGRES_33_CREATE_FACTS_BASE_OBJECTS}"
  "${POSTGRES_34_CREATE_FACTS_YEAR_LOAD}"
  "${POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD}"
  "${POSTGRES_36_DROP_FACTS_YEAR_LOAD}"
  "${POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS}"
  "${POSTGRES_51_UNIFY_FACTS}"
  "${POSTGRES_61_LOAD_NOTES_STAGING}"
 )

 # Validate each SQL file
 for SQL_FILE in "${SQL_FILES[@]}"; do
  if ! __validate_sql_structure "${SQL_FILE}"; then
   __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 done

 ## Validate configuration file if it exists
 if [[ -f "${ETL_CONFIG_FILE}" ]]; then
  __logi "ETL configuration file found and loaded"
 else
  __logw "ETL configuration file not found, using defaults"
 fi

 __logi "=== ETL PREREQUISITES CHECK COMPLETED ==="
 __log_finish
}

# Checks if DWH tables exist. If not, creates them.
function __checkBaseTables {
 __log_start
 __logi "=== CHECKING DWH TABLES ==="
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_11_CHECK_DWH_BASE_TABLES}" 2>&1
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __createBaseTables
 fi

 __logi "Recreating base staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_31_CREATE_BASE_STAGING_OBJECTS}" 2>&1

 __logi "Recreating staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_32_CREATE_STAGING_OBJECTS}" 2>&1

 __logi "=== DWH TABLES CHECK COMPLETED ==="
 __log_finish
}

# Creates DWH tables (dimensions and facts) for initial load.
# This includes dropping existing objects and rebuilding from scratch.
function __createBaseTables {
 __log_start
 __logi "=== CREATING DWH TABLES ==="
 __logi "Dropping any existing DWH objects."
 psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_DATAMART_OBJECTS}" 2>&1
 psql -d "${DBNAME}" -f "${POSTGRES_13_DROP_DWH_OBJECTS}" 2>&1

 __logi "Creating tables for star model if they do not exist."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_22_CREATE_DWH_TABLES}" 2>&1
 __logi "Creating partitions for facts table."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_22A_CREATE_FACT_PARTITIONS}" 2>&1
 __logi "Regions for countries."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_23_GET_WORLD_REGIONS}" 2>&1
 __logi "Adding functions."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_24_ADD_FUNCTIONS}" 2>&1

 __logi "Populating ISO country codes reference table."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_24A_POPULATE_ISO_CODES}" 2>&1

 __logi "Initial dimension population."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_25_POPULATE_DIMENSIONS}" 2>&1

 __logi "Initial user dimension population."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_26_UPDATE_DIMENSIONS}" 2>&1

 __logi "Creating base staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_31_CREATE_BASE_STAGING_OBJECTS}" 2>&1

 __logi "Creating staging objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_32_CREATE_STAGING_OBJECTS}" 2>&1

 echo "INSERT INTO dwh.properties VALUES ('initial load', 'true')" \
  | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 2>&1

 __initialFacts

 __logi "=== DWH TABLES CREATED SUCCESSFULLY ==="
 __log_finish
}

# Processes notes and comments incrementally.
# Updates dimensions and loads new facts since last run.
function __processNotesETL {
 __log_start
 __logi "=== PROCESSING NOTES ETL ==="

 # Load notes into staging.
 __logi "Loading notes into staging."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_61_LOAD_NOTES_STAGING}" 2>&1

 # Process notes actions into DWH.
 __logi "Processing notes actions into DWH."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "CALL staging.process_notes_actions_into_dwh();" 2>&1

 # Unify facts, by computing dates between years.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_51_UNIFY_FACTS}" 2>&1

 __log_finish
}

# Creates initial facts for all years.
function __initialFacts {
 __log_start
 __logi "=== CREATING INITIAL FACTS ==="

 # Create initial facts base objects.
 __logi "Creating initial facts base objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_33_CREATE_FACTS_BASE_OBJECTS}" 2>&1

 # Create initial facts load.
 __logi "Creating initial facts load."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_34_CREATE_FACTS_YEAR_LOAD}" 2>&1

 # Execute initial facts load.
 __logi "Executing initial facts load."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD}" 2>&1

 # Drop initial facts load.
 __logi "Dropping initial facts load."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_36_DROP_FACTS_YEAR_LOAD}" 2>&1

 # Add constraints, indexes and triggers.
 __logi "Adding constraints, indexes and triggers."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS}" 2>&1

 __log_finish
}

# Performs database maintenance operations.
function __perform_database_maintenance {
 __log_start
 __logi "=== PERFORMING DATABASE MAINTENANCE ==="

 if [[ "${ETL_VACUUM_AFTER_LOAD}" == "true" ]]; then
  __logi "Running VACUUM ANALYZE on fact table"
  psql -d "${DBNAME}" -c "VACUUM ANALYZE dwh.facts;" 2>&1
 fi

 if [[ "${ETL_ANALYZE_AFTER_LOAD}" == "true" ]]; then
  __logi "Running ANALYZE on dimension tables"
  psql -d "${DBNAME}" -c "ANALYZE dwh.dimension_users, dwh.dimension_countries, dwh.dimension_regions, dwh.dimension_continents, dwh.dimension_days, dwh.dimension_time_of_week, dwh.dimension_applications, dwh.dimension_application_versions, dwh.dimension_hashtags, dwh.dimension_timezones, dwh.dimension_seasons;" 2>&1
 fi

 __logi "=== DATABASE MAINTENANCE COMPLETED ==="
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
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Processing: ${PROCESS_TYPE}."

 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi

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

 __checkPrereqs

 # Handle create mode
 if [[ "${PROCESS_TYPE}" == "--create" ]]; then
  __logi "CREATE MODE - Creating initial data warehouse"
  set +E
  __checkBaseTables
  set -E
  __processNotesETL
  __perform_database_maintenance
  "${DATAMART_COUNTRIES_SCRIPT}"
  "${DATAMART_USERS_SCRIPT}"
 fi

 # Handle incremental mode or default mode
 if [[ "${PROCESS_TYPE}" == "--incremental" ]] || [[ "${PROCESS_TYPE}" == "" ]]; then
  __logi "INCREMENTAL MODE - Processing only new data"
  set +E
  __checkBaseTables
  set -E
  __processNotesETL
  __perform_database_maintenance
  "${DATAMART_COUNTRIES_SCRIPT}"
  "${DATAMART_USERS_SCRIPT}"
 fi

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
  if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
   mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
   rmdir "${TMP_DIR}"
  fi
 else
  main
 fi
fi

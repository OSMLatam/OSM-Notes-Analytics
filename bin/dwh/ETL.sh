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
# Version: 2025-10-27
VERSION="2025-10-27"

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

# Load local properties if they exist (overrides global settings)
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local" ]]; then
 # shellcheck disable=SC1091
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local"
fi

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME

# Main script name for trap handlers (must be global, not local)
declare MAIN_SCRIPT_NAME
MAIN_SCRIPT_NAME=$(basename "${0}" .sh)
readonly MAIN_SCRIPT_NAME

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

# Configure log file early if running from cron (not a terminal)
# This prevents logger from writing to stdout which would be sent by email
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILENAME}"
fi

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
declare -r POSTGRES_33_CREATE_FACTS_BASE_OBJECTS_SIMPLE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_33_initialFactsBaseObjects_Simple.sql"
# Create initial facts load.
declare -r POSTGRES_34_CREATE_FACTS_YEAR_LOAD="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_34_initialFactsLoadCreate.sql"
# Execute initial facts load.
declare -r POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_35_initialFactsLoadExecute.sql"
declare -r POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD_SIMPLE="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_35_initialFactsLoadExecute_Simple.sql"
declare -r POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD_PHASE2="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_35_initialFactsLoadExecute_Phase2.sql"
declare -r POSTGRES_34_INITIAL_FACTS_LOAD_PARALLEL="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_34_initialFactsLoadCreate_Parallel.sql"
# Drop initial facts load.
declare -r POSTGRES_36_DROP_FACTS_YEAR_LOAD="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_36_initialFactsLoadDrop.sql"
# Add constraints, indexes and triggers.
declare -r POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql"
# Create automation detection system.
declare -r POSTGRES_50_CREATE_AUTOMATION_DETECTION="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_50_createAutomationDetection.sql"
# Create experience levels system.
declare -r POSTGRES_51_CREATE_EXPERIENCE_LEVELS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_51_createExperienceLevels.sql"
# Create note activity metrics trigger.
declare -r POSTGRES_52_CREATE_NOTE_ACTIVITY_METRICS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_52_createNoteActivityMetrics.sql"
# Create hashtag analysis views.
declare -r POSTGRES_53_CREATE_HASHTAG_VIEWS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/ETL_53_createHashtagViews.sql"
# Enhance datamarts with hashtag metrics.
declare -r POSTGRES_53A_ENHANCE_DATAMARTS_HASHTAGS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/improvements/13_enhance_datamarts_hashtags.sql"
# Create specialized hashtag indexes.
declare -r POSTGRES_53B_CREATE_HASHTAG_INDEXES="${SCRIPT_BASE_DIRECTORY}/sql/dwh/improvements/13_create_hashtag_indexes.sql"
# Unify facts.
declare -r POSTGRES_54_UNIFY_FACTS="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_51_unify.sql"

# Load notes staging.
declare -r POSTGRES_61_LOAD_NOTES_STAGING="${SCRIPT_BASE_DIRECTORY}/sql/dwh/Staging_61_loadNotes.sql"

# Datamart script files.
declare -r DATAMART_COUNTRIES_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartCountries/datamartCountries.sh"
declare -r DATAMART_USERS_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartUsers/datamartUsers.sh"
declare -r DATAMART_GLOBAL_SCRIPT="${SCRIPT_BASE_DIRECTORY}/bin/dwh/datamartGlobal/datamartGlobal.sh"

###########
# FUNCTIONS

# ETL Configuration file.
declare -r ETL_CONFIG_FILE="${SCRIPT_BASE_DIRECTORY}/etc/etl.properties"

# ETL Recovery and monitoring variables.

# Load ETL configuration if available.
if [[ -f "${ETL_CONFIG_FILE}" ]]; then
 # shellcheck disable=SC1090
 source "${ETL_CONFIG_FILE}"
 # Only log if there's a problem - configuration loading is expected
else
 __logw "ETL configuration file not found, using defaults"
fi

# Load local ETL configuration if available (overrides global settings)
declare -r ETL_CONFIG_FILE_LOCAL="${SCRIPT_BASE_DIRECTORY}/etc/etl.properties.local"
if [[ -f "${ETL_CONFIG_FILE_LOCAL}" ]]; then
 # shellcheck disable=SC1090
 source "${ETL_CONFIG_FILE_LOCAL}"
 # Only log if there's a problem - configuration loading is expected
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
declare -r ETL_TEST_MODE="${ETL_TEST_MODE:-false}"

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
 echo "  ETL_TEST_MODE        Test mode: process only 2013-2014 (default: false)"
 echo "  CLEAN                Clean temporary files (default: true)"
 echo "  LOG_LEVEL            Logging level (default: ERROR)"
 echo
 echo "Examples:"
 echo "  ${0} --create                    # First time setup (all years)"
 echo "  ${0} --incremental               # Regular updates (use in crontab)"
 echo "  ETL_TEST_MODE=true ${0} --create # Test mode (2013-2014 only)"
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit 0
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
  "${POSTGRES_50_CREATE_AUTOMATION_DETECTION}"
  "${POSTGRES_51_CREATE_EXPERIENCE_LEVELS}"
  "${POSTGRES_52_CREATE_NOTE_ACTIVITY_METRICS}"
  "${POSTGRES_53_CREATE_HASHTAG_VIEWS}"
  "${POSTGRES_53A_ENHANCE_DATAMARTS_HASHTAGS}"
  "${POSTGRES_53B_CREATE_HASHTAG_INDEXES}"
  "${POSTGRES_54_UNIFY_FACTS}"
  "${POSTGRES_61_LOAD_NOTES_STAGING}"
 )

 # Validate each SQL file
 for SQL_FILE in "${SQL_FILES[@]}"; do
  # shellcheck disable=SC2310  # invocation in condition is intentional; failures handled explicitly
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

# Checks if base ingestion tables exist and have required columns.
# Returns 0 if validation passes, 1 if validation fails.
function __checkIngestionBaseTables {
 __log_start
 __logi "=== CHECKING INGESTION BASE TABLES AND COLUMNS ==="
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_10_CHECK_BASE_TABLES}" 2>&1
 RET=${?}
 set -e
 __logi "Base tables check result code: ${RET}"
 if [[ "${RET}" -ne 0 ]]; then
  __loge "Base ingestion tables validation failed. Please check the error message above."
  __loge "This usually means tables or required columns are missing."
  __loge "Please ensure OSM-Notes-Ingestion system has created the tables with correct schema."
  __log_finish
  return 1
 fi

 __logi "=== INGESTION BASE TABLES VALIDATION PASSED ==="
 __log_finish
 return 0
}

# Checks if DWH tables exist. Returns 0 if they exist, 1 if they don't.
function __checkBaseTables {
 __log_start
 __logi "=== CHECKING DWH TABLES ==="
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_11_CHECK_DWH_BASE_TABLES}" 2>&1
 RET=${?}
 set -e
 __logi "Check result code: ${RET}"
 if [[ "${RET}" -ne 0 ]]; then
  __logi "DWH tables are missing - will be created by caller"
  __log_finish
  return 1
 fi

 __logi "DWH tables exist, recreating staging objects"
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

 # Note: __initialFacts is called separately by the caller
 # (either __initialFacts or __initialFactsParallel)

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

 # Create note activity metrics trigger (before processing to ensure metrics are calculated).
 __logi "Creating note activity metrics trigger."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_52_CREATE_NOTE_ACTIVITY_METRICS}" 2>&1

 # Ensure trigger is enabled for incremental loads (needed for metrics calculation)
 __logi "Ensuring note activity metrics trigger is enabled for incremental processing..."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SELECT dwh.enable_note_activity_metrics_trigger();" 2>&1

 # Process notes actions into DWH.
 __logi "Processing notes actions into DWH."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "CALL staging.process_notes_actions_into_dwh();" 2>&1

 # Unify facts, by computing dates between years.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_54_UNIFY_FACTS}" 2>&1

 # Create hashtag analysis views.
 __logi "Creating hashtag analysis views."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_53_CREATE_HASHTAG_VIEWS}" 2>&1

 # Enhance datamarts with hashtag metrics.
 __logi "Enhancing datamarts with hashtag metrics."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_53A_ENHANCE_DATAMARTS_HASHTAGS}" 2>&1

 # Create specialized hashtag indexes.
 __logi "Creating specialized hashtag indexes."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_53B_CREATE_HASHTAG_INDEXES}" 2>&1

 # Update automation levels for modified users.
 __logi "Updating automation levels for modified users."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "CALL dwh.update_automation_levels_for_modified_users();" 2>&1

 # Update experience levels for modified users.
 __logi "Updating experience levels for modified users."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "CALL dwh.update_experience_levels_for_modified_users();" 2>&1

 __log_finish
}

# Creates initial facts for all years using parallel processing.
function __initialFactsParallel {
 __log_start
 __logi "=== CREATING INITIAL FACTS (PARALLEL) ==="

 # Create initial facts base objects.
 __logi "Creating initial facts base objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_33_CREATE_FACTS_BASE_OBJECTS_SIMPLE}" 2>&1

 # Disable note activity metrics trigger for performance during bulk load
 # This improves ETL speed by 5-15% during initial load
 # Note: Trigger may not exist yet, so we'll handle the error gracefully
 __logi "Disabling note activity metrics trigger for bulk load performance..."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=0 \
  -c "SELECT dwh.disable_note_activity_metrics_trigger();" 2>&1 || {
  __logw "Note: Trigger may not exist yet (will be created later). Continuing..."
 }

 # Phase 1: Parallel load by year
 __logi "Phase 1: Starting parallel load by year..."

 # Adjust MAX_THREADS for parallel processing
 # Uses n-1 cores, if number of cores is greater than 1.
 # This prevents monopolization of the CPUs.
 local adjusted_threads="${MAX_THREADS}"
 if [[ "${MAX_THREADS}" -gt 6 ]]; then
  adjusted_threads=$((MAX_THREADS - 2))
  __logi "Reducing MAX_THREADS from ${MAX_THREADS} to ${adjusted_threads} (leaving 2 cores free)"
 elif [[ "${MAX_THREADS}" -gt 1 ]]; then
  adjusted_threads=$((MAX_THREADS - 1))
  __logi "Reducing MAX_THREADS from ${MAX_THREADS} to ${adjusted_threads} (leaving 1 core free)"
 fi

 # Get list of years from 2013 to current year
 # shellcheck disable=SC2155
 local current_year
 current_year=$(date +%Y)
 local start_year=2013

 # In test mode, process only 2013 and 2014 for faster testing
 # This maintains data integrity by processing complete years
 if [[ "${ETL_TEST_MODE}" == "true" ]]; then
  start_year=2013
  local test_end_year=2014
  current_year="${test_end_year}"
  __logi "TEST MODE: Processing years 2013-2014 (small subset for testing)"
  __logi "NOTE: Use incremental mode afterward to process remaining years"
 else
  __logi "PRODUCTION MODE: Processing all years from 2013 to ${current_year}"
 fi

 local year="${start_year}"
 local pids=()

 # Create procedures for each year
 while [[ ${year} -le ${current_year} ]]; do
  __logi "Creating procedure for year ${year}..."
  YEAR=${year} envsubst < "${POSTGRES_34_INITIAL_FACTS_LOAD_PARALLEL}" \
   | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 2>&1

  year=$((year + 1))
 done

 # Disable note activity metrics trigger for performance during bulk load
 # This improves ETL speed by 5-15% during initial load
 __logi "Disabling note activity metrics trigger for bulk load performance..."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SELECT dwh.disable_note_activity_metrics_trigger();" 2>&1 || {
  __logw "Note: Trigger may not exist yet (will be created later). Continuing..."
 }

 # Execute parallel load for each year
 year="${start_year}"
 __logi "Executing parallel load for years ${start_year}-${current_year} (max ${adjusted_threads} concurrent)..."

 while [[ ${year} -le ${current_year} ]]; do
  (
   __logi "Starting year ${year} load (PID: $$)..."
   psql -d "${DBNAME}" -c "CALL staging.process_initial_load_by_year_${year}();" 2>&1
   __logi "Finished year ${year} load (PID: $$)."
  ) &
  pids+=($!)
  year=$((year + 1))

  # Limit concurrent processes to adjusted_threads
  if [[ ${#pids[@]} -ge ${adjusted_threads} ]]; then
   wait "${pids[0]}"
   pids=("${pids[@]:1}")
  fi
 done

 # Wait for all remaining processes
 __logi "Waiting for all year loads to complete..."
 for pid in "${pids[@]}"; do
  wait "${pid}"
 done
 __logi "Phase 1: All parallel loads completed."

 # Phase 2: Update recent_opened_dimension_id_date for all facts
 __logi "Phase 2: Updating recent_opened_dimension_id_date for all facts..."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD_PHASE2}" 2>&1
 __logi "Phase 2: Update completed."

 # Add constraints, indexes and triggers.
 __logi "Adding constraints, indexes and triggers."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS}" 2>&1

 # Create automation detection system.
 __logi "Creating automation detection system."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_50_CREATE_AUTOMATION_DETECTION}" 2>&1

 # Create experience levels system.
 __logi "Creating experience levels system."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_51_CREATE_EXPERIENCE_LEVELS}" 2>&1

 # Create note activity metrics trigger.
 __logi "Creating note activity metrics trigger."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_52_CREATE_NOTE_ACTIVITY_METRICS}" 2>&1

 # Enable note activity metrics trigger after creation
 # (It was disabled before bulk load for performance)
 __logi "Enabling note activity metrics trigger for future incremental loads..."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SELECT dwh.enable_note_activity_metrics_trigger();" 2>&1

 # Create hashtag analysis views.
 __logi "Creating hashtag analysis views."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_53_CREATE_HASHTAG_VIEWS}" 2>&1

 # Enhance datamarts with hashtag metrics.
 __logi "Enhancing datamarts with hashtag metrics."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_53A_ENHANCE_DATAMARTS_HASHTAGS}" 2>&1

 # Create specialized hashtag indexes.
 __logi "Creating specialized hashtag indexes."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_53B_CREATE_HASHTAG_INDEXES}" 2>&1

 __log_finish
}

# Creates initial facts for all years.
function __initialFacts {
 __log_start
 __logi "=== CREATING INITIAL FACTS ==="

 # Create initial facts base objects.
 __logi "Creating initial facts base objects."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_33_CREATE_FACTS_BASE_OBJECTS_SIMPLE}" 2>&1

 # Disable note activity metrics trigger for performance during bulk load
 # This improves ETL speed by 5-15% during initial load
 # Note: Trigger may not exist yet, so we'll handle the error gracefully
 __logi "Disabling note activity metrics trigger for bulk load performance..."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=0 \
  -c "SELECT dwh.disable_note_activity_metrics_trigger();" 2>&1 || {
  __logw "Note: Trigger may not exist yet (will be created later). Continuing..."
 }

 # Skip year-specific load creation for simple initial load
 # __logi "Creating initial facts load."
 # psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
 #  -f "${POSTGRES_34_CREATE_FACTS_YEAR_LOAD}" 2>&1

 # Execute initial facts load.
 __logi "Executing initial facts load."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_35_EXECUTE_FACTS_YEAR_LOAD_SIMPLE}" 2>&1

 # Skip the year-specific load creation and drop steps for simple initial load

 # Add constraints, indexes and triggers.
 __logi "Adding constraints, indexes and triggers."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_41_ADD_CONSTRAINTS_INDEXES_TRIGGERS}" 2>&1

 # Create automation detection system.
 __logi "Creating automation detection system."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_50_CREATE_AUTOMATION_DETECTION}" 2>&1

 # Create experience levels system.
 __logi "Creating experience levels system."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_51_CREATE_EXPERIENCE_LEVELS}" 2>&1

 # Create note activity metrics trigger.
 __logi "Creating note activity metrics trigger."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_52_CREATE_NOTE_ACTIVITY_METRICS}" 2>&1

 # Enable note activity metrics trigger after creation
 # (It was disabled before bulk load for performance)
 __logi "Enabling note activity metrics trigger for future incremental loads..."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SELECT dwh.enable_note_activity_metrics_trigger();" 2>&1

 # Create hashtag analysis views.
 __logi "Creating hashtag analysis views."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_53_CREATE_HASHTAG_VIEWS}" 2>&1

 # Enhance datamarts with hashtag metrics.
 __logi "Enhancing datamarts with hashtag metrics."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_53A_ENHANCE_DATAMARTS_HASHTAGS}" 2>&1

 # Create specialized hashtag indexes.
 __logi "Creating specialized hashtag indexes."
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_53B_CREATE_HASHTAG_INDEXES}" 2>&1

 __log_finish
}

# Detects if this is the first execution by checking if DWH facts table is empty.
function __detectFirstExecution {
 # Temporarily disable logging to stdout for this function
 local temp_log_file
 temp_log_file=$(mktemp)

 {
  __log_start
  __logi "=== DETECTING EXECUTION MODE ==="

  # Check if DWH facts table exists and has data
  local facts_count
  facts_count=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM dwh.facts;" 2> /dev/null || echo "0")
  __logi "Query result for facts count: '${facts_count}'"

  # Check if initial load flag exists
  local initial_load_flag
  initial_load_flag=$(psql -d "${DBNAME}" -Atq -c "SELECT value FROM dwh.properties WHERE key = 'initial load';" 2> /dev/null || echo "")
  __logi "Query result for initial load flag: '${initial_load_flag}'"

  local result
  if [[ "${facts_count}" -eq 0 ]]; then
   __logi "FIRST EXECUTION DETECTED - No facts found in DWH"
   __logi "Found ${facts_count} facts in DWH, initial load flag: '${initial_load_flag}'"
   __logi "Will perform initial load with complete data warehouse creation"
   result="true"
  else
   __logi "INCREMENTAL EXECUTION DETECTED - Found ${facts_count} facts in DWH"
   __logi "Will process only new data since last run"
   result="false"
  fi

  __log_finish
 } >> "${temp_log_file}" 2>&1

 # Output the log file to stdout
 cat "${temp_log_file}"
 rm -f "${temp_log_file}"

 # Return the result
 echo "${result}"
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
 # shellcheck disable=SC2154  # variables inside trap are defined dynamically by Bash
 # Note: Cannot use 'local' in trap handlers as they execute outside function context
 trap '{
  ERROR_LINE="${LINENO}"
  ERROR_COMMAND="${BASH_COMMAND}"
  ERROR_EXIT_CODE="$?"

  if [[ "${ERROR_EXIT_CODE}" -ne 0 ]]; then
   printf "%s ERROR: The script %s did not finish correctly. Temporary directory: ${TMP_DIR:-} - Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}" "${ERROR_LINE}";
   printf "ERROR: Failed command: %s (exit code: %d)\n" "${ERROR_COMMAND}" "${ERROR_EXIT_CODE}";
   exit "${ERROR_EXIT_CODE}";
  fi;
 }' ERR
 # shellcheck disable=SC2154  # variables inside trap are defined dynamically by Bash
 trap '{
  printf "%s WARN: The script %s was terminated. Temporary directory: ${TMP_DIR:-}\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}";
  exit ${ERROR_GENERAL};
 }' SIGINT SIGTERM
 __log_finish
}

######
# MAIN

function main() {
 # Only log errors during initialization - normal startup is silent
 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi

 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 # shellcheck disable=SC2034
 ONLY_EXECUTION="no"
 flock -n 7
 # shellcheck disable=SC2034
 ONLY_EXECUTION="yes"

 __checkPrereqs

 # Validate base ingestion tables and columns before processing
 __logi "Validating base ingestion tables and columns..."
 if ! __checkIngestionBaseTables; then
  __loge "Base ingestion tables validation failed. ETL cannot proceed."
  exit 1
 fi

 __logi "PROCESS_TYPE value: '${PROCESS_TYPE}'"

 # Handle create mode (explicit)
 if [[ "${PROCESS_TYPE}" == "--create" ]]; then
  __logi "CREATE MODE - Creating initial data warehouse (explicit)"
  set +E
  # shellcheck disable=SC2310
  if ! __checkBaseTables; then
   __logi "Tables missing, creating them"
   __createBaseTables
  else
   # Ensure schema exists even if tables exist (for datamart scripts)
   __logi "Ensuring dwh schema exists"
   psql -d "${DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS dwh;" 2>&1
  fi
  set -E
  __initialFactsParallel # Use parallel version
  __perform_database_maintenance
  "${DATAMART_COUNTRIES_SCRIPT}" ""
  "${DATAMART_USERS_SCRIPT}" ""
  "${DATAMART_GLOBAL_SCRIPT}" ""
 fi

 # Handle incremental mode or default mode (with auto-detection)
 if [[ "${PROCESS_TYPE}" == "--incremental" ]] || [[ "${PROCESS_TYPE}" == "" ]]; then
  __logi "Entering incremental mode with auto-detection"
  # Auto-detect if this is the first execution
  local is_first_execution
  is_first_execution=$(__detectFirstExecution | tail -1)
  __logi "Detection result: '${is_first_execution}'"

  if [[ "${is_first_execution}" == "true" ]]; then
   __logi "AUTO-DETECTED FIRST EXECUTION - Performing initial load"
   set +E
   # shellcheck disable=SC2310
   if ! __checkBaseTables; then
    __logi "Tables missing, creating them"
    __createBaseTables
   else
    # Ensure schema exists even if tables exist (for datamart scripts)
    __logi "Ensuring dwh schema exists"
    psql -d "${DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS dwh;" 2>&1 || true
   fi
   set -E
   __logi "About to call __initialFactsParallel"
   __initialFactsParallel # Use parallel version
   __logi "Finished calling __initialFactsParallel"
   __perform_database_maintenance
   set +e
   "${DATAMART_COUNTRIES_SCRIPT}" "" || true
   "${DATAMART_USERS_SCRIPT}" "" || true
   "${DATAMART_GLOBAL_SCRIPT}" "" || true
   set -e
  else
   __logi "AUTO-DETECTED INCREMENTAL EXECUTION - Processing only new data"
   set +E
   # shellcheck disable=SC2310
   if ! __checkBaseTables; then
    __logi "Tables missing, creating them"
    __createBaseTables
   else
    # Ensure schema exists even if tables exist (for datamart scripts)
    __logi "Ensuring dwh schema exists"
    psql -d "${DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS dwh;" 2>&1 || true
   fi
   set -E
   __logi "About to call __processNotesETL"
   __processNotesETL
   __logi "Finished calling __processNotesETL"
   __perform_database_maintenance
   set +e
   "${DATAMART_COUNTRIES_SCRIPT}" "" || true
   "${DATAMART_USERS_SCRIPT}" "" || true
   "${DATAMART_GLOBAL_SCRIPT}" "" || true
   set -e
  fi
 fi

 __logw "Ending process."
 __log_finish
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

# Logger already initialized at line 93, log file already set if running from cron
if [[ "${SKIP_MAIN:-}" != "true" ]]; then
 if [[ ! -t 1 ]]; then
  # Log file already configured above, just redirect main output
  main >> "${LOG_FILENAME}"
  if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
   mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
   rmdir "${TMP_DIR}" 2> /dev/null || rm -rf "${TMP_DIR}" 2> /dev/null || true
  fi
 else
  main
 fi
fi

#!/bin/bash

# Copy base tables from Ingestion DB to Analytics DB for initial load.
# This script is part of the hybrid strategy: copy tables for initial load,
# then use Foreign Data Wrappers for incremental processing.
#
# After DWH population, these tables will be dropped by dropCopiedBaseTables.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-29

set -euo pipefail

# Base directory for the project.
# Allow SCRIPT_BASE_DIRECTORY to be set externally (e.g., by tests)
declare SCRIPT_BASE_DIRECTORY
if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &> /dev/null && pwd)"
fi
readonly SCRIPT_BASE_DIRECTORY

# Load logger
# shellcheck disable=SC1091
if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh" ]]; then
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh"
else
 # Minimal logger if file doesn't exist
 __logi() { echo "[INFO] $*"; }
 __loge() { echo "[ERROR] $*" >&2; }
 __logw() { echo "[WARN] $*"; }
 __log_start() { echo "[START]"; }
 __log_finish() { echo "[FINISH]"; }
fi

# Save original state of user variables before loading properties
# This allows tests to unset them for peer authentication
USER_INGESTION_WAS_UNSET=false
USER_DWH_WAS_UNSET=false
if [[ -z "${DB_USER_INGESTION+x}" ]]; then
 USER_INGESTION_WAS_UNSET=true
fi
if [[ -z "${DB_USER_DWH+x}" ]]; then
 USER_DWH_WAS_UNSET=true
fi

# Load properties (handle missing file gracefully for testing)
# shellcheck disable=SC1091
set +e
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh" ]]; then
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh" 2> /dev/null || true
fi
set -e

# Load local properties if they exist
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local" ]]; then
 # shellcheck disable=SC1091
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local" 2> /dev/null || true
fi

# Database configuration
# Use explicit database names - no fallback to avoid confusion
INGESTION_DB="${DBNAME_INGESTION:-notes}"
ANALYTICS_DB="${DBNAME_DWH:-notes_dwh}"
# Only set user if explicitly provided (allows peer authentication when not set)
# If variables were unset before loading properties, restore empty state for peer auth
if [[ "${USER_INGESTION_WAS_UNSET}" == "true" ]]; then
 INGESTION_USER=""
else
 INGESTION_USER="${DB_USER_INGESTION:-}"
fi
if [[ "${USER_DWH_WAS_UNSET}" == "true" ]]; then
 ANALYTICS_USER=""
else
 ANALYTICS_USER="${DB_USER_DWH:-}"
fi

# Helper function to build psql command array
build_psql_array() {
 local dbname="$1"
 local dbuser="${2:-}"
 local -n psql_array="$3" # nameref to array

 psql_array=()
 # Use CI/CD environment variables if available
 if [[ -n "${TEST_DBHOST:-}" ]] || [[ -n "${PGHOST:-}" ]]; then
  psql_array+=(-h "${TEST_DBHOST:-${PGHOST:-localhost}}")
  psql_array+=(-p "${TEST_DBPORT:-${PGPORT:-5432}}")
  psql_array+=(-U "${dbuser:-${TEST_DBUSER:-${PGUSER:-postgres}}}")
  psql_array+=(-d "${dbname}")
 else
  # Local environment - use peer authentication
  if [[ -n "${dbuser}" ]]; then
   psql_array+=(-U "${dbuser}")
  fi
  psql_array+=(-d "${dbname}")
 fi
}

# Tables to copy (in order of dependencies)
TABLES=("countries" "users" "notes" "note_comments" "note_comments_text")

__log_start
__logi "=== COPYING BASE TABLES FOR INITIAL LOAD ==="
__logi "Source DB: ${INGESTION_DB} (user: ${INGESTION_USER})"
__logi "Target DB: ${ANALYTICS_DB} (user: ${ANALYTICS_USER})"

# Skip copying if source and target are the same database (hybrid test mode)
if [[ "${INGESTION_DB}" == "${ANALYTICS_DB}" ]]; then
 __logi "Source and target databases are the same (${INGESTION_DB}), skipping table copy"
 __logi "Tables are already accessible in the same database"
 __log_finish
 exit 0
fi

# Build psql command arrays for source and target databases
declare -a INGESTION_PSQL_ARGS
declare -a ANALYTICS_PSQL_ARGS
build_psql_array "${INGESTION_DB}" "${INGESTION_USER}" INGESTION_PSQL_ARGS
build_psql_array "${ANALYTICS_DB}" "${ANALYTICS_USER}" ANALYTICS_PSQL_ARGS

# Set passwords for CI/CD environments
if [[ -n "${TEST_DBHOST:-}" ]] || [[ -n "${PGHOST:-}" ]]; then
 INGESTION_PGPASSWORD="${TEST_DBPASSWORD:-${PGPASSWORD:-postgres}}"
 ANALYTICS_PGPASSWORD="${TEST_DBPASSWORD:-${PGPASSWORD:-postgres}}"
else
 INGESTION_PGPASSWORD=""
 ANALYTICS_PGPASSWORD=""
fi

# Validate source database connection
set +e
connection_output=$(PGPASSWORD="${INGESTION_PGPASSWORD}" psql "${INGESTION_PSQL_ARGS[@]}" -c "SELECT 1;" 2>&1)
connection_exit_code=$?
set -e
if [[ ${connection_exit_code} -ne 0 ]]; then
 __loge "ERROR: Cannot connect to source database ${INGESTION_DB}"
 __loge "Connection error: ${connection_output}"
 exit 1
fi

# Validate target database connection
set +e
connection_output=$(PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${ANALYTICS_PSQL_ARGS[@]}" -c "SELECT 1;" 2>&1)
connection_exit_code=$?
set -e
if [[ ${connection_exit_code} -ne 0 ]]; then
 __loge "ERROR: Cannot connect to target database ${ANALYTICS_DB}"
 __loge "Connection error: ${connection_output}"
 exit 1
fi

# Create schema if not exists
__logi "Ensuring public schema exists in target database"
PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${ANALYTICS_PSQL_ARGS[@]}" -c "CREATE SCHEMA IF NOT EXISTS public;" > /dev/null 2>&1 || true

# Copy each table
for table in "${TABLES[@]}"; do
 __logi "Copying table: ${table}"

 # Verify source database connection before checking table
 set +e
 connection_output=$(PGPASSWORD="${INGESTION_PGPASSWORD}" psql "${INGESTION_PSQL_ARGS[@]}" -c "SELECT 1;" 2>&1)
 connection_exit_code=$?
 set -e
 if [[ ${connection_exit_code} -ne 0 ]]; then
  __loge "ERROR: Cannot connect to source database ${INGESTION_DB} while copying table ${table}"
  __loge "Source database may have been dropped or is unavailable"
  __loge "Connection error: ${connection_output}"
  exit 1
 fi

 # Check if table exists in source
 if ! PGPASSWORD="${INGESTION_PGPASSWORD}" psql "${INGESTION_PSQL_ARGS[@]}" -t -c \
  "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table}';" \
  | grep -q 1; then
  __logw "Table ${table} does not exist in source database, skipping"
  continue
 fi

 # Check if table already exists in target (should not happen, but handle gracefully)
 if PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${ANALYTICS_PSQL_ARGS[@]}" -t -c \
  "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table}';" \
  | grep -q 1; then
  __logw "Table ${table} already exists in target database, dropping first"
  set +e
  drop_output=$(PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${ANALYTICS_PSQL_ARGS[@]}" -c "DROP TABLE IF EXISTS public.${table} CASCADE;" 2>&1)
  drop_exit_code=$?
  set -e
  if [[ ${drop_exit_code} -ne 0 ]]; then
   __logw "Warning: Failed to drop existing table ${table}: ${drop_output}"
  fi
 fi

 # Get table structure and create in target
 __logi "Creating table structure for ${table}"
 # Build pg_dump command array
 declare -a PGDUMP_ARGS
 if [[ -n "${TEST_DBHOST:-}" ]] || [[ -n "${PGHOST:-}" ]]; then
  PGDUMP_ARGS=(-h "${TEST_DBHOST:-${PGHOST:-localhost}}" -p "${TEST_DBPORT:-${PGPORT:-5432}}" -U "${INGESTION_USER:-${TEST_DBUSER:-${PGUSER:-postgres}}}" -d "${INGESTION_DB}")
 else
  PGDUMP_ARGS=(-d "${INGESTION_DB}")
  [[ -n "${INGESTION_USER}" ]] && PGDUMP_ARGS+=(-U "${INGESTION_USER}")
 fi

 set +e
 schema_output=$(PGPASSWORD="${INGESTION_PGPASSWORD}" pg_dump "${PGDUMP_ARGS[@]}" \
  -t "public.${table}" \
  --schema-only \
  --no-owner --no-acl \
  2>&1 | PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${ANALYTICS_PSQL_ARGS[@]}" -q 2>&1)
 schema_exit_code=${PIPESTATUS[0]}
 set -e
 if [[ ${schema_exit_code} -ne 0 ]]; then
  __loge "ERROR: Failed to create table structure for ${table}"
  __loge "Schema creation error: ${schema_output}"
  exit 1
 fi

 # Copy data using COPY (fastest method)
 __logi "Copying data for ${table}"
 set +e
 row_count=$(PGPASSWORD="${INGESTION_PGPASSWORD}" psql "${INGESTION_PSQL_ARGS[@]}" -t -c "SELECT COUNT(*) FROM public.${table};" 2>&1 | tr -d ' ')
 row_count_exit_code=$?
 set -e
 if [[ ${row_count_exit_code} -ne 0 ]]; then
  __loge "ERROR: Failed to get row count for ${table}"
  exit 1
 fi
 __logi "Copying ${row_count} rows from ${table}"

 # Capture errors from both psql commands in the pipeline
 set +e
 copy_errors=$(mktemp)
 # Capture both stdout and stderr from the pipeline
 PGPASSWORD="${INGESTION_PGPASSWORD}" psql "${INGESTION_PSQL_ARGS[@]}" \
  -c "\COPY public.${table} TO STDOUT" 2>&1 | \
 PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${ANALYTICS_PSQL_ARGS[@]}" \
  -c "\COPY public.${table} FROM STDIN" > "${copy_errors}" 2>&1
 # Capture PIPESTATUS immediately after the pipeline (it resets after each command)
 copy_exit_code_1=${PIPESTATUS[0]}
 copy_exit_code_2=${PIPESTATUS[1]}
 copy_error_content=$(cat "${copy_errors}")
 rm -f "${copy_errors}"
 set -e

 if [[ ${copy_exit_code_1} -ne 0 ]] || [[ ${copy_exit_code_2} -ne 0 ]]; then
  __loge "ERROR: Failed to copy data for ${table}"
  __loge "COPY TO STDOUT exit code: ${copy_exit_code_1}"
  __loge "COPY FROM STDIN exit code: ${copy_exit_code_2}"
  __loge "COPY error details: ${copy_error_content}"
  exit 1
 fi

 # Verify row count
 target_count=$(PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${ANALYTICS_PSQL_ARGS[@]}" -t -c "SELECT COUNT(*) FROM public.${table};" | tr -d ' ')
 if [[ "${row_count}" != "${target_count}" ]]; then
  __loge "ERROR: Row count mismatch for ${table}: source=${row_count}, target=${target_count}"
  exit 1
 fi
 __logi "Verified: ${target_count} rows copied for ${table}"

 # Create indexes (copy from source)
 __logi "Creating indexes for ${table}"
 set +e
 index_list=$(PGPASSWORD="${INGESTION_PGPASSWORD}" psql "${INGESTION_PSQL_ARGS[@]}" -t -A -c \
  "SELECT 'CREATE INDEX IF NOT EXISTS ' || indexname || ' ON public.${table} ' ||
          regexp_replace(indexdef, '^CREATE (UNIQUE )?INDEX .* ON public\.${table} ', '') || ';'
   FROM pg_indexes
   WHERE tablename = '${table}' AND schemaname = 'public'
   AND indexname NOT LIKE '%_pkey';" 2>&1)
 index_list_exit_code=$?
 set -e
 if [[ ${index_list_exit_code} -eq 0 ]] && [[ -n "${index_list}" ]]; then
  while IFS= read -r index_sql; do
   if [[ -n "${index_sql}" ]]; then
    set +e
    index_output=$(PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${ANALYTICS_PSQL_ARGS[@]}" -c "${index_sql}" 2>&1)
    index_exit_code=$?
    set -e
    if [[ ${index_exit_code} -ne 0 ]]; then
     # shellcheck disable=SC2310  # Function invocation in || condition is intentional for error handling
     __logw "Warning: Failed to create index for ${table}: ${index_output}"
    fi
   fi
  done <<< "${index_list}"
 fi

 # Analyze table for better query performance
 __logi "Analyzing table ${table}"
 set +e
 analyze_output=$(PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${ANALYTICS_PSQL_ARGS[@]}" -c "ANALYZE public.${table};" 2>&1)
 analyze_exit_code=$?
 set -e
 if [[ ${analyze_exit_code} -ne 0 ]]; then
  __logw "Warning: Failed to analyze table ${table}: ${analyze_output}"
 fi

 __logi "Table ${table} copied successfully"
done

__logi "=== BASE TABLES COPY COMPLETED ==="
__log_finish
exit 0

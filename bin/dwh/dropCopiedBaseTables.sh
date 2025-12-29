#!/bin/bash

# Drop copied base tables after initial DWH population.
# This script is part of the hybrid strategy: tables are copied for initial load,
# then dropped after DWH is populated to free disk space.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-27

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

# Save state of DB_USER_DWH before loading properties (to detect if it was explicitly set)
DB_USER_DWH_WAS_SET="${DB_USER_DWH+x}"

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
ANALYTICS_DB="${DBNAME_DWH:-notes_dwh}"
# Only set user if explicitly provided via environment variable (allows peer authentication when not set)
# If DB_USER_DWH was not explicitly set before loading properties, ignore the value from properties.sh
if [[ -z "${DB_USER_DWH_WAS_SET}" ]]; then
 # Variable was not set in environment - use peer authentication (ignore value from properties.sh)
 ANALYTICS_USER=""
elif [[ -z "${DB_USER_DWH:-}" ]]; then
 # Variable was explicitly set but is empty - use peer authentication
 ANALYTICS_USER=""
else
 # Variable was explicitly set with a value - use it
 ANALYTICS_USER="${DB_USER_DWH}"
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

# Tables to drop (in reverse order of dependencies)
TABLES=("note_comments_text" "note_comments" "notes" "users" "countries")

__log_start
__logi "=== DROPPING COPIED BASE TABLES ==="
# shellcheck disable=SC2312  # Command substitution in log message is intentional; whoami command is safe
__logi "Target DB: ${ANALYTICS_DB} (user: ${ANALYTICS_USER:-$(whoami)})"

# Build psql command array
declare -a PSQL_CMD_ARGS
build_psql_array "${ANALYTICS_DB}" "${ANALYTICS_USER}" PSQL_CMD_ARGS

# Set password for CI/CD environments
if [[ -n "${TEST_DBHOST:-}" ]] || [[ -n "${PGHOST:-}" ]]; then
 ANALYTICS_PGPASSWORD="${TEST_DBPASSWORD:-${PGPASSWORD:-postgres}}"
else
 ANALYTICS_PGPASSWORD=""
fi

# Validate database connection
if ! PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${PSQL_CMD_ARGS[@]}" -c "SELECT 1;" > /dev/null 2>&1; then
 __loge "ERROR: Cannot connect to database ${ANALYTICS_DB}"
 exit 1
fi

# Drop each table
for table in "${TABLES[@]}"; do
 __logi "Dropping table: ${table}"

 # Check if table exists
 if PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${PSQL_CMD_ARGS[@]}" -t -c \
  "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table}';" \
  | grep -q 1; then

  # Get row count before dropping (for logging)
  local_row_count=$(PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${PSQL_CMD_ARGS[@]}" -t -c "SELECT COUNT(*) FROM public.${table};" 2> /dev/null | tr -d ' ' || echo "0")
  __logi "Dropping ${table} (${local_row_count} rows)"

  # Drop table
  if PGPASSWORD="${ANALYTICS_PGPASSWORD}" psql "${PSQL_CMD_ARGS[@]}" -c "DROP TABLE IF EXISTS public.${table} CASCADE;" > /dev/null 2>&1; then
   __logi "Table ${table} dropped successfully"
  else
   __logw "Warning: Failed to drop table ${table}, continuing..."
  fi
 else
  __logi "Table ${table} does not exist, skipping"
 fi
done

__logi "=== COPIED BASE TABLES DROP COMPLETED ==="
__log_finish
exit 0

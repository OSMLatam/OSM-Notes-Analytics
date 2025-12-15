#!/bin/bash

# Drop copied base tables after initial DWH population.
# This script is part of the hybrid strategy: tables are copied for initial load,
# then dropped after DWH is populated to free disk space.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-27

set -euo pipefail

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Load logger
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh"

# Save state of DB_USER_DWH before loading properties (to detect if it was explicitly set)
DB_USER_DWH_WAS_SET="${DB_USER_DWH+x}"

# Load properties
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Load local properties if they exist
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local" ]]; then
 # shellcheck disable=SC1091
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local"
fi

# Database configuration
ANALYTICS_DB="${DBNAME_DWH:-osm_notes}"
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

# Tables to drop (in reverse order of dependencies)
TABLES=("note_comments_text" "note_comments" "notes" "users" "countries")

__log_start
__logi "=== DROPPING COPIED BASE TABLES ==="
__logi "Target DB: ${ANALYTICS_DB} (user: ${ANALYTICS_USER:-$(whoami)})"

# Build psql command array
PSQL_CMD_ARGS=(-d "${ANALYTICS_DB}")
if [[ -n "${ANALYTICS_USER:-}" ]]; then
 PSQL_CMD_ARGS+=(-U "${ANALYTICS_USER}")
fi

# Validate database connection
if ! psql "${PSQL_CMD_ARGS[@]}" -c "SELECT 1;" > /dev/null 2>&1; then
 __loge "ERROR: Cannot connect to database ${ANALYTICS_DB}"
 exit 1
fi

# Drop each table
for table in "${TABLES[@]}"; do
 __logi "Dropping table: ${table}"

 # Check if table exists
 if psql "${PSQL_CMD_ARGS[@]}" -t -c \
  "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table}';" \
  | grep -q 1; then

  # Get row count before dropping (for logging)
  local_row_count=$(psql "${PSQL_CMD_ARGS[@]}" -t -c "SELECT COUNT(*) FROM public.${table};" 2> /dev/null | tr -d ' ' || echo "0")
  __logi "Dropping ${table} (${local_row_count} rows)"

  # Drop table
  if psql "${PSQL_CMD_ARGS[@]}" -c "DROP TABLE IF EXISTS public.${table} CASCADE;" > /dev/null 2>&1; then
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

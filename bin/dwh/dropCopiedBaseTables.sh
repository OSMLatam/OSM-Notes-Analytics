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

# Load properties
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Load local properties if they exist
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local" ]]; then
 # shellcheck disable=SC1091
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local"
fi

# Database configuration
ANALYTICS_DB="${DBNAME_DWH:-${DBNAME:-osm_notes}}"
# Only set user if explicitly provided (allows peer authentication when not set)
ANALYTICS_USER="${DB_USER_DWH:-}"

# Tables to drop (in reverse order of dependencies)
TABLES=("note_comments_text" "note_comments" "notes" "users" "countries")

__log_start
__logi "=== DROPPING COPIED BASE TABLES ==="
__logi "Target DB: ${ANALYTICS_DB} (user: ${ANALYTICS_USER})"

# Validate database connection
if ! psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -c "SELECT 1;" > /dev/null 2>&1; then
 __loge "ERROR: Cannot connect to database ${ANALYTICS_DB}"
 exit 1
fi

# Drop each table
for table in "${TABLES[@]}"; do
 __logi "Dropping table: ${table}"

 # Check if table exists
 if psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -t -c \
  "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table}';" \
  | grep -q 1; then

  # Get row count before dropping (for logging)
  local_row_count=$(psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -t -c "SELECT COUNT(*) FROM public.${table};" 2> /dev/null | tr -d ' ' || echo "0")
  __logi "Dropping ${table} (${local_row_count} rows)"

  # Drop table
  if psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} \
   -c "DROP TABLE IF EXISTS public.${table} CASCADE;" > /dev/null 2>&1; then
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

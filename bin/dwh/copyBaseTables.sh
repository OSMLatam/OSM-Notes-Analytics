#!/bin/bash

# Copy base tables from Ingestion DB to Analytics DB for initial load.
# This script is part of the hybrid strategy: copy tables for initial load,
# then use Foreign Data Wrappers for incremental processing.
#
# After DWH population, these tables will be dropped by dropCopiedBaseTables.sh
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

# Load properties
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Load local properties if they exist
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local" ]]; then
 # shellcheck disable=SC1091
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh.local"
fi

# Database configuration
# Default to same DB if not specified (backward compatibility)
INGESTION_DB="${DBNAME_INGESTION:-notes_dwh}"
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

# Validate source database connection
if ! psql -d "${INGESTION_DB}" ${INGESTION_USER:+-U "${INGESTION_USER}"} -c "SELECT 1;" > /dev/null 2>&1; then
 __loge "ERROR: Cannot connect to source database ${INGESTION_DB}"
 exit 1
fi

# Validate target database connection
if ! psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -c "SELECT 1;" > /dev/null 2>&1; then
 __loge "ERROR: Cannot connect to target database ${ANALYTICS_DB}"
 exit 1
fi

# Create schema if not exists
__logi "Ensuring public schema exists in target database"
psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -c "CREATE SCHEMA IF NOT EXISTS public;" > /dev/null 2>&1 || true

# Copy each table
for table in "${TABLES[@]}"; do
 __logi "Copying table: ${table}"

 # Check if table exists in source
 if ! psql -d "${INGESTION_DB}" ${INGESTION_USER:+-U "${INGESTION_USER}"} -t -c \
  "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table}';" \
  | grep -q 1; then
  __logw "Table ${table} does not exist in source database, skipping"
  continue
 fi

 # Check if table already exists in target (should not happen, but handle gracefully)
 if psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -t -c \
  "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table}';" \
  | grep -q 1; then
  __logw "Table ${table} already exists in target database, dropping first"
  psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -c "DROP TABLE IF EXISTS public.${table} CASCADE;" > /dev/null 2>&1 || true
 fi

 # Get table structure and create in target
 __logi "Creating table structure for ${table}"
 pg_dump -d "${INGESTION_DB}" ${INGESTION_USER:+-U "${INGESTION_USER}"} \
  -t "public.${table}" \
  --schema-only \
  --no-owner --no-acl \
  | psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -q > /dev/null 2>&1 || {
  __loge "ERROR: Failed to create table structure for ${table}"
  exit 1
 }

 # Copy data using COPY (fastest method)
 __logi "Copying data for ${table}"
 row_count=$(psql -d "${INGESTION_DB}" ${INGESTION_USER:+-U "${INGESTION_USER}"} -t -c "SELECT COUNT(*) FROM public.${table};" | tr -d ' ')
 __logi "Copying ${row_count} rows from ${table}"

 if ! psql -d "${INGESTION_DB}" ${INGESTION_USER:+-U "${INGESTION_USER}"} \
  -c "\COPY public.${table} TO STDOUT" 2> /dev/null \
  | psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} \
   -c "\COPY public.${table} FROM STDIN" > /dev/null 2>&1; then
  __loge "ERROR: Failed to copy data for ${table}"
  exit 1
 fi

 # Verify row count
 target_count=$(psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -t -c "SELECT COUNT(*) FROM public.${table};" | tr -d ' ')
 if [[ "${row_count}" != "${target_count}" ]]; then
  __loge "ERROR: Row count mismatch for ${table}: source=${row_count}, target=${target_count}"
  exit 1
 fi
 __logi "Verified: ${target_count} rows copied for ${table}"

 # Create indexes (copy from source)
 __logi "Creating indexes for ${table}"
 psql -d "${INGESTION_DB}" ${INGESTION_USER:+-U "${INGESTION_USER}"} -t -A -c "
   SELECT 'CREATE INDEX IF NOT EXISTS ' || indexname || ' ON public.${table} ' ||
          regexp_replace(indexdef, '^CREATE (UNIQUE )?INDEX .* ON public\.${table} ', '') || ';'
   FROM pg_indexes
   WHERE tablename = '${table}' AND schemaname = 'public'
   AND indexname NOT LIKE '%_pkey';
 " 2> /dev/null | while read -r index_sql; do
  if [[ -n "${index_sql}" ]]; then
   psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -c "${index_sql}" > /dev/null 2>&1 || {
    # shellcheck disable=SC2310  # Function invocation in || condition is intentional for error handling
    __logw "Warning: Failed to create index for ${table}, continuing..."
   }
  fi
 done || true

 # Analyze table for better query performance
 __logi "Analyzing table ${table}"
 psql -d "${ANALYTICS_DB}" ${ANALYTICS_USER:+-U "${ANALYTICS_USER}"} -c "ANALYZE public.${table};" > /dev/null 2>&1 || true

 __logi "Table ${table} copied successfully"
done

__logi "=== BASE TABLES COPY COMPLETED ==="
__log_finish
exit 0

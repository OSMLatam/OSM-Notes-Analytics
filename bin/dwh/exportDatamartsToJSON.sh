#!/bin/bash

# Exports datamarts to JSON files for web viewer consumption.
# This allows the web viewer to read precalculated data without direct database access.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-23
# Note: This script now uses SELECT * to dynamically export all columns,
# including any new year-based columns added to the datamart tables.

# Fails when a variable is not initialized.
set -u
# Fails with an non-zero return code.
set -e
# Fails if one of the commands of the pipe fails.
set -o pipefail

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

# Temporary directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

# Schema validation function using ajv
function __validate_json_with_schema() {
 local JSON_FILE="${1}"
 local SCHEMA_FILE="${2}"
 local NAME="${3:-$(basename "${JSON_FILE}")}"

 if [[ ! -f "${JSON_FILE}" ]]; then
  echo "ERROR: JSON file not found: ${JSON_FILE}"
  return 1
 fi

 if [[ ! -f "${SCHEMA_FILE}" ]]; then
  echo "WARNING: Schema file not found: ${SCHEMA_FILE}"
  return 0
 fi

 if command -v ajv > /dev/null 2>&1; then
  if ajv validate -s "${SCHEMA_FILE}" -d "${JSON_FILE}" > /dev/null 2>&1; then
   echo "  ✓ Valid: ${NAME}"
   return 0
  else
   echo "  ✗ Invalid: ${NAME}"
   ajv validate -s "${SCHEMA_FILE}" -d "${JSON_FILE}" 2>&1 || true
   return 1
  fi
 else
  echo "WARNING: ajv not available, skipping schema validation"
  return 0
 fi
}

# Calculate datamart schema hash for change detection
function __calculate_schema_hash() {
 if ! command -v psql > /dev/null 2>&1; then
  echo ""
  return 1
 fi

 # Get column definitions from datamart tables
 local SCHEMA_HASH
 SCHEMA_HASH=$(
  psql -d "${DBNAME}" -Atq << 'EOF' | sha256sum | cut -d' ' -f1
SELECT
  COALESCE(string_agg(column_name || ':' || data_type || ':' || ordinal_position, '|' ORDER BY table_name, ordinal_position), '')
FROM (
  SELECT
    'datamartusers' as table_name,
    column_name,
    data_type,
    ordinal_position
  FROM information_schema.columns
  WHERE table_schema = 'dwh' AND table_name = 'datamartusers'
  UNION ALL
  SELECT
    'datamartcountries' as table_name,
    column_name,
    data_type,
    ordinal_position
  FROM information_schema.columns
  WHERE table_schema = 'dwh' AND table_name = 'datamartcountries'
) t
EOF
 )
 echo "${SCHEMA_HASH}"
}

# Get current version from version tracking file
function __get_current_version() {
 local VERSION_FILE="${SCRIPT_BASE_DIRECTORY}/.json_export_version"

 if [[ -f "${VERSION_FILE}" ]]; then
  cat "${VERSION_FILE}"
 else
  echo "1.0.0"
 fi
}

# Increment version (MAJOR.MINOR.PATCH)
function __increment_version() {
 local CURRENT_VERSION="${1:-1.0.0}"
 local VERSION_TYPE="${2:-patch}" # major, minor, or patch
 local MAJOR MINOR PATCH

 IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"

 case "${VERSION_TYPE}" in
 major)
  MAJOR=$((MAJOR + 1))
  MINOR=0
  PATCH=0
  ;;
 minor)
  MINOR=$((MINOR + 1))
  PATCH=0
  ;;
 patch | *)
  PATCH=$((PATCH + 1))
  ;;
 esac

 echo "${MAJOR}.${MINOR}.${PATCH}"
}

# Save version to file
function __save_version() {
 local VERSION="${1}"
 local VERSION_FILE="${SCRIPT_BASE_DIRECTORY}/.json_export_version"
 echo "${VERSION}" > "${VERSION_FILE}"
}

# Cleanup function for temporary directory
function __cleanup_temp() {
 if [[ -d "${ATOMIC_TEMP_DIR}" ]]; then
  echo "Cleaning up temporary directory..."
  rm -rf "${ATOMIC_TEMP_DIR}"
 fi
}

# Reset json_exported flag for modified entities
function __reset_exported_flags() {
 echo "$(date +%Y-%m-%d\ %H:%M:%S) - Resetting export flags for modified entities..."

 # Reset users marked as modified
 psql -d "${DBNAME}" -Atq -c "
  UPDATE dwh.datamartusers
  SET json_exported = FALSE
  FROM dwh.dimension_users
  WHERE dwh.datamartusers.dimension_user_id = dwh.dimension_users.dimension_user_id
    AND dwh.dimension_users.modified = TRUE
 " > /dev/null 2>&1 || true

 # Reset countries marked as modified
 psql -d "${DBNAME}" -Atq -c "
  UPDATE dwh.datamartcountries
  SET json_exported = FALSE
  FROM dwh.dimension_countries
  WHERE dwh.datamartcountries.dimension_country_id = dwh.dimension_countries.dimension_country_id
    AND dwh.dimension_countries.modified = TRUE
 " > /dev/null 2>&1 || true

 echo "  Export flags reset for modified entities"
}

# Schema files location (from OSM-Notes-Common submodule)
declare SCHEMA_DIR="${SCHEMA_DIR:-${SCRIPT_BASE_DIRECTORY}/lib/osm-common/schemas}"
readonly SCHEMA_DIR

# Output directory for JSON files (final destination)
declare OUTPUT_DIR="${JSON_OUTPUT_DIR:-./output/json}"
readonly OUTPUT_DIR

# Temporary directory for atomic writes (inside TMP_DIR)
declare ATOMIC_TEMP_DIR="${TMP_DIR}/atomic_export"
readonly ATOMIC_TEMP_DIR

# Validation error counter
VALIDATION_ERROR_COUNT=0

# Register cleanup trap
trap __cleanup_temp EXIT

# Create temporary directories for atomic writes
mkdir -p "${ATOMIC_TEMP_DIR}/users"
mkdir -p "${ATOMIC_TEMP_DIR}/countries"
mkdir -p "${ATOMIC_TEMP_DIR}/indexes"

echo "$(date +%Y-%m-%d\ %H:%M:%S) - Starting datamart JSON export to temporary directory"

# Check if dwh schema exists
if ! psql -d "${DBNAME}" -Atq -c "SELECT 1 FROM information_schema.schemata WHERE schema_name = 'dwh'" | grep -q 1; then
 __loge "Schema 'dwh' does not exist. Please run the ETL process first to create the data warehouse."
 exit 1
fi

# Check if datamartUsers table exists
if ! psql -d "${DBNAME}" -Atq -c "SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'datamartusers'" | grep -q 1; then
 __loge "Table 'dwh.datamartUsers' does not exist. Please run the datamart population scripts first:
	- bin/dwh/datamartUsers/datamartUsers.sh
	- bin/dwh/datamartCountries/datamartCountries.sh"
 exit 1
fi

# Reset export flags for entities marked as modified in dimension tables
__reset_exported_flags

# Export users - incremental mode
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Exporting users datamart (incremental)..."

# Copy existing user files to temp directory to preserve unchanged ones
if [[ -d "${OUTPUT_DIR}/users" ]]; then
 echo "  Copying existing user files..."
 cp -p "${OUTPUT_DIR}/users"/*.json "${ATOMIC_TEMP_DIR}/users/" 2> /dev/null || true
fi

# Export only modified users
MODIFIED_USER_COUNT=0
psql -d "${DBNAME}" -Atq << SQL_USERS | while IFS='|' read -r user_id username; do
SELECT
  user_id,
  username
FROM dwh.datamartusers
WHERE user_id IS NOT NULL
  AND json_exported = FALSE
ORDER BY user_id;
SQL_USERS

 if [[ -n "${user_id}" ]]; then
  # Export each modified user to a separate JSON file
  # Use SELECT * to dynamically include all columns
  psql -d "${DBNAME}" -Atq -c "
      SELECT row_to_json(t)
      FROM dwh.datamartusers t
      WHERE t.user_id = ${user_id}
	" > "${ATOMIC_TEMP_DIR}/users/${user_id}.json"

  echo "  Exported modified user: ${user_id} (${username})"
  MODIFIED_USER_COUNT=$((MODIFIED_USER_COUNT + 1))

  # Mark as exported in database
  psql -d "${DBNAME}" -Atq -c "
      UPDATE dwh.datamartusers
      SET json_exported = TRUE
      WHERE user_id = ${user_id}
	" > /dev/null 2>&1 || true

  # Validate only modified user files
  if ! __validate_json_with_schema \
   "${ATOMIC_TEMP_DIR}/users/${user_id}.json" \
   "${SCHEMA_DIR}/user-profile.schema.json" \
   "user ${user_id}"; then
   VALIDATION_ERROR_COUNT=$((VALIDATION_ERROR_COUNT + 1))
  fi
 fi
done

if [[ ${MODIFIED_USER_COUNT} -gt 0 ]]; then
 echo "  Total modified users exported: ${MODIFIED_USER_COUNT}"
else
 echo "  No modified users to export"
fi

# Create user index file
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Creating user index..."
psql -d "${DBNAME}" -Atq -c "
  SELECT json_agg(t)
  FROM (
    SELECT
      user_id,
      username,
      id_contributor_type,
      date_starting_creating_notes,
      history_whole_open,
      history_whole_closed,
      history_whole_commented,
      history_year_open,
      history_year_closed,
      history_year_commented,
      avg_days_to_resolution,
      resolution_rate,
      notes_resolved_count,
      notes_still_open_count
    FROM dwh.datamartusers
    WHERE user_id IS NOT NULL
    ORDER BY history_whole_open DESC NULLS LAST, history_whole_closed DESC NULLS LAST
  ) t
" > "${ATOMIC_TEMP_DIR}/indexes/users.json"

# Validate user index
if ! __validate_json_with_schema \
 "${ATOMIC_TEMP_DIR}/indexes/users.json" \
 "${SCHEMA_DIR}/user-index.schema.json" \
 "user index"; then
 VALIDATION_ERROR_COUNT=$((VALIDATION_ERROR_COUNT + 1))
fi

# Export countries - incremental mode
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Exporting countries datamart (incremental)..."

# Copy existing country files to temp directory to preserve unchanged ones
if [[ -d "${OUTPUT_DIR}/countries" ]]; then
 echo "  Copying existing country files..."
 cp -p "${OUTPUT_DIR}/countries"/*.json "${ATOMIC_TEMP_DIR}/countries/" 2> /dev/null || true
fi

# Export only modified countries
MODIFIED_COUNTRY_COUNT=0
psql -d "${DBNAME}" -Atq << SQL_COUNTRIES | while IFS='|' read -r country_id country_name; do
SELECT country_id, country_name_en
FROM dwh.datamartcountries
WHERE country_id IS NOT NULL
  AND json_exported = FALSE
ORDER BY country_id;
SQL_COUNTRIES

 if [[ -n "${country_id}" ]]; then
  # Export each modified country to a separate JSON file
  # Use SELECT * to dynamically include all columns
  psql -d "${DBNAME}" -Atq -c "
      SELECT row_to_json(t)
      FROM dwh.datamartcountries t
      WHERE t.country_id = ${country_id}
	" > "${ATOMIC_TEMP_DIR}/countries/${country_id}.json"

  echo "  Exported modified country: ${country_id} (${country_name})"
  MODIFIED_COUNTRY_COUNT=$((MODIFIED_COUNTRY_COUNT + 1))

  # Mark as exported in database
  psql -d "${DBNAME}" -Atq -c "
      UPDATE dwh.datamartcountries
      SET json_exported = TRUE
      WHERE country_id = ${country_id}
	" > /dev/null 2>&1 || true

  # Validate only modified country files
  if ! __validate_json_with_schema \
   "${ATOMIC_TEMP_DIR}/countries/${country_id}.json" \
   "${SCHEMA_DIR}/country-profile.schema.json" \
   "country ${country_id}"; then
   VALIDATION_ERROR_COUNT=$((VALIDATION_ERROR_COUNT + 1))
  fi
 fi
done

if [[ ${MODIFIED_COUNTRY_COUNT} -gt 0 ]]; then
 echo "  Total modified countries exported: ${MODIFIED_COUNTRY_COUNT}"
else
 echo "  No modified countries to export"
fi

# Create country index file
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Creating country index..."
psql -d "${DBNAME}" -Atq -c "
  SELECT json_agg(t)
  FROM (
    SELECT
      country_id,
      country_name,
      country_name_es,
      country_name_en,
      date_starting_creating_notes,
      history_whole_open,
      history_whole_closed,
      history_whole_commented,
      history_year_open,
      history_year_closed,
      history_year_commented,
      avg_days_to_resolution,
      resolution_rate,
      notes_resolved_count,
      notes_still_open_count
    FROM dwh.datamartcountries
    WHERE country_id IS NOT NULL
    ORDER BY history_whole_open DESC NULLS LAST, history_whole_closed DESC NULLS LAST
  ) t
" > "${ATOMIC_TEMP_DIR}/indexes/countries.json"

# Validate country index
if ! __validate_json_with_schema \
 "${ATOMIC_TEMP_DIR}/indexes/countries.json" \
 "${SCHEMA_DIR}/country-index.schema.json" \
 "country index"; then
 VALIDATION_ERROR_COUNT=$((VALIDATION_ERROR_COUNT + 1))
fi

# Create metadata file with versioning
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Creating metadata with versioning..."

# Get current version and calculate schema hash
CURRENT_VERSION=$(__get_current_version)
SCHEMA_VERSION="1.0.0"
DATA_SCHEMA_HASH=$(__calculate_schema_hash)
EXPORT_TIMESTAMP=$(date +%s)

cat > "${ATOMIC_TEMP_DIR}/metadata.json" << EOF
{
  "export_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "export_timestamp": ${EXPORT_TIMESTAMP},
  "total_users": $(find "${ATOMIC_TEMP_DIR}/users" -maxdepth 1 -type f | wc -l),
  "total_countries": $(find "${ATOMIC_TEMP_DIR}/countries" -maxdepth 1 -type f | wc -l),
  "version": "${CURRENT_VERSION}",
  "schema_version": "${SCHEMA_VERSION}",
  "api_compat_min": "1.0.0",
  "data_schema_hash": "${DATA_SCHEMA_HASH}"
}
EOF

echo "  Export version: ${CURRENT_VERSION}"
echo "  Schema hash: ${DATA_SCHEMA_HASH}"

# Validate metadata
if ! __validate_json_with_schema \
 "${ATOMIC_TEMP_DIR}/metadata.json" \
 "${SCHEMA_DIR}/metadata.schema.json" \
 "metadata"; then
 VALIDATION_ERROR_COUNT=$((VALIDATION_ERROR_COUNT + 1))
fi

# Create global statistics file
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Creating global statistics..."
psql -d "${DBNAME}" -Atq -c "
  SELECT row_to_json(t)
  FROM (
    SELECT
      -- Meta information
      CURRENT_TIMESTAMP as export_date,
      (SELECT MIN(date_id) FROM dwh.dimension_days) as data_from,
      CURRENT_DATE as data_to,

      -- Total counts (from facts table)
      (SELECT COUNT(DISTINCT id_note) FROM dwh.facts WHERE action_comment = 'opened') as notes_opened_total,
      (SELECT COUNT(DISTINCT id_note) FROM dwh.facts WHERE action_comment = 'closed') as notes_closed_total,
      (SELECT COUNT(*) FROM dwh.facts WHERE action_comment = 'commented') as notes_commented_total,
      (SELECT COUNT(*) FROM dwh.facts WHERE action_comment = 'reopened') as notes_reopened_total,

      -- Unique counts
      (SELECT COUNT(DISTINCT opened_dimension_id_user) FROM dwh.facts WHERE opened_dimension_id_user IS NOT NULL) as unique_users_created,
      (SELECT COUNT(DISTINCT action_dimension_id_user) FROM dwh.facts) as unique_users_active,
      (SELECT COUNT(DISTINCT dimension_id_country) FROM dwh.facts) as unique_countries,

      -- Current status (open notes)
      (SELECT COUNT(DISTINCT id_note) FROM dwh.facts f1
       WHERE action_comment = 'opened'
       AND NOT EXISTS (
         SELECT 1 FROM dwh.facts f2
         WHERE f2.id_note = f1.id_note
         AND f2.action_comment = 'closed'
       )
      ) as notes_currently_open,

      -- First note (simplified - using fact_id as proxy)
      (SELECT json_build_object(
        'note_id', id_note,
        'date', action_at,
        'country_id', dimension_id_country
      ) FROM dwh.facts
       WHERE fact_id = (SELECT MIN(fact_id) FROM dwh.facts WHERE action_comment = 'opened')
       ORDER BY fact_id LIMIT 1
      ) as first_note,

      -- Latest note (simplified)
      (SELECT json_build_object(
        'note_id', id_note,
        'date', action_at,
        'country_id', dimension_id_country
      ) FROM dwh.facts
       WHERE fact_id = (SELECT MAX(fact_id) FROM dwh.facts WHERE action_comment = 'opened')
       ORDER BY fact_id DESC LIMIT 1
      ) as latest_note,

      -- Resolution metrics (aggregated from datamarts)
      (SELECT AVG(avg_days_to_resolution) FROM dwh.datamartusers
       WHERE avg_days_to_resolution IS NOT NULL) as avg_days_to_resolution_global,
      (SELECT AVG(resolution_rate) FROM dwh.datamartusers
       WHERE resolution_rate IS NOT NULL) as avg_resolution_rate_global,

      -- Recent activity (last 30 days from datamarts)
      (SELECT SUM(history_day_open) FROM dwh.datamartusers) as notes_opened_last_30_days_users,
      (SELECT SUM(history_day_closed) FROM dwh.datamartusers) as notes_closed_last_30_days_users,

      (SELECT SUM(history_day_open) FROM dwh.datamartcountries) as notes_opened_last_30_days_countries,
      (SELECT SUM(history_day_closed) FROM dwh.datamartcountries) as notes_closed_last_30_days_countries,

      -- Year activity (current year from datamarts)
      (SELECT SUM(history_year_open) FROM dwh.datamartusers) as notes_opened_this_year_users,
      (SELECT SUM(history_year_closed) FROM dwh.datamartusers) as notes_closed_this_year_users,

      (SELECT SUM(history_year_open) FROM dwh.datamartcountries) as notes_opened_this_year_countries,
      (SELECT SUM(history_year_closed) FROM dwh.datamartcountries) as notes_closed_this_year_countries
  ) t
" > "${ATOMIC_TEMP_DIR}/global_stats.json"

# Validate global stats
if ! __validate_json_with_schema \
 "${ATOMIC_TEMP_DIR}/global_stats.json" \
 "${SCHEMA_DIR}/global-stats.schema.json" \
 "global stats"; then
 VALIDATION_ERROR_COUNT=$((VALIDATION_ERROR_COUNT + 1))
fi

echo "  ✓ Global statistics exported"

# Check validation results
if [[ ${VALIDATION_ERROR_COUNT} -gt 0 ]]; then
 echo ""
 echo "ERROR: Validation failed with ${VALIDATION_ERROR_COUNT} error(s)"
 echo "Keeping existing files in ${OUTPUT_DIR}"
 echo "Invalid files are in ${ATOMIC_TEMP_DIR} for inspection"
 exit 1
fi

# All validations passed - atomic move to final destination
echo ""
echo "$(date +%Y-%m-%d\ %H:%M:%S) - All validations passed, moving to final destination..."

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/users"
mkdir -p "${OUTPUT_DIR}/countries"
mkdir -p "${OUTPUT_DIR}/indexes"

# Move files atomically (move is atomic operation)
mv "${ATOMIC_TEMP_DIR}"/* "${OUTPUT_DIR}/"

echo "$(date +%Y-%m-%d\ %H:%M:%S) - JSON export completed successfully"
echo "  Users: $(find "${OUTPUT_DIR}/users" -maxdepth 1 -type f | wc -l) files"
echo "  Countries: $(find "${OUTPUT_DIR}/countries" -maxdepth 1 -type f | wc -l) files"
echo "  Output directory: ${OUTPUT_DIR}"

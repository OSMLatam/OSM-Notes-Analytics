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

# Cleanup function for temporary directory
function __cleanup_temp() {
 if [[ -d "${ATOMIC_TEMP_DIR}" ]]; then
  echo "Cleaning up temporary directory..."
  rm -rf "${ATOMIC_TEMP_DIR}"
 fi
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

# Export all users to individual JSON files
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Exporting users datamart..."

psql -d "${DBNAME}" -Atq << SQL_USERS | while IFS='|' read -r user_id username; do
SELECT user_id, username
FROM dwh.datamartusers
WHERE user_id IS NOT NULL
ORDER BY user_id;
SQL_USERS

 if [[ -n "${user_id}" ]]; then
  # Export each user to a separate JSON file
  # Use SELECT * to dynamically include all columns
  psql -d "${DBNAME}" -Atq -c "
      SELECT row_to_json(t)
      FROM dwh.datamartusers t
      WHERE t.user_id = ${user_id}
	" > "${ATOMIC_TEMP_DIR}/users/${user_id}.json"

  echo "  Exported user: ${user_id} (${username})"

  # Validate each user file
  if ! __validate_json_with_schema \
   "${ATOMIC_TEMP_DIR}/users/${user_id}.json" \
   "${SCHEMA_DIR}/user-profile.schema.json" \
   "user ${user_id}"; then
   VALIDATION_ERROR_COUNT=$((VALIDATION_ERROR_COUNT + 1))
  fi
 fi
done

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

# Export all countries to individual JSON files
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Exporting countries datamart..."

psql -d "${DBNAME}" -Atq << SQL_COUNTRIES | while IFS='|' read -r country_id country_name; do
SELECT country_id, country_name_en
FROM dwh.datamartcountries
WHERE country_id IS NOT NULL
ORDER BY country_id;
SQL_COUNTRIES

 if [[ -n "${country_id}" ]]; then
  # Export each country to a separate JSON file
  # Use SELECT * to dynamically include all columns
  psql -d "${DBNAME}" -Atq -c "
      SELECT row_to_json(t)
      FROM dwh.datamartcountries t
      WHERE t.country_id = ${country_id}
	" > "${ATOMIC_TEMP_DIR}/countries/${country_id}.json"

  echo "  Exported country: ${country_id} (${country_name})"

  # Validate each country file
  if ! __validate_json_with_schema \
   "${ATOMIC_TEMP_DIR}/countries/${country_id}.json" \
   "${SCHEMA_DIR}/country-profile.schema.json" \
   "country ${country_id}"; then
   VALIDATION_ERROR_COUNT=$((VALIDATION_ERROR_COUNT + 1))
  fi
 fi
done

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

# Create metadata file
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Creating metadata..."
cat > "${ATOMIC_TEMP_DIR}/metadata.json" << EOF
{
  "export_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_users": $(find "${ATOMIC_TEMP_DIR}/users" -maxdepth 1 -type f | wc -l),
  "total_countries": $(find "${ATOMIC_TEMP_DIR}/countries" -maxdepth 1 -type f | wc -l),
  "version": "2025-10-23"
}
EOF

# Validate metadata
if ! __validate_json_with_schema \
 "${ATOMIC_TEMP_DIR}/metadata.json" \
 "${SCHEMA_DIR}/metadata.schema.json" \
 "metadata"; then
 VALIDATION_ERROR_COUNT=$((VALIDATION_ERROR_COUNT + 1))
fi

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

#!/bin/bash

# Exports JSON files and pushes to GitHub Pages data repository
# This script exports datamarts to JSON and publishes them to the OSM-Notes-Data
# repository using intelligent incremental mode (country-by-country).
#
# Usage: ./bin/dwh/exportAndPushJSONToGitHub.sh
#
# Environment variables:
#   MAX_AGE_DAYS: Maximum age in days for country files before regeneration (default: 30)
#                 Countries older than this will be regenerated
#   COUNTRIES_PER_BATCH: Number of countries to process before taking a break (default: 10)
#   DBNAME_DWH: Database name for DWH (default: from etc/properties.sh)
#
# Behavior:
#   - Identifies countries that need export (missing, outdated, or not exported)
#   - Exports each country individually
#   - Commits and pushes each country immediately after export
#   - Removes countries from GitHub that no longer exist in local database
#   - Continues with next country even if one fails
#   - Generates README.md with alphabetical list of countries
#   - Updates country index at the end
#
# Author: Andres Gomez (AngocA)
# Version: 2026-01-17

set -eu pipefail

# Script basename for lock file
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME

# Lock file for single execution
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Process start time
PROCESS_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
readonly PROCESS_START_TIME
ORIGINAL_PID=$$
readonly ORIGINAL_PID

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAX_AGE_DAYS="${MAX_AGE_DAYS:-30}"
readonly MAX_AGE_DAYS
COUNTRIES_PER_BATCH="${COUNTRIES_PER_BATCH:-10}"
readonly COUNTRIES_PER_BATCH

# Project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &> /dev/null && pwd)"
readonly SCRIPT_DIR
ANALYTICS_DIR="${SCRIPT_DIR}"
readonly ANALYTICS_DIR
# Support both locations: ${HOME}/OSM-Notes-Data (preferred) and ${HOME}/github/OSM-Notes-Data (fallback)
if [[ -d "${HOME}/OSM-Notes-Data" ]]; then
 DATA_REPO_DIR="${HOME}/OSM-Notes-Data"
elif [[ -d "${HOME}/github/OSM-Notes-Data" ]]; then
 DATA_REPO_DIR="${HOME}/github/OSM-Notes-Data"
else
 DATA_REPO_DIR="${HOME}/OSM-Notes-Data"
fi
readonly DATA_REPO_DIR

# Function to print colored messages
print_info() {
 echo -e "${GREEN}ℹ${NC} $1"
}

print_warn() {
 echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
 echo -e "${RED}✗${NC} $1"
}

print_success() {
 echo -e "${GREEN}✓${NC} $1"
}

print_country() {
 echo -e "${BLUE}→${NC} $1"
}

# Load database configuration and common functions
if [[ -f "${ANALYTICS_DIR}/etc/properties.sh" ]]; then
 # shellcheck disable=SC1091
 source "${ANALYTICS_DIR}/etc/properties.sh"
fi

# Get database name
DBNAME="${DBNAME_DWH:-notes_dwh}"
readonly DBNAME

# Load common functions if available
if [[ -f "${ANALYTICS_DIR}/lib/osm-common/commonFunctions.sh" ]]; then
 # shellcheck disable=SC1091
 source "${ANALYTICS_DIR}/lib/osm-common/commonFunctions.sh"
fi

# Load validation functions if available
if [[ -f "${ANALYTICS_DIR}/lib/osm-common/validationFunctions.sh" ]]; then
 # shellcheck disable=SC1091
 source "${ANALYTICS_DIR}/lib/osm-common/validationFunctions.sh"
fi

# Schema validation function using ajv
validate_json_with_schema() {
 local json_file="${1}"
 local schema_file="${2}"
 local name="${3:-$(basename "${json_file}")}"

 if [[ ! -f "${json_file}" ]]; then
  print_error "JSON file not found: ${json_file}"
  return 1
 fi

 if [[ ! -f "${schema_file}" ]]; then
  print_warn "Schema file not found: ${schema_file}, skipping validation"
  return 0
 fi

 if command -v ajv > /dev/null 2>&1; then
  if ajv validate -s "${schema_file}" -d "${json_file}" > /dev/null 2>&1; then
   return 0
  else
   print_error "Validation failed for: ${name}"
   ajv validate -s "${schema_file}" -d "${json_file}" 2>&1 || true
   return 1
  fi
 else
  print_warn "ajv not available, skipping schema validation"
  return 0
 fi
}

# Export a single country to JSON
export_single_country() {
 local country_id="${1}"
 local country_name="${2}"
 local output_file="${3}"

 print_country "Exporting country ${country_id} (${country_name})..."

 # Export country to JSON
 if ! psql -d "${DBNAME}" -Atq -c "
      SELECT row_to_json(t)
      FROM dwh.datamartcountries t
      WHERE t.country_id = ${country_id}
	" > "${output_file}" 2>&1; then
  print_error "Failed to export country ${country_id}"
  return 1
 fi

 # Validate JSON file
 local schema_file="${ANALYTICS_DIR}/lib/osm-common/schemas/country-profile.schema.json"
 if ! validate_json_with_schema "${output_file}" "${schema_file}" "country ${country_id}"; then
  print_error "Validation failed for country ${country_id}"
  return 1
 fi

 print_success "Country ${country_id} exported and validated"
 return 0
}

# Get list of countries that need export
get_countries_to_export() {
 local max_age_seconds=$((MAX_AGE_DAYS * 24 * 60 * 60))
 local cutoff_time=$(($(date +%s) - max_age_seconds))
 local temp_list
 temp_list=$(mktemp "/tmp/countries_to_export_XXXXXX.txt")

 # Get all countries from database and check each one
 local temp_db_output
 temp_db_output=$(mktemp "/tmp/countries_db_XXXXXX.txt")
 psql -d "${DBNAME}" -Atq -c "
SELECT
  country_id,
  country_name_en
FROM dwh.datamartcountries
WHERE country_id IS NOT NULL
ORDER BY country_id;
" > "${temp_db_output}"

 while IFS='|' read -r country_id country_name; do
  if [[ -z "${country_id}" ]]; then
   continue
  fi

  local repo_file="${DATA_REPO_DIR}/data/countries/${country_id}.json"
  local needs_export=false

  # Check if file doesn't exist in repo
  if [[ ! -f "${repo_file}" ]]; then
   needs_export=true
  else
   # Check if file is older than MAX_AGE_DAYS
   local file_time
   file_time=$(stat -c %Y "${repo_file}" 2> /dev/null || echo "0")
   if [[ ${file_time} -lt ${cutoff_time} ]]; then
    needs_export=true
   fi

   # Check if country is marked as not exported in database
   local exported_status
   exported_status=$(psql -d "${DBNAME}" -Atq -c "SELECT json_exported FROM dwh.datamartcountries WHERE country_id = ${country_id};" 2> /dev/null || echo "false")
   if [[ "${exported_status}" != "t" ]] && [[ "${exported_status}" != "true" ]]; then
    needs_export=true
   fi
  fi

  if [[ "${needs_export}" == "true" ]]; then
   echo "${country_id}|${country_name}" >> "${temp_list}"
  fi
 done < "${temp_db_output}"

 rm -f "${temp_db_output}"

 # Output the list
 if [[ -f "${temp_list}" ]]; then
  cat "${temp_list}"
  rm -f "${temp_list}"
 fi
}

# Commit and push a single country file
commit_and_push_country() {
 local country_id="${1}"
 local country_name="${2}"

 cd "${DATA_REPO_DIR}"

 # Ensure we're on main branch
 git checkout main 2> /dev/null || true

 # Pull latest changes
 git pull origin main 2> /dev/null || true

 # Add only this country file
 local country_file="data/countries/${country_id}.json"
 if [[ ! -f "${country_file}" ]]; then
  print_error "Country file not found: ${country_file}"
  return 1
 fi

 git add "${country_file}"

 # Check if there are changes to commit
 if git diff --cached --quiet; then
  print_warn "No changes for country ${country_id} (file unchanged)"
  return 0
 fi

 # Commit
 local timestamp
 timestamp=$(date '+%Y-%m-%d %H:%M:%S')
 if ! git commit -m "Auto-update: Country ${country_id} (${country_name}) - ${timestamp}

Incremental export: country ${country_id}" > /dev/null 2>&1; then
  print_error "Failed to commit country ${country_id}"
  return 1
 fi

 # Push to GitHub
 if ! git push origin main > /dev/null 2>&1; then
  print_error "Failed to push country ${country_id} to GitHub"
  git reset HEAD~1 2> /dev/null || true # Rollback commit on push failure
  return 1
 fi

 print_success "Country ${country_id} pushed to GitHub"
 return 0
}

# Remove countries from GitHub that don't exist in local database
remove_obsolete_countries() {
 print_info "Checking for obsolete countries in GitHub..."

 cd "${DATA_REPO_DIR}"
 git checkout main 2> /dev/null || true
 git pull origin main 2> /dev/null || true

 # Get list of country IDs from database
 local db_countries_file
 db_countries_file=$(mktemp "/tmp/db_countries_XXXXXX.txt")
 psql -d "${DBNAME}" -Atq -c "
SELECT country_id
FROM dwh.datamartcountries
WHERE country_id IS NOT NULL
ORDER BY country_id;
" > "${db_countries_file}"

 # Get list of country files in GitHub
 local github_countries_file
 github_countries_file=$(mktemp "/tmp/github_countries_XXXXXX.txt")
 if [[ -d "${DATA_REPO_DIR}/data/countries" ]]; then
  find "${DATA_REPO_DIR}/data/countries" -name "*.json" -type f \
   | sed 's|.*/||' | sed 's|\.json$||' | sort > "${github_countries_file}"
 else
  touch "${github_countries_file}"
 fi

 # Find countries in GitHub that are not in database
 local obsolete_countries
 obsolete_countries=$(comm -23 "${github_countries_file}" "${db_countries_file}")

 rm -f "${db_countries_file}" "${github_countries_file}"

 if [[ -z "${obsolete_countries}" ]]; then
  print_info "No obsolete countries found"
  return 0
 fi

 local obsolete_count
 obsolete_count=$(echo "${obsolete_countries}" | grep -c . || echo "0")
 print_warn "Found ${obsolete_count} obsolete countries to remove"

 # Remove each obsolete country
 echo "${obsolete_countries}" | while read -r country_id; do
  if [[ -z "${country_id}" ]]; then
   continue
  fi

  local country_file="data/countries/${country_id}.json"
  if [[ -f "${DATA_REPO_DIR}/${country_file}" ]]; then
   print_warn "Removing obsolete country: ${country_id}"
   git rm "${country_file}" > /dev/null 2>&1 || true
  fi
 done

 # Commit removal if there are changes
 if ! git diff --cached --quiet; then
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  git commit -m "Remove obsolete countries - ${timestamp}

Removed countries that no longer exist in local database." > /dev/null 2>&1
  git push origin main > /dev/null 2>&1 || print_warn "Failed to push removal of obsolete countries"
  print_success "Removed ${obsolete_count} obsolete countries"
 else
  print_info "No obsolete countries to remove"
 fi
}

# Generate README.md with alphabetical list of countries
generate_countries_readme() {
 print_info "Generating countries README.md..."

 readme_file="${DATA_REPO_DIR}/data/countries/README.md"
 temp_readme=$(mktemp "/tmp/countries_readme_XXXXXX.md")

 # Header
 cat > "${temp_readme}" << 'EOF'
# Countries Data

This directory contains JSON files with country profiles from OSM Notes Analytics.

## Available Countries

The following countries are available (sorted alphabetically):

EOF

 # Get countries from database with names
 psql -d "${DBNAME}" -Atq -c "
SELECT
  country_id,
  COALESCE(country_name_en, country_name, 'Unknown') as name
FROM dwh.datamartcountries
WHERE country_id IS NOT NULL
ORDER BY COALESCE(country_name_en, country_name, 'Unknown');
" | while IFS='|' read -r country_id country_name; do
  if [[ -z "${country_id}" ]]; then
   continue
  fi

  local country_file="${country_id}.json"
  if [[ -f "${DATA_REPO_DIR}/data/countries/${country_file}" ]]; then
   echo "- [${country_name}](./${country_file}) (ID: ${country_id})" >> "${temp_readme}"
  fi
 done

 # Footer
 cat >> "${temp_readme}" << EOF

## Usage

Each JSON file contains complete country profile data including:
- Historical statistics (open, closed, commented notes)
- Resolution metrics
- User activity patterns
- Geographic patterns
- Hashtag usage
- Temporal patterns

## Last Updated

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

 # Copy to repository
 cp "${temp_readme}" "${readme_file}"
 rm -f "${temp_readme}"

 print_success "Countries README.md generated"
}

# Update country index and metadata
update_country_index() {
 print_info "Updating country index..."

 cd "${ANALYTICS_DIR}"

 # Create temporary directory for index files
 local temp_index_dir
 temp_index_dir=$(mktemp -d "/tmp/country_index_XXXXXX")
 readonly temp_index_dir

 # Export country index
 if ! psql -d "${DBNAME}" -Atq -c "
  SELECT COALESCE(json_agg(t), '[]'::json)
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
      notes_still_open_count,
      notes_health_score,
      new_vs_resolved_ratio,
      notes_created_last_30_days,
      notes_resolved_last_30_days
    FROM dwh.datamartcountries
    WHERE country_id IS NOT NULL
    ORDER BY history_whole_open DESC NULLS LAST, history_whole_closed DESC NULLS LAST
  ) t
" > "${temp_index_dir}/countries.json" 2> /dev/null; then
  print_error "Failed to export country index"
  rm -rf "${temp_index_dir}"
  return 1
 fi

 # Copy index to data repo
 mkdir -p "${DATA_REPO_DIR}/data/indexes"
 cp "${temp_index_dir}/countries.json" "${DATA_REPO_DIR}/data/indexes/countries.json"

 # Commit and push index
 cd "${DATA_REPO_DIR}"
 git checkout main 2> /dev/null || true
 git pull origin main 2> /dev/null || true
 git add "data/indexes/countries.json"

 if ! git diff --cached --quiet; then
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  git commit -m "Auto-update: Country index - ${timestamp}" > /dev/null 2>&1
  git push origin main > /dev/null 2>&1 || print_warn "Failed to push country index"
 fi

 rm -rf "${temp_index_dir}"
 print_success "Country index updated"
}

# Setup lock file for single execution
setup_lock() {
 print_warn "Validating single execution."
 exec 7> "${LOCK}"
 if ! flock -n 7; then
  print_error "Another instance of ${BASENAME} is already running."
  print_error "Lock file: ${LOCK}"
  if [[ -f "${LOCK}" ]]; then
   print_error "Lock file contents:"
   cat "${LOCK}" || true
  fi
  exit 1
 fi

 cat > "${LOCK}" << EOF
PID: ${ORIGINAL_PID}
Process: ${BASENAME}
Started: ${PROCESS_START_TIME}
Main script: ${0}
EOF
}

# Cleanup function to remove lock file
cleanup() {
 rm -f "${LOCK}" 2> /dev/null || true
}

# Trap to cleanup lock file on exit
trap cleanup EXIT INT TERM

# Setup lock before proceeding
setup_lock

# Check if data repository exists
if [[ ! -d "${DATA_REPO_DIR}" ]]; then
 print_error "Data repository not found at: ${DATA_REPO_DIR}"
 echo ""
 echo "Please create the repository first:"
 echo "1. Go to https://github.com/OSMLatam/OSM-Notes-Data"
 echo "2. Clone it: git clone https://github.com/OSMLatam/OSM-Notes-Data.git"
 echo ""
 exit 1
fi

# Main execution: Intelligent incremental mode (country-by-country)
print_info "Using intelligent incremental mode (country-by-country)"
print_info "Max age for regeneration: ${MAX_AGE_DAYS} days"
print_info "Countries per batch: ${COUNTRIES_PER_BATCH}"

# Ensure data repository is up to date
cd "${DATA_REPO_DIR}"
git checkout main 2> /dev/null || true
git pull origin main 2> /dev/null || true

# Create countries directory if it doesn't exist
mkdir -p "${DATA_REPO_DIR}/data/countries"

# Copy schemas once at the beginning
print_info "Copying JSON schemas to data repository..."
SCHEMA_SOURCE_DIR="${ANALYTICS_DIR}/lib/osm-common/schemas"
SCHEMA_TARGET_DIR="${DATA_REPO_DIR}/schemas"

if [[ -d "${SCHEMA_SOURCE_DIR}" ]]; then
 mkdir -p "${SCHEMA_TARGET_DIR}"
 rsync -av --include="*.json" --include="README.md" --exclude="*" "${SCHEMA_SOURCE_DIR}/" "${SCHEMA_TARGET_DIR}/" > /dev/null 2>&1 || true
fi

# Remove obsolete countries from GitHub
remove_obsolete_countries

# Get list of countries to export
print_info "Identifying countries that need export..."
countries_to_export=$(get_countries_to_export)

if [[ -z "${countries_to_export}" ]]; then
 print_success "No countries need export. All countries are up to date!"
 # Still update index and README
 update_country_index
 generate_countries_readme
 # Commit and push README if changed
 cd "${DATA_REPO_DIR}"
 git add "data/countries/README.md" 2> /dev/null || true
 if ! git diff --cached --quiet; then
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  git commit -m "Update countries README - ${timestamp}" > /dev/null 2>&1
  git push origin main > /dev/null 2>&1 || true
 fi
 exit 0
fi

total_countries=$(echo "${countries_to_export}" | wc -l)
print_info "Found ${total_countries} countries that need export"

# Process countries one by one
processed=0
successful=0
failed=0

# Save countries to temporary file to avoid subshell issues
temp_countries_file=$(mktemp "/tmp/countries_list_XXXXXX.txt")
echo "${countries_to_export}" > "${temp_countries_file}"

while IFS='|' read -r country_id country_name; do
 if [[ -z "${country_id}" ]]; then
  continue
 fi

 processed=$((processed + 1))
 print_info "[${processed}/${total_countries}] Processing country ${country_id}..."

 # Create temporary file for export
 temp_file=$(mktemp "/tmp/country_${country_id}_XXXXXX.json")

 # Export country
 if export_single_country "${country_id}" "${country_name}" "${temp_file}"; then
  # Copy to data repository
  cp "${temp_file}" "${DATA_REPO_DIR}/data/countries/${country_id}.json"

  # Commit and push
  if commit_and_push_country "${country_id}" "${country_name}"; then
   successful=$((successful + 1))

   # Mark as exported in database
   psql -d "${DBNAME}" -Atq -c "
     UPDATE dwh.datamartcountries
     SET json_exported = TRUE
     WHERE country_id = ${country_id}
	" > /dev/null 2>&1 || true

   print_success "Country ${country_id} completed successfully"
  else
   failed=$((failed + 1))
   print_error "Failed to push country ${country_id}"
  fi
 else
  failed=$((failed + 1))
  print_error "Failed to export country ${country_id}"
 fi

 # Cleanup temp file
 rm -f "${temp_file}"

 # Take a break every COUNTRIES_PER_BATCH countries
 if [[ $((processed % COUNTRIES_PER_BATCH)) -eq 0 ]]; then
  print_info "Processed ${processed} countries. Taking a short break..."
  sleep 2
 fi
done < "${temp_countries_file}"

rm -f "${temp_countries_file}"

# Update indexes and README at the end
update_country_index
generate_countries_readme

# Commit and push README if changed
cd "${DATA_REPO_DIR}"
git add "data/countries/README.md" 2> /dev/null || true
if ! git diff --cached --quiet; then
 timestamp=$(date '+%Y-%m-%d %H:%M:%S')
 git commit -m "Update countries README - ${timestamp}" > /dev/null 2>&1
 git push origin main > /dev/null 2>&1 || print_warn "Failed to push countries README"
fi

# Summary
print_info "Export completed!"
print_info "Total processed: ${processed}"
print_info "Successful: ${successful}"
if [[ ${failed} -gt 0 ]]; then
 print_warn "Failed: ${failed}"
fi

print_info "Allow 1-2 minutes for GitHub Pages to update"
print_info "Schemas available at: https://osmlatam.github.io/OSM-Notes-Data/schemas/"

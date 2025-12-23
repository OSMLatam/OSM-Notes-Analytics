#!/bin/bash

# Exports CSV files and pushes to GitHub Pages data repository
# This script exports closed notes to CSV (one per country) and publishes them
# to the OSM-Notes-Data repository without preserving CSV file history
# (other files in the repository maintain their history)
#
# Usage: ./bin/dwh/exportAndPushCSVToGitHub.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-XX

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &> /dev/null && pwd)"
readonly SCRIPT_DIR
ANALYTICS_DIR="${SCRIPT_DIR}"
readonly ANALYTICS_DIR
DATA_REPO_DIR="${HOME}/github/OSM-Notes-Data"
readonly DATA_REPO_DIR

# Loads the global properties
# shellcheck disable=SC1091
source "${ANALYTICS_DIR}/etc/properties.sh"
# Load local properties if they exist (overrides global settings)
if [[ -f "${ANALYTICS_DIR}/etc/properties.sh.local" ]]; then
 # shellcheck disable=SC1091
 source "${ANALYTICS_DIR}/etc/properties.sh.local"
fi

# SQL script path
SQL_SCRIPT="${ANALYTICS_DIR}/sql/dwh/export/exportClosedNotesByCountry.sql"
readonly SQL_SCRIPT

# Temporary directory for CSV export
TEMP_CSV_DIR=$(mktemp -d "/tmp/csv_export_XXXXXX")
readonly TEMP_CSV_DIR

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

# Function to sanitize country name for filename
function __sanitize_filename() {
 local name="${1}"
 # Replace spaces with underscores, remove special characters
 echo "${name}" | sed 's/ /_/g' | sed 's/[^a-zA-Z0-9_-]//g' | tr '[:upper:]' '[:lower:]'
}

# Function to export notes for a specific country
function __export_country_notes() {
 local country_id="${1}"
 local country_name="${2}"
 local sanitized_name
 sanitized_name=$(__sanitize_filename "${country_name}")

 local output_file="${TEMP_CSV_DIR}/${country_id}_${sanitized_name}.csv"

 print_info "Exporting notes for country: ${country_name} (ID: ${country_id})"

 # Create CSV with header and data
 {
  # Header row (optimized order for AI context)
  echo "note_id,country_name,latitude,longitude,opened_at,closed_at,days_to_resolution,opened_by_username,opening_comment,total_comments,was_reopened,closed_by_username,closing_comment"

  # Data rows - replace :country_id variable in SQL and execute
  sed "s/:country_id/${country_id}/g" "${SQL_SCRIPT}" \
   | psql -d "${DBNAME_DWH}" \
    --csv \
    -t \
    2> /dev/null
 } > "${output_file}"

 # Count lines (excluding header)
 local line_count
 line_count=$(wc -l < "${output_file}" | tr -d ' ')
 line_count=$((line_count - 1)) # Subtract header row

 if [[ ${line_count} -gt 0 ]]; then
  print_info "  Exported ${line_count} notes"
  return 0
 else
  print_warn "  No notes found for country ${country_name} (ID: ${country_id})"
  # Remove empty file
  rm -f "${output_file}"
  return 1
 fi
}

# Cleanup function
function __cleanup() {
 rm -rf "${TEMP_CSV_DIR}" 2> /dev/null || true
 rm -f "${COUNTRY_LIST:-}" 2> /dev/null || true
}
trap __cleanup EXIT

# Check if data repository exists
if [[ ! -d "${DATA_REPO_DIR}" ]]; then
 print_error "Data repository not found at: ${DATA_REPO_DIR}"
 echo ""
 echo "Please create the repository first:"
 echo "1. Go to https://github.com/OSMLatam/OSM-Notes-Data"
 echo "2. Clone it: git clone https://github.com/OSMLatam/OSM-Notes-Data.git ${DATA_REPO_DIR}"
 echo ""
 exit 1
fi

# Step 1: Export CSV files
print_info "Step 1: Exporting CSV files from Analytics..."

# Check if dwh schema exists
if ! psql -d "${DBNAME_DWH}" -Atq -c "SELECT 1 FROM information_schema.schemata WHERE schema_name = 'dwh'" | grep -q 1; then
 print_error "Schema 'dwh' does not exist. Please run the ETL process first."
 exit 1
fi

# Check if SQL script exists
if [[ ! -f "${SQL_SCRIPT}" ]]; then
 print_error "SQL script not found: ${SQL_SCRIPT}"
 exit 1
fi

# Create temporary directory for CSV export
mkdir -p "${TEMP_CSV_DIR}"

# Get list of countries that have closed notes
print_info "Getting list of countries with closed notes..."

# Export notes for each country
COUNTRY_LIST=$(mktemp)
psql -d "${DBNAME_DWH}" -Atq << 'EOF' > "${COUNTRY_LIST}"
SELECT DISTINCT
  dc.country_id,
  COALESCE(c.country_name, 'Unknown') AS country_name
FROM dwh.facts f
  JOIN dwh.dimension_countries dc
    ON f.dimension_id_country = dc.dimension_country_id
  LEFT JOIN countries c
    ON dc.country_id = c.country_id
WHERE f.action_comment = 'closed'
ORDER BY COALESCE(c.country_name, 'Unknown');
EOF

total_countries=0
exported_countries=0
total_notes=0

while IFS='|' read -r country_id country_name; do
 if [[ -n "${country_id}" && -n "${country_name}" ]]; then
  total_countries=$((total_countries + 1))

  if __export_country_notes "${country_id}" "${country_name}"; then
   exported_countries=$((exported_countries + 1))
   # Count notes in the file
   file_notes=$(wc -l < "${TEMP_CSV_DIR}/${country_id}_$(__sanitize_filename "${country_name}").csv" | tr -d ' ')
   file_notes=$((file_notes - 1)) # Subtract header
   total_notes=$((total_notes + file_notes))
  fi
 fi
done < "${COUNTRY_LIST}"

rm -f "${COUNTRY_LIST}"

if [[ ${exported_countries} -eq 0 ]]; then
 print_warn "No CSV files were exported"
 exit 0
fi

print_success "Export completed: ${exported_countries} countries, ${total_notes} total notes"

# Step 2: Copy to data repository
print_info "Step 2: Copying CSV files to data repository..."
CSV_TARGET_DIR="${DATA_REPO_DIR}/csv/notes-by-country"
mkdir -p "${CSV_TARGET_DIR}"

# Copy all CSV files
if ! rsync -av --delete "${TEMP_CSV_DIR}/" "${CSV_TARGET_DIR}/"; then
 print_error "Failed to copy CSV files"
 exit 1
fi

print_success "CSV files copied to data repository"

# Step 3: Git commit and push (without preserving CSV history)
print_info "Step 3: Committing and pushing to GitHub..."

cd "${DATA_REPO_DIR}"

# Ensure we're on main branch
git checkout main 2> /dev/null || true

# Remove CSV directory from git index (if it exists) to start fresh
# This removes CSV files from tracking but keeps them in working directory
if git ls-files --error-unmatch csv/notes-by-country/ > /dev/null 2>&1; then
 print_info "Removing existing CSV files from git history..."
 git rm -r --cached csv/notes-by-country/ 2> /dev/null || true
fi

# Add all CSV files (fresh add, no history)
print_info "Adding CSV files to git..."
git add csv/notes-by-country/

# Check if there are changes to commit
if git diff --cached --quiet; then
 print_warn "No changes to commit (CSV files are identical to previous version)"
 exit 0
fi

# Get file count for commit message
FILE_COUNT=$(find csv/notes-by-country/ -name "*.csv" 2> /dev/null | wc -l || echo "0")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Commit changes (only CSV files, replaces previous CSV commits)
git commit -m "Auto-update: ${FILE_COUNT} CSV files (closed notes by country) - ${TIMESTAMP}

This commit replaces all previous CSV files. CSV history is not preserved.
Other files in the repository maintain their full history."

# Push to GitHub
# Note: In production, ensure git credentials are configured for the user running this script
# See docs/GitHub_Push_Setup.md for configuration instructions
print_info "Pushing to GitHub..."
if git push origin main; then
 print_success "CSV files pushed to GitHub successfully"
 echo ""
 echo "CSV files are now available at:"
 echo "https://github.com/OSMLatam/OSM-Notes-Data/tree/main/csv/notes-by-country"
 echo ""
 echo "Raw file access:"
 echo "https://raw.githubusercontent.com/OSMLatam/OSM-Notes-Data/main/csv/notes-by-country/"
else
 print_error "Failed to push to GitHub"
 echo ""
 echo "Please check:"
 echo "1. Git credentials are configured (SSH key or Personal Access Token)"
 echo "2. Remote repository exists and is accessible"
 echo "3. Network connection is available"
 echo ""
 echo "For production setup, see: docs/GitHub_Push_Setup.md"
 exit 1
fi

echo ""
print_success "Done! CSV files updated in GitHub repository"
print_info "Note: CSV file history is not preserved. Each export replaces previous CSV files."

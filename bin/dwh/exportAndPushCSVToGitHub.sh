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

# Script basename for log file
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME

# Configure log file when running from cron (not a terminal)
# This prevents output from being sent by email and saves it to a log file instead
if [[ ! -t 1 ]] && [[ "${1:-}" != "--help" ]] && [[ "${1:-}" != "-h" ]]; then
 LOG_DIR="/tmp"
 mkdir -p "${LOG_DIR}"
 LOG_FILE="${LOG_DIR}/${BASENAME}.log"
 # Redirect all output to log file to prevent cron from sending emails
 exec >> "${LOG_FILE}" 2>&1
fi

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

# Support both locations: ${HOME}/OSM-Notes-Data (preferred) and ${HOME}/github/OSM-Notes-Data (fallback)
if [[ -d "${HOME}/OSM-Notes-Data" ]]; then
 DATA_REPO_DIR="${HOME}/OSM-Notes-Data"
elif [[ -d "${HOME}/github/OSM-Notes-Data" ]]; then
 DATA_REPO_DIR="${HOME}/github/OSM-Notes-Data"
else
 DATA_REPO_DIR="${HOME}/OSM-Notes-Data"
fi
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

# Lock file for single execution
LOCK="${TEMP_CSV_DIR}/${BASENAME}.lock"
readonly LOCK

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

# Wrapper for psql that sets application_name for better process identification
# Usage: __psql_with_appname [appname] [psql_args...]
# If appname is not provided, uses BASENAME (script name without .sh)
# If first argument starts with '-', it's a psql option, not an appname
function __psql_with_appname {
 local appname
 if [[ "${1:-}" =~ ^- ]]; then
  # First argument is a psql option, use default appname
  appname="${BASENAME}"
 else
  # First argument is an appname
  appname="${1}"
  shift
 fi
 PGAPPNAME="${appname}" psql "$@"
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
 local start_time
 local end_time
 local duration

 print_info "Exporting notes for country: ${country_name} (ID: ${country_id})"
 start_time=$(date +%s)

 # Create CSV with header and data
 {
  # Header row (optimized order for AI context)
  echo "note_id,country_name,latitude,longitude,opened_at,closed_at,days_to_resolution,opened_by_username,opening_comment,total_comments,was_reopened,closed_by_username,closing_comment"

  # Data rows - replace :country_id variable in SQL and execute
  sed "s/:country_id/${country_id}/g" "${SQL_SCRIPT}" \
   | __psql_with_appname "${BASENAME}-country-${country_id}" -d "${DBNAME_DWH}" \
    --csv \
    -t \
    2> /dev/null
 } > "${output_file}"

 end_time=$(date +%s)
 duration=$((end_time - start_time))

 # Count lines (excluding header)
 local line_count
 line_count=$(wc -l < "${output_file}" | tr -d ' ')
 line_count=$((line_count - 1)) # Subtract header row

 if [[ ${line_count} -gt 0 ]]; then
  print_info "  Exported ${line_count} notes in ${duration}s"
  return 0
 else
  print_warn "  No notes found for country ${country_name} (ID: ${country_id}) in ${duration}s"
  # Remove empty file
  rm -f "${output_file}"
  return 1
 fi
}

# Cleanup function
function __cleanup() {
 rm -rf "${TEMP_CSV_DIR}" 2> /dev/null || true
 rm -f "${COUNTRY_LIST:-}" 2> /dev/null || true
 rm -f "${LOCK:-}" 2> /dev/null || true
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
 echo "Or if it exists elsewhere, create a symlink or set DATA_REPO_DIR environment variable"
 echo ""
 exit 1
fi

# Safety check: Prevent execution if DBNAME_DWH looks like a test database
# This prevents accidentally overwriting production CSV files with test data
if [[ "${DBNAME_DWH:-}" =~ ^(test|mock|demo|dev|local).*$ ]] || [[ "${DBNAME_DWH:-}" =~ .*_(test|mock|demo|dev)$ ]]; then
 print_error "Safety check failed: DBNAME_DWH appears to be a test database: ${DBNAME_DWH}"
 echo ""
 echo "This script should only run against production databases to avoid corrupting"
 echo "production data in GitHub. If you need to test, use a separate test repository."
 echo ""
 echo "To override this check, set FORCE_EXPORT=true environment variable"
 if [[ "${FORCE_EXPORT:-}" != "true" ]]; then
  exit 1
 else
  print_warn "FORCE_EXPORT=true is set - proceeding despite test database warning"
 fi
fi

# Validate single execution using flock
print_info "Validating single execution..."
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

# Write lock file information
cat > "${LOCK}" << EOF
PID: $$
Process: ${BASENAME}
Started: $(date '+%Y-%m-%d %H:%M:%S')
Temporary directory: ${TEMP_CSV_DIR}
Main script: ${0}
EOF

# Step 1: Export CSV files
print_info "Step 1: Exporting CSV files from Analytics..."
STEP1_START=$(date +%s)

# Check if dwh schema exists
if ! __psql_with_appname -d "${DBNAME_DWH}" -Atq -c "SELECT 1 FROM information_schema.schemata WHERE schema_name = 'dwh'" | grep -q 1; then
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
COUNTRY_LIST_START=$(date +%s)

# Export notes for each country
COUNTRY_LIST=$(mktemp)
__psql_with_appname -d "${DBNAME_DWH}" -Atq << 'EOF' > "${COUNTRY_LIST}"
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

COUNTRY_LIST_END=$(date +%s)
COUNTRY_LIST_DURATION=$((COUNTRY_LIST_END - COUNTRY_LIST_START))
print_info "Country list retrieved in ${COUNTRY_LIST_DURATION}s"

# Configuration for incremental commits
# Commit and push every N countries to reduce risk of losing work
COUNTRIES_PER_COMMIT="${COUNTRIES_PER_COMMIT:-20}"
readonly COUNTRIES_PER_COMMIT

# CSV target directory (needed for incremental commits)
CSV_TARGET_DIR="${DATA_REPO_DIR}/csv/notes-by-country"
mkdir -p "${CSV_TARGET_DIR}"

TOTAL_COUNTRIES=0
EXPORTED_COUNTRIES=0
TOTAL_NOTES=0
EXPORT_START=$(date +%s)
COMMITTED_COUNTRIES=0

# Function to commit and push current batch of CSV files
function __commit_and_push_batch() {
 local batch_start="${1}"
 local batch_end="${2}"
 local batch_count="${3}"

 print_info "Committing batch: countries ${batch_start}-${batch_end} (${batch_count} countries)"

 cd "${DATA_REPO_DIR}"

 # Configure git safe.directory if needed (for dubious ownership error)
 git config --global --add safe.directory "${DATA_REPO_DIR}" 2> /dev/null || true

 # Check and fix permissions if needed
 # The .git directory should be writable by the current user
 CURRENT_USER=$(whoami)
 GIT_OWNER=$(stat -c '%U' "${DATA_REPO_DIR}/.git" 2> /dev/null || echo "unknown")
 GIT_GROUP=$(stat -c '%G' "${DATA_REPO_DIR}/.git" 2> /dev/null || echo "unknown")
 
 if [[ ! -w "${DATA_REPO_DIR}/.git" ]]; then
  print_warn "Git directory not writable. Checking ownership..."
  
  if [[ "${CURRENT_USER}" != "${GIT_OWNER}" ]]; then
   # Check if user is in the git owner's group
   if groups "${CURRENT_USER}" 2>/dev/null | grep -q "\b${GIT_GROUP}\b"; then
    # User is in the group, try to fix group permissions
    print_info "User ${CURRENT_USER} is in group ${GIT_GROUP}, checking group permissions..."
    if [[ -r "${DATA_REPO_DIR}/.git" ]]; then
     # Try to make group writable
     chmod -R g+w "${DATA_REPO_DIR}/.git" 2> /dev/null || true
     if [[ -w "${DATA_REPO_DIR}/.git" ]]; then
      print_success "Fixed group permissions"
     else
      print_error "Could not fix group permissions. Owner: ${GIT_OWNER}, Group: ${GIT_GROUP}"
      print_error "Please run: sudo chmod -R g+w ${DATA_REPO_DIR}/.git"
      print_error "Or: sudo chown -R ${CURRENT_USER}:${CURRENT_USER} ${DATA_REPO_DIR}/.git"
      return 1
     fi
    else
     print_error "Cannot read git directory. Please fix permissions."
     return 1
    fi
   else
    print_error "Git directory owned by ${GIT_OWNER}:${GIT_GROUP}, but script running as ${CURRENT_USER}"
    print_error "Please fix ownership: sudo chown -R ${CURRENT_USER}:${CURRENT_USER} ${DATA_REPO_DIR}/.git"
    print_error "Or add ${CURRENT_USER} to ${GIT_GROUP} group: sudo usermod -a -G ${GIT_GROUP} ${CURRENT_USER}"
    return 1
   fi
  else
   # Same owner, try to fix permissions
   if ! chmod -R u+w "${DATA_REPO_DIR}/.git" 2> /dev/null; then
    print_error "Could not fix git directory permissions"
    return 1
   fi
  fi
 fi

 # Remove stale lock file if it exists
 if [[ -f "${DATA_REPO_DIR}/.git/index.lock" ]]; then
  print_warn "Removing stale git lock file..."
  if ! rm -f "${DATA_REPO_DIR}/.git/index.lock" 2> /dev/null; then
   # Try with different user if we have sudo access
   if command -v sudo > /dev/null 2>&1 && [[ "${CURRENT_USER}" != "${GIT_OWNER}" ]]; then
    sudo -u "${GIT_OWNER}" rm -f "${DATA_REPO_DIR}/.git/index.lock" 2> /dev/null || true
   fi
   if [[ -f "${DATA_REPO_DIR}/.git/index.lock" ]]; then
    print_error "Could not remove lock file. Please remove manually:"
    print_error "  sudo rm -f ${DATA_REPO_DIR}/.git/index.lock"
    return 1
   fi
  fi
 fi

 # Ensure we're on main branch
 git checkout main 2> /dev/null || true

 # Pull latest changes to avoid conflicts
 git pull origin main 2> /dev/null || true

 # Copy current batch of CSV files (exclude lock files and other non-CSV files)
 rsync -av --exclude='*.lock' --exclude='*.log' "${TEMP_CSV_DIR}/" "${CSV_TARGET_DIR}/" > /dev/null 2>&1

 # Remove CSV directory from git index if this is the first batch
 if [[ ${COMMITTED_COUNTRIES} -eq 0 ]] && git ls-files --error-unmatch csv/notes-by-country/ > /dev/null 2>&1; then
  print_info "Removing existing CSV files from git history..."
  git rm -r --cached csv/notes-by-country/ 2> /dev/null || true
 fi

 # Remove any non-CSV files that might have been copied (lock files, etc.)
 find "${CSV_TARGET_DIR}" -type f ! -name "*.csv" -delete 2> /dev/null || true

 # Add all CSV files (including previous batches)
 git add csv/notes-by-country/*.csv 2> /dev/null || true

 # Check if there are changes to commit
 # Try different methods for compatibility with different git versions
 local has_changes=false
 if git diff --staged --quiet 2> /dev/null; then
  has_changes=false
 elif git diff --cached --quiet 2> /dev/null; then
  has_changes=false
 elif git status --porcelain csv/notes-by-country/ 2> /dev/null | grep -qE "^A|^M"; then
  has_changes=true
 else
  # Last resort: check if files were actually added
  if git status --short csv/notes-by-country/ 2> /dev/null | grep -q .; then
   has_changes=true
  fi
 fi

 if [[ "${has_changes}" == "false" ]]; then
  print_warn "No changes to commit in this batch"
  return 0
 fi

 # Get file count for commit message
 FILE_COUNT=$(find csv/notes-by-country/ -name "*.csv" 2> /dev/null | wc -l || echo "0")
 TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

 # Check if the last commit was a CSV update (to use --amend and avoid history)
 # This keeps only the latest CSV version in git history
 local use_amend=false
 local last_commit_msg
 last_commit_msg=$(git log -1 --pretty=%B 2> /dev/null || echo "")
 if echo "${last_commit_msg}" | grep -q "Auto-update.*CSV files"; then
  use_amend=true
  print_info "Previous CSV commit found, will amend to replace it (no history preserved)"
 fi

 # Commit changes locally (amend if previous commit was CSV to avoid history)
 # NO PUSH here - we'll push only once at the end with a single commit
 local commit_output
 if [[ "${use_amend}" == "true" ]]; then
  commit_output=$(git commit --amend -m "Auto-update: ${FILE_COUNT} CSV files (closed notes by country) - ${TIMESTAMP}

This commit replaces all previous CSV files. CSV history is not preserved.
Total countries exported: ${EXPORTED_COUNTRIES}
Total notes: ${TOTAL_NOTES}" 2>&1)
 else
  commit_output=$(git commit -m "Auto-update: ${FILE_COUNT} CSV files (closed notes by country) - ${TIMESTAMP}

This commit replaces all previous CSV files. CSV history is not preserved.
Total countries exported: ${EXPORTED_COUNTRIES}
Total notes: ${TOTAL_NOTES}" 2>&1)
 fi
 local commit_exit_code=$?

 if [[ ${commit_exit_code} -eq 0 ]]; then
  # Only commit locally, NO push (push will happen once at the end)
  print_success "Batch ${batch_start}-${batch_end} committed locally (${FILE_COUNT} CSV files, no push yet)"
  COMMITTED_COUNTRIES=$((COMMITTED_COUNTRIES + batch_count))
  return 0
 else
  print_error "Failed to commit batch ${batch_start}-${batch_end}"
  print_error "Git commit error: ${commit_output}"
  return 1
 fi
}

BATCH_START=1
BATCH_COUNT=0

while IFS='|' read -r country_id country_name; do
 if [[ -n "${country_id}" && -n "${country_name}" ]]; then
  TOTAL_COUNTRIES=$((TOTAL_COUNTRIES + 1))

  # shellcheck disable=SC2310  # Function invocation in condition is intentional for error handling
  if __export_country_notes "${country_id}" "${country_name}"; then
   EXPORTED_COUNTRIES=$((EXPORTED_COUNTRIES + 1))
   BATCH_COUNT=$((BATCH_COUNT + 1))

   # Count notes in the file
   sanitized_name=$(__sanitize_filename "${country_name}")
   file_notes=$(wc -l < "${TEMP_CSV_DIR}/${country_id}_${sanitized_name}.csv" | tr -d ' ')
   file_notes=$((file_notes - 1)) # Subtract header
   TOTAL_NOTES=$((TOTAL_NOTES + file_notes))

   # Commit and push every COUNTRIES_PER_COMMIT countries
   if [[ ${BATCH_COUNT} -ge ${COUNTRIES_PER_COMMIT} ]]; then
    BATCH_END=${EXPORTED_COUNTRIES}
    if __commit_and_push_batch "${BATCH_START}" "${BATCH_END}" "${BATCH_COUNT}"; then
     BATCH_START=$((BATCH_END + 1))
     BATCH_COUNT=0
    else
     print_warn "Continuing despite commit failure. Will retry at end."
    fi
   fi
  fi
 fi
done < "${COUNTRY_LIST}"

# Commit remaining countries if any (local commit only, no push)
if [[ ${BATCH_COUNT} -gt 0 ]]; then
 BATCH_END=${EXPORTED_COUNTRIES}
 __commit_and_push_batch "${BATCH_START}" "${BATCH_END}" "${BATCH_COUNT}"
fi

# Step 2: Create single commit with all CSV files (replacing any previous CSV commits)
print_info "Step 2: Creating single CSV commit (no history preserved)..."
STEP2_START=$(date +%s)
cd "${DATA_REPO_DIR}"

# Ensure we're on main branch
git checkout main 2> /dev/null || true

# Pull latest changes to avoid conflicts
git pull origin main 2> /dev/null || true

# Find the commit before any CSV commits (to reset to)
base_commit=$(git log --oneline --all --grep="Auto-update.*CSV files" 2> /dev/null | tail -1 | cut -d' ' -f1)

if [[ -n "${base_commit}" ]]; then
 # Reset to before CSV commits, keeping all files staged
 print_info "Resetting to before CSV commits (keeping files)..."
 git reset --soft "${base_commit}^" 2> /dev/null || git reset --soft HEAD~1 2> /dev/null || true
else
 # No previous CSV commits, remove from index if they exist
 if git ls-files --error-unmatch csv/notes-by-country/ > /dev/null 2>&1; then
  print_info "Removing existing CSV files from git history..."
  git rm -r --cached csv/notes-by-country/ 2> /dev/null || true
 fi
fi

# Ensure all CSV files are copied and staged
rsync -av --exclude='*.lock' --exclude='*.log' "${TEMP_CSV_DIR}/" "${CSV_TARGET_DIR}/" > /dev/null 2>&1
find "${CSV_TARGET_DIR}" -type f ! -name "*.csv" -delete 2> /dev/null || true
git add csv/notes-by-country/*.csv 2> /dev/null || true

# Create single commit with all CSV files
FILE_COUNT=$(find csv/notes-by-country/ -name "*.csv" 2> /dev/null | wc -l || echo "0")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if git diff --cached --quiet 2> /dev/null && git diff --staged --quiet 2> /dev/null; then
 print_warn "No changes to commit (CSV files are identical to previous version)"
else
 if git commit -m "Auto-update: ${FILE_COUNT} CSV files (closed notes by country) - ${TIMESTAMP}

This commit replaces all previous CSV files. CSV history is not preserved.
Total countries: ${EXPORTED_COUNTRIES}
Total notes: ${TOTAL_NOTES}" > /dev/null 2>&1; then
  print_success "Single CSV commit created (${FILE_COUNT} files)"
 else
  print_error "Failed to create CSV commit"
  exit 1
 fi
fi

STEP2_END=$(date +%s)
STEP2_DURATION=$((STEP2_END - STEP2_START))
print_success "Step 2 completed in ${STEP2_DURATION}s"

# Step 3: Push single commit to GitHub
print_info "Step 3: Pushing to GitHub (single commit)..."
STEP3_START=$(date +%s)

# Push to GitHub (force if we reset history, otherwise normal push)
if git log --oneline -1 | grep -q "Auto-update.*CSV files"; then
 # We have CSV commits, check if we need to force push
 remote_commit_count=$(git log --oneline origin/main..HEAD --grep="Auto-update.*CSV files" 2> /dev/null | wc -l || echo "0")
 
 if [[ ${remote_commit_count} -gt 1 ]] || git log --oneline origin/main | grep -q "Auto-update.*CSV files"; then
  # Force push to replace remote CSV commits with our single commit
  if git push --force-with-lease origin main > /dev/null 2>&1; then
   STEP3_END=$(date +%s)
   STEP3_DURATION=$((STEP3_END - STEP3_START))
   print_success "CSV files pushed to GitHub successfully in ${STEP3_DURATION}s (single commit, no history)"
  else
   print_error "Failed to push to GitHub"
   exit 1
  fi
 else
  # Normal push (first time or no previous CSV commits on remote)
  if git push origin main > /dev/null 2>&1; then
   STEP3_END=$(date +%s)
   STEP3_DURATION=$((STEP3_END - STEP3_START))
   print_success "CSV files pushed to GitHub successfully in ${STEP3_DURATION}s"
  else
   print_error "Failed to push to GitHub"
   exit 1
  fi
 fi
else
 print_warn "No CSV commit to push"
fi

rm -f "${COUNTRY_LIST}"

EXPORT_END=$(date +%s)
EXPORT_DURATION=$((EXPORT_END - EXPORT_START))

if [[ ${EXPORTED_COUNTRIES} -eq 0 ]]; then
 print_warn "No CSV files were exported"
 exit 0
fi

STEP1_END=$(date +%s)
STEP1_DURATION=$((STEP1_END - STEP1_START))

# Calculate average time per country (using integer division)
AVG_TIME_PER_COUNTRY=0
if [[ ${EXPORTED_COUNTRIES} -gt 0 ]]; then
 AVG_TIME_PER_COUNTRY=$((EXPORT_DURATION / EXPORTED_COUNTRIES))
fi

print_success "Export completed: ${EXPORTED_COUNTRIES} countries, ${TOTAL_NOTES} total notes"
print_info "Export timing: ${EXPORT_DURATION}s (countries: ${EXPORTED_COUNTRIES}, avg: ${AVG_TIME_PER_COUNTRY}s per country)"
print_info "Step 1 total time: ${STEP1_DURATION}s"

# Final summary
TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - STEP1_START))

print_success "All CSV files exported"
# Calculate total batches committed locally
TOTAL_BATCHES_LOCAL=$((COMMITTED_COUNTRIES / COUNTRIES_PER_COMMIT))
if [[ $((COMMITTED_COUNTRIES % COUNTRIES_PER_COMMIT)) -gt 0 ]]; then
 TOTAL_BATCHES_LOCAL=$((TOTAL_BATCHES_LOCAL + 1))
fi
print_info "Total batches committed locally: ${TOTAL_BATCHES_LOCAL}"
echo ""
echo "CSV files are now available at:"
echo "https://github.com/OSMLatam/OSM-Notes-Data/tree/main/csv/notes-by-country"
echo ""
echo "Raw file access:"
echo "https://raw.githubusercontent.com/OSMLatam/OSM-Notes-Data/main/csv/notes-by-country/"
echo ""
print_info "Total execution time: ${TOTAL_DURATION}s"
print_info "Note: CSV file history is not preserved. Only the latest version is kept in git."

echo ""
print_success "Done! CSV files updated in GitHub repository"
print_info "Note: CSV file history is not preserved. Each export replaces previous CSV files."

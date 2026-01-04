#!/bin/bash

# Exports JSON files and pushes to GitHub Pages data repository
# This script exports datamarts to JSON and publishes them to the OSM-Notes-Data
# repository without preserving JSON file history (other files maintain their history)
#
# Usage: ./bin/dwh/exportAndPushJSONToGitHub.sh
#
# This script:
# 1. Exports datamarts to JSON files
# 2. Copies JSON files to OSM-Notes-Data/data/
# 3. Copies JSON schemas to OSM-Notes-Data/schemas/
# 4. Commits and pushes to GitHub (replaces previous JSON files)
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-28

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

# Step 1: Export JSON files
print_info "Step 1: Exporting JSON files from Analytics..."
cd "${ANALYTICS_DIR}"

if [[ ! -f "bin/dwh/exportDatamartsToJSON.sh" ]]; then
 print_error "Export script not found"
 exit 1
fi

./bin/dwh/exportDatamartsToJSON.sh

# Check if export was successful
if [[ ! -d "output/json" ]]; then
 print_error "Export failed - output/json directory not found"
 exit 1
fi

print_success "JSON files exported successfully"

# Step 2: Copy to data repository
print_info "Step 2: Copying to data repository..."
mkdir -p "${DATA_REPO_DIR}/data"
rsync -av --delete "${ANALYTICS_DIR}/output/json/" "${DATA_REPO_DIR}/data/"

print_success "Files copied to data repository"

# Step 2.5: Copy JSON schemas to data repository
print_info "Step 2.5: Copying JSON schemas to data repository..."
SCHEMA_SOURCE_DIR="${ANALYTICS_DIR}/lib/osm-common/schemas"
SCHEMA_TARGET_DIR="${DATA_REPO_DIR}/schemas"

if [[ ! -d "${SCHEMA_SOURCE_DIR}" ]]; then
 print_error "Schema directory not found: ${SCHEMA_SOURCE_DIR}"
 exit 1
fi

# Create schemas directory in data repository
mkdir -p "${SCHEMA_TARGET_DIR}"

# Copy all JSON schema files
if ! rsync -av --include="*.json" --include="README.md" --exclude="*" "${SCHEMA_SOURCE_DIR}/" "${SCHEMA_TARGET_DIR}/"; then
 print_error "Failed to copy schemas"
 exit 1
fi

print_success "Schemas copied to data repository"

# Step 3: Git commit and push (without preserving JSON history)
print_info "Step 3: Committing and pushing to GitHub..."

cd "${DATA_REPO_DIR}"

# Ensure we're on main branch
git checkout main 2> /dev/null || true

# Remove data and schemas directories from git index (if they exist) to start fresh
# This removes JSON files from tracking but keeps them in working directory
if git ls-files --error-unmatch data/ > /dev/null 2>&1; then
 print_info "Removing existing JSON data files from git history..."
 git rm -r --cached data/ 2> /dev/null || true
fi

if git ls-files --error-unmatch schemas/ > /dev/null 2>&1; then
 print_info "Removing existing JSON schemas from git history..."
 git rm -r --cached schemas/ 2> /dev/null || true
fi

# Add all JSON files and schemas (fresh add, no history)
print_info "Adding JSON files and schemas to git..."
git add data/ schemas/

# Check if there are changes to commit
if git diff --cached --quiet; then
 print_warn "No changes to commit (JSON files are identical to previous version)"
 exit 0
fi

# Get file count for commit message
FILE_COUNT=$(find data/ -name "*.json" 2> /dev/null | wc -l || echo "0")
SCHEMA_COUNT=$(find schemas/ -name "*.json" 2> /dev/null | wc -l || echo "0")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Commit changes (only JSON files, replaces previous JSON commits)
if [[ ${SCHEMA_COUNT} -gt 0 ]]; then
 git commit -m "Auto-update: ${FILE_COUNT} JSON files and ${SCHEMA_COUNT} schemas - ${TIMESTAMP}

This commit replaces all previous JSON files. JSON history is not preserved.
Other files in the repository maintain their full history."
else
 git commit -m "Auto-update: ${FILE_COUNT} JSON files - ${TIMESTAMP}

This commit replaces all previous JSON files. JSON history is not preserved.
Other files in the repository maintain their full history."
fi

# Push to GitHub
# Note: In production, ensure git credentials are configured for the user running this script
# See docs/GitHub_Push_Setup.md for configuration instructions
if git push origin main; then
 print_success "Data pushed to GitHub successfully"
 echo ""
 echo "Data is now available at:"
 echo "https://osmlatam.github.io/OSM-Notes-Data/"
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
print_success "Done! JSON files updated in GitHub repository"
print_info "Note: JSON file history is not preserved. Each export replaces previous JSON files."
print_info "Allow 1-2 minutes for GitHub Pages to update"
print_info "Schemas available at: https://osmlatam.github.io/OSM-Notes-Data/schemas/"

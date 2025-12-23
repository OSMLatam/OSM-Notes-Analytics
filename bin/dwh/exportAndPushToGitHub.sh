#!/bin/bash

# Exports JSON and pushes to GitHub Pages data repository
# Usage: ./bin/dwh/exportAndPushToGitHub.sh
#
# This script:
# 1. Exports datamarts to JSON files
# 2. Copies JSON files to OSM-Notes-Data/data/
# 3. Copies JSON schemas to OSM-Notes-Data/schemas/
# 4. Commits and pushes to GitHub
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-22

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

# Step 3: Git commit and push
print_info "Step 3: Pushing to GitHub..."

cd "${DATA_REPO_DIR}"

# Check if there are changes
if git diff --quiet && git diff --cached --quiet; then
 print_warn "No changes to commit"
 exit 0
fi

# Get file count for commit message
FILE_COUNT=$(find data/ -name "*.json" | wc -l)
SCHEMA_COUNT=$(find schemas/ -name "*.json" 2> /dev/null | wc -l || echo "0")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Commit changes (data and schemas)
git add data/ schemas/
if [[ ${SCHEMA_COUNT} -gt 0 ]]; then
 git commit -m "Auto-update: ${FILE_COUNT} JSON files and ${SCHEMA_COUNT} schemas exported from Analytics - ${TIMESTAMP}"
else
 git commit -m "Auto-update: ${FILE_COUNT} JSON files exported from Analytics - ${TIMESTAMP}"
fi

# Push to GitHub
if git push origin main; then
 print_success "Data pushed to GitHub successfully"
 echo ""
 echo "Data is now available at:"
 echo "https://osmlatam.github.io/OSM-Notes-Data/"
else
 print_error "Failed to push to GitHub"
 echo ""
 echo "Please check:"
 echo "1. Git credentials are configured"
 echo "2. Remote repository exists and is accessible"
 echo "3. Network connection is available"
 exit 1
fi

echo ""
print_success "Done! Data and schemas updated in GitHub Pages"
print_info "Allow 1-2 minutes for GitHub Pages to update"
print_info "Schemas available at: https://osmlatam.github.io/OSM-Notes-Data/schemas/"

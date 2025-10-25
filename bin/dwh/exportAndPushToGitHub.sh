#!/bin/bash

# Exports JSON and pushes to GitHub Pages data repository
# Usage: ./bin/dwh/exportAndPushToGitHub.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-25

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
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Commit changes
git add data/
git commit -m "Auto-update: ${FILE_COUNT} JSON files exported from Analytics - ${TIMESTAMP}"

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
print_success "Done! Data updated in GitHub Pages"
print_info "Allow 1-2 minutes for GitHub Pages to update"

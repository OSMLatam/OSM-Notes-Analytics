#!/bin/bash

# Setup script for OSM-Notes-Analytics
# This script helps configure the Analytics repository after cloning
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-13

set -euo pipefail

# Colors for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r NC='\033[0m' # No Color

# Script base directory
declare SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCRIPT_DIR

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OSM-Notes-Analytics Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to print status
__print_status() {
 local -r status="${1}"
 local -r message="${2}"
 if [[ "${status}" == "OK" ]]; then
  echo -e "${GREEN}✓${NC} ${message}"
 elif [[ "${status}" == "WARN" ]]; then
  echo -e "${YELLOW}⚠${NC} ${message}"
 else
  echo -e "${RED}✗${NC} ${message}"
 fi
}

# Check prerequisites
echo "Checking prerequisites..."
echo ""

# Check Bash version
declare BASH_VERSION_NUMBER
BASH_VERSION_NUMBER="${BASH_VERSION%%.*}"
if [[ "${BASH_VERSION_NUMBER}" -ge 4 ]]; then
 __print_status "OK" "Bash version: ${BASH_VERSION}"
else
 __print_status "ERROR" "Bash 4.0+ required, found: ${BASH_VERSION}"
 exit 1
fi

# Check PostgreSQL
if command -v psql &> /dev/null; then
 __print_status "OK" "PostgreSQL client found"
else
 __print_status "ERROR" "PostgreSQL client (psql) not found"
 exit 1
fi

# Check if running on Linux
if [[ "$(uname -s)" == "Linux" ]]; then
 __print_status "OK" "Running on Linux"
else
 __print_status "WARN" "Not running on Linux ($(uname -s))"
fi

echo ""
echo "Checking configuration files..."
echo ""

# Check properties.sh
if [[ -f "${SCRIPT_DIR}/etc/properties.sh" ]]; then
 __print_status "OK" "Configuration file found: etc/properties.sh"
else
 __print_status "ERROR" "Configuration file not found: etc/properties.sh"
 exit 1
fi

# Check etl.properties
if [[ -f "${SCRIPT_DIR}/etc/etl.properties" ]]; then
 __print_status "OK" "ETL configuration found: etc/etl.properties"
else
 __print_status "ERROR" "ETL configuration not found: etc/etl.properties"
 exit 1
fi

echo ""
echo "Testing database connection..."
echo ""

# Source properties to get DB config
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/etc/properties.sh"

# Test database connection
if psql -d "${DBNAME}" -U "${DB_USER}" -c "SELECT version();" &> /dev/null; then
 __print_status "OK" "Database connection successful (${DBNAME})"
else
 __print_status "ERROR" "Cannot connect to database: ${DBNAME}"
 echo ""
 echo "Please configure database credentials in etc/properties.sh"
 exit 1
fi

echo ""
echo "Checking base tables (should be populated by Ingestion system)..."
echo ""

# Check if base tables exist and have data
declare -a BASE_TABLES=("notes" "note_comments" "note_comments_text" "users" "countries")
declare ALL_TABLES_OK=true

for TABLE in "${BASE_TABLES[@]}"; do
 if psql -d "${DBNAME}" -U "${DB_USER}" -c "SELECT COUNT(*) FROM ${TABLE};" &> /dev/null; then
  declare COUNT
  COUNT=$(psql -d "${DBNAME}" -U "${DB_USER}" -t -c "SELECT COUNT(*) FROM ${TABLE};")
  COUNT=$(echo "${COUNT}" | tr -d '[:space:]')
  if [[ "${COUNT}" -gt 0 ]]; then
   __print_status "OK" "Table ${TABLE} exists with ${COUNT} rows"
  else
   __print_status "WARN" "Table ${TABLE} exists but is empty"
   ALL_TABLES_OK=false
  fi
 else
  __print_status "ERROR" "Table ${TABLE} does not exist"
  ALL_TABLES_OK=false
 fi
done

if [[ "${ALL_TABLES_OK}" == "false" ]]; then
 echo ""
 echo -e "${YELLOW}⚠ Base tables are not properly populated${NC}"
 echo "Please run the Ingestion system (OSM-Notes-profile) first:"
 echo "  cd ~/github/OSM-Notes-profile"
 echo "  ./bin/process/processPlanetNotes.sh --base"
 echo ""
 read -r -p "Do you want to continue anyway? [y/N] " response
 if [[ ! "${response}" =~ ^[Yy]$ ]]; then
  exit 1
 fi
fi

echo ""
echo "Checking DWH schema..."
echo ""

# Check if DWH schema exists
if psql -d "${DBNAME}" -U "${DB_USER}" -c "\dn dwh" &> /dev/null; then
 __print_status "OK" "DWH schema already exists"
 echo ""
 echo "It looks like the Analytics system was already initialized."
 echo ""
 read -r -p "Do you want to recreate the DWH? [y/N] " response
 if [[ "${response}" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Dropping existing DWH schema..."
  psql -d "${DBNAME}" -U "${DB_USER}" -c "DROP SCHEMA IF EXISTS dwh CASCADE;"
  __print_status "OK" "DWH schema dropped"
 fi
else
 __print_status "OK" "DWH schema does not exist (will be created)"
fi

echo ""
echo "========================================${NC}"
echo "Setup Summary"
echo "========================================${NC}"
echo ""
echo "Database: ${DBNAME}"
echo "User: ${DB_USER}"
echo "Script directory: ${SCRIPT_DIR}"
echo ""
echo "Next steps:"
echo ""
echo "1. Configure your settings (if not already done):"
echo "   nano ${SCRIPT_DIR}/etc/properties.sh"
echo "   nano ${SCRIPT_DIR}/etc/etl.properties"
echo ""
echo "2. Run initial ETL to create DWH:"
echo "   cd ${SCRIPT_DIR}"
echo "   export LOG_LEVEL=INFO"
echo "   ./bin/dwh/ETL.sh --create"
echo ""
echo "3. Populate datamarts:"
echo "   ./bin/dwh/datamartCountries/datamartCountries.sh"
echo "   ./bin/dwh/datamartUsers/datamartUsers.sh"
echo ""
echo "4. Setup cron jobs for regular updates:"
echo "   crontab -e"
echo "   # Add these lines:"
echo "   0 * * * * ${SCRIPT_DIR}/bin/dwh/ETL.sh --incremental"
echo "   30 2 * * * ${SCRIPT_DIR}/bin/dwh/datamartCountries/datamartCountries.sh"
echo "   0 3 * * * ${SCRIPT_DIR}/bin/dwh/datamartUsers/datamartUsers.sh"
echo ""
echo "For more information, see: docs/MIGRATION_GUIDE.md"
echo ""
echo -e "${GREEN}Setup verification complete!${NC}"
echo ""

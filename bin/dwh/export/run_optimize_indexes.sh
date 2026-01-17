#!/bin/bash

# Script to run export optimization indexes on production
# Usage: ./bin/dwh/export/run_optimize_indexes.sh
#
# This script will prompt for the PostgreSQL password for user angoca
# on server 192.168.0.7

set -euo pipefail

# Configuration
PGHOST="${PGHOST:-192.168.0.7}"
PGDATABASE="${PGDATABASE:-notes_dwh}"
PGUSER="${PGUSER:-angoca}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." &> /dev/null && pwd)"
SQL_SCRIPT="${SCRIPT_DIR}/sql/dwh/export/export_optimize_indexes.sql"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Export Optimization Indexes Setup ===${NC}"
echo ""
echo "This script will create specialized indexes to optimize CSV export performance."
echo ""
echo "Configuration:"
echo "  Host: ${PGHOST}"
echo "  Database: ${PGDATABASE}"
echo "  User: ${PGUSER}"
echo "  SQL Script: ${SQL_SCRIPT}"
echo ""

# Check if SQL script exists
if [[ ! -f "${SQL_SCRIPT}" ]]; then
 echo "Error: SQL script not found: ${SQL_SCRIPT}"
 exit 1
fi

# Prompt for confirmation
read -rp "Do you want to continue? (yes/no): " confirm
if [[ "${confirm}" != "yes" ]]; then
 echo "Aborted."
 exit 0
fi

echo ""
echo -e "${YELLOW}Executing SQL script...${NC}"
echo ""

# Execute SQL script
# Note: This will prompt for password if not in .pgpass
export PGHOST PGDATABASE PGUSER
if psql -f "${SQL_SCRIPT}" -v ON_ERROR_STOP=1; then
 echo ""
 echo -e "${GREEN}✓ Indexes created successfully!${NC}"
 echo ""
 echo "You can verify the indexes were created with:"
 echo "  psql -h ${PGHOST} -U ${PGUSER} -d ${PGDATABASE} -c \"SELECT indexname FROM pg_indexes WHERE schemaname = 'dwh' AND indexname LIKE 'idx_facts_export%';\""
 echo ""
 echo "Monitor index usage with:"
 echo "  psql -h ${PGHOST} -U ${PGUSER} -d ${PGDATABASE} -c \"SELECT * FROM dwh.v_export_index_performance;\""
else
 echo ""
 echo "Error: Failed to create indexes. Please check the error messages above."
 exit 1
fi

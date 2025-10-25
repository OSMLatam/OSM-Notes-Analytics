#!/bin/bash

# ETL Monitoring Script
# Monitor ETL execution status and recent activity
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-24

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SCRIPT_BASE_DIRECTORY="$(cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

# Load database properties if available
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh" ]]; then
 # shellcheck disable=SC1091
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== OSM Notes Analytics - ETL Monitor ==="
echo ""

# Check if ETL is currently running
echo "1. Process Status:"
if pgrep -f "ETL.sh" > /dev/null; then
 echo -e "${GREEN}✓ ETL is running${NC}"
 echo ""
 echo "Running processes:"
 for pid in $(pgrep -f "ETL.sh"); do
  ps -p "$pid" -o pid=,cmd= | awk '{print "  PID:", $1, "| Command:", $2, $3, $4}'
 done
else
 echo -e "${YELLOW}⚠ ETL is not running${NC}"
fi
echo ""

# Check last execution log
echo "2. Last Execution:"
LAST_LOG=$(find /tmp -name "ETL.log" -path "*/ETL_*" -type f -printf '%T@ %p\n' 2> /dev/null | sort -rn | head -1 | cut -d' ' -f2-)
if [ -n "${LAST_LOG}" ]; then
 echo "  Log file: ${LAST_LOG}"
 echo ""

 # Get last execution timestamp
 LOG_DIR=$(dirname "${LAST_LOG}")
 if [ -f "${LOG_DIR}/ETL.lock" ]; then
  LOCK_TIME=$(stat -c %y "${LOG_DIR}/ETL.lock" 2> /dev/null || echo "unknown")
  echo "  Lock created: ${LOCK_TIME}"
 fi

 echo ""
 echo "  Last 20 lines of log:"
 echo "  ---"
 tail -20 "${LAST_LOG}" | sed 's/^/  /'
 echo "  ---"
else
 echo -e "${YELLOW}  No execution logs found${NC}"
fi
echo ""

# Check database connectivity
echo "3. Database Connection:"
if command -v psql &> /dev/null; then
 if psql -h "${DBHOST:-localhost}" -p "${DBPORT:-5432}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -c "SELECT 1" &> /dev/null; then
  echo -e "${GREEN}✓ Database connection OK${NC}"

  # Check ETL status if etl_control table exists
  if psql -h "${DBHOST:-localhost}" -p "${DBPORT:-5432}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -t -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'etl_control')" 2> /dev/null | grep -q "t"; then
   echo ""
   echo "  ETL Control Status:"
   psql -h "${DBHOST:-localhost}" -p "${DBPORT:-5432}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -c "
        SELECT
          table_name,
          COALESCE(last_processed_timestamp::text, 'N/A') as last_processed,
          COALESCE(rows_processed::text, 'N/A') as rows_processed,
          COALESCE(status, 'N/A') as status
        FROM dwh.etl_control;
      " 2> /dev/null || echo "  Could not query etl_control table"
  fi
 else
  echo -e "${RED}✗ Database connection FAILED${NC}"
 fi
else
 echo -e "${YELLOW}⚠ psql not found${NC}"
fi
echo ""

# Check facts table statistics
echo "4. Data Warehouse Statistics:"
if command -v psql &> /dev/null; then
 psql -h "${DBHOST:-localhost}" -p "${DBPORT:-5432}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -c "
    SELECT
      'facts' as table_name,
      COUNT(*)::text as row_count,
      MAX(action_at)::text as last_action
    FROM dwh.facts

    UNION ALL

    SELECT
      'dimension_users' as table_name,
      COUNT(*)::text as row_count,
      NULL::text as last_action
    FROM dwh.dimension_users

    UNION ALL

    SELECT
      'dimension_countries' as table_name,
      COUNT(*)::text as row_count,
      NULL::text as last_action
    FROM dwh.dimension_countries

    UNION ALL

    SELECT
      'datamartUsers' as table_name,
      COUNT(*)::text as row_count,
      NULL::text as last_action
    FROM dwh.datamartUsers

    UNION ALL

    SELECT
      'datamartCountries' as table_name,
      COUNT(*)::text as row_count,
      NULL::text as last_action
    FROM dwh.datamartCountries;
  " 2> /dev/null || echo "  Could not query database"
fi
echo ""

# Check disk space
echo "5. Disk Space:"
df -h /tmp 2> /dev/null | tail -1 | awk '{print "  /tmp: " $4 " available (" $5 " used)"}'
echo ""

# Summary
echo "=== Summary ==="
if pgrep -f "ETL.sh" > /dev/null; then
 echo -e "${GREEN}Status: RUNNING${NC}"
elif [ -n "${LAST_LOG}" ]; then
 echo -e "${YELLOW}Status: IDLE (last run completed)${NC}"
else
 echo -e "${RED}Status: UNKNOWN${NC}"
fi
echo ""
echo "For detailed logs, check: ${LAST_LOG:-/tmp/ETL_*/ETL.log}"
echo ""

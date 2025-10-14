#!/bin/bash

# Validate all - Complete validation script
# Author: Andres Gomez (AngocA)
# Version: 2025-10-14

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo ""
echo "======================================"
echo -e "${BLUE}🔍 OSM-Notes-Analytics Validation${NC}"
echo "======================================"
echo ""

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to run check
run_check() {
 local check_name="$1"
 local check_command="$2"
 # shellcheck disable=SC2034

 TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

 echo -n "Checking ${check_name}... "

 if eval "${check_command}" > /dev/null 2>&1; then
  echo -e "${GREEN}✅${NC}"
  PASSED_CHECKS=$((PASSED_CHECKS + 1))
  return 0
 else
  echo -e "${RED}❌${NC}"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
  return 1
 fi
}

# Check dependencies
echo -e "${BLUE}📦 Checking dependencies...${NC}"
run_check "PostgreSQL" "command -v psql"
run_check "Bash 4.0+" "[[ ${BASH_VERSION%%.*} -ge 4 ]]"
run_check "Git" "command -v git"
echo ""

# Check optional tools
echo -e "${BLUE}🔧 Checking testing tools...${NC}"
run_check "BATS" "command -v bats"
run_check "shellcheck" "command -v shellcheck"
run_check "shfmt" "command -v shfmt"
echo ""

# Check file structure
echo -e "${BLUE}📁 Checking file structure...${NC}"
run_check "bin/dwh directory" "[[ -d ${PROJECT_ROOT}/bin/dwh ]]"
run_check "sql/dwh directory" "[[ -d ${PROJECT_ROOT}/sql/dwh ]]"
run_check "tests directory" "[[ -d ${PROJECT_ROOT}/tests ]]"
run_check "lib/osm-common directory" "[[ -d ${PROJECT_ROOT}/lib/osm-common ]]"
echo ""

# Check key files
echo -e "${BLUE}📄 Checking key files...${NC}"
run_check "ETL.sh" "[[ -f ${PROJECT_ROOT}/bin/dwh/ETL.sh ]]"
run_check "properties.sh" "[[ -f ${PROJECT_ROOT}/etc/properties.sh ]]"
run_check "test_helper.bash" "[[ -f ${PROJECT_ROOT}/tests/test_helper.bash ]]"
run_check "README.md" "[[ -f ${PROJECT_ROOT}/README.md ]]"
echo ""

# Check database connection (optional)
echo -e "${BLUE}🗄️  Checking database...${NC}"
if run_check "Database 'dwh' accessible" "psql -d dwh -c 'SELECT 1' > /dev/null 2>&1"; then
 run_check "PostGIS extension" "psql -d dwh -c \"SELECT 1 FROM pg_extension WHERE extname='postgis'\" | grep -q 1"
 run_check "btree_gist extension" "psql -d dwh -c \"SELECT 1 FROM pg_extension WHERE extname='btree_gist'\" | grep -q 1"
else
 echo -e "${YELLOW}⚠️  Database not accessible - skipping extension checks${NC}"
fi
echo ""

# Run quality tests
echo -e "${BLUE}✨ Running quality tests...${NC}"
if cd "${PROJECT_ROOT}" && ./tests/run_quality_tests.sh > /tmp/validate_quality.log 2>&1; then
 echo -e "${GREEN}✅ Quality tests passed${NC}"
 PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
 echo -e "${RED}❌ Quality tests failed${NC}"
 echo "   See /tmp/validate_quality.log for details"
 FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
echo ""

# Run DWH tests (optional)
if psql -d dwh -c "SELECT 1;" > /dev/null 2>&1; then
 echo -e "${BLUE}🏗️  Running DWH tests...${NC}"
 if cd "${PROJECT_ROOT}" && timeout 300 ./tests/run_dwh_tests.sh > /tmp/validate_dwh.log 2>&1; then
  echo -e "${GREEN}✅ DWH tests passed${NC}"
  PASSED_CHECKS=$((PASSED_CHECKS + 1))
 else
  echo -e "${RED}❌ DWH tests failed or timed out${NC}"
  echo "   See /tmp/validate_dwh.log for details"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
 fi
 TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
 echo ""
fi

# Summary
echo ""
echo "======================================"
echo -e "${BLUE}📊 Validation Summary${NC}"
echo "======================================"
echo "Total Checks: ${TOTAL_CHECKS}"
echo -e "Passed: ${GREEN}${PASSED_CHECKS} ✅${NC}"
echo -e "Failed: ${RED}${FAILED_CHECKS} ❌${NC}"
echo ""

if [ ${FAILED_CHECKS} -eq 0 ]; then
 echo -e "${GREEN}✅ All validations passed!${NC}"
 exit 0
else
 echo -e "${RED}❌ Some validations failed${NC}"
 exit 1
fi

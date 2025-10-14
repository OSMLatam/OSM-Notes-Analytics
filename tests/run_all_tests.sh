#!/bin/bash

# Run all tests for OSM-Notes-Analytics
# Author: Andres Gomez (AngocA)
# Version: 2025-10-14

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
 echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "======================================"
log_info "OSM-Notes-Analytics Test Runner"
echo "======================================"
echo "Project Root: ${PROJECT_ROOT}"
echo ""

# Counter for overall results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Function to run a test suite
run_suite() {
 local suite_name="$1"
 local suite_script="$2"
 # shellcheck disable=SC2034

 echo ""
 echo "======================================"
 log_info "Running ${suite_name}"
 echo "======================================"
 echo ""

 TOTAL_SUITES=$((TOTAL_SUITES + 1))

 if [[ -f "${suite_script}" ]]; then
  if bash "${suite_script}"; then
   log_success "${suite_name} completed successfully"
   PASSED_SUITES=$((PASSED_SUITES + 1))
  else
   log_error "${suite_name} failed"
   FAILED_SUITES=$((FAILED_SUITES + 1))
  fi
 else
  log_warning "${suite_name} script not found: ${suite_script}"
  FAILED_SUITES=$((FAILED_SUITES + 1))
 fi
}

# Run Quality Tests
run_suite "Quality Tests" "${SCRIPT_DIR}/run_quality_tests.sh"

# Run DWH Tests
run_suite "DWH and ETL Tests" "${SCRIPT_DIR}/run_dwh_tests.sh"

# Show final summary
echo ""
echo "======================================"
log_info "Overall Test Summary"
echo "======================================"
echo "Total Test Suites: ${TOTAL_SUITES}"
echo "Passed: ${PASSED_SUITES} ✅"
echo "Failed: ${FAILED_SUITES} ❌"
echo ""

if [[ ${FAILED_SUITES} -eq 0 ]]; then
 log_success "🎉 All test suites passed!"
 exit 0
else
 log_error "❌ ${FAILED_SUITES} test suite(s) failed"
 exit 1
fi

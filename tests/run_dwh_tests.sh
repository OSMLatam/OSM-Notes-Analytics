#!/bin/bash

# Run DWH and ETL tests for OSM-Notes-Analytics
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

# Export project root for tests
export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"

# Load test properties
if [[ -f "${SCRIPT_DIR}/properties.sh" ]]; then
 # shellcheck source=tests/properties.sh
 source "${SCRIPT_DIR}/properties.sh"
else
 log_error "Test properties not found"
 exit 1
fi

# Check if BATS is installed
if ! command -v bats &> /dev/null; then
 log_error "BATS is not installed. Please install it first:"
 echo "  # Ubuntu/Debian:"
 echo "  sudo apt-get install bats"
 echo ""
 echo "  # macOS:"
 echo "  brew install bats-core"
 echo ""
 echo "  # Manual installation:"
 echo "  git clone https://github.com/bats-core/bats-core.git"
 echo "  cd bats-core"
 echo "  sudo ./install.sh /usr/local"
 exit 1
fi

log_info "Starting DWH and ETL tests..."
echo "Project Root: ${PROJECT_ROOT}"
echo "Test Database: ${TEST_DBNAME}"
echo ""

# Counter for test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test suite
run_test_suite() {
 local test_file="$1"
 local test_name
 test_name="$(basename "${test_file}")"

 log_info "Running ${test_name}..."

 if bats "${test_file}"; then
  log_success "${test_name} passed"
  PASSED_TESTS=$((PASSED_TESTS + 1))
 else
  log_error "${test_name} failed"
  FAILED_TESTS=$((FAILED_TESTS + 1))
 fi

 TOTAL_TESTS=$((TOTAL_TESTS + 1))
 echo ""
}

# Run unit tests
log_info "Running unit tests..."
echo "===================="
echo ""

if [[ -d "${SCRIPT_DIR}/unit/bash" ]]; then
 for test_file in "${SCRIPT_DIR}"/unit/bash/*.bats; do
  if [[ -f "${test_file}" ]]; then
   run_test_suite "${test_file}"
  fi
 done
else
 log_warning "No unit bash tests found"
fi

# Run integration tests
log_info "Running integration tests..."
echo "============================="
echo ""

if [[ -d "${SCRIPT_DIR}/integration" ]]; then
 for test_file in "${SCRIPT_DIR}"/integration/*.bats; do
  if [[ -f "${test_file}" ]]; then
   run_test_suite "${test_file}"
  fi
 done
else
 log_warning "No integration tests found"
fi

# Show summary
echo ""
echo "======================================"
log_info "Test Summary"
echo "======================================"
echo "Total Test Suites: ${TOTAL_TESTS}"
echo "Passed: ${PASSED_TESTS} ✅"
echo "Failed: ${FAILED_TESTS} ❌"

if [[ ${FAILED_TESTS} -eq 0 ]]; then
 log_success "All tests passed!"
 exit 0
else
 log_error "${FAILED_TESTS} test suite(s) failed"
 exit 1
fi

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
echo "Test DB Host: ${TEST_DBHOST:-localhost}"
echo "Test DB Port: ${TEST_DBPORT:-5432}"
echo "Test DB User: ${TEST_DBUSER:-postgres}"
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

# Setup: Generate mock data and populate DWH
log_info "Setting up test environment..."
echo "===================="

# Run mock ETL to populate test database
if [[ -f "${SCRIPT_DIR}/run_mock_etl.sh" ]]; then
 log_info "Populating test database with mock data..."
 log_info "Database connection info:"
 log_info "  TEST_DBNAME=${TEST_DBNAME:-}"
 log_info "  TEST_DBHOST=${TEST_DBHOST:-}"
 log_info "  TEST_DBPORT=${TEST_DBPORT:-}"
 log_info "  TEST_DBUSER=${TEST_DBUSER:-}"
 log_info "  TEST_DBPASSWORD=${TEST_DBPASSWORD:+***set***}"

 # Ensure all required variables are set for CI/CD environment
 if [[ -n "${TEST_DBHOST:-}" ]]; then
  if [[ -z "${TEST_DBNAME:-}" ]]; then
   log_error "TEST_DBNAME is required but not set"
   exit 1
  fi
  if [[ -z "${TEST_DBUSER:-}" ]]; then
   log_error "TEST_DBUSER is required but not set"
   exit 1
  fi
  # Export variables to ensure they're available to subprocesses
  export TEST_DBNAME TEST_DBHOST TEST_DBPORT TEST_DBUSER TEST_DBPASSWORD
  export PGHOST="${TEST_DBHOST}"
  export PGPORT="${TEST_DBPORT:-5432}"
  export PGUSER="${TEST_DBUSER}"
  export PGPASSWORD="${TEST_DBPASSWORD:-postgres}"
  export PGDATABASE="${TEST_DBNAME}"
 fi

 # Verify database connection before running mock ETL
 # Use appropriate connection method based on environment
 if [[ -n "${TEST_DBHOST:-}" ]]; then
  # CI/CD environment - use host/port/user
  log_info "Verifying database connection (CI/CD mode)..."
  CONNECTION_OUTPUT=$(PGPASSWORD="${TEST_DBPASSWORD:-postgres}" psql -h "${TEST_DBHOST}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-postgres}" -d "${TEST_DBNAME}" -c "SELECT 1;" 2>&1)
  CONNECTION_EXIT_CODE=$?
  if [[ ${CONNECTION_EXIT_CODE} -ne 0 ]]; then
   log_error "Cannot connect to database before running mock ETL"
   log_error "Connection attempt failed with exit code: ${CONNECTION_EXIT_CODE}"
   log_error "Connection details:"
   log_error "  Host: ${TEST_DBHOST}"
   log_error "  Port: ${TEST_DBPORT:-5432}"
   log_error "  User: ${TEST_DBUSER:-postgres}"
   log_error "  Database: ${TEST_DBNAME}"
   log_error "  Password: ${TEST_DBPASSWORD:+***set***}"
   log_error "Error output:"
   if [[ -n "${CONNECTION_OUTPUT}" ]]; then
    echo "${CONNECTION_OUTPUT}" | sed 's/^/  /' | while IFS= read -r line || [[ -n "${line}" ]]; do
     log_error "${line}"
    done
   fi
   exit 1
  fi
  log_success "Database connection verified"
 else
  # Local environment - use peer authentication
  log_info "Verifying database connection (local mode)..."
  CONNECTION_OUTPUT=$(psql -d "${TEST_DBNAME}" -c "SELECT 1;" 2>&1)
  CONNECTION_EXIT_CODE=$?
  if [[ ${CONNECTION_EXIT_CODE} -ne 0 ]]; then
   log_error "Cannot connect to database before running mock ETL"
   log_error "Connection attempt failed with exit code: ${CONNECTION_EXIT_CODE}"
   log_error "Database: ${TEST_DBNAME}"
   log_error "Error output:"
   if [[ -n "${CONNECTION_OUTPUT}" ]]; then
    echo "${CONNECTION_OUTPUT}" | sed 's/^/  /' | while IFS= read -r line || [[ -n "${line}" ]]; do
     log_error "${line}"
    done
   fi
   exit 1
  fi
  log_success "Database connection verified"
 fi

 if bash "${SCRIPT_DIR}/run_mock_etl.sh"; then
  log_success "Test database populated"
 else
  EXIT_CODE=$?
  log_error "Failed to populate test database with mock data"
  log_error "Exit code: ${EXIT_CODE}"
  log_error "Check the output above for detailed error messages"
  exit 1
 fi
else
 log_warning "Mock ETL script not found, skipping data setup"
fi

echo ""

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

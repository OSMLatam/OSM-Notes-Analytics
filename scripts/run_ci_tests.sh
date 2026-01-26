#!/usr/bin/env bash
#
# Run CI Tests Locally
# Simulates the GitHub Actions workflow to test changes locally
# Author: Andres Gomez (AngocA)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_message() {
 local color="${1}"
 shift
 echo -e "${color}$*${NC}"
}

print_message "${YELLOW}" "=== Running CI Tests Locally (OSM-Notes-Analytics) ==="
echo

cd "${PROJECT_ROOT}"

# Check if BATS is installed
if ! command -v bats > /dev/null 2>&1; then
 print_message "${YELLOW}" "Installing BATS..."
 if ! (sudo apt-get update && sudo apt-get install -y bats) 2> /dev/null; then
  git clone https://github.com/bats-core/bats-core.git /tmp/bats 2> /dev/null || true
  if [[ -d /tmp/bats ]]; then
   sudo /tmp/bats/install.sh /usr/local 2> /dev/null || {
    print_message "${RED}" "Failed to install BATS. Please install manually:"
    echo "  git clone https://github.com/bats-core/bats-core.git"
    echo "  cd bats-core"
    echo "  ./install.sh /usr/local"
    exit 1
   }
  fi
 fi
fi

# Check PostgreSQL
if command -v psql > /dev/null 2>&1; then
 print_message "${GREEN}" "✓ PostgreSQL client found"
else
 print_message "${YELLOW}" "⚠ PostgreSQL client not found (tests may skip DB tests)"
fi

# Check shellcheck
if ! command -v shellcheck > /dev/null 2>&1; then
 print_message "${YELLOW}" "Installing shellcheck..."
 if ! (sudo apt-get update && sudo apt-get install -y shellcheck) 2> /dev/null; then
  print_message "${YELLOW}" "⚠ Could not install shellcheck automatically"
 fi
fi

# Check shfmt
if ! command -v shfmt > /dev/null 2>&1; then
 print_message "${YELLOW}" "Installing shfmt..."
 wget -q -O /tmp/shfmt https://github.com/mvdan/sh/releases/download/v3.7.0/shfmt_v3.7.0_linux_amd64
 chmod +x /tmp/shfmt
 sudo mv /tmp/shfmt /usr/local/bin/shfmt || {
  print_message "${YELLOW}" "⚠ Could not install shfmt automatically"
 }
fi

echo
print_message "${YELLOW}" "=== Step 1: Quality Checks ==="
echo

# Run shellcheck
if command -v shellcheck > /dev/null 2>&1; then
 print_message "${BLUE}" "Running shellcheck on Analytics scripts..."
 if find bin/dwh -name "*.sh" -type f -exec shellcheck -x -o all {} \; 2>&1 | grep -q "error"; then
  print_message "${RED}" "✗ shellcheck found errors"
  find bin/dwh -name "*.sh" -type f -exec shellcheck -x -o all {} \;
  exit 1
 else
  print_message "${GREEN}" "✓ shellcheck passed"
 fi
else
 print_message "${YELLOW}" "⚠ shellcheck not available, skipping"
fi

# Check code formatting with shfmt
print_message "${BLUE}" "Checking Analytics code formatting..."
if command -v shfmt > /dev/null 2>&1; then
 if find bin/dwh -name "*.sh" -type f -exec shfmt -d -i 1 -sr -bn {} \; 2>&1 | grep -q "."; then
  print_message "${RED}" "✗ Code formatting issues found"
  find bin/dwh -name "*.sh" -type f -exec shfmt -d -i 1 -sr -bn {} \;
  exit 1
 else
  print_message "${GREEN}" "✓ Code formatting check passed"
 fi
else
 print_message "${YELLOW}" "⚠ shfmt not available, skipping format check"
fi

# Check Prettier formatting
if command -v prettier > /dev/null 2>&1 || command -v npx > /dev/null 2>&1; then
 print_message "${BLUE}" "Checking Prettier formatting..."
 if command -v prettier > /dev/null 2>&1; then
  PRETTIER_CMD=prettier
 else
  PRETTIER_CMD="npx prettier"
 fi
 if ${PRETTIER_CMD} --check "**/*.{md,json,yaml,yml,css,html}" --ignore-path .prettierignore 2> /dev/null; then
  print_message "${GREEN}" "✓ Prettier formatting check passed"
 else
  print_message "${RED}" "✗ Prettier formatting check failed"
  exit 1
 fi
fi

# Check SQL formatting (optional)
if command -v sqlfluff > /dev/null 2>&1; then
 print_message "${BLUE}" "Checking SQL formatting..."
 if find sql -name "*.sql" -type f -exec sqlfluff lint {} \; 2>&1 | grep -q "error"; then
  print_message "${YELLOW}" "⚠ SQL formatting issues found (non-blocking)"
 else
  print_message "${GREEN}" "✓ SQL formatting check passed"
 fi
fi

# Check code quality
print_message "${BLUE}" "Checking code quality..."
TRAILING_FILES=$(find bin/dwh -name "*.sh" -type f -exec grep -l " $" {} \; 2> /dev/null || true)
if [[ -n "${TRAILING_FILES}" ]]; then
 print_message "${RED}" "✗ Found trailing whitespace"
 echo "${TRAILING_FILES}"
 exit 1
else
 print_message "${GREEN}" "✓ No trailing whitespace found"
fi

echo
print_message "${YELLOW}" "=== Step 2: Unit and Integration Tests ==="
echo

# Setup test environment
export TEST_DBNAME=osm_notes_analytics_test
export TEST_DBHOST=localhost
export TEST_DBPORT=5432
export TEST_DBUSER=postgres
export TEST_DBPASSWORD=postgres
export PGPASSWORD=postgres
export PGHOST=localhost
export PGPORT=5432
export PGUSER=postgres
export PGDATABASE=osm_notes_analytics_test

# Check if PostgreSQL is running
if command -v pg_isready > /dev/null 2>&1 && pg_isready -h localhost -p 5432 -U postgres > /dev/null 2>&1; then
 print_message "${GREEN}" "✓ PostgreSQL is running"

 # Setup test database
 print_message "${BLUE}" "Setting up test database..."
 psql -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2> /dev/null || true
 psql -c "CREATE EXTENSION IF NOT EXISTS btree_gist;" 2> /dev/null || true

 # Run DWH Tests
 print_message "${BLUE}" "Running DWH Tests..."
 if [[ -f tests/run_dwh_tests.sh ]]; then
  if ./tests/run_dwh_tests.sh; then
   print_message "${GREEN}" "✓ DWH Tests passed"
  else
   print_message "${RED}" "✗ DWH Tests failed"
   exit 1
  fi
 else
  print_message "${YELLOW}" "⚠ DWH test script not found"
 fi

 # Run Hybrid ETL Integration Test (if Ingestion submodule is available)
 if [[ -d "../OSM-Notes-Ingestion" ]] || [[ -d "lib/osm-ingestion" ]]; then
  print_message "${BLUE}" "Running Hybrid ETL Integration Test..."
  if [[ -f tests/run_processAPINotes_with_etl_controlled.sh ]]; then
   export INGESTION_ROOT="${PROJECT_ROOT}/../OSM-Notes-Ingestion"
   if ./tests/run_processAPINotes_with_etl_controlled.sh all; then
    print_message "${GREEN}" "✓ Hybrid ETL Integration Test passed"
   else
    print_message "${YELLOW}" "⚠ Hybrid ETL Integration Test failed (non-blocking)"
   fi
  fi
 else
  print_message "${YELLOW}" "⚠ Skipping hybrid test - OSM-Notes-Ingestion submodule not available"
 fi
else
 print_message "${YELLOW}" "⚠ PostgreSQL is not running. Skipping tests."
 print_message "${YELLOW}" "   Start PostgreSQL to run tests:"
 print_message "${YELLOW}" "   docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=dwh postgis/postgis:15-3.3"
fi

echo
print_message "${YELLOW}" "=== Step 3: Test Coverage Evaluation ==="
echo

# Test coverage evaluation function
evaluate_test_coverage() {
 local scripts_dir="${1:-bin}"
 local tests_dir="${2:-tests}"

 print_message "${BLUE}" "Evaluating test coverage..."

 # Count test files for a script
 count_test_files() {
  local script_path="${1}"
  local script_name
  script_name=$(basename "${script_path}" .sh)

  local test_count=0

  # Check unit tests
  if [[ -d "${PROJECT_ROOT}/${tests_dir}/unit" ]]; then
   if find "${PROJECT_ROOT}/${tests_dir}/unit" -name "test_${script_name}.sh" -o -name "*${script_name}*.sh" -o -name "*${script_name}*.bats" 2> /dev/null | grep -q .; then
    test_count=$(find "${PROJECT_ROOT}/${tests_dir}/unit" \( -name "*${script_name}*.sh" -o -name "*${script_name}*.bats" \) -type f 2> /dev/null | wc -l | tr -d ' ')
   fi
  fi

  # Check integration tests
  if [[ -d "${PROJECT_ROOT}/${tests_dir}/integration" ]]; then
   if find "${PROJECT_ROOT}/${tests_dir}/integration" -name "*${script_name}*.sh" -o -name "*${script_name}*.bats" 2> /dev/null | grep -q .; then
    test_count=$((test_count + $(find "${PROJECT_ROOT}/${tests_dir}/integration" \( -name "*${script_name}*.sh" -o -name "*${script_name}*.bats" \) -type f 2> /dev/null | wc -l | tr -d ' ')))
   fi
  fi

  # Also check tests directory directly (for simpler structures)
  if [[ -d "${PROJECT_ROOT}/${tests_dir}" ]]; then
   if find "${PROJECT_ROOT}/${tests_dir}" -maxdepth 1 -name "*${script_name}*.sh" -o -name "*${script_name}*.bats" 2> /dev/null | grep -q .; then
    test_count=$((test_count + $(find "${PROJECT_ROOT}/${tests_dir}" -maxdepth 1 \( -name "*${script_name}*.sh" -o -name "*${script_name}*.bats" \) -type f 2> /dev/null | wc -l | tr -d ' ')))
   fi
  fi

  echo "${test_count}"
 }

 # Calculate coverage percentage
 calculate_coverage() {
  local script_path="${1}"
  local test_count
  test_count=$(count_test_files "${script_path}")

  if [[ ${test_count} -gt 0 ]]; then
   # Heuristic: 1 test = 40%, 2 tests = 60%, 3+ tests = 80%
   local coverage=0
   if [[ ${test_count} -ge 3 ]]; then
    coverage=80
   elif [[ ${test_count} -eq 2 ]]; then
    coverage=60
   elif [[ ${test_count} -eq 1 ]]; then
    coverage=40
   fi
   echo "${coverage}"
  else
   echo "0"
  fi
 }

 # Find all scripts
 local scripts=()
 if [[ -d "${PROJECT_ROOT}/${scripts_dir}" ]]; then
  while IFS= read -r -d '' script; do
   scripts+=("${script}")
  done < <(find "${PROJECT_ROOT}/${scripts_dir}" -name "*.sh" -type f -print0 2> /dev/null | sort -z)
 fi

 if [[ ${#scripts[@]} -eq 0 ]]; then
  print_message "${YELLOW}" "⚠ No scripts found in ${scripts_dir}/, skipping coverage evaluation"
  return 0
 fi

 local total_scripts=${#scripts[@]}
 local scripts_with_tests=0
 local scripts_above_threshold=0
 local total_coverage=0
 local coverage_count=0

 for script in "${scripts[@]}"; do
  local script_name
  script_name=$(basename "${script}")
  local test_count
  test_count=$(count_test_files "${script}")
  local coverage
  coverage=$(calculate_coverage "${script}")

  if [[ ${test_count} -gt 0 ]]; then
   scripts_with_tests=$((scripts_with_tests + 1))
   if [[ "${coverage}" =~ ^[0-9]+$ ]] && [[ ${coverage} -gt 0 ]]; then
    total_coverage=$((total_coverage + coverage))
    coverage_count=$((coverage_count + 1))

    if [[ ${coverage} -ge 80 ]]; then
     scripts_above_threshold=$((scripts_above_threshold + 1))
    fi
   fi
  fi
 done

 # Calculate overall coverage
 local overall_coverage=0
 if [[ ${coverage_count} -gt 0 ]]; then
  overall_coverage=$((total_coverage / coverage_count))
 fi

 echo
 echo "Coverage Summary:"
 echo "  Total scripts: ${total_scripts}"
 echo "  Scripts with tests: ${scripts_with_tests}"
 echo "  Scripts above 80% coverage: ${scripts_above_threshold}"
 echo "  Average coverage: ${overall_coverage}%"
 echo

 if [[ ${overall_coverage} -ge 80 ]]; then
  print_message "${GREEN}" "✓ Coverage target met (${overall_coverage}% >= 80%)"
 elif [[ ${overall_coverage} -ge 50 ]]; then
  print_message "${YELLOW}" "⚠ Coverage below target (${overall_coverage}% < 80%), improvement needed"
 else
  print_message "${YELLOW}" "⚠ Coverage significantly below target (${overall_coverage}% < 50%)"
 fi

 echo
 print_message "${BLUE}" "Note: This is an estimated coverage based on test file presence."
 print_message "${BLUE}" "For accurate coverage, use code instrumentation tools like bashcov."
}

# Run coverage evaluation (non-blocking)
if [[ -d "${PROJECT_ROOT}/bin" ]] || [[ -d "${PROJECT_ROOT}/scripts" ]]; then
 if [[ -d "${PROJECT_ROOT}/bin" ]]; then
  evaluate_test_coverage "bin" "tests" || true
 elif [[ -d "${PROJECT_ROOT}/scripts" ]]; then
  evaluate_test_coverage "scripts" "tests" || true
 fi
else
 print_message "${YELLOW}" "⚠ No bin/ or scripts/ directory found, skipping coverage evaluation"
fi

echo
print_message "${GREEN}" "=== All CI Tests Completed Successfully ==="
echo
print_message "${GREEN}" "✅ Quality Checks: PASSED"
if command -v pg_isready > /dev/null 2>&1 && pg_isready -h localhost -p 5432 -U postgres > /dev/null 2>&1; then
 print_message "${GREEN}" "✅ DWH Tests: PASSED"
fi
echo

exit 0

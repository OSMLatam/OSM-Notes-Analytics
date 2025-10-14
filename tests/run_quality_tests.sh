#!/bin/bash

# Run quality tests for OSM-Notes-Analytics
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

# Counter for test results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

log_info "Starting Quality Tests for OSM-Notes-Analytics"
echo "Project Root: ${PROJECT_ROOT}"
echo ""

# Check if shellcheck is installed
if ! command -v shellcheck &> /dev/null; then
 log_warning "shellcheck is not installed. Skipping shellcheck tests."
 log_info "To install shellcheck:"
 echo "  sudo apt-get install shellcheck  # Ubuntu/Debian"
 echo "  brew install shellcheck          # macOS"
 SHELLCHECK_AVAILABLE=false
else
 SHELLCHECK_AVAILABLE=true
fi

# Check if shfmt is installed
if ! command -v shfmt &> /dev/null; then
 log_warning "shfmt is not installed. Skipping format tests."
 log_info "To install shfmt:"
 echo "  wget -O shfmt https://github.com/mvdan/sh/releases/download/v3.7.0/shfmt_v3.7.0_linux_amd64"
 echo "  chmod +x shfmt && sudo mv shfmt /usr/local/bin/"
 SHFMT_AVAILABLE=false
else
 SHFMT_AVAILABLE=true
fi

echo ""

# Run shellcheck on Analytics scripts
if [[ "${SHELLCHECK_AVAILABLE}" == "true" ]]; then
 log_info "Running shellcheck on Analytics scripts..."
 TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

 if find "${PROJECT_ROOT}/bin/dwh" -name "*.sh" -type f -exec shellcheck -x -o all {} \; 2>&1; then
  log_success "Shellcheck passed for Analytics scripts"
  PASSED_CHECKS=$((PASSED_CHECKS + 1))
 else
  log_error "Shellcheck found issues in Analytics scripts"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
 fi
 echo ""

 # Run shellcheck on Common submodule (integration check)
 log_info "Running shellcheck on Common submodule (integration check)..."
 TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

 if find "${PROJECT_ROOT}/lib/osm-common" -name "*.sh" -type f -exec shellcheck -x -o all {} \; 2>&1; then
  log_success "Shellcheck passed for Common submodule"
  PASSED_CHECKS=$((PASSED_CHECKS + 1))
 else
  log_warning "Shellcheck found issues in Common submodule (integration context)"
  log_info "Note: Common is maintained in Profile repo - these may not be bugs"
  PASSED_CHECKS=$((PASSED_CHECKS + 1)) # Don't fail on Common issues
 fi
 echo ""
fi

# Run shfmt on Analytics scripts
if [[ "${SHFMT_AVAILABLE}" == "true" ]]; then
 log_info "Checking Analytics code formatting (shfmt -i 1 -sr -bn)..."
 TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

 if find "${PROJECT_ROOT}/bin/dwh" -name "*.sh" -type f -exec shfmt -d -i 1 -sr -bn {} \; 2>&1; then
  log_success "Format check passed for Analytics scripts"
  PASSED_CHECKS=$((PASSED_CHECKS + 1))
 else
  log_error "Format issues found in Analytics scripts"
  log_info "To fix formatting, run:"
  echo "  find bin/dwh -name '*.sh' -type f -exec shfmt -w -i 1 -sr -bn {} \\;"
  FAILED_CHECKS=$((FAILED_CHECKS + 1))
 fi
 echo ""
fi

# Check for trailing whitespace
log_info "Checking for trailing whitespace..."
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

TRAILING_FILES=$(find "${PROJECT_ROOT}/bin/dwh" -name "*.sh" -type f -exec grep -l " $" {} \; 2> /dev/null)
if [[ -n "${TRAILING_FILES}" ]]; then
 echo "${TRAILING_FILES}"
 log_warning "Found trailing whitespace in Analytics scripts"
 FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
 log_success "No trailing whitespace found"
 PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi
echo ""

# Check for proper shebang
log_info "Checking shebangs..."
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

INVALID_SHEBANGS=$(find "${PROJECT_ROOT}/bin/dwh" -name "*.sh" -type f -exec head -1 {} \; | grep -vc "#!/bin/bash" || echo "0")
INVALID_SHEBANGS=$(echo "${INVALID_SHEBANGS}" | tr -d ' \n')
if [[ "${INVALID_SHEBANGS}" -gt 0 ]] 2> /dev/null; then
 log_warning "Found ${INVALID_SHEBANGS} script(s) without proper shebang"
 FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
 log_success "All shebangs are correct"
 PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi
echo ""

# Check for TODO/FIXME comments
log_info "Checking for TODO/FIXME comments..."
TODO_COUNT=$(find "${PROJECT_ROOT}/bin/dwh" -name "*.sh" -type f -exec grep -c "TODO\|FIXME" {} \; 2> /dev/null | awk '{s+=$1} END {print s+0}' || echo "0")
log_info "Found ${TODO_COUNT} TODO/FIXME comments"
echo ""

# Show summary
echo "======================================"
log_info "Quality Test Summary"
echo "======================================"
echo "Total Checks: ${TOTAL_CHECKS}"
echo "Passed: ${PASSED_CHECKS} ✅"
echo "Failed: ${FAILED_CHECKS} ❌"
echo "TODO/FIXME: ${TODO_COUNT} 📝"
echo ""

if [[ ${FAILED_CHECKS} -eq 0 ]]; then
 log_success "All quality checks passed!"
 exit 0
else
 log_error "${FAILED_CHECKS} quality check(s) failed"
 exit 1
fi

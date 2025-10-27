#!/bin/bash

# Run Performance Benchmark Suite
#
# This script runs comprehensive performance benchmarks for the DWH,
# particularly focusing on trigger performance impact.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-26

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Project root
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_ROOT

# Load properties
if [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
 # shellcheck disable=SC1090
 source "${PROJECT_ROOT}/etc/properties.sh"
else
 # If no properties file, use defaults
 declare DBNAME="${DBNAME:-dwh}"
 declare DB_USER="${DB_USER:-postgres}"
fi

# Output directory
OUTPUT_DIR="${SCRIPT_DIR}/results"
mkdir -p "${OUTPUT_DIR}"
readonly OUTPUT_DIR

# Timestamp for results
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
readonly TIMESTAMP

# Results file
RESULTS_FILE="${OUTPUT_DIR}/benchmark_${TIMESTAMP}.txt"
readonly RESULTS_FILE

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored messages
print_success() {
 echo -e "${GREEN}✓${NC} $1"
}

print_error() {
 echo -e "${RED}✗${NC} $1"
}

print_info() {
 echo -e "${YELLOW}→${NC} $1"
}

# Header
echo "════════════════════════════════════════════════════════════════"
echo "  DWH Performance Benchmark Suite"
echo "  Timestamp: $(date)"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Check database connection
print_info "Checking database connection..."
if ! psql -d "${DBNAME}" -c "SELECT version();" > /dev/null 2>&1; then
 print_error "Cannot connect to database: ${DBNAME}"
 exit 1
fi
print_success "Database connection OK"
echo ""

# Run benchmarks
print_info "Running benchmarks..."
echo "Results will be saved to: ${RESULTS_FILE}"
echo ""

# Run SQL benchmark
print_info "Executing benchmark SQL..."
if psql -d "${DBNAME}" \
 -f "${SCRIPT_DIR}/benchmark_trigger_performance.sql" \
 > "${RESULTS_FILE}" 2>&1; then
 print_success "Benchmark completed"
else
 print_error "Benchmark failed. Check log: ${RESULTS_FILE}"
 exit 1
fi
echo ""

# Parse results
print_info "Analyzing results..."
echo ""

# Extract key metrics
echo "════════════════════════════════════════════════════════════════"
echo "  SUMMARY"
echo "════════════════════════════════════════════════════════════════"

# Find execution times
if grep -q "Execution Time:" "${RESULTS_FILE}"; then
 echo ""
 echo "Execution Times:"
 grep "Execution Time:" "${RESULTS_FILE}" | head -20
fi

# Find plan summary
if grep -q "Planning Time:" "${RESULTS_FILE}"; then
 echo ""
 echo "Planning Times:"
 grep "Planning Time:" "${RESULTS_FILE}" | head -5
fi

# Find buffer hits
if grep -q "Buffers:" "${RESULTS_FILE}"; then
 echo ""
 echo "Buffer Usage:"
 grep -A 2 "Buffers:" "${RESULTS_FILE}" | head -10
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
print_success "Full results saved to: ${RESULTS_FILE}"
print_info "Review the file for detailed performance metrics"
echo ""

# Optional: Compare with previous run
if [[ -f "${OUTPUT_DIR}/benchmark_latest.txt" ]]; then
 print_info "Previous benchmark exists: benchmark_latest.txt"
 print_info "Use 'diff' to compare with current run"
 echo ""
fi

# Save as latest
cp "${RESULTS_FILE}" "${OUTPUT_DIR}/benchmark_latest.txt"
print_success "Saved as latest benchmark"
echo ""

print_info "Benchmark suite completed successfully"
exit 0

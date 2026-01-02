#!/bin/bash

# Script to replace "return 1" with "skip" when database connection fails in test files
# This ensures tests are skipped instead of failing when database is unavailable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find all .bats files
find "${SCRIPT_DIR}/unit/bash" -name "*.bats" -type f | while read -r test_file; do
 # Create backup
 cp "${test_file}" "${test_file}.bak"

 # Replace pattern: if ! verify_database_connection; then ... return 1 ... fi
 # With: skip_if_no_db_connection
 sed -i 's/if ! verify_database_connection(); then[[:space:]]*echo "Database connection failed - test cannot proceed" >&2[[:space:]]*return 1[[:space:]]*fi/skip_if_no_db_connection/g' "${test_file}"

 # Also handle single-line patterns
 sed -i 's/if ! verify_database_connection(); then.*return 1.*fi/skip_if_no_db_connection/g' "${test_file}"

 # Check if file was modified
 if ! diff -q "${test_file}" "${test_file}.bak" > /dev/null; then
  echo "Fixed: ${test_file}"
  rm "${test_file}.bak"
 else
  rm "${test_file}.bak"
 fi
done

echo "Done fixing test skips"

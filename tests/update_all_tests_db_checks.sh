#!/bin/bash

# Script to update all test files to use verify_database_connection()
# instead of silently skipping when DB is not available
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-27

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="${SCRIPT_DIR}/unit/bash"

if [[ ! -d "${TESTS_DIR}" ]]; then
 echo "Tests directory not found: ${TESTS_DIR}" >&2
 exit 1
fi

# Find all .bats files
mapfile -t test_files < <(find "${TESTS_DIR}" -name "*.bats" -type f | sort)

if [[ ${#test_files[@]} -eq 0 ]]; then
 echo "No test files found"
 exit 0
fi

echo "Found ${#test_files[@]} test files"
echo "============================================================"

updated_count=0

for test_file in "${test_files[@]}"; do
 test_name=$(basename "${test_file}")
 echo ""
 echo "Processing: ${test_name}"

 # Check if file already uses verify_database_connection
 if grep -q 'verify_database_connection' "${test_file}"; then
  echo "  Already uses verify_database_connection, skipping"
  continue
 fi

 # Check if file contains the skip pattern
 if ! grep -q 'skip "No database configured"' "${test_file}"; then
  echo "  No skip pattern found, skipping"
  continue
 fi

 echo "  Found skip pattern, updating..."

 # Create backup
 cp "${test_file}" "${test_file}.bak"

 # Create temp file for processing
 temp_file=$(mktemp)
 # shellcheck disable=SC2064
 # SC2064: We want temp_file to expand when trap executes, not when defined
 trap "rm -f '${temp_file}'" EXIT

 # Process file line by line
 skip_next_fi=false
 in_skip_block=false

 # shellcheck disable=SC2094
 # SC2094: We're reading from original file, writing to temp_file (different files)
 while IFS= read -r line || [[ -n "${line}" ]]; do
  # Check if this line starts a skip block
  if [[ "${line}" =~ ^[[:space:]]*if[[:space:]]+\[\[[[:space:]]*-z[[:space:]]+"\$\{DBNAME:-\}" ]]; then
   # Check if next few lines contain skip pattern
   # shellcheck disable=SC2094
   # SC2094: We're reading from original file, writing to temp_file (different files)
   if grep -A 3 "^${line}$" "${test_file}" | grep -q 'skip "No database configured"'; then
    in_skip_block=true
    # Output replacement
    {
     echo "  # Verify database connection - will fail explicitly if DB is not available"
     echo "  if ! verify_database_connection; then"
     echo "    echo \"Database connection failed - test cannot proceed\" >&2"
     echo "    return 1"
     echo "  fi"
    } >> "${temp_file}"
    skip_next_fi=true
    continue
   fi
  fi

  # Skip lines that are part of the skip block
  if [[ "${in_skip_block}" == "true" ]]; then
   # Skip the skip line
   if [[ "${line}" =~ skip.*database ]]; then
    continue
   fi
   # Skip empty lines in the block
   if [[ "${line}" =~ ^[[:space:]]*$ ]]; then
    continue
   fi
   # If we see 'fi', skip it if it's closing the skip block
   if [[ "${line}" =~ ^[[:space:]]*fi[[:space:]]*$ ]] && [[ "${skip_next_fi}" == "true" ]]; then
    skip_next_fi=false
    in_skip_block=false
    continue
   fi
   # If we see a non-empty line that's not 'fi', we've moved past the skip block
   if [[ ! "${line}" =~ ^[[:space:]]*fi[[:space:]]*$ ]]; then
    in_skip_block=false
    skip_next_fi=false
   fi
  fi

  # Output the line
  echo "${line}" >> "${temp_file}"
 done < "${test_file}"

 # Ensure test_helper is loaded
 if ! grep -q "^load test_helper" "${temp_file}" && ! grep -q "^load ../../../tests/test_helper" "${temp_file}"; then
  # Add after the bats_require_minimum_version line if it exists
  if grep -q "bats_require_minimum_version" "${temp_file}"; then
   sed -i '/bats_require_minimum_version/a\
\
# Load test helper for database connection verification\
load test_helper' "${temp_file}"
  else
   # Add after shebang
   sed -i '1a\
# Load test helper for database connection verification\
load test_helper' "${temp_file}"
  fi
 fi

 # Replace the original file
 mv "${temp_file}" "${test_file}"

 echo "  Updated successfully (backup: ${test_file}.bak)"
 updated_count=$((updated_count + 1))
done

echo ""
echo "============================================================"
echo "Summary: Updated ${updated_count} out of ${#test_files[@]} files"
echo ""
echo "Review the changes and remove .bak files if everything looks good:"
echo "  find tests/unit/bash -name '*.bak' -delete"

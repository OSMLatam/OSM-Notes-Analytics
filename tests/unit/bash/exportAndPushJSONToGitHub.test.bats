#!/usr/bin/env bats
# Test suite for exportAndPushJSONToGitHub.sh script
# Author: Andres Gomez (AngocA)
# Version: 2026-01-17

# Require minimum BATS version
bats_require_minimum_version 1.5.0

# Load test helper
load ../../test_helper

# Get script directory (go up from tests/unit/bash to project root)
SCRIPT_BASE_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIR

# Test that script exists and is executable
@test "exportAndPushJSONToGitHub.sh script exists and is executable" {
  [ -f "${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh" ]
  [ -x "${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh" ]
}

# Test that script has required functions
@test "exportAndPushJSONToGitHub.sh contains required functions" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Check for main functions
  grep -q "export_single_country" "${script_file}"
  grep -q "get_countries_to_export" "${script_file}"
  grep -q "commit_and_push_country" "${script_file}"
  grep -q "remove_obsolete_countries" "${script_file}"
  grep -q "generate_countries_readme" "${script_file}"
  grep -q "update_country_index" "${script_file}"
}

# Test that script has correct default configuration
@test "exportAndPushJSONToGitHub.sh has correct default configuration" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Check for default MAX_AGE_DAYS
  grep -q 'MAX_AGE_DAYS="${MAX_AGE_DAYS:-30}"' "${script_file}"

  # Check for default COUNTRIES_PER_BATCH
  grep -q 'COUNTRIES_PER_BATCH="${COUNTRIES_PER_BATCH:-10}"' "${script_file}"
}

# Test that script uses intelligent incremental mode (no INCREMENTAL_MODE variable)
@test "exportAndPushJSONToGitHub.sh uses intelligent incremental mode by default" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Should NOT have INCREMENTAL_MODE variable (removed)
  ! grep -q 'INCREMENTAL_MODE=' "${script_file}" || {
    # If found, it should only be in comments
    grep 'INCREMENTAL_MODE' "${script_file}" | grep -q '^[[:space:]]*#' || false
  }

  # Should have intelligent incremental mode logic
  grep -q "intelligent incremental mode" "${script_file}"
}

# Test that script includes cleanup of obsolete countries
@test "exportAndPushJSONToGitHub.sh includes obsolete country cleanup" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Should call remove_obsolete_countries
  grep -q "remove_obsolete_countries" "${script_file}"

  # Should have function definition
  grep -q "^remove_obsolete_countries()" "${script_file}" || \
  grep -q "^# Remove countries from GitHub" "${script_file}"
}

# Test that script generates README.md
@test "exportAndPushJSONToGitHub.sh generates countries README.md" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Should call generate_countries_readme
  grep -q "generate_countries_readme" "${script_file}"

  # Should have function definition
  grep -q "^generate_countries_readme()" "${script_file}" || \
  grep -q "^# Generate README.md" "${script_file}"
}

# Test that script validates JSON with schema
@test "exportAndPushJSONToGitHub.sh includes JSON schema validation" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Should have validation function
  grep -q "validate_json_with_schema" "${script_file}"

  # Should validate country files
  grep -q "country-profile.schema.json" "${script_file}"
}

# Test that script marks countries as exported in database
@test "exportAndPushJSONToGitHub.sh marks countries as exported" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Should update json_exported flag
  grep -q "json_exported = TRUE" "${script_file}"
  grep -q "UPDATE dwh.datamartcountries" "${script_file}"
}

# Test that script checks for obsolete countries
@test "exportAndPushJSONToGitHub.sh checks for obsolete countries logic" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Should compare database countries with GitHub files
  grep -q "comm -23" "${script_file}" || grep -q "obsolete" "${script_file}"
  grep -q "git rm" "${script_file}"
}

# Test that script generates README with alphabetical order
@test "exportAndPushJSONToGitHub.sh generates README in alphabetical order" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Should order by country name
  grep -q "ORDER BY.*country_name" "${script_file}" || \
  grep -q "ORDER BY.*COALESCE" "${script_file}"
}

# Test that script has proper error handling
@test "exportAndPushJSONToGitHub.sh has error handling" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Should have error handling for failed exports
  grep -q "Failed to export" "${script_file}"
  grep -q "Failed to push" "${script_file}"

  # Should continue on errors
  grep -q "failed=\$((failed + 1))" "${script_file}"
}

# Test that script has lock file mechanism
@test "exportAndPushJSONToGitHub.sh has lock file mechanism" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Should have lock file setup
  grep -q "setup_lock" "${script_file}"
  grep -q "flock" "${script_file}"
  grep -q "LOCK=" "${script_file}"
}

# Test that script has cleanup on exit
@test "exportAndPushJSONToGitHub.sh has cleanup on exit" {
  local script_file="${SCRIPT_BASE_DIR}/bin/dwh/exportAndPushJSONToGitHub.sh"

  # Should have cleanup function
  grep -q "cleanup()" "${script_file}"
  grep -q "trap cleanup" "${script_file}"
}

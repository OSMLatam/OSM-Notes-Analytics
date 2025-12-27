#!/bin/bash

# Helper script to verify database connection before running tests
# This script can be sourced by test files to ensure DB is available
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-27

verify_database_connection() {
 local dbname="${TEST_DBNAME:-${DBNAME:-}}"

 # First check if database name is configured
 if [[ -z "${dbname}" ]]; then
  echo "ERROR: No database configured (TEST_DBNAME or DBNAME not set)" >&2
  echo "Please configure TEST_DBNAME in tests/properties.sh or set it as an environment variable" >&2
  echo "Default test database name: osm_notes_analytics_test" >&2
  return 1
 fi

 # Try to connect to the database
 # Use appropriate connection method based on environment
 if [[ -n "${TEST_DBHOST:-}" ]]; then
  # CI/CD environment - use host/port/user
  if ! PGPASSWORD="${TEST_DBPASSWORD:-postgres}" psql -h "${TEST_DBHOST}" -p "${TEST_DBPORT:-5432}" -U "${TEST_DBUSER:-postgres}" -d "${dbname}" -c "SELECT 1;" > /dev/null 2>&1; then
   echo "ERROR: Cannot connect to database ${dbname}" >&2
   echo "Connection details:" >&2
   echo "  TEST_DBNAME=${TEST_DBNAME:-}" >&2
   echo "  TEST_DBHOST=${TEST_DBHOST:-}" >&2
   echo "  TEST_DBPORT=${TEST_DBPORT:-}" >&2
   echo "  TEST_DBUSER=${TEST_DBUSER:-}" >&2
   echo "Please verify database connection settings and ensure the database exists" >&2
   return 1
  fi
 else
  # Local environment - use peer authentication
  if ! psql -d "${dbname}" -c "SELECT 1;" > /dev/null 2>&1; then
   echo "ERROR: Cannot connect to database ${dbname}" >&2
   echo "Connection details:" >&2
   echo "  TEST_DBNAME=${TEST_DBNAME:-}" >&2
   echo "  DBNAME=${DBNAME:-}" >&2
   echo "Please verify:" >&2
   echo "  1. Database ${dbname} exists (run: createdb ${dbname})" >&2
   echo "  2. PostgreSQL is running" >&2
   echo "  3. You have permission to connect to the database" >&2
   return 1
  fi
 fi

 return 0
}

# Export function for use in other scripts
export -f verify_database_connection

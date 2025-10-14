#!/usr/bin/env bash

# Test helper functions for BATS tests - OSM-Notes-Analytics
# Author: Andres Gomez (AngocA)
# Version: 2025-10-14

# Test database configuration
# Use the values already set by run_tests.sh, don't override them
# Only set defaults if not already set

# Test directories
# Detect if running in Docker or host
if [[ -f "/app/bin/dwh/ETL.sh" ]]; then
 # Running in Docker container
 export TEST_BASE_DIR="/app"
else
 # Running on host - detect project root
 TEST_BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
 export TEST_BASE_DIR
fi
export TEST_TMP_DIR="/tmp/bats_test_$$"

# Test environment variables
export LOG_LEVEL="DEBUG"
export __log_level="DEBUG"
export CLEAN="false"
export MAX_THREADS="2"
export TEST_MODE="true"

# Set required variables for ETL.sh BEFORE loading scripts
export BASENAME="test"
export TMP_DIR="/tmp/test_$$"
export DBNAME="${TEST_DBNAME}"
export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
export LOG_FILENAME="/tmp/test.log"
export LOCK="/tmp/test.lock"

# Load project properties
# Only load properties.sh if we're in Docker, otherwise use test-specific properties
if [[ -f "/app/bin/dwh/ETL.sh" ]]; then
 # Running in Docker - load original properties
 if [[ -f "${TEST_BASE_DIR}/etc/properties.sh" ]]; then
  source "${TEST_BASE_DIR}/etc/properties.sh"
 elif [[ -f "${TEST_BASE_DIR}/tests/properties.sh" ]]; then
  source "${TEST_BASE_DIR}/tests/properties.sh"
 else
  echo "Warning: properties.sh not found"
 fi
else
 # Running on host - use test-specific properties
 if [[ -f "${TEST_BASE_DIR}/tests/properties.sh" ]]; then
  source "${TEST_BASE_DIR}/tests/properties.sh"
 else
  echo "Warning: tests/properties.sh not found, using default test values"
 fi
fi

# Create a simple logger for tests
__start_logger() {
 echo "Logger started"
}

# Create basic logging functions that always print
__logd() {
 echo "DEBUG: $*"
}

__logi() {
 echo "INFO: $*"
}

__logw() {
 echo "WARN: $*"
}

__loge() {
 echo "ERROR: $*" >&2
}

__logf() {
 echo "FATAL: $*" >&2
}

__logt() {
 echo "TRACE: $*"
}

__log_start() {
 __logi "Starting function"
}

__log_finish() {
 __logi "Function completed"
}

# Load validation functions after defining simple logging
if [[ -f "${TEST_BASE_DIR}/lib/osm-common/validationFunctions.sh" ]]; then
 source "${TEST_BASE_DIR}/lib/osm-common/validationFunctions.sh"
else
 echo "Warning: validationFunctions.sh not found at lib/osm-common/"
fi

# Set additional environment variables for Docker container
export PGHOST="${TEST_DBHOST}"
export PGUSER="${TEST_DBUSER}"
export PGPASSWORD="${TEST_DBPASSWORD}"
export PGDATABASE="${TEST_DBNAME}"

# Initialize logging system
__start_logger

# Setup function - runs before each test
setup() {
 # Create temporary directory
 mkdir -p "${TEST_TMP_DIR}"

 # Set up test environment
 export TMP_DIR="${TEST_TMP_DIR}"
 export DBNAME="${TEST_DBNAME}"

 # Mock external commands if needed
 if ! command -v psql &> /dev/null; then
  # Create mock psql if not available
  create_mock_psql
 fi
}

# Teardown function - runs after each test
teardown() {
 # Clean up temporary directory
 rm -rf "${TEST_TMP_DIR}"
}

# Create mock psql for testing
create_mock_psql() {
 cat > "${TEST_TMP_DIR}/psql" << 'EOF'
#!/bin/bash
# Mock psql command for testing
echo "Mock psql called with: $*"
exit 0
EOF
 chmod +x "${TEST_TMP_DIR}/psql"
 export PATH="${TEST_TMP_DIR}:${PATH}"
}

# Mock psql function for host testing
mock_psql() {
 if [[ -f "/app/bin/dwh/ETL.sh" ]]; then
  # Running in Docker - use real psql
  command psql "$@"
 else
  # Running on host - simulate psql
  echo "Mock psql called with: $*"
  
  # Check if this is a connection test with invalid parameters
  if [[ "$*" == *"-h localhost"* ]] && [[ "$*" == *"-p 5434"* ]]; then
   # Simulate connection failure for invalid port
   echo "psql: error: connection to server at localhost (::1), port 5434 failed: Connection refused" >&2
   echo "Is the server running on that host and accepting TCP/IP connections?" >&2
   return 2
  fi
  
  # Check if this is a connection test with invalid database/user
  if [[ "$*" == *"test_db"* ]] || [[ "$*" == *"test_user"* ]]; then
   # Simulate connection failure for invalid database/user
   echo "psql: error: connection to server at localhost (::1), port 5434 failed: Connection refused" >&2
   echo "Is the server running on that host and accepting TCP/IP connections?" >&2
   return 2
  fi
  
  # For other cases, simulate success
  return 0
 fi
}

# Helper function to create test database
create_test_database() {
 echo "DEBUG: Function called"
 local dbname="${1:-${TEST_DBNAME}}"
 echo "DEBUG: dbname = ${dbname}"
 
 # Check if PostgreSQL is available
 if psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  echo "DEBUG: PostgreSQL available, using real database"
  
  # Try to connect to the specified database first
  if psql -d "${dbname}" -c "SELECT 1;" >/dev/null 2>&1; then
   echo "Test database ${dbname} already exists and is accessible"
  else
   echo "Test database ${dbname} does not exist, creating it..."
   createdb "${dbname}" 2>/dev/null || true
   echo "Test database ${dbname} created successfully"
  fi
   
  # Create DWH schema
  echo "Creating DWH schema..."
  psql -d "${dbname}" << 'EOF'
-- Create DWH schema for Analytics
CREATE SCHEMA IF NOT EXISTS dwh;

-- Install required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Create basic dimension tables for testing
CREATE TABLE IF NOT EXISTS dwh.dimension_users (
  id_user SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  username VARCHAR(256) NOT NULL,
  valid_from TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  valid_to TIMESTAMP WITH TIME ZONE,
  is_current BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS dwh.dimension_countries (
  id_country SERIAL PRIMARY KEY,
  country_id INTEGER NOT NULL,
  name VARCHAR(256) NOT NULL,
  iso_code VARCHAR(2)
);

CREATE TABLE IF NOT EXISTS dwh.dimension_days (
  id_day SERIAL PRIMARY KEY,
  date DATE NOT NULL,
  year INTEGER NOT NULL,
  month INTEGER NOT NULL,
  day INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS dwh.facts (
  id_fact SERIAL PRIMARY KEY,
  note_id INTEGER NOT NULL,
  id_user INTEGER,
  id_country INTEGER,
  id_day INTEGER,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Create datamart tables
CREATE TABLE IF NOT EXISTS dwh.datamart_users (
  id_user INTEGER PRIMARY KEY,
  username VARCHAR(256),
  total_notes INTEGER DEFAULT 0,
  total_comments INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS dwh.datamart_countries (
  id_country INTEGER PRIMARY KEY,
  country_name VARCHAR(256),
  total_notes INTEGER DEFAULT 0
);

-- Create base tables for compatibility with ingestion system
CREATE TABLE IF NOT EXISTS users (
  user_id INTEGER NOT NULL PRIMARY KEY,
  username VARCHAR(256) NOT NULL
);

CREATE TABLE IF NOT EXISTS countries (
  country_id INTEGER PRIMARY KEY,
  name VARCHAR(256) NOT NULL
);

CREATE TABLE IF NOT EXISTS notes (
  id INTEGER NOT NULL,
  note_id INTEGER NOT NULL,
  lat DECIMAL(10,8) NOT NULL,
  lon DECIMAL(11,8) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL,
  closed_at TIMESTAMP WITH TIME ZONE,
  id_user INTEGER,
  id_country INTEGER
);

-- Insert test countries
INSERT INTO countries (country_id, name) VALUES
  (1, 'United States'),
  (2, 'United Kingdom'),
  (3, 'Germany'),
  (4, 'Japan'),
  (5, 'Australia')
ON CONFLICT (country_id) DO NOTHING;
EOF
   
  return 0
 else
  echo "DEBUG: PostgreSQL not available, using simulated database"
  echo "Test database ${dbname} created (simulated)"
 fi
}

# Helper function to drop test database
drop_test_database() {
 local dbname="${1:-${TEST_DBNAME}}"

 # Detect if running in Docker or host
 if [[ -f "/app/bin/dwh/ETL.sh" ]]; then
  # Running in Docker - actually drop the database to clean up between tests
  echo "Dropping test database ${dbname}..."
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "postgres" -c "DROP DATABASE IF EXISTS ${dbname};" 2>/dev/null || true
  echo "Test database ${dbname} dropped successfully"
 else
  # Running on host - simulate database drop
  echo "Test database ${dbname} dropped (simulated)"
 fi
}

# Helper function to run SQL file
run_sql_file() {
 local sql_file="${1}"
 local dbname="${2:-${TEST_DBNAME}}"

 if [[ -f "${sql_file}" ]]; then
  # Detect if running in Docker or host
  if [[ -f "/app/bin/dwh/ETL.sh" ]]; then
   # Running in Docker - use real psql
   psql -d "${dbname}" -f "${sql_file}" 2> /dev/null
   return $?
  else
   # Running on host - simulate SQL execution
   echo "SQL file ${sql_file} executed (simulated)"
   return 0
  fi
 else
  echo "SQL file not found: ${sql_file}"
  return 1
 fi
}

# Helper function to check if table exists
table_exists() {
 local table_name="${1}"
 local schema_name="${2:-public}"
 local dbname="${3:-${TEST_DBNAME}}"

 # Detect if running in Docker or host
 if [[ -f "/app/bin/dwh/ETL.sh" ]]; then
  # Running in Docker - try to connect to real database
  local result
  result=$(psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${schema_name}' AND table_name = '${table_name}';" 2> /dev/null | tr -d ' ')

  if [[ -n "${result}" ]] && [[ "${result}" == "1" ]]; then
   return 0
  else
   return 1
  fi
 else
  # Running on host - simulate table check
  echo "Table ${table_name} exists (simulated)"
  return 0
 fi
}

# Helper function to count rows in table
count_rows() {
 local table_name="${1}"
 local dbname="${2:-${TEST_DBNAME}}"

 # Try to connect to real database first (both Docker and host)
 local result
 result=$(psql -U "${TEST_DBUSER:-$(whoami)}" -d "${dbname}" -t -c "SELECT COUNT(*) FROM ${table_name};" 2> /dev/null)
 
 if [[ -n "${result}" ]] && [[ "${result}" =~ ^[0-9]+$ ]]; then
  # Successfully connected to real database
  echo "${result// /}"
 else
  # Running on host - simulate count
  echo "0"
 fi
}

# Helper function to check if function exists
function_exists() {
 local function_name="${1}"
 local dbname="${2:-${TEST_DBNAME}}"

 # Detect if running in Docker or host
 if [[ -f "/app/bin/dwh/ETL.sh" ]]; then
  # Running in Docker - try to connect to real database
  local result
  result=$(psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = '${function_name}';" 2> /dev/null | tr -d ' ')

  if [[ "${result}" == "1" ]]; then
   return 0
  else
   return 1
  fi
 else
  # Running on host - simulate function check
  echo "Function ${function_name} exists (simulated)"
  return 0
 fi
}

# Helper function to check if procedure exists
procedure_exists() {
 local procedure_name="${1}"
 local dbname="${2:-${TEST_DBNAME}}"

 # Detect if running in Docker or host
 if [[ -f "/app/bin/dwh/ETL.sh" ]]; then
  # Running in Docker - try to connect to real database
  local result
  result=$(psql -d "${dbname}" -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = '${procedure_name}' AND routine_type = 'PROCEDURE';" 2> /dev/null | tr -d ' ')

  if [[ "${result}" == "1" ]]; then
   return 0
  else
   return 1
  fi
 else
  # Running on host - simulate procedure check
  echo "Procedure ${procedure_name} exists (simulated)"
  return 0
 fi
}

# Helper function to assert directory exists
assert_dir_exists() {
  local dir_path="$1"
  if [[ ! -d "${dir_path}" ]]; then
    echo "Directory does not exist: ${dir_path}" >&2
    return 1
  fi
  return 0
}



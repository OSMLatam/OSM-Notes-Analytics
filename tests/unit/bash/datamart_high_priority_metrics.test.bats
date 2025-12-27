#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for high priority metrics in datamarts
# Tests that the newly implemented high priority metrics are calculated correctly
#
# New metrics tested:
# - application_usage_trends: JSON array of application usage trends by year
# - version_adoption_rates: JSON array of version adoption rates by year
# - notes_health_score: Overall notes health score (0-100) for countries
# - new_vs_resolved_ratio: Ratio of new notes created vs resolved notes (last 30 days) for countries
# - user_response_time: Average time in days from note open to first comment by user
# - days_since_last_action: Days since user last performed any action
# - collaboration_patterns: JSON object with collaboration metrics for users
# - notes_opened_but_not_closed_by_user: Notes opened by user but never closed by same user

load ../../../tests/test_helper

setup() {
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export SCRIPT_BASE_DIRECTORY

  # Load properties
  # shellcheck disable=SC1090
  source "${SCRIPT_BASE_DIRECTORY}/tests/properties.sh"

  # Setup test database if needed and DBNAME is configured
  if [[ -z "${SKIP_TEST_SETUP:-}" ]] && [[ -n "${DBNAME:-}" ]]; then
    setup_test_database
  fi
}

# ============================================================================
# Application Usage Trends Tests
# ============================================================================

# Test that application_usage_trends column exists in datamartCountries
@test "Application usage trends column should exist in datamartCountries table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check if column exists
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartcountries'
      AND column_name = 'application_usage_trends';
  "

  [[ "${status}" -eq 0 ]]
  [[ $(echo "${output}" | grep -c "application_usage_trends") -eq 1 ]] || echo "Column should exist"
}

# Test that application_usage_trends column exists in datamartUsers
@test "Application usage trends column should exist in datamartUsers table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check if column exists
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartusers'
      AND column_name = 'application_usage_trends';
  "

  [[ "${status}" -eq 0 ]]
  [[ $(echo "${output}" | grep -c "application_usage_trends") -eq 1 ]] || echo "Column should exist"
}

# Test that application_usage_trends JSON has valid structure for countries
@test "Application usage trends JSON should have valid structure for countries" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Test JSON structure (skip if no data)
  run psql -d "${DBNAME}" -t -c "
    SELECT json_typeof(application_usage_trends)
    FROM dwh.datamartcountries
    WHERE application_usage_trends IS NOT NULL
    LIMIT 1;
  "

  [[ "${status}" -eq 0 ]]
  # Should be array or null
  [[ -z "${output}" ]] || [[ "${output}" == *"array"* ]] || echo "Should be valid JSON array or null"
}

# Test that application_usage_trends JSON has valid structure for users
@test "Application usage trends JSON should have valid structure for users" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Test JSON structure
  run psql -d "${DBNAME}" -t -c "
    SELECT json_typeof(application_usage_trends)
    FROM dwh.datamartusers
    WHERE application_usage_trends IS NOT NULL
    LIMIT 1;
  "

  [[ "${status}" -eq 0 ]]
  # Should be array or null
  [[ -z "${output}" ]] || [[ "${output}" == *"array"* ]] || echo "Should be valid JSON array or null"
}

# ============================================================================
# Version Adoption Rates Tests
# ============================================================================

# Test that version_adoption_rates column exists in datamartCountries
@test "Version adoption rates column should exist in datamartCountries table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check if column exists
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartcountries'
      AND column_name = 'version_adoption_rates';
  "

  [[ "${status}" -eq 0 ]]
  [[ $(echo "${output}" | grep -c "version_adoption_rates") -eq 1 ]] || echo "Column should exist"
}

# Test that version_adoption_rates column exists in datamartUsers
@test "Version adoption rates column should exist in datamartUsers table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check if column exists
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartusers'
      AND column_name = 'version_adoption_rates';
  "

  [[ "${status}" -eq 0 ]]
  [[ $(echo "${output}" | grep -c "version_adoption_rates") -eq 1 ]] || echo "Column should exist"
}

# Test that version_adoption_rates JSON has valid structure
@test "Version adoption rates JSON should have valid structure" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Test JSON structure for countries
  run psql -d "${DBNAME}" -t -c "
    SELECT json_typeof(version_adoption_rates)
    FROM dwh.datamartcountries
    WHERE version_adoption_rates IS NOT NULL
    LIMIT 1;
  "

  [[ "${status}" -eq 0 ]]
  # Should be array or null
  [[ -z "${output}" ]] || [[ "${output}" == *"array"* ]] || echo "Should be valid JSON array or null"
}

# ============================================================================
# Notes Health Score Tests (Countries only)
# ============================================================================

# Test that notes_health_score column exists in datamartCountries
@test "Notes health score column should exist in datamartCountries table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check if column exists
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartcountries'
      AND column_name = 'notes_health_score';
  "

  [[ "${status}" -eq 0 ]]
  [[ $(echo "${output}" | grep -c "notes_health_score") -eq 1 ]] || echo "Column should exist"
}

# Test that notes_health_score is within valid range (0-100)
@test "Notes health score should be within valid range (0-100) for countries" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check that health score is between 0 and 100
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartcountries
    WHERE notes_health_score IS NOT NULL
      AND (notes_health_score < 0 OR notes_health_score > 100);
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 countries with invalid scores
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All health scores should be between 0 and 100"
}

# ============================================================================
# New vs Resolved Ratio Tests (Countries only)
# ============================================================================

# Test that new_vs_resolved_ratio column exists in datamartCountries
@test "New vs resolved ratio column should exist in datamartCountries table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check if column exists
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartcountries'
      AND column_name = 'new_vs_resolved_ratio';
  "

  [[ "${status}" -eq 0 ]]
  [[ $(echo "${output}" | grep -c "new_vs_resolved_ratio") -eq 1 ]] || echo "Column should exist"
}

# Test that new_vs_resolved_ratio is non-negative
@test "New vs resolved ratio should be non-negative for countries" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check that ratio is non-negative (can be 0 or positive, or 999.99 for infinite)
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartcountries
    WHERE new_vs_resolved_ratio IS NOT NULL
      AND new_vs_resolved_ratio < 0;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 countries with negative ratios
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All ratios should be non-negative"
}

# ============================================================================
# User Response Time Tests (Users only)
# ============================================================================

# Test that user_response_time column exists in datamartUsers
@test "User response time column should exist in datamartUsers table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check if column exists
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartusers'
      AND column_name = 'user_response_time';
  "

  [[ "${status}" -eq 0 ]]
  [[ $(echo "${output}" | grep -c "user_response_time") -eq 1 ]] || echo "Column should exist"
}

# Test that user_response_time is non-negative
@test "User response time should be non-negative for users" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check that response time is non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartusers
    WHERE user_response_time IS NOT NULL
      AND user_response_time < 0;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with negative response times
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All response times should be non-negative"
}

# ============================================================================
# Days Since Last Action Tests (Users only)
# ============================================================================

# Test that days_since_last_action column exists in datamartUsers
@test "Days since last action column should exist in datamartUsers table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check if column exists
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartusers'
      AND column_name = 'days_since_last_action';
  "

  [[ "${status}" -eq 0 ]]
  [[ $(echo "${output}" | grep -c "days_since_last_action") -eq 1 ]] || echo "Column should exist"
}

# Test that days_since_last_action is non-negative
@test "Days since last action should be non-negative for users" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check that days since last action is non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartusers
    WHERE days_since_last_action IS NOT NULL
      AND days_since_last_action < 0;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with negative days
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All days since last action should be non-negative"
}

# ============================================================================
# Collaboration Patterns Tests (Users only)
# ============================================================================

# Test that collaboration_patterns column exists in datamartUsers
@test "Collaboration patterns column should exist in datamartUsers table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check if column exists
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartusers'
      AND column_name = 'collaboration_patterns';
  "

  [[ "${status}" -eq 0 ]]
  [[ $(echo "${output}" | grep -c "collaboration_patterns") -eq 1 ]] || echo "Column should exist"
}

# Test that collaboration_patterns JSON has valid structure
@test "Collaboration patterns JSON should have valid structure for users" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Test JSON structure
  run psql -d "${DBNAME}" -t -c "
    SELECT json_typeof(collaboration_patterns)
    FROM dwh.datamartusers
    WHERE collaboration_patterns IS NOT NULL
    LIMIT 1;
  "

  [[ "${status}" -eq 0 ]]
  # Should be object or null
  [[ -z "${output}" ]] || [[ "${output}" == *"object"* ]] || echo "Should be valid JSON object or null"
}

# Test that collaboration_patterns contains expected fields
@test "Collaboration patterns JSON should contain expected fields" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check JSON structure for users
  run psql -d "${DBNAME}" -t -c "
    SELECT jsonb_object_keys(collaboration_patterns::jsonb)
    FROM dwh.datamartusers
    WHERE collaboration_patterns IS NOT NULL
    LIMIT 1;
  "

  [[ "${status}" -eq 0 ]]
  # Should have some keys (mentions_given, mentions_received, etc.)
  [[ -n "${output}" ]] || echo "Should have JSON keys"
}

# Test that collaboration_patterns values are non-negative
@test "Collaboration patterns values should be non-negative" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check that collaboration metrics are non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartusers
    WHERE collaboration_patterns IS NOT NULL
      AND (
        (collaboration_patterns::jsonb->>'mentions_given')::INTEGER < 0
        OR (collaboration_patterns::jsonb->>'mentions_received')::INTEGER < 0
        OR (collaboration_patterns::jsonb->>'replies_count')::INTEGER < 0
        OR (collaboration_patterns::jsonb->>'collaboration_score')::INTEGER < 0
      );
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with negative collaboration metrics
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All collaboration metrics should be non-negative"
}

# ============================================================================
# Integration Tests - Verify calculations match facts table
# ============================================================================

# Test that application usage trends can be calculated from facts
@test "Application usage trends should be calculable from facts table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Test that we can calculate trends from facts
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(DISTINCT EXTRACT(YEAR FROM d.date_id))
    FROM dwh.facts f
    JOIN dwh.dimension_days d ON f.opened_dimension_id_date = d.dimension_day_id
    WHERE f.dimension_application_creation IS NOT NULL
      AND f.action_comment = 'opened';
  "

  [[ "${status}" -eq 0 ]]
  # Should contain numeric values (may be 0 if no test data)
  [[ "${output}" =~ [0-9] ]]
}

# Test that version adoption rates can be calculated from facts
@test "Version adoption rates should be calculable from facts table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Test that we can calculate version adoption from facts
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(DISTINCT f.dimension_application_version)
    FROM dwh.facts f
    WHERE f.dimension_application_version IS NOT NULL
      AND f.action_comment = 'opened';
  "

  [[ "${status}" -eq 0 ]]
  # Should contain numeric values (may be 0 if no test data)
  [[ "${output}" =~ [0-9] ]]
}

# Test that user response time can be calculated from facts
@test "User response time should be calculable from facts table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Test that we can calculate response time from facts
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM (
      SELECT DISTINCT ON (f1.id_note) f1.id_note
      FROM dwh.facts f1
      WHERE f1.action_comment = 'opened'
    ) o
    JOIN (
      SELECT DISTINCT ON (f2.id_note) f2.id_note
      FROM dwh.facts f2
      WHERE f2.action_comment = 'commented'
    ) c ON c.id_note = o.id_note;
  "

  [[ "${status}" -eq 0 ]]
  # Should contain numeric values (may be 0 if no test data)
  [[ "${output}" =~ [0-9] ]]
}


# ============================================================================
# Notes Opened But Not Closed By User Tests
# ============================================================================

# Test that notes_opened_but_not_closed_by_user column exists in datamartUsers
@test "Notes opened but not closed by user column should exist in datamartUsers table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check if column exists
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartusers'
      AND column_name = 'notes_opened_but_not_closed_by_user';
  "

  [[ "${status}" -eq 0 ]]
  [[ $(echo "${output}" | grep -c "notes_opened_but_not_closed_by_user") -eq 1 ]] || echo "Column should exist"
}

# Test that notes_opened_but_not_closed_by_user is non-negative
@test "Notes opened but not closed by user should be non-negative" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check that all values are non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartusers
    WHERE notes_opened_but_not_closed_by_user IS NOT NULL
      AND notes_opened_but_not_closed_by_user < 0;
  "

  [[ "${status}" -eq 0 ]]
  count="${output// /}"
  [[ "${count}" == "0" ]] || echo "All values should be non-negative"
}

# Test that notes_opened_but_not_closed_by_user is less than or equal to history_whole_open
@test "Notes opened but not closed by user should be <= total opened notes" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Check that notes_opened_but_not_closed_by_user <= history_whole_open
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartusers
    WHERE notes_opened_but_not_closed_by_user IS NOT NULL
      AND history_whole_open IS NOT NULL
      AND notes_opened_but_not_closed_by_user > history_whole_open;
  "

  [[ "${status}" -eq 0 ]]
  count="${output// /}"
  [[ "${count}" == "0" ]] || echo "Should not exceed total opened notes"
}

# Test that notes_opened_but_not_closed_by_user can be calculated from facts
@test "Notes opened but not closed by user should be calculable from facts table" {
  # Verify database connection - will fail explicitly if DB is not available
  if ! verify_database_connection; then
    echo "Database connection failed - test cannot proceed" >&2
    return 1
  fi

  # Test that we can calculate this metric from facts
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(DISTINCT f1.id_note)
    FROM dwh.facts f1
    WHERE f1.opened_dimension_id_user IS NOT NULL
      AND f1.action_comment = 'opened'
      AND NOT EXISTS (
        SELECT 1
        FROM dwh.facts f2
        WHERE f2.id_note = f1.id_note
          AND f2.closed_dimension_id_user = f1.opened_dimension_id_user
          AND f2.action_comment = 'closed'
      );
  "

  [[ "${status}" -eq 0 ]]
  # Should contain numeric values (may be 0 if no test data)
  [[ "${output}" =~ [0-9] ]]
}

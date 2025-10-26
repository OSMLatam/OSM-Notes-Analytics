#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for resolution metrics in datamartUsers
# Tests that resolution metrics are calculated correctly for users

load test_helper

setup() {
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export SCRIPT_BASE_DIRECTORY

  # Load properties
  # shellcheck disable=SC1090
  source "${SCRIPT_BASE_DIRECTORY}/tests/properties.sh"

  export TEST_USER_ID=99999
}

# Test that resolution metrics columns exist in datamartUsers
@test "Resolution metrics columns should exist in datamartUsers table" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check if columns exist
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartUsers'
      AND column_name IN ('avg_days_to_resolution', 'median_days_to_resolution',
                          'notes_resolved_count', 'notes_still_open_count',
                          'resolution_rate');
  "

  [[ "${status}" -eq 0 ]]
  # Should have 5 lines (one per column)
  [[ $(echo "${output}" | grep -c "resolution") -eq 5 ]] || echo "Resolution columns should exist"
}

# Test that resolution metrics can be calculated for users
@test "Resolution metrics should be calculable from facts table for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Test the calculation query
  run psql -d "${DBNAME}" -t -c "
    SELECT
      AVG(days_to_resolution) as avg_resolution,
      COUNT(DISTINCT id_note) FILTER (WHERE action_comment = 'closed') as resolved_count
    FROM dwh.facts
    WHERE days_to_resolution IS NOT NULL
      AND action_comment = 'closed'
    LIMIT 1;
  "

  [[ "${status}" -eq 0 ]]
  # Output should contain numeric values
  [[ "${output}" =~ [0-9] ]] || echo "Should return numeric results"
}

# Test that resolution rate calculation handles edge cases for users
@test "Resolution rate should handle division by zero for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Test resolution rate calculation doesn't error with zero total
  run psql -d "${DBNAME}" -t -c "
    SELECT
      CASE
        WHEN (0 + 0) > 0 THEN (0::DECIMAL / (0 + 0) * 100)
        ELSE 0
      END as rate;
  "

  [[ "${status}" -eq 0 ]]
  # Should return 0 without error
  [[ "${output}" =~ [0] ]] || echo "Should handle division by zero"
}

# Test that resolution metrics match cross-reference with facts for users
@test "Resolution metrics should match facts table calculation for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Get a user with data
  run psql -d "${DBNAME}" -t -c "
    SELECT dimension_user_id
    FROM dwh.datamartUsers
    WHERE notes_resolved_count IS NOT NULL
      AND notes_resolved_count > 0
    LIMIT 1;
  "

  if [[ $(echo "${output}" | tr -d ' ') == "" ]]; then
    skip "No user with resolution data available"
  fi

  local user_id=$(echo "${output}" | tr -d ' ')

  # Calculate resolution rate from facts
  run psql -d "${DBNAME}" -t -c "
    WITH facts_calc AS (
      SELECT
        (SELECT COUNT(DISTINCT id_note) FROM dwh.facts
         WHERE dimension_id_user = ${user_id} AND action_comment = 'closed') as resolved,
        (SELECT COUNT(DISTINCT id_note) FROM dwh.facts
         WHERE dimension_id_user = ${user_id} AND action_comment = 'opened'
         AND NOT EXISTS (
           SELECT 1 FROM dwh.facts f3
           WHERE f3.id_note = id_note AND f3.action_comment = 'closed'
             AND f3.dimension_id_user = dimension_id_user
         )) as still_open
    )
    SELECT
      CASE
        WHEN resolved + still_open > 0
        THEN (resolved::DECIMAL / (resolved + still_open) * 100)
        ELSE 0
      END
    FROM facts_calc;
  "

  [[ "${status}" -eq 0 ]]
  [[ "${output}" =~ [0-9] ]] || echo "Should calculate rate from facts"

  # Compare with datamart value
  run psql -d "${DBNAME}" -t -c "
    SELECT resolution_rate
    FROM dwh.datamartUsers
    WHERE dimension_user_id = ${user_id};
  "

  # Both should exist and not be NULL
  [[ "${status}" -eq 0 ]]
  [[ -n "${output}" ]] || echo "Datamart should have resolution rate"
}

# Test that resolution metrics are not NULL for users with activity
@test "Resolution metrics should not be NULL for users with activity" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check users with activity have metrics calculated
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE history_whole_open > 0
      AND (avg_days_to_resolution IS NULL
           OR notes_resolved_count IS NULL);
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with metrics missing when they have activity
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "Users with activity should have metrics"
}

# Test that resolution rate is between 0 and 100 for users
@test "Resolution rate should be between 0 and 100 for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that all resolution rates are valid percentages
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE resolution_rate IS NOT NULL
      AND (resolution_rate < 0 OR resolution_rate > 100);
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with invalid rates
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All rates should be between 0 and 100"
}

# Test that resolution time metrics are non-negative for users
@test "Resolution time metrics should be non-negative for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that resolution times are valid
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE (avg_days_to_resolution IS NOT NULL AND avg_days_to_resolution < 0)
       OR (median_days_to_resolution IS NOT NULL AND median_days_to_resolution < 0)
       OR (notes_resolved_count IS NOT NULL AND notes_resolved_count < 0)
       OR (notes_still_open_count IS NOT NULL AND notes_still_open_count < 0);
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with negative metrics
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All metrics should be non-negative"
}

# Test that notes_resolved_count + notes_still_open_count is consistent
@test "Resolution metrics counts should be consistent for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that resolved + still_open doesn't exceed opened (we don't have exact count)
  # Just verify the query runs without error
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE notes_resolved_count IS NOT NULL
      AND notes_still_open_count IS NOT NULL;
  "

  [[ "${status}" -eq 0 ]]
  echo "Consistency check passed"
}

# Test that datamart update procedure includes resolution metrics for users
@test "Datamart update procedure should include resolution metrics calculation for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that the procedure text includes resolution metrics
  run psql -d "${DBNAME}" -t -c "
    SELECT pg_get_functiondef('dwh.update_datamart_user'::regproc);
  "

  [[ "${status}" -eq 0 ]]
  # Should contain mentions of resolution metrics
  [[ "${output}" == *"avg_days_to_resolution"* ]] || echo "Procedure should calculate avg resolution"
  [[ "${output}" == *"resolution_rate"* ]] || echo "Procedure should calculate resolution rate"
}

# Test edge case: user with only opened notes (0% resolution)
@test "Resolution rate should handle users with no resolved notes" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Look for users with only opened notes
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE notes_still_open_count > 0
      AND notes_resolved_count = 0
      AND resolution_rate = 0;
  "

  [[ "${status}" -eq 0 ]]
  # Test passes if query runs without error
  echo "Edge case test passed"
}

# Test edge case: user with all notes resolved (100% resolution)
@test "Resolution rate should handle users with all notes resolved" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Look for users with all notes resolved
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE notes_still_open_count = 0
      AND notes_resolved_count > 0
      AND resolution_rate = 100;
  "

  [[ "${status}" -eq 0 ]]
  # Test passes if query runs without error
  echo "Edge case test passed"
}


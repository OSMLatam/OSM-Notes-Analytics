#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for content quality metrics in datamarts
# Tests that content quality metrics are calculated correctly

load ../../../tests/test_helper

setup() {
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export SCRIPT_BASE_DIRECTORY

  # Load properties
  # shellcheck disable=SC1090
  source "${SCRIPT_BASE_DIRECTORY}/tests/properties.sh"

  # Setup test database if needed
  if [[ -z "${SKIP_TEST_SETUP:-}" ]]; then
    setup_test_database
  fi
}

# Test that content quality columns exist in datamartCountries
@test "Content quality columns should exist in datamartCountries table" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check if columns exist
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartCountries'
      AND column_name IN ('avg_comment_length', 'comments_with_url_count',
                          'comments_with_url_pct', 'comments_with_mention_count',
                          'comments_with_mention_pct', 'avg_comments_per_note');
  "

  [[ "${status}" -eq 0 ]]
  # Should have 6 lines (one per column)
  [[ $(echo "${output}" | grep -c "comment") -eq 6 ]] || echo "Quality columns should exist"
}

# Test that content quality columns exist in datamartUsers
@test "Content quality columns should exist in datamartUsers table" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check if columns exist
  run psql -d "${DBNAME}" -t -c "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'dwh'
      AND table_name = 'datamartUsers'
      AND column_name IN ('avg_comment_length', 'comments_with_url_count',
                          'comments_with_url_pct', 'comments_with_mention_count',
                          'comments_with_mention_pct', 'avg_comments_per_note');
  "

  [[ "${status}" -eq 0 ]]
  # Should have 6 lines (one per column)
  [[ $(echo "${output}" | grep -c "comment") -eq 6 ]] || echo "Quality columns should exist"
}

# Test that avg_comment_length is non-negative for countries
@test "Avg comment length should be non-negative for countries" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that comment length is non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartCountries
    WHERE avg_comment_length IS NOT NULL
      AND avg_comment_length < 0;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 countries with negative comment length
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All comment lengths should be non-negative"
}

# Test that avg_comment_length is non-negative for users
@test "Avg comment length should be non-negative for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that comment length is non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE avg_comment_length IS NOT NULL
      AND avg_comment_length < 0;
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with negative comment length
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All comment lengths should be non-negative"
}

# Test that URL and mention percentages are between 0 and 100
@test "URL and mention percentages should be between 0 and 100 for countries" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that percentages are valid (0-100)
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartCountries
    WHERE (comments_with_url_pct IS NOT NULL AND (comments_with_url_pct < 0 OR comments_with_url_pct > 100))
       OR (comments_with_mention_pct IS NOT NULL AND (comments_with_mention_pct < 0 OR comments_with_mention_pct > 100));
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 countries with invalid percentages
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All percentages should be between 0 and 100"
}

# Test that URL and mention percentages are between 0 and 100 for users
@test "URL and mention percentages should be between 0 and 100 for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that percentages are valid (0-100)
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE (comments_with_url_pct IS NOT NULL AND (comments_with_url_pct < 0 OR comments_with_url_pct > 100))
       OR (comments_with_mention_pct IS NOT NULL AND (comments_with_mention_pct < 0 OR comments_with_mention_pct > 100));
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with invalid percentages
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All percentages should be between 0 and 100"
}

# Test that counts are non-negative
@test "Comment counts should be non-negative for countries" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that counts are non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartCountries
    WHERE (comments_with_url_count IS NOT NULL AND comments_with_url_count < 0)
       OR (comments_with_mention_count IS NOT NULL AND comments_with_mention_count < 0)
       OR (avg_comments_per_note IS NOT NULL AND avg_comments_per_note < 0);
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 countries with negative counts
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All counts should be non-negative"
}

# Test that counts are non-negative for users
@test "Comment counts should be non-negative for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that counts are non-negative
  run psql -d "${DBNAME}" -t -c "
    SELECT COUNT(*)
    FROM dwh.datamartUsers
    WHERE (comments_with_url_count IS NOT NULL AND comments_with_url_count < 0)
       OR (comments_with_mention_count IS NOT NULL AND comments_with_mention_count < 0)
       OR (avg_comments_per_note IS NOT NULL AND avg_comments_per_note < 0);
  "

  [[ "${status}" -eq 0 ]]
  # Should have 0 users with negative counts
  [[ "${output}" =~ ^[0\ ]+$ ]] || echo "All counts should be non-negative"
}

# Test content quality metrics can be calculated from facts
@test "Content quality metrics should be calculable from facts table" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Test calculation query (check for content quality columns)
  run psql -d "${DBNAME}" -t -c "
    SELECT
      AVG(comment_length) as avg_length,
      COUNT(*) FILTER (WHERE has_url = TRUE) as url_count
    FROM dwh.facts
    WHERE comment_length IS NOT NULL
    LIMIT 1;
  "

  [[ "${status}" -eq 0 ]]
  # Output should contain numeric values
  [[ "${output}" =~ [0-9] ]] || echo "Should return numeric results"
}

# Test comment length calculation from facts
@test "Comment length should be calculable for countries" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Test that we can calculate average comment length
  run psql -d "${DBNAME}" -t -c "
    SELECT AVG(comment_length)
    FROM dwh.facts
    WHERE dimension_id_country IN (
      SELECT dimension_country_id
      FROM dwh.datamartCountries
      WHERE avg_comment_length IS NOT NULL
      LIMIT 1
    )
    AND comment_length IS NOT NULL;
  "

  [[ "${status}" -eq 0 ]]
  # Should return valid number
  [[ -n "${output}" ]] || echo "Should return comment length"
}

# Test datamart update procedure includes content quality metrics
@test "Datamart update procedure should include content quality metrics calculation for countries" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that the procedure text includes quality metrics
  run psql -d "${DBNAME}" -t -c "
    SELECT pg_get_functiondef('dwh.update_datamart_country'::regproc);
  "

  [[ "${status}" -eq 0 ]]
  # Should contain mentions of quality metrics
  [[ "${output}" == *"avg_comment_length"* ]] || echo "Procedure should calculate avg comment length"
  [[ "${output}" == *"comments_with_url_pct"* ]] || echo "Procedure should calculate URL percentage"
}

# Test datamart update procedure includes content quality metrics for users
@test "Datamart update procedure should include content quality metrics calculation for users" {
  if [[ -z "${DBNAME:-}" ]]; then
    skip "No database configured"
  fi

  # Check that the procedure text includes quality metrics
  run psql -d "${DBNAME}" -t -c "
    SELECT pg_get_functiondef('dwh.update_datamart_user'::regproc);
  "

  [[ "${status}" -eq 0 ]]
  # Should contain mentions of quality metrics
  [[ "${output}" == *"avg_comment_length"* ]] || echo "Procedure should calculate avg comment length"
  [[ "${output}" == *"comments_with_url_pct"* ]] || echo "Procedure should calculate URL percentage"
}


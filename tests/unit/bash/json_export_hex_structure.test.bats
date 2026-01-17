#!/usr/bin/env bats
# Test suite for JSON export with hexadecimal directory structure
# Author: Andres Gomez (AngocA)
# Version: 2026-01-15

# Require minimum BATS version
bats_require_minimum_version 1.5.0

# Load test helper
load ../../test_helper

# Helper function to extract and test get_user_subdir
get_user_subdir_test() {
  local user_id=$1
  local mod
  local hex_mod
  local d1
  local d2
  local d3
  mod=$((user_id % 4096))
  hex_mod=$(printf "%03x" $mod)
  d1=$(echo "$hex_mod" | cut -c1)
  d2=$(echo "$hex_mod" | cut -c2)
  d3=$(echo "$hex_mod" | cut -c3)
  echo "${d1}/${d2}/${d3}"
}

# Test the get_user_subdir function
@test "get_user_subdir calculates correct subdirectory for small IDs" {
  run get_user_subdir_test 1
  [ "$status" -eq 0 ]
  [ "$output" = "0/0/1" ]
  
  run get_user_subdir_test 50
  [ "$status" -eq 0 ]
  [ "$output" = "0/3/2" ]
  
  run get_user_subdir_test 123
  [ "$status" -eq 0 ]
  [ "$output" = "0/7/b" ]
}

@test "get_user_subdir calculates correct subdirectory for medium IDs" {
  run get_user_subdir_test 1649
  [ "$status" -eq 0 ]
  [ "$output" = "6/7/1" ]
  
  run get_user_subdir_test 15071
  [ "$status" -eq 0 ]
  [ "$output" = "a/d/f" ]
  
  run get_user_subdir_test 1004700
  [ "$status" -eq 0 ]
  [ "$output" = "4/9/c" ]
}

@test "get_user_subdir calculates correct subdirectory for large IDs" {
  run get_user_subdir_test 2084878
  [ "$status" -eq 0 ]
  [ "$output" = "0/0/e" ]
  
  run get_user_subdir_test 23670762
  [ "$status" -eq 0 ]
  [ "$output" = "f/e/a" ]
}

@test "get_user_subdir distributes uniformly across 4096 directories" {
  # Test distribution by checking multiple IDs
  local subdirs=()
  for i in {1..100}; do
    subdir=$(get_user_subdir_test $i)
    subdirs+=("$subdir")
  done
  
  # Count unique subdirectories
  local unique_count
  unique_count=$(printf '%s\n' "${subdirs[@]}" | sort -u | wc -l)
  
  # With 100 IDs, we should have good distribution (at least 20+ unique directories)
  [ "$unique_count" -gt 20 ]
}

@test "get_user_subdir handles edge cases" {
  # Test modulo 0
  run get_user_subdir_test 0
  [ "$status" -eq 0 ]
  [ "$output" = "0/0/0" ]
  
  # Test modulo 4096 (should be 0/0/0)
  run get_user_subdir_test 4096
  [ "$status" -eq 0 ]
  [ "$output" = "0/0/0" ]
  
  # Test modulo 4095 (max)
  run get_user_subdir_test 4095
  [ "$status" -eq 0 ]
  [ "$output" = "f/f/f" ]
  
  # Test very large number
  run get_user_subdir_test 999999999
  [ "$status" -eq 0 ]
  # Should be valid 3-level path
  [[ "$output" =~ ^[0-9a-f]/[0-9a-f]/[0-9a-f]$ ]]
}

@test "JSON export creates correct directory structure for users" {
  skip_if_no_db_connection
  
  # Test that subdirectories are calculated correctly for various user IDs
  local subdir1
  subdir1=$(get_user_subdir_test 1)
  [ "$subdir1" = "0/0/1" ]
  
  local subdir50
  subdir50=$(get_user_subdir_test 50)
  [ "$subdir50" = "0/3/2" ]
  
  local subdir123
  subdir123=$(get_user_subdir_test 123)
  [ "$subdir123" = "0/7/b" ]
  
  local subdir1649
  subdir1649=$(get_user_subdir_test 1649)
  [ "$subdir1649" = "6/7/1" ]
}

@test "JSON export counts files correctly in subdirectory structure" {
  local test_dir="${TEST_TMP_DIR}/test_count"
  mkdir -p "${test_dir}/users"
  
  # Create test files in subdirectory structure
  mkdir -p "${test_dir}/users/0/0/1"
  mkdir -p "${test_dir}/users/0/3/2"
  mkdir -p "${test_dir}/users/6/7/1"
  
  echo '{"user_id": 1}' > "${test_dir}/users/0/0/1/1.json"
  echo '{"user_id": 50}' > "${test_dir}/users/0/3/2/50.json"
  echo '{"user_id": 1649}' > "${test_dir}/users/6/7/1/1649.json"
  
  # Count files recursively
  local count
  count=$(find "${test_dir}/users" -type f -name "*.json" | wc -l)
  
  [ "$count" -eq 3 ]
}

@test "JSON export migrates flat structure to subdirectory structure" {
  local test_dir="${TEST_TMP_DIR}/test_migration"
  mkdir -p "${test_dir}/users"
  
  # Create files in flat structure (old)
  echo '{"user_id": 1}' > "${test_dir}/users/1.json"
  echo '{"user_id": 50}' > "${test_dir}/users/50.json"
  echo '{"user_id": 123}' > "${test_dir}/users/123.json"
  
  # Simulate migration: organize files into subdirectories
  local temp_dir="${TEST_TMP_DIR}/temp_migration"
  mkdir -p "${temp_dir}/users"
  
  for file in "${test_dir}/users"/*.json; do
    if [[ -f "$file" ]]; then
      local user_id
      user_id=$(basename "$file" .json)
      if [[ "$user_id" =~ ^[0-9]+$ ]]; then
        local subdir
        subdir=$(get_user_subdir_test "$user_id")
        mkdir -p "${temp_dir}/users/${subdir}"
        cp "$file" "${temp_dir}/users/${subdir}/"
      fi
    fi
  done
  
  # Verify files are in correct subdirectories
  [ -f "${temp_dir}/users/0/0/1/1.json" ]
  [ -f "${temp_dir}/users/0/3/2/50.json" ]
  [ -f "${temp_dir}/users/0/7/b/123.json" ]
  
  # Verify old flat files still exist (migration doesn't delete originals)
  [ -f "${test_dir}/users/1.json" ]
}

@test "get_user_subdir produces valid 3-level paths" {
  # Test various IDs to ensure format is always x/x/x
  local test_ids=(1 10 100 1000 10000 100000 1000000)
  
  for user_id in "${test_ids[@]}"; do
    local subdir
    subdir=$(get_user_subdir_test "$user_id")
    
    # Should be exactly 5 characters: "x/x/x"
    [ "${#subdir}" -eq 5 ]
    
    # Should contain exactly 2 slashes
    local slash_count
    slash_count=$(echo "$subdir" | tr -cd '/' | wc -c)
    [ "$slash_count" -eq 2 ]
    
    # Each part should be single hex character
    local part1 part2 part3
    IFS='/' read -r part1 part2 part3 <<< "$subdir"
    [[ "$part1" =~ ^[0-9a-f]$ ]]
    [[ "$part2" =~ ^[0-9a-f]$ ]]
    [[ "$part3" =~ ^[0-9a-f]$ ]]
  done
}

@test "get_user_subdir handles modulo 4096 correctly" {
  # Test that modulo 4096 is applied correctly
  # IDs that are multiples of 4096 should map to 0/0/0
  run get_user_subdir_test 0
  [ "$status" -eq 0 ]
  [ "$output" = "0/0/0" ]
  
  run get_user_subdir_test 4096
  [ "$status" -eq 0 ]
  [ "$output" = "0/0/0" ]
  
  run get_user_subdir_test 8192
  [ "$status" -eq 0 ]
  [ "$output" = "0/0/0" ]
  
  # Test that 4095 maps to f/f/f (max modulo value)
  run get_user_subdir_test 4095
  [ "$status" -eq 0 ]
  [ "$output" = "f/f/f" ]
  
  # Test that 4097 maps to 0/0/1 (4096 + 1)
  run get_user_subdir_test 4097
  [ "$status" -eq 0 ]
  [ "$output" = "0/0/1" ]
}

@test "JSON export preserves existing files in subdirectory structure" {
  local test_output="${TEST_TMP_DIR}/test_preserve"
  mkdir -p "${test_output}/users/0/0/1"
  mkdir -p "${test_output}/users/0/3/2"
  
  # Create existing files
  echo '{"user_id": 1, "existing": true}' > "${test_output}/users/0/0/1/1.json"
  echo '{"user_id": 50, "existing": true}' > "${test_output}/users/0/3/2/50.json"
  
  # Simulate copying to temp directory (as script does)
  local temp_dir="${TEST_TMP_DIR}/temp_preserve"
  mkdir -p "${temp_dir}/users"
  
  # Copy recursively (new structure)
  cp -rp "${test_output}/users"/* "${temp_dir}/users/" 2>/dev/null || true
  
  # Verify files are preserved
  [ -f "${temp_dir}/users/0/0/1/1.json" ]
  [ -f "${temp_dir}/users/0/3/2/50.json" ]
  
  # Verify content is preserved
  grep -q '"existing": true' "${temp_dir}/users/0/0/1/1.json"
}

@test "JSON export handles both flat and subdirectory structures during migration" {
  local test_dir="${TEST_TMP_DIR}/test_mixed"
  mkdir -p "${test_dir}/users"
  mkdir -p "${test_dir}/users/0/0/1"
  
  # Mix of old (flat) and new (subdirectory) structures
  echo '{"user_id": 100}' > "${test_dir}/users/100.json"  # Old structure
  echo '{"user_id": 1}' > "${test_dir}/users/0/0/1/1.json"  # New structure
  
  local temp_dir="${TEST_TMP_DIR}/temp_mixed"
  mkdir -p "${temp_dir}/users"
  
  # Check for flat structure files
  if find "${test_dir}/users" -maxdepth 1 -name "*.json" | head -1 | grep -q .; then
    # Copy flat files to subdirectories
    for file in "${test_dir}/users"/*.json; do
      if [[ -f "$file" ]]; then
        local user_id
        user_id=$(basename "$file" .json)
        if [[ "$user_id" =~ ^[0-9]+$ ]]; then
          local subdir
          subdir=$(get_user_subdir_test "$user_id")
          mkdir -p "${temp_dir}/users/${subdir}"
          cp "$file" "${temp_dir}/users/${subdir}/"
        fi
      fi
    done
  fi
  
  # Copy subdirectory structure recursively
  if [[ -d "${test_dir}/users" ]]; then
    # Find all JSON files in subdirectories and copy them preserving structure
    find "${test_dir}/users" -type f -path "*/[0-9a-f]/*/[0-9a-f]/*.json" | while read -r file; do
      # Extract relative path from test_dir/users (e.g., "0/0/1/1.json" from "/path/to/users/0/0/1/1.json")
      local rel_path="${file#${test_dir}/users/}"
      # Create directory structure and copy file
      mkdir -p "${temp_dir}/users/$(dirname "$rel_path")"
      cp "$file" "${temp_dir}/users/${rel_path}" 2>/dev/null || true
    done
  fi
  
  # Verify both files end up in correct structure
  [ -f "${temp_dir}/users/0/6/4/100.json" ]  # Migrated from flat
  [ -f "${temp_dir}/users/0/0/1/1.json" ]    # Already in subdirectory
}

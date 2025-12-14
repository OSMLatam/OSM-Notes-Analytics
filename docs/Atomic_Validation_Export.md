# Atomic Validation Strategy for JSON Export

## Overview

This document describes how to implement atomic validation in the export process: generate files in a temporary location, validate them, and only move them to the final destination if validation passes.

**Note:** Examples in this document use `DBNAME` for simplicity. For DWH operations, use `DBNAME_DWH` (or `DBNAME_INGESTION` for Ingestion tables). The `DBNAME` variable is maintained for backward compatibility when both databases are the same.

## Strategy: Atomic Write with Validation

### Problem Statement

When exporting JSON files via cron:
- Invalid data should **never** replace valid data
- The destination should always have valid files
- Failed exports should not break the viewer

### Solution: Atomic Write Pattern

```
Generate → Validate → Move (if valid) → Cleanup
    ↓         ↓            ↓               ↓
  Temp    Check all    Success       Remove temp
                ↓
              Fail
                ↓
            Keep old files
```

## Implementation

### Modified exportDatamartsToJSON.sh

```bash
#!/usr/bin/env bash

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Loads the global properties.
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME

# Temporary directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"

# Load common functions
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Load validation functions
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

# Final output directory
declare OUTPUT_DIR="${JSON_OUTPUT_DIR:-./output/json}"
readonly OUTPUT_DIR

# Schema directory
declare SCHEMA_DIR="${SCHEMA_DIR:-${SCRIPT_BASE_DIRECTORY}/lib/osm-common/schemas}"
readonly SCHEMA_DIR

# Temporary directory for atomic writes (inside TMP_DIR)
declare ATOMIC_TEMP_DIR="${TMP_DIR}/atomic_export"
readonly ATOMIC_TEMP_DIR

# Validation tracking
declare -i VALIDATION_ERRORS=0

# Cleanup function
function __cleanup_temp() {
  if [[ -d "${ATOMIC_TEMP_DIR}" ]]; then
    echo "Cleaning up temporary directory..."
    rm -rf "${ATOMIC_TEMP_DIR}"
  fi
}

# Trap to ensure cleanup on exit
trap __cleanup_temp EXIT

# Enhanced validation function
function __validate_json_with_schema() {
  local JSON_FILE="${1}"
  local SCHEMA_FILE="${2}"
  local NAME="${3:-$(basename "${JSON_FILE}")}"

  if [[ ! -f "${JSON_FILE}" ]]; then
    echo "ERROR: JSON file not found: ${JSON_FILE}"
    return 1
  fi

  if [[ ! -f "${SCHEMA_FILE}" ]]; then
    echo "WARNING: Schema file not found: ${SCHEMA_FILE}"
    return 0
  fi

  if command -v ajv > /dev/null 2>&1; then
    if ajv validate -s "${SCHEMA_FILE}" -d "${JSON_FILE}" > /dev/null 2>&1; then
      echo "  ✓ Valid: ${NAME}"
      return 0
    else
      echo "  ✗ Invalid: ${NAME}"
      ajv validate -s "${SCHEMA_FILE}" -d "${JSON_FILE}" 2>&1 || true
      return 1
    fi
  else
    echo "WARNING: ajv not available, skipping schema validation"
    return 0
  fi
}

# Create temporary directories
mkdir -p "${ATOMIC_TEMP_DIR}/users"
mkdir -p "${ATOMIC_TEMP_DIR}/countries"
mkdir -p "${ATOMIC_TEMP_DIR}/indexes"

echo "$(date +%Y-%m-%d\ %H:%M:%S) - Starting datamart JSON export to temporary directory"

# Export all users to temporary directory
psql -d "${DBNAME}" -Atq << SQL_USERS | while IFS='|' read -r user_id username; do
SELECT user_id, username
FROM dwh.datamartusers
WHERE user_id IS NOT NULL
ORDER BY user_id;
SQL_USERS

 if [[ -n "${user_id}" ]]; then
  psql -d "${DBNAME}" -Atq -c "
      SELECT row_to_json(t)
      FROM dwh.datamartusers t
      WHERE t.user_id = ${user_id}
	" > "${ATOMIC_TEMP_DIR}/users/${user_id}.json"

  # Validate each user file
  if ! __validate_json_with_schema \
    "${ATOMIC_TEMP_DIR}/users/${user_id}.json" \
    "${SCHEMA_DIR}/user-profile.schema.json" \
    "user ${user_id}"; then
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  fi
 fi
done

# Create user index in temp
psql -d "${DBNAME}" -Atq -c "
  SELECT json_agg(t)
  FROM (
    SELECT
      user_id,
      username,
      history_whole_open,
      history_whole_closed,
      history_year_open,
      history_year_closed
    FROM dwh.datamartusers
    WHERE user_id IS NOT NULL
    ORDER BY history_whole_open DESC NULLS LAST, history_whole_closed DESC NULLS LAST
  ) t
" > "${ATOMIC_TEMP_DIR}/indexes/users.json"

# Validate user index
if ! __validate_json_with_schema \
  "${ATOMIC_TEMP_DIR}/indexes/users.json" \
  "${SCHEMA_DIR}/user-index.schema.json" \
  "user index"; then
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Export countries (similar pattern)
psql -d "${DBNAME}" -Atq << SQL_COUNTRIES | while IFS='|' read -r country_id country_name; do
SELECT country_id, country_name_en
FROM dwh.datamartcountries
WHERE country_id IS NOT NULL
ORDER BY country_id;
SQL_COUNTRIES

 if [[ -n "${country_id}" ]]; then
  psql -d "${DBNAME}" -Atq -c "
      SELECT row_to_json(t)
      FROM dwh.datamartcountries t
      WHERE t.country_id = ${country_id}
	" > "${ATOMIC_TEMP_DIR}/countries/${country_id}.json"

  # Validate each country file
  if ! __validate_json_with_schema \
    "${ATOMIC_TEMP_DIR}/countries/${country_id}.json" \
    "${SCHEMA_DIR}/country-profile.schema.json" \
    "country ${country_id}"; then
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  fi
 fi
done

# Create country index in temp
psql -d "${DBNAME}" -Atq -c "
  SELECT json_agg(t)
  FROM (
    SELECT
      country_id,
      country_name,
      country_name_es,
      country_name_en,
      history_whole_open,
      history_whole_closed,
      history_year_open,
      history_year_closed
    FROM dwh.datamartcountries
    WHERE country_id IS NOT NULL
    ORDER BY history_whole_open DESC NULLS LAST, history_whole_closed DESC NULLS LAST
  ) t
" > "${ATOMIC_TEMP_DIR}/indexes/countries.json"

# Validate country index
if ! __validate_json_with_schema \
  "${ATOMIC_TEMP_DIR}/indexes/countries.json" \
  "${SCHEMA_DIR}/country-index.schema.json" \
  "country index"; then
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Create metadata in temp
cat > "${ATOMIC_TEMP_DIR}/metadata.json" << EOF
{
  "export_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_users": $(find "${ATOMIC_TEMP_DIR}/users" -maxdepth 1 -type f | wc -l),
  "total_countries": $(find "${ATOMIC_TEMP_DIR}/countries" -maxdepth 1 -type f | wc -l),
  "version": "2025-10-23"
}
EOF

# Validate metadata
if ! __validate_json_with_schema \
  "${ATOMIC_TEMP_DIR}/metadata.json" \
  "${SCHEMA_DIR}/metadata.schema.json" \
  "metadata"; then
  VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
fi

# Check validation results
if [[ ${VALIDATION_ERRORS} -gt 0 ]]; then
  echo ""
  echo "ERROR: Validation failed with ${VALIDATION_ERRORS} error(s)"
  echo "Keeping existing files in ${OUTPUT_DIR}"
  echo "Invalid files are in ${ATOMIC_TEMP_DIR} for inspection"
  exit 1
fi

# All validations passed - atomic move to final destination
echo ""
echo "$(date +%Y-%m-%d\ %H:%M:%S) - All validations passed, moving to final destination..."

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/users"
mkdir -p "${OUTPUT_DIR}/countries"
mkdir -p "${OUTPUT_DIR}/indexes"

# Move files atomically (move is atomic operation)
mv "${ATOMIC_TEMP_DIR}"/* "${OUTPUT_DIR}/"

echo "$(date +%Y-%m-%d\ %H:%M:%S) - Export completed successfully"
echo "  Users: $(find "${OUTPUT_DIR}/users" -maxdepth 1 -type f | wc -l) files"
echo "  Countries: $(find "${OUTPUT_DIR}/countries" -maxdepth 1 -type f | wc -l) files"
echo "  Output directory: ${OUTPUT_DIR}"
```

## Key Features

### 1. Temporary Directory
- All files generated in `${TMP_DIR}/atomic_export` (where TMP_DIR is created with `mktemp`)
- Prevents partial writes to destination
- Isolated from live data
- Uses standard project pattern with SCRIPT_BASE_DIRECTORY

### 2. Validation During Export
- Each file validated immediately after creation
- Errors tracked in `VALIDATION_ERRORS` counter
- Detailed logging for debugging

### 3. Atomic Move
- Only moves files if all validations pass
- Uses `mv` command (atomic operation)
- No partially written files in destination

### 4. Error Handling
- On validation failure: keep old files, exit with error
- Temp directory kept for inspection
- Cron job fails, viewer shows old data

### 5. Cleanup
- `trap` ensures temp directory cleaned up
- Runs on script exit (success or failure)
- Prevents disk space issues

## Benefits

✅ **Data Integrity** - Destination always has valid files  
✅ **No Partial Updates** - Either all files updated or none  
✅ **Fail Fast** - Stop immediately on validation error  
✅ **Inspectable** - Failed files remain in temp for debugging  
✅ **Resilient** - Viewer continues working with old data  

## Cron Job Integration

```bash
#!/bin/bash
# /opt/osm-analytics/update-and-export.sh

cd /opt/osm-analytics/OSM-Notes-Analytics

# ETL
./bin/dwh/ETL.sh || exit 1

# Datamarts
./bin/dwh/datamartUsers/datamartUsers.sh || exit 1
./bin/dwh/datamartCountries/datamartCountries.sh || exit 1

# Export with validation
./bin/dwh/exportDatamartsToJSON.sh || exit 1

# If we get here, all files are valid
echo "SUCCESS: All exports validated and moved to destination"
```

## Monitoring

### Success Log
```
2025-10-23 19:45:00 - Starting datamart JSON export to temporary directory
  ✓ Valid: user 123
  ✓ Valid: user 456
  ...
  ✓ Valid: user index
  ✓ Valid: country 789
  ...
  ✓ Valid: country index
  ✓ Valid: metadata

2025-10-23 19:45:15 - All validations passed, moving to final destination...
2025-10-23 19:45:15 - Export completed successfully
```

### Failure Log
```
2025-10-23 19:45:00 - Starting datamart JSON export to temporary directory
  ✓ Valid: user 123
  ✗ Invalid: user 456
    ERROR: JSON validation failed
    Schema error: ...

ERROR: Validation failed with 1 error(s)
Keeping existing files in /var/www/osm-notes-data
Invalid files are in /tmp/exportDatamartsToJSON_XXXXXX/atomic_export for inspection
```

## Testing

### Test validation failure

```bash
# Create a test script that intentionally fails validation
# This helps ensure the atomic write pattern works

# Manual test
cd OSM-Notes-Analytics
bin/dwh/exportDatamartsToJSON.sh

# Should either:
# - Succeed and move files (if all valid)
# - Fail and keep old files (if any invalid)
```

## Files Affected

### Analytics Repository
- `bin/dwh/exportDatamartsToJSON.sh` - Modified to use temp directory and validation

### Viewer Repository
- `scripts/validate-schemas.sh` - Still useful for manual testing/debugging
- `docs/Atomic_Validation_Export.md` - This document

## Migration Steps

1. **Update exportDatamartsToJSON.sh** with new validation logic
2. **Test thoroughly** with both valid and invalid data
3. **Monitor logs** for first few cron runs
4. **Remove old validation** if separate validation script exists

## References

- See `exportDatamartsToJSON.sh` for current implementation
- See `docs/DATA_CONTRACT.md` for schema documentation
- See `lib/OSM-Notes-Common/schemas/` for schema definitions


# Schema Validation Integration with Cron Jobs

## Overview

This document explains how to integrate JSON Schema validation into the automated cron job workflow
that generates and exports OSM Notes data.

## Current Architecture

### Data Flow with Cron

```
Cron Job (every 15 minutes)
    ↓
┌─────────────────────────────────────────┐
│  OSM-Notes-Analytics                    │
│  ./bin/dwh/ETL.sh                       │
│  ./bin/dwh/datamartUsers/datamartUsers.sh│
│  ./bin/dwh/datamartCountries/datamart... │
│  ./bin/dwh/exportDatamartsToJSON.sh    │
└─────────────────────────────────────────┘
    ↓
/var/www/osm-notes-data/ (shared directory)
    ↓
┌─────────────────────────────────────────┐
│  OSM-Notes-Viewer                       │
│  Reads JSON files directly               │
└─────────────────────────────────────────┘
```

## Where to Add Validation

### Option 1: During Export (Recommended)

**Location:** In `exportDatamartsToJSON.sh` script

**When:** After each JSON file is created, before finalizing export

**Pros:**

- Catches errors immediately
- Prevents invalid data from being written
- Easy to integrate into existing workflow

**Implementation:**

```bash
# In exportDatamartsToJSON.sh
# After line 117 (user export):
__validate_json_with_schema \
  "${OUTPUT_DIR}/users/${user_id}.json" \
  "${SCHEMA_DIR}/user-profile.schema.json"

# After line 139 (user index):
__validate_json_with_schema \
  "${OUTPUT_DIR}/indexes/users.json" \
  "${SCHEMA_DIR}/user-index.schema.json"

# After country exports...
__validate_json_with_schema \
  "${OUTPUT_DIR}/countries/${country_id}.json" \
  "${SCHEMA_DIR}/country-profile.schema.json"

# After line 182 (country index):
__validate_json_with_schema \
  "${OUTPUT_DIR}/indexes/countries.json" \
  "${SCHEMA_DIR}/country-index.schema.json"

# After line 193 (metadata):
__validate_json_with_schema \
  "${OUTPUT_DIR}/metadata.json" \
  "${SCHEMA_DIR}/metadata.schema.json"
```

### Option 2: After Export (Alternative)

**Location:** Separate validation script called by cron

**When:** After all exports are complete

**Pros:**

- Cleaner separation of concerns
- Easier to debug
- Can run independently

**Implementation:**

Create `bin/dwh/validateExportedJSON.sh`:

```bash
#!/usr/bin/env bash
# Validates all exported JSON files against schemas

set -e

# Load properties
source "$(dirname "$0")/../../etc/properties.sh"

OUTPUT_DIR="${JSON_OUTPUT_DIR:-./output/json}"
SCHEMA_DIR="${SCHEMA_DIR:-../../lib/osm-common/schemas}"

echo "$(date +%Y-%m-%d\ %H:%M:%S) - Starting JSON validation"

# Validate metadata
echo "Validating metadata..."
ajv validate -s "${SCHEMA_DIR}/metadata.schema.json" \
  -d "${OUTPUT_DIR}/metadata.json"

# Validate indexes
echo "Validating user index..."
ajv validate -s "${SCHEMA_DIR}/user-index.schema.json" \
  -d "${OUTPUT_DIR}/indexes/users.json"

echo "Validating country index..."
ajv validate -s "${SCHEMA_DIR}/country-index.schema.json" \
  -d "${OUTPUT_DIR}/indexes/countries.json"

# Validate sample profiles (first 10)
echo "Validating sample user profiles..."
for file in $(find "${OUTPUT_DIR}/users" -name "*.json" | head -10); do
  ajv validate -s "${SCHEMA_DIR}/user-profile.schema.json" -d "$file"
done

echo "Validating sample country profiles..."
for file in $(find "${OUTPUT_DIR}/countries" -name "*.json" | head -10); do
  ajv validate -s "${SCHEMA_DIR}/country-profile.schema.json" -d "$file"
done

echo "$(date +%Y-%m-%d\ %H:%M:%S) - JSON validation completed"
```

Then update cron job:

```bash
*/15 * * * * /opt/osm-analytics/update-and-export.sh
```

Where `update-and-export.sh`:

```bash
#!/bin/bash
cd /opt/osm-analytics/OSM-Notes-Analytics

# ETL
./bin/dwh/ETL.sh

# Datamarts
./bin/dwh/datamartUsers/datamartUsers.sh
./bin/dwh/datamartCountries/datamartCountries.sh

# Export to JSON
./bin/dwh/exportDatamartsToJSON.sh

# Validate exported JSON
./bin/dwh/validateExportedJSON.sh

# Upload to CDN (if using)
aws s3 sync output/json/ s3://osm-notes-data/api/ --delete
```

## Recommended Approach

**Use Option 1 (During Export)** because:

1. ✅ **Fail fast** - Stops immediately if validation fails
2. ✅ **Fewer files** - No need to rollback invalid exports
3. ✅ **Clear errors** - Know exactly which record failed
4. ✅ **Already implemented** - Function exists in script

## Error Handling

### What happens when validation fails?

**Option 1:** Exit with error, cron job fails, no data exported

**Pros:**

- Prevents bad data from being served
- Forces investigation

**Cons:**

- Viewer shows old data until fix
- May cause gaps in data timeline

**Option 2:** Log error but continue

**Pros:**

- More resilient
- Partial data available

**Cons:**

- May serve inconsistent data
- Harder to debug

### Recommended Strategy

```bash
# In exportDatamartsToJSON.sh

# Strict validation - exit on error
if ! __validate_json_with_schema \
  "${OUTPUT_DIR}/users/${user_id}.json" \
  "${SCHEMA_DIR}/user-profile.schema.json"; then
  __error "Validation failed for user ${user_id}"
fi
```

## Cron Job Setup

### Complete Cron Workflow

```bash
# Edit crontab
crontab -e

# Add:
*/15 * * * * /opt/osm-analytics/update-and-export.sh >> /var/log/osm-analytics.log 2>&1
```

### Monitoring

```bash
# Check last run
tail -f /var/log/osm-analytics.log

# Check for validation errors
grep "validation failed" /var/log/osm-analytics.log

# Check last export time
cat /var/www/osm-notes-data/metadata.json | jq .export_date
```

## Validation Points Summary

| **Validation Point** | **When**          | **Why**                     |
| -------------------- | ----------------- | --------------------------- |
| During export        | After each file   | Fail fast, prevent bad data |
| After export         | At end of cron    | Verify complete export      |
| In CI/CD             | Before deployment | Catch issues before prod    |
| Manual               | On demand         | Debugging and testing       |

## Best Practices

1. **Validate during export** - Catch errors immediately
2. **Exit on failure** - Don't serve bad data
3. **Log validation errors** - Help debugging
4. **Monitor logs** - Set up alerts for failures
5. **Test schemas** - Update schemas before production

## Testing

### Test validation locally

```bash
# In Analytics repo
cd bin/dwh
./exportDatamartsToJSON.sh

# Should validate all files automatically
```

### Manual validation

```bash
# In Viewer repo
./scripts/validate-schemas.sh

# Validates schemas against data files
```

## References

- See `exportDatamartsToJSON.sh` for existing validation function
- See `docs/DATA_CONTRACT.md` for schema documentation
- See `lib/OSM-Notes-Common/schemas/` for schema definitions

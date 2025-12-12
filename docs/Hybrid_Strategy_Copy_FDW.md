# Hybrid Strategy: Database Separation

## Summary

**Implemented strategy:**
- **Initial load**: Copy base tables locally to avoid millions of cross-database queries
- **Incremental execution**: Use Foreign Data Wrappers (FDW) to access new data

**Benefits:**
- ✅ Initial load without FDW overhead (local tables)
- ✅ Incremental with FDW only for small volumes
- ✅ Better performance: ~30.5h initial, ~6-18min incremental

---

## Implementation

### Created Files

**Scripts:**
- `bin/dwh/copyBaseTables.sh` - Copies base tables for initial load
- `bin/dwh/dropCopiedBaseTables.sh` - Drops copied tables after load
- `sql/dwh/ETL_60_setupFDW.sql` - Configures FDW for incremental

**Tests:**
- `tests/unit/bash/hybrid_strategy_copy_fdw.test.bats`

### How It Works

**Initial load (first execution):**
```
1. ETL.sh detects first execution
   ↓
2. copyBaseTables.sh copies tables: notes, note_comments, note_comments_text, users, countries
   ↓
3. ETL processes data (local tables, no FDW)
   ↓
4. dropCopiedBaseTables.sh drops copied tables
```

**Incremental execution:**
```
1. ETL.sh detects incremental execution
   ↓
2. ETL_60_setupFDW.sql configures FDW (if not exists)
   ↓
3. ETL processes new data using foreign tables
```

---

## Configuration

### Variables in `etc/properties.sh`

```bash
# If using separate DBs
DBNAME_INGESTION="osm_notes"
DBNAME_DWH="osm_notes_dwh"
DB_USER_INGESTION="ingestion_user"
DB_USER_DWH="analytics_user"

# FDW configuration (for incremental)
FDW_INGESTION_HOST="localhost"
FDW_INGESTION_DBNAME="osm_notes"
FDW_INGESTION_PORT="5432"
FDW_INGESTION_USER="analytics_readonly"
FDW_INGESTION_PASSWORD=""  # Use .pgpass or environment variable
```

### Create Read-Only User for FDW

```sql
-- In Ingestion DB
CREATE USER analytics_readonly WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE osm_notes TO analytics_readonly;
GRANT USAGE ON SCHEMA public TO analytics_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analytics_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO analytics_readonly;
```

---

## Usage

### First Execution (Initial Load)

```bash
./bin/dwh/ETL.sh
```

Auto-detects first execution and:
1. Copies base tables from Ingestion to Analytics
2. Populates DWH using local tables (no FDW)
3. Drops copied tables after completion

### Subsequent Executions (Incremental)

```bash
./bin/dwh/ETL.sh
```

Auto-detects incremental execution and:
1. Configures FDW (if not exists)
2. Processes new data using foreign tables

---

## Troubleshooting

### Error: "Cannot connect to source database"

**Solution:** Verify `DBNAME_INGESTION` and `DB_USER_INGESTION` variables in `etc/properties.sh`

### Error: "Failed to setup Foreign Data Wrappers"

**Solution:**
- Verify that `analytics_readonly` user exists in Ingestion DB
- Verify read permissions
- Verify `FDW_INGESTION_*` variables in `etc/properties.sh`

### Error: "Table already exists in target database"

**Solution:** The script handles this automatically (drops and recreates). If it persists:
```bash
psql -d osm_notes_dwh -c "DROP TABLE IF EXISTS public.notes, public.note_comments, public.note_comments_text, public.users, public.countries CASCADE;"
```

---

## Testing

```bash
# Hybrid strategy tests
bats tests/unit/bash/hybrid_strategy_copy_fdw.test.bats

# All tests
./tests/run_all_tests.sh
```

---

## Technical Details

### Copy Method

The `copyBaseTables.sh` script uses **COPY with piping** (fastest method):

```bash
psql -d "${INGESTION_DB}" -c "\COPY public.notes TO STDOUT" | \
psql -d "${ANALYTICS_DB}" -c "\COPY public.notes FROM STDIN"
```

**Estimated performance:**
- notes: ~1-5 minutes
- note_comments: ~5-20 minutes
- note_comments_text: ~2-10 minutes
- users: ~10-30 seconds
- countries: ~1-5 seconds
- **Total: 10-40 minutes** for all tables

### Foreign Data Wrappers

The `ETL_60_setupFDW.sql` script configures:
- Foreign server pointing to Ingestion DB
- Foreign tables: `notes`, `note_comments`, `note_comments_text`, `users`, `countries`
- Optimizations: `fetch_size='10000'`, `use_remote_estimate='true'`

**Estimated overhead:** 15-25% on incremental queries (acceptable for small volumes)

---

## Status

✅ **Implemented and ready to use**

The strategy is fully integrated in `ETL.sh` and runs automatically based on detected mode.

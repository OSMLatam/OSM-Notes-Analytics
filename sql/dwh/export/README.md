# CSV Export Optimization

## Overview

This directory contains optimized SQL queries and indexes for exporting closed notes to CSV files by country. The export process has been significantly optimized to reduce execution time, especially for countries with large numbers of closed notes.

## Files

- `exportClosedNotesByCountry.sql` - Optimized SQL query for exporting closed notes
- `export_optimize_indexes.sql` - Specialized indexes for export performance

## Performance Optimizations

### SQL Query Optimizations (exportClosedNotesByCountry.sql)

#### 1. Eliminated Correlated Subqueries
**Before**: Subqueries executed for each row:
```sql
-- Slow: Executes once per row
(SELECT COUNT(*) FROM dwh.facts WHERE id_note = closed_fact.id_note ...) AS total_comments
```

**After**: Pre-aggregated using GROUP BY:
```sql
-- Fast: Single aggregation pass
note_metrics AS (
  SELECT id_note, COUNT(*) AS total_comments, ...
  FROM dwh.facts GROUP BY id_note
)
```

**Impact**: Reduces query time from O(n²) to O(n) for countries with many notes.

#### 2. Removed Duplicate Logic
**Before**: Latest close logic duplicated in CTE and main query.

**After**: Single `latest_closes` CTE used throughout.

**Impact**: Eliminates redundant work and improves query planner efficiency.

#### 3. Optimized FDW JOINs with LATERAL
**Before**: Subqueries with DISTINCT ON for opening/closing comments.

**After**: LATERAL JOINs that push filters down to FDW queries:
```sql
LEFT JOIN LATERAL (
  SELECT nct.body
  FROM public.note_comments nc
  WHERE nc.note_id = lc.id_note AND nc.event = 'opened'
  ORDER BY nc.sequence_action ASC
  LIMIT 1
) opening_comment ON TRUE
```

**Impact**: Reduces network round-trips to Ingestion DB and improves query planning.

#### 4. Created Helper Function
**Before**: Inline REGEXP_REPLACE operations repeated multiple times.

**After**: Reusable `dwh.clean_comment_for_csv()` function marked as IMMUTABLE.

**Impact**: Allows PostgreSQL to optimize and cache the function.

### Index Optimizations (export_optimize_indexes.sql)

#### Index 1: `idx_facts_export_latest_close`
```sql
CREATE INDEX ON dwh.facts(id_note, fact_id DESC)
WHERE action_comment = 'closed';
```
**Purpose**: Optimizes `DISTINCT ON (id_note) ... ORDER BY id_note, fact_id DESC` in `latest_closes` CTE.

#### Index 2: `idx_facts_export_country_latest_close`
```sql
CREATE INDEX ON dwh.facts(dimension_id_country, id_note, fact_id DESC)
WHERE action_comment = 'closed';
```
**Purpose**: Optimizes country-filtered latest close queries (most common pattern).

#### Index 3: `idx_facts_export_note_metrics`
```sql
CREATE INDEX ON dwh.facts(id_note, action_comment)
INCLUDE (fact_id)
WHERE action_comment IN ('commented', 'opened', 'closed', 'reopened');
```
**Purpose**: Optimizes comment counting and reopen detection aggregations.

## Usage

### 1. Create Indexes (One-time Setup)

Run the index creation script:
```bash
psql -d "${DBNAME_DWH}" -f sql/dwh/export/export_optimize_indexes.sql
```

**Note**: These indexes are complementary to existing indexes and safe to create in production.

### 2. Run Export Script

The export script (`bin/dwh/exportAndPushCSVToGitHub.sh`) automatically uses the optimized SQL:
```bash
./bin/dwh/exportAndPushCSVToGitHub.sh
```

### 3. Monitor Performance

Check index usage:
```sql
SELECT * FROM dwh.v_export_index_performance;
```

Or use the monitoring function:
```sql
SELECT * FROM dwh.monitor_export_index_usage();
```

## Performance Monitoring

The export script now includes detailed timing information:

```
ℹ Exporting notes for country: 대한민국 (ID: 307756)
ℹ   Exported 15234 notes in 45s
✓ Export completed: 150 countries, 1234567 total notes
ℹ Export timing: 2345s (countries: 150, avg: 15s per country)
ℹ Step 1 total time: 2400s
```

### Timing Breakdown

- **Per-country export time**: Shows time for each country export
- **Total export time**: Sum of all country exports
- **Average time per country**: Helps identify if specific countries are slow
- **Step timing**: Breakdown by major steps (Export, Copy, Git Push)

## Expected Performance Improvements

### Before Optimization
- **Large countries** (10K+ notes): 5-15 minutes per country
- **Medium countries** (1K-10K notes): 30 seconds - 2 minutes per country
- **Small countries** (<1K notes): 5-30 seconds per country

### After Optimization
- **Large countries** (10K+ notes): 1-3 minutes per country (60-80% faster)
- **Medium countries** (1K-10K notes): 10-30 seconds per country (50-70% faster)
- **Small countries** (<1K notes): 2-10 seconds per country (40-60% faster)

**Note**: Actual performance depends on:
- Database hardware and configuration
- Network latency to Ingestion DB (if using FDW)
- Number of notes per country
- System load

## Troubleshooting

### Slow Export for Specific Countries

1. **Check query plan**:
   ```sql
   EXPLAIN ANALYZE
   -- Replace :country_id with actual ID
   -- Run the query from exportClosedNotesByCountry.sql
   ```

2. **Verify indexes are being used**:
   ```sql
   SELECT * FROM dwh.v_export_index_performance;
   ```
   Look for `index_scans > 0` to confirm indexes are used.

3. **Check FDW performance** (if using FDW):
   ```sql
   -- Test FDW query directly
   SELECT COUNT(*) FROM public.note_comments WHERE event = 'opened';
   ```

### Indexes Not Being Used

1. **Update statistics**:
   ```sql
   ANALYZE dwh.facts;
   ```

2. **Check index exists**:
   ```sql
   SELECT indexname FROM pg_indexes 
   WHERE schemaname = 'dwh' 
   AND indexname LIKE 'idx_facts_export%';
   ```

3. **Force index usage** (temporary, for testing):
   ```sql
   SET enable_seqscan = off;
   -- Run query
   SET enable_seqscan = on;
   ```

## Additional Optimizations (Future)

### Ingestion Database Indexes

For optimal FDW performance, create these indexes in the **Ingestion database**:

```sql
-- Opening comments
CREATE INDEX idx_note_comments_opened 
  ON public.note_comments(note_id, sequence_action)
  WHERE event = 'opened';

CREATE INDEX idx_note_comments_text_opened
  ON public.note_comments_text(note_id, sequence_action);

-- Closing comments  
CREATE INDEX idx_note_comments_closed
  ON public.note_comments(note_id, sequence_action DESC)
  WHERE event = 'closed';

CREATE INDEX idx_note_comments_text_closed
  ON public.note_comments_text(note_id, sequence_action DESC);
```

**Note**: These indexes are in the Ingestion database, not the DWH database.

## Version History

- **2026-01-17**: Initial optimization
  - Eliminated correlated subqueries
  - Added LATERAL JOINs for FDW optimization
  - Created specialized indexes
  - Added performance monitoring

## Related Documentation

- `bin/dwh/exportAndPushCSVToGitHub.sh` - Export script with timing
- `docs/PERFORMANCE_BASELINES.md` - Performance benchmarks
- `sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql` - Base indexes

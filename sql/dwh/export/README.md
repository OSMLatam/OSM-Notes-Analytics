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

#### 5. Limited Export Size for AI Context
**New**: Export limited to most recent notes (configurable, default: 400,000 notes per country).

**Rationale**:
- **GitHub file size limit**: 100 MB per file
- **Germany example**: 609,147 notes = 143 MB (exceeds limit)
- **400K notes estimate**: ~94 MB (under limit)
- **AI context needs**: Recent notes are more valuable than very old historical data
  - Recent patterns reflect current resolution strategies
  - Old notes may contain outdated patterns
  - 400K notes provide sufficient diversity for AI training

**Impact**: 
- Keeps files under GitHub's 100MB limit
- Faster exports (less data to process)
- More relevant data for AI context (recent patterns)

## Configuration

### Maximum Notes Per Country

The export can be limited using the `MAX_NOTES_PER_COUNTRY` environment variable:

```bash
# Export maximum 400K notes per country (default)
export MAX_NOTES_PER_COUNTRY=400000
./bin/dwh/exportAndPushCSVToGitHub.sh

# Export maximum 200K notes per country (smaller files)
export MAX_NOTES_PER_COUNTRY=200000
./bin/dwh/exportAndPushCSVToGitHub.sh

# Export maximum 500K notes per country (closer to limit)
export MAX_NOTES_PER_COUNTRY=500000
./bin/dwh/exportAndPushCSVToGitHub.sh
```

### Size Estimation

Based on Germany's data:
- **609,147 notes** = **143 MB**
- **Average per note**: ~245 bytes
- **400K notes estimate**: ~98 MB (under 100MB limit)
- **500K notes estimate**: ~122 MB (exceeds limit)

**Recommendation**: Use 400K as default to stay safely under GitHub's limit while providing sufficient context for AI.

## AI Context Considerations

### How Many Notes Are Needed?

For AI context on how to resolve notes in a country, you need:

1. **Diversity of patterns** (different types of issues, resolutions)
2. **Recent patterns** (current resolution strategies)
3. **Sufficient examples** (to learn common patterns)

**Analysis**:
- **10K-50K notes**: Good for basic patterns, but may miss edge cases
- **100K-200K notes**: Good coverage of common patterns
- **300K-400K notes**: Excellent coverage including edge cases
- **500K+ notes**: Diminishing returns, very old data may be less relevant

**Recommendation**: **400K notes** provides:
- ✅ Excellent pattern coverage
- ✅ Recent data (prioritized by `ORDER BY action_at DESC`)
- ✅ Under GitHub's 100MB limit
- ✅ Fast export times

### What Makes Good AI Context?

The exported CSV includes:
- **Opening comments**: What problems were reported
- **Closing comments**: How they were resolved
- **Resolution time**: How long it took
- **Comment patterns**: Number of comments, reopen status
- **User patterns**: Who opened/closed notes

This provides sufficient context for AI to learn:
- Common problem types in a country
- Effective resolution strategies
- Typical resolution timelines
- Communication patterns

## Usage

```bash
# Export with default limit (400K notes per country)
./bin/dwh/exportAndPushCSVToGitHub.sh

# Export with custom limit
MAX_NOTES_PER_COUNTRY=300000 ./bin/dwh/exportAndPushCSVToGitHub.sh
```

## Indexes

See `export_optimize_indexes.sql` for specialized indexes that improve export performance.

## Troubleshooting

### Large Files Still Exceeding 100MB

If a country still exceeds 100MB with 400K notes:
1. Reduce `MAX_NOTES_PER_COUNTRY` to 300K or 200K
2. Check if comments are unusually long (may need additional filtering)
3. Consider excluding very old notes (e.g., only last 5 years)

### Export Too Slow

1. Ensure indexes from `export_optimize_indexes.sql` are created
2. Check if FDW connection is slow (consider direct connection optimization)
3. Verify partition pruning is working (check `EXPLAIN ANALYZE`)

### Missing Recent Notes

The export prioritizes most recent notes (`ORDER BY action_at DESC`). If you need older notes:
1. Increase `MAX_NOTES_PER_COUNTRY`
2. Or modify SQL to use different ordering (e.g., random sampling)

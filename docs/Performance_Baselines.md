---
title: "Query Performance Baselines"
description: "The data warehouse is optimized for analytics queries through:"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "performance"
audience:
  - "developers"
project: "OSM-Notes-Analytics"
status: "active"
---

# Query Performance Baselines

This document provides performance baselines and expectations for common queries against the OSM
Notes Analytics data warehouse. Use these baselines to understand what to expect when querying
datamarts and the star schema.

## Overview

The data warehouse is optimized for analytics queries through:

- **Pre-computed datamarts**: Fast lookups for country and user metrics
- **Star schema**: Efficient joins between facts and dimensions
- **Incremental updates**: Only modified data is recalculated
- **Indexes**: Optimized for common query patterns

## Performance Factors

### Data Volume Assumptions

These baselines assume:

- **Facts table**: ~10-50 million rows (typical production size)
- **DatamartCountries**: ~200-250 countries
- **DatamartUsers**: ~10,000-100,000 active users
- **DatamartGlobal**: 1 row (aggregate statistics)

### Hardware Assumptions

- **CPU**: 4+ cores
- **RAM**: 8GB+ available for PostgreSQL
- **Storage**: SSD (not HDD)
- **PostgreSQL version**: 12+ with default configuration

## Query Categories

### 1. Simple Datamart Queries

**Pattern**: Direct SELECT from pre-computed datamarts

#### 1.1 Single Row Lookup (by ID)

```sql
-- Country profile lookup
SELECT * FROM dwh.datamartcountries
WHERE dimension_country_id = 42;
```

**Expected Time**: < 10ms  
**Why**: Primary key lookup, single row, all columns pre-computed

#### 1.2 Single Row Lookup (by Name)

```sql
-- Country profile by name
SELECT * FROM dwh.datamartcountries
WHERE country_name_en = 'Colombia';
```

**Expected Time**: < 50ms  
**Why**: Index on country_name_en, single row result

#### 1.3 User Profile Lookup

```sql
-- User profile by dimension ID
SELECT * FROM dwh.datamartusers
WHERE dimension_user_id = 1234;
```

**Expected Time**: < 10ms  
**Why**: Primary key lookup, single row

#### 1.4 User Profile by OSM User ID

```sql
-- User profile by OSM user_id
SELECT * FROM dwh.datamartusers
WHERE user_id = 567890;
```

**Expected Time**: < 50ms  
**Why**: Index on user_id, single row result

#### 1.5 Global Statistics

```sql
-- Global statistics (single row)
SELECT * FROM dwh.datamartglobal
WHERE dimension_global_id = 1;
```

**Expected Time**: < 10ms  
**Why**: Single row, primary key lookup

---

### 2. Filtered Queries

**Pattern**: Queries with WHERE clauses and filters

#### 2.1 Country Filtering by Activity

```sql
-- Countries with high activity
SELECT country_name_en, history_whole_open, history_whole_closed
FROM dwh.datamartcountries
WHERE history_whole_open > 10000
ORDER BY history_whole_open DESC;
```

**Expected Time**: 50-200ms  
**Why**: Sequential scan with filter, sorting required

#### 2.2 User Filtering by Activity

```sql
-- Active users (opened 100+ notes)
SELECT username, history_whole_open, history_whole_closed
FROM dwh.datamartusers
WHERE history_whole_open >= 100
ORDER BY history_whole_open DESC
LIMIT 100;
```

**Expected Time**: 100-500ms  
**Why**: Sequential scan, sorting, limit applied

#### 2.3 Date Range Filtering

```sql
-- Countries with recent activity
SELECT country_name_en, notes_created_last_30_days
FROM dwh.datamartcountries
WHERE notes_created_last_30_days > 0
ORDER BY notes_created_last_30_days DESC;
```

**Expected Time**: 50-200ms  
**Why**: Sequential scan, simple filter

---

### 3. Aggregation Queries

**Pattern**: COUNT, SUM, AVG, MIN, MAX across datamarts

#### 3.1 Count Records

```sql
-- Total countries in datamart
SELECT COUNT(*) FROM dwh.datamartcountries;
```

**Expected Time**: < 50ms  
**Why**: Fast count on indexed table (~200-250 rows)

#### 3.2 Count with Filter

```sql
-- Active countries (with notes)
SELECT COUNT(*) FROM dwh.datamartcountries
WHERE history_whole_open > 0;
```

**Expected Time**: < 100ms  
**Why**: Sequential scan with filter

#### 3.3 Sum Aggregations

```sql
-- Total notes opened globally (sum from countries)
SELECT SUM(history_whole_open) as total_opened
FROM dwh.datamartcountries;
```

**Expected Time**: 50-150ms  
**Why**: Sequential scan, sum calculation

#### 3.4 Average Calculations

```sql
-- Average notes per country
SELECT AVG(history_whole_open) as avg_notes_per_country
FROM dwh.datamartcountries
WHERE history_whole_open > 0;
```

**Expected Time**: 50-150ms  
**Why**: Sequential scan, average calculation

---

### 4. Ranking and Top N Queries

**Pattern**: ORDER BY with LIMIT

#### 4.1 Top Countries by Activity

```sql
-- Top 10 countries by notes opened
SELECT country_name_en, history_whole_open
FROM dwh.datamartcountries
ORDER BY history_whole_open DESC
LIMIT 10;
```

**Expected Time**: 50-200ms  
**Why**: Sequential scan, sorting, limit

#### 4.2 Top Users by Activity

```sql
-- Top 20 users by notes opened
SELECT username, history_whole_open
FROM dwh.datamartusers
ORDER BY history_whole_open DESC
LIMIT 20;
```

**Expected Time**: 200-1000ms  
**Why**: Sequential scan on larger table, sorting

#### 4.3 Top Countries by Resolution Rate

```sql
-- Top countries by resolution rate
SELECT country_name_en, resolution_rate
FROM dwh.datamartcountries
WHERE history_whole_open > 100
ORDER BY resolution_rate DESC
LIMIT 10;
```

**Expected Time**: 100-300ms  
**Why**: Sequential scan, filter, sort

---

### 5. JSON Field Queries

**Pattern**: Extracting data from JSON columns

#### 5.1 Extract JSON Array

```sql
-- Get hashtags for a country
SELECT country_name_en, hashtags
FROM dwh.datamartcountries
WHERE dimension_country_id = 42;
```

**Expected Time**: < 10ms  
**Why**: Primary key lookup, JSON stored as text

#### 5.2 JSON Aggregation

```sql
-- Get application usage trends (JSON)
SELECT country_name_en, application_usage_trends
FROM dwh.datamartcountries
WHERE dimension_country_id = 42;
```

**Expected Time**: < 10ms  
**Why**: Primary key lookup

#### 5.3 JSON Array Length

```sql
-- Count hashtags per country
SELECT
  country_name_en,
  json_array_length(hashtags) as hashtag_count
FROM dwh.datamartcountries
WHERE hashtags IS NOT NULL;
```

**Expected Time**: 100-300ms  
**Why**: Sequential scan, JSON parsing for each row

---

### 6. Star Schema Queries (Facts Table)

**Pattern**: Queries against `dwh.facts` with joins to dimensions

#### 6.1 Simple Facts Query

```sql
-- Notes opened in last 30 days
SELECT COUNT(*)
FROM dwh.facts
WHERE action_comment = 'opened'
  AND action_at >= CURRENT_DATE - INTERVAL '30 days';
```

**Expected Time**: 500ms - 2s  
**Why**: Large table scan, date filter, no pre-computation

**Optimization Tip**: Use `datamartGlobal.notes_created_last_30_days` instead (10ms)

#### 6.2 Facts with Dimension Join

```sql
-- Notes by country (join to dimension)
SELECT
  dc.country_name_en,
  COUNT(*) as note_count
FROM dwh.facts f
JOIN dwh.dimension_countries dc ON f.dimension_id_country = dc.dimension_country_id
WHERE f.action_comment = 'opened'
GROUP BY dc.country_name_en
ORDER BY note_count DESC
LIMIT 10;
```

**Expected Time**: 2-10s  
**Why**: Large table scan, join, group by, sort

**Optimization Tip**: Use `datamartCountries` instead (50-200ms)

#### 6.3 Facts with Multiple Joins

```sql
-- User activity by country
SELECT
  dc.country_name_en,
  du.username,
  COUNT(*) as action_count
FROM dwh.facts f
JOIN dwh.dimension_countries dc ON f.dimension_id_country = dc.dimension_country_id
JOIN dwh.dimension_users du ON f.dimension_id_user = du.dimension_user_id
WHERE f.action_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY dc.country_name_en, du.username
ORDER BY action_count DESC
LIMIT 20;
```

**Expected Time**: 5-20s  
**Why**: Large table scan, multiple joins, group by, sort

**Optimization Tip**: Pre-aggregate in datamarts or use materialized views

#### 6.4 Complex Facts Query with Aggregations

```sql
-- Resolution time analysis
SELECT
  AVG(days_to_resolution) as avg_resolution_days,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_resolution) as median_resolution_days
FROM dwh.facts
WHERE action_comment = 'closed'
  AND days_to_resolution IS NOT NULL
  AND action_at >= CURRENT_DATE - INTERVAL '1 year';
```

**Expected Time**: 3-15s  
**Why**: Large table scan, filter, aggregation, percentile calculation

---

### 7. Time-Series Queries

**Pattern**: Temporal analysis queries

#### 7.1 Monthly Activity Trends

```sql
-- Monthly activity from datamart (pre-computed JSON)
SELECT
  country_name_en,
  activity_by_month
FROM dwh.datamartcountries
WHERE dimension_country_id = 42;
```

**Expected Time**: < 10ms  
**Why**: Primary key lookup, JSON already computed

#### 7.2 Yearly Breakdown

```sql
-- Yearly activity from datamart
SELECT
  country_name_en,
  activity_by_year
FROM dwh.datamartcountries
WHERE dimension_country_id = 42;
```

**Expected Time**: < 10ms  
**Why**: Primary key lookup

#### 7.3 Time-Series from Facts (Not Recommended)

```sql
-- Monthly activity from facts (slower)
SELECT
  DATE_TRUNC('month', action_at) as month,
  COUNT(*) as action_count
FROM dwh.facts
WHERE dimension_id_country = 42
  AND action_at >= CURRENT_DATE - INTERVAL '2 years'
GROUP BY DATE_TRUNC('month', action_at)
ORDER BY month;
```

**Expected Time**: 2-10s  
**Why**: Large table scan, date truncation, group by

**Optimization Tip**: Use `datamartCountries.activity_by_month` JSON field instead

---

### 8. Cross-Datamart Queries

**Pattern**: Joining or comparing multiple datamarts

#### 8.1 Country-User Comparison

```sql
-- Compare country totals with user totals (validation query)
SELECT
  (SELECT SUM(history_whole_open) FROM dwh.datamartcountries) as country_total,
  (SELECT SUM(history_whole_open) FROM dwh.datamartusers) as user_total;
```

**Expected Time**: 200-500ms  
**Why**: Two sequential scans, subqueries

#### 8.2 User Activity by Country

```sql
-- Users active in specific country (requires facts table)
SELECT
  du.username,
  COUNT(DISTINCT f.id_note) as notes_in_country
FROM dwh.facts f
JOIN dwh.dimension_users du ON f.dimension_id_user = du.dimension_user_id
WHERE f.dimension_id_country = 42
GROUP BY du.username
ORDER BY notes_in_country DESC
LIMIT 20;
```

**Expected Time**: 3-15s  
**Why**: Large table scan, join, group by

**Optimization Tip**: Use `datamartCountries.users_open_notes` JSON field (pre-computed)

---

## Performance Optimization Tips

### 1. Use Datamarts Instead of Facts

**❌ Slow Query:**

```sql
SELECT COUNT(*) FROM dwh.facts WHERE action_comment = 'opened';
-- Expected: 2-10s
```

**✅ Fast Query:**

```sql
SELECT SUM(history_whole_open) FROM dwh.datamartcountries;
-- Expected: 50-150ms
```

### 2. Use Pre-Computed JSON Fields

**❌ Slow Query:**

```sql
SELECT DATE_TRUNC('month', action_at), COUNT(*)
FROM dwh.facts
WHERE dimension_id_country = 42
GROUP BY DATE_TRUNC('month', action_at);
-- Expected: 2-10s
```

**✅ Fast Query:**

```sql
SELECT activity_by_month FROM dwh.datamartcountries
WHERE dimension_country_id = 42;
-- Expected: < 10ms
```

### 3. Add LIMIT to Ranking Queries

**❌ Slower:**

```sql
SELECT * FROM dwh.datamartusers ORDER BY history_whole_open DESC;
-- Returns all rows, then sorts
```

**✅ Faster:**

```sql
SELECT * FROM dwh.datamartusers
ORDER BY history_whole_open DESC LIMIT 10;
-- Sorts only what's needed
```

### 4. Use Indexed Columns

Queries on these columns are faster:

- `dimension_country_id` (primary key)
- `dimension_user_id` (primary key)
- `user_id` (indexed)
- `country_name_en` (indexed)
- `iso_alpha2`, `iso_alpha3` (indexed)

### 5. Avoid Full Table Scans on Facts

The `dwh.facts` table is large. Always:

- Use date filters: `WHERE action_at >= ...`
- Use action filters: `WHERE action_comment = 'opened'`
- Consider using datamarts instead

### 6. Use EXPLAIN ANALYZE

To understand query performance:

```sql
EXPLAIN ANALYZE
SELECT * FROM dwh.datamartcountries
WHERE history_whole_open > 10000;
```

This shows:

- Execution plan
- Actual execution time
- Index usage
- Sequential scans

---

## Performance Monitoring

### Check Query Performance

```sql
-- Find slow queries
SELECT
  pid,
  now() - pg_stat_activity.query_start AS duration,
  query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 seconds'
  AND state = 'active';
```

### Check Table Sizes

```sql
-- Table sizes
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'dwh'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Check Index Usage

```sql
-- Index usage statistics
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'dwh'
ORDER BY idx_scan DESC;
```

---

## Expected Performance Summary

| Query Type                 | Expected Time   | Optimization                |
| -------------------------- | --------------- | --------------------------- |
| Single row datamart lookup | < 10ms          | Use primary key             |
| Filtered datamart query    | 50-200ms        | Add indexes if needed       |
| Top N ranking              | 100-500ms       | Use LIMIT                   |
| Aggregation (datamart)     | 50-200ms        | Pre-computed                |
| Simple facts query         | 500ms-2s        | Use datamarts instead       |
| Facts with joins           | 2-10s           | Use datamarts instead       |
| Complex facts query        | 5-20s           | Consider materialized views |
| JSON extraction            | < 10ms (single) | Pre-computed JSON           |
| JSON parsing (all rows)    | 100-300ms       | Acceptable for small tables |

---

## When to Use Each Approach

### Use Datamarts When:

- ✅ You need country-level or user-level aggregates
- ✅ You need pre-computed metrics (resolution rates, health scores)
- ✅ You need temporal patterns (monthly/yearly activity)
- ✅ You need JSON aggregations (hashtags, applications)
- ✅ **Performance is critical** (< 200ms expected)

### Use Facts Table When:

- ⚠️ You need note-level detail
- ⚠️ You need custom date ranges not in datamarts
- ⚠️ You need complex cross-dimensional analysis
- ⚠️ You need real-time data (datamarts update incrementally)
- ⚠️ **Performance is acceptable** (2-20s expected)

### Use Materialized Views When:

- 💡 You need frequently-run complex queries
- 💡 You need cross-datamart aggregations
- 💡 You need custom time ranges
- 💡 **Performance must be < 1s for complex queries**

---

## Troubleshooting Slow Queries

### Query is Slower Than Expected

1. **Check if datamart exists**: Use datamarts instead of facts when possible
2. **Check indexes**: Use `EXPLAIN ANALYZE` to see if indexes are used
3. **Check table size**: Large tables need more time
4. **Check filters**: Add date/action filters to reduce scan size
5. **Check for locks**: Other queries might be blocking

### Query Times Out

1. **Add LIMIT**: Reduce result set size
2. **Add filters**: Reduce scan size
3. **Use datamarts**: Pre-computed data is faster
4. **Check hardware**: Insufficient RAM/CPU can cause timeouts
5. **Check for missing indexes**: Add indexes on frequently filtered columns

---

## Best Practices

1. **Always prefer datamarts** for country/user-level queries
2. **Use LIMIT** for ranking queries
3. **Filter early** with WHERE clauses
4. **Use EXPLAIN ANALYZE** to understand query plans
5. **Monitor slow queries** regularly
6. **Add indexes** for frequently filtered columns
7. **Consider materialized views** for complex repeated queries
8. **Update datamarts regularly** to keep data fresh

---

## Related Documentation

- [Metric Definitions](Metric_Definitions.md) - Complete list of available metrics
- [DWH Star Schema Data Dictionary](DWH_Star_Schema_Data_Dictionary.md) - Schema details
- [Testing Guide](Testing_Guide.md) - How to test query performance
- [Troubleshooting Guide](Troubleshooting_Guide.md) - Common issues and solutions

---

**Last Updated**: 2025-12-14  
**Version**: 1.0

# Global Datamart

The global datamart provides worldwide statistics for OSM notes, aggregated across all countries and users.

## Overview

Unlike `datamartCountries` and `datamartUsers` which provide statistics filtered by country or user respectively, the global datamart provides aggregate statistics for the entire OSM notes database.

The global datamart contains a single record (dimension_global_id = 1) with aggregated metrics including:

- Total notes opened, closed, commented, and reopened
- Currently open notes
- Notes statistics for current year
- Average and median resolution times
- Resolution rates
- Active user counts
- Application usage statistics
- Comment metrics
- Age distribution of notes

## Usage

### Population

The global datamart is automatically populated during the ETL process:

```bash
bin/dwh/ETL.sh
```

Or run it manually:

```bash
bin/dwh/datamartGlobal/datamartGlobal.sh
```

### Export to JSON

The global datamart is exported to JSON during the export process:

```bash
bin/dwh/exportDatamartsToJSON.sh
```

This creates two files:

- `output/json/global_stats.json` - Complete datamart data
- `output/json/global_stats_summary.json` - Simplified version with key metrics

### Viewing the Data

Query the global datamart directly:

```sql
SELECT *
FROM dwh.datamartglobal
WHERE dimension_global_id = 1;
```

Or view specific statistics:

```sql
SELECT
  currently_open_count,
  history_whole_open,
  history_whole_closed,
  avg_days_to_resolution,
  resolution_rate
FROM dwh.datamartglobal
WHERE dimension_global_id = 1;
```

## Key Metrics

### Current Status
- `currently_open_count` - Notes currently open
- `currently_closed_count` - Notes currently closed
- `notes_created_last_30_days` - Notes created in last 30 days
- `notes_resolved_last_30_days` - Notes resolved in last 30 days
- `notes_backlog_size` - Open notes older than 7 days

### Historical Totals
- `history_whole_open` - Total opened notes in history
- `history_whole_closed` - Total closed notes in history
- `history_whole_reopened` - Total reopened notes in history
- `history_whole_commented` - Total commented notes in history

### Current Year
- `history_year_open` - Notes opened this year
- `history_year_closed` - Notes closed this year
- `history_year_reopened` - Notes reopened this year

### Resolution Metrics
- `avg_days_to_resolution` - Average days to resolve (all time)
- `median_days_to_resolution` - Median days to resolve (all time)
- `avg_days_to_resolution_current_year` - Average days for notes created this year
- `median_days_to_resolution_current_year` - Median days for notes created this year
- `resolution_rate` - Percentage of notes resolved

### Additional Metrics
- `active_users_count` - Users active in last 30 days
- `top_countries` - Top countries by activity (JSON)
- `applications_used` - Most used applications (JSON)
- `notes_age_distribution` - Distribution of note ages (JSON)
- `avg_comments_per_note` - Average comments per note
- `comments_with_url_pct` - Percentage of comments with URLs
- `comments_with_mention_pct` - Percentage of comments with mentions

## Files

- `datamartGlobal_11_checkTables.sql` - Verifies table exists
- `datamartGlobal_12_createTable.sql` - Creates the table structure
- `datamartGlobal_31_populate.sql` - Populates the datamart with statistics

## Integration

The global datamart is integrated into the main ETL process in `bin/dwh/ETL.sh` and is exported automatically during JSON export.

## Author

Andres Gomez (AngocA)
OSM-LatAm, OSM-Colombia, MaptimeBogota.



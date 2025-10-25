# Execution Guide - OSM Notes Analytics

Complete guide for executing all components of the OSM Notes Analytics system.

## 📋 Table of Contents

- [Overview](#overview)
- [ETL Process](#etl-process)
- [Profile Generation](#profile-generation)
- [Datamart Management](#datamart-management)
- [Utility Scripts](#utility-scripts)
- [Environment Variables](#environment-variables)
- [Troubleshooting](#troubleshooting)

---

## Overview

The OSM Notes Analytics system consists of several components:

| Component | Script | Purpose |
|-----------|--------|---------|
| **ETL** | `bin/dwh/ETL.sh` | Transform raw notes into star schema DWH |
| **Profiles** | `bin/dwh/profile.sh` | Generate user/country profiles |
| **Datamarts** | `bin/dwh/datamart*/datamart*.sh` | Pre-compute aggregations |
| **Export** | `bin/dwh/exportDatamartsToJSON.sh` | Export to JSON for web viewer |
| **Cleanup** | `bin/dwh/cleanupDWH.sh` | Remove DWH objects |

---

## ETL Process

The ETL process transforms OSM notes from base tables into a star schema data warehouse.

### Quick Start

#### Initial Load (First Time Setup)

```bash
# Complete initial load with all data
./bin/dwh/ETL.sh
```

This will:
1. Create DWH schema and tables
2. Create partitions for facts table
3. Populate dimension tables
4. Load all facts from base tables
5. Create indexes and constraints
6. Update datamarts

**Expected Duration**: Several hours (depends on data volume)

#### Incremental Update (Regular Operations)

```bash
# Update with only new data since last run
./bin/dwh/ETL.sh incremental
```

This will:
1. Check existing DWH tables
2. Process only new notes/comments
3. Update affected datamarts
4. Much faster than initial load

**Expected Duration**: 15-30 minutes

### ETL Process Types

| Type | Command | Description |
|------|---------|-------------|
| **Initial Load** | `./bin/dwh/ETL.sh` | Complete load from scratch |
| **Incremental** | `./bin/dwh/ETL.sh incremental` | Process only new data |
| **Validation** | Built-in | Automatic validation after each run |

### Environment Variables

```bash
# Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
export LOG_LEVEL="INFO"

# Enable/disable parallel processing
export ETL_PARALLEL_ENABLED="true"

# Batch size for processing
export ETL_BATCH_SIZE="1000"

# Database credentials (usually in etc/properties.sh)
export DBNAME="osm_notes"
export DBHOST="localhost"
export DBPORT="5432"
export DBUSER="postgres"
```

### Monitoring ETL Progress

```bash
# Real-time log monitoring
tail -40f $(ls -1rtd /tmp/ETL_* | tail -1)/ETL.log

# Check last execution status
ls -ltr /tmp/ETL_*/
```

### Recovery

The ETL has built-in recovery mechanisms:

- **Lock Files**: Prevents concurrent executions
- **JSON Recovery File**: Tracks last successful step
- **Automatic Resumption**: Can resume from last checkpoint

---

## Profile Generation

Generate profiles for users or countries with detailed analytics.

### Generate User Profile

```bash
# Basic usage
./bin/dwh/profile.sh user angoca

# With custom output
./bin/dwh/profile.sh user angoca json > angoca_profile.json
```

**Example Output**:
```json
{
  "type": "user",
  "username": "angoca",
  "experience_level": "expert",
  "total_notes_opened": 1523,
  "total_notes_closed": 892,
  "countries_activity": [...],
  "top_hashtags": [...]
}
```

### Generate Country Profile

```bash
# Basic usage
./bin/dwh/profile.sh country Colombia

# Export to JSON
./bin/dwh/profile.sh country Colombia json > colombia_profile.json
```

**Example Output**:
```json
{
  "type": "country",
  "country_name": "Colombia",
  "total_notes": 15234,
  "active_users": 456,
  "top_hashtags": [...],
  "activity_timeline": [...]
}
```

### Profile Output Formats

| Format | Description | File Extension |
|--------|-------------|----------------|
| **json** | JSON format (default) | `.json` |
| **html** | HTML report | `.html` |
| **csv** | CSV format | `.csv` |

---

## Datamart Management

Datamarts are pre-computed aggregations that speed up queries.

### Automated Update

Datamarts are **automatically updated** during ETL execution. No manual intervention needed.

### Manual Update (If Needed)

```bash
# Update country datamart
./bin/dwh/datamartCountries/datamartCountries.sh

# Update user datamart
./bin/dwh/datamartUsers/datamartUsers.sh
```

### What Gets Updated

- **Country Datamart**: All countries marked as `modified = TRUE`
- **User Datamart**: All users marked as `modified = TRUE`
- **Smart Incremental**: Only processes changed entities

---

## Utility Scripts

### Export Datamarts to JSON

```bash
# Export all datamarts to JSON
./bin/dwh/exportDatamartsToJSON.sh

# Output goes to output/ directory
ls output/*.json
```

### Cleanup DWH

**⚠️ WARNING**: This removes all DWH objects!

```bash
# Remove all DWH objects (facts, dimensions, datamarts)
./bin/dwh/cleanupDWH.sh
```

Use case: Fresh start or reset after schema changes.

---

## Environment Variables

### Common Variables

| Variable | Description | Default | Used By |
|----------|-------------|---------|---------|
| `LOG_LEVEL` | Logging verbosity | `ERROR` | All scripts |
| `CLEAN` | Clean temporary files | `true` | All scripts |
| `DBNAME` | Database name | `osm_notes` | All scripts |
| `DBHOST` | Database host | `localhost` | All scripts |
| `DBPORT` | Database port | `5432` | All scripts |
| `DBUSER` | Database user | `postgres` | All scripts |

### ETL-Specific Variables

| Variable | Description | Default | Used By |
|----------|-------------|---------|---------|
| `ETL_BATCH_SIZE` | Records per batch | `1000` | ETL.sh |
| `ETL_PARALLEL_ENABLED` | Enable parallel processing | `true` | ETL.sh |
| `ETL_VACUUM_AFTER_LOAD` | Vacuum after load | `true` | ETL.sh |
| `ETL_ANALYZE_AFTER_LOAD` | Analyze after load | `true` | ETL.sh |

### Profile-Specific Variables

| Variable | Description | Default | Used By |
|----------|-------------|---------|---------|
| `OUTPUT_FORMAT` | Output format | `json` | profile.sh |

### Configuration File

Most variables can be set in `etc/properties.sh`:

```bash
# Load configuration
source etc/properties.sh

# Execute scripts
./bin/dwh/ETL.sh
```

---

## Troubleshooting

### Common Issues

#### 1. ETL Fails with "Lock File Exists"

**Problem**: Another ETL process is running

**Solution**:
```bash
# Check for running processes
ps aux | grep ETL.sh

# If no process running, remove lock file
rm /tmp/ETL_*/ETL.lock
```

#### 2. Out of Memory During ETL

**Problem**: Large dataset causes memory issues

**Solution**:
```bash
# Reduce batch size
export ETL_BATCH_SIZE="500"

# Disable parallel processing
export ETL_PARALLEL_ENABLED="false"

# Re-run ETL
./bin/dwh/ETL.sh incremental
```

#### 3. Database Connection Issues

**Problem**: Cannot connect to database

**Solution**:
```bash
# Verify connection
psql -h $DBHOST -p $DBPORT -U $DBUSER -d $DBNAME -c "SELECT 1"

# Check properties file
cat etc/properties.sh
```

#### 4. Slow Query Performance

**Problem**: Queries are slow

**Solution**:
```bash
# Run VACUUM ANALYZE
psql -d $DBNAME -c "VACUUM ANALYZE dwh.facts"

# Rebuild indexes if needed
psql -d $DBNAME -c "REINDEX SCHEMA dwh"
```

### Getting Help

1. Check logs: `/tmp/ETL_*/ETL.log`
2. Review documentation: `docs/`
3. Check GitHub Issues: [https://github.com/OSMLatam/OSM-Notes-Analytics/issues](https://github.com/OSMLatam/OSM-Notes-Analytics/issues)

---

## Best Practices

### Daily Operations

```bash
# Incremental update (recommended every 15-30 minutes)
*/15 * * * * /path/to/OSM-Notes-Analytics/bin/dwh/ETL.sh incremental
```

### Weekly Maintenance

```bash
# VACUUM ANALYZE (recommended weekly)
psql -d $DBNAME -c "VACUUM ANALYZE dwh.facts"
```

### Monthly Tasks

```bash
# Check index usage
psql -d $DBNAME -c "SELECT * FROM pg_stat_user_indexes WHERE schemaname = 'dwh'"

# Review disk usage
psql -d $DBNAME -c "SELECT pg_size_pretty(pg_database_size('osm_notes'))"
```

---

## Additional Resources

- [DWH Data Dictionary](DWH_Star_Schema_Data_Dictionary.md)
- [ETL Enhanced Features](ETL_Enhanced_Features.md)
- [DWH Maintenance Guide](DWH_Maintenance_Guide.md)
- [Partitioning Strategy](partitioning_strategy.md)

---

**Last Updated**: 2025-01-24  
**Author**: Andres Gomez (AngocA)

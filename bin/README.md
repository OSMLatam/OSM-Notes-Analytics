# Bin Directory

This directory contains the executable scripts for the OSM-Notes-Analytics project, primarily
focused on ETL (Extract, Transform, Load) processes and datamart generation.

## Overview

The `bin/` directory houses the main operational scripts that transform raw OSM notes data into a
comprehensive data warehouse with pre-computed analytics datamarts.

## Directory Structure

```text
bin/
└── dwh/                           # Data Warehouse scripts
    ├── ETL.sh                     # Main ETL orchestration script
    ├── profile.sh                 # Profile generator for users and countries
    ├── cleanupDWH.sh              # Cleanup DWH objects and temp files
    ├── README.md                  # DWH documentation
    ├── datamartCountries/         # Country datamart scripts
    │   └── datamartCountries.sh
    └── datamartUsers/             # User datamart scripts
        └── datamartUsers.sh
```

## Main Scripts

### 1. ETL.sh - Main ETL Process

**Location:** `bin/dwh/ETL.sh`

**Purpose:** Orchestrates the complete ETL process to populate the data warehouse from base tables.

**Features:**

- Creates star schema dimensions and fact tables
- Supports initial load and incremental updates
- Parallel processing by year (2013-present)
- Recovery and resume capabilities
- Resource monitoring and validation
- Comprehensive logging

**Usage:**

```bash
# Initial DWH creation (first run)
./bin/dwh/ETL.sh --create

# Incremental update (for scheduled runs)
./bin/dwh/ETL.sh --incremental

# Show help
./bin/dwh/ETL.sh --help
```

**Execution Modes:**

- **--create**: Full initial load, creates all DWH objects from scratch
- **--incremental**: Processes only new data since last run (default for cron jobs)
- **--help**: Shows detailed help information

**Configuration:**

- Database connection: `etc/properties.sh`
- ETL settings: `etc/etl.properties`

**Logging:**

```bash
# Follow ETL progress in real-time
tail -40f $(ls -1rtd /tmp/ETL_* | tail -1)/ETL.log
```

**Performance:**

- Initial load: ~30 hours (with parallel processing)
- Incremental update: 5-15 minutes (depends on new data volume)
- Resource requirements: 4GB+ RAM, multi-core CPU recommended

### 2. profile.sh - Profile Generator

**Location:** `bin/dwh/profile.sh`

**Purpose:** Generates detailed profiles for users and countries based on datamart data.

**Usage:**

```bash
# User profile
./bin/dwh/profile.sh --user AngocA

# Country profile (English name)
./bin/dwh/profile.sh --country Colombia
./bin/dwh/profile.sh --country "United States of America"

# Country profile (Spanish name)
./bin/dwh/profile.sh --pais Colombia
./bin/dwh/profile.sh --pais "Estados Unidos"

# General notes statistics
./bin/dwh/profile.sh
```

**Output includes:**

- Historical activity timeline
- Geographic distribution
- Working hours heatmap
- Rankings and leaderboards
- Activity patterns
- First and most recent actions

**Prerequisites:**

- Datamarts must be populated first
- Run `datamartCountries.sh` and `datamartUsers.sh` before generating profiles

### 3. datamartCountries.sh - Country Datamart

**Location:** `bin/dwh/datamartCountries/datamartCountries.sh`

**Purpose:** Populates the country-level datamart with pre-computed analytics.

**Usage:**

```bash
./bin/dwh/datamartCountries/datamartCountries.sh
```

**Features:**

- Aggregates note statistics by country
- Computes yearly historical data (2013-present)
- Generates user rankings per country
- Calculates working hours patterns
- Tracks first and latest activities

**Execution time:** ~20 minutes

**Prerequisites:**

- ETL must be completed
- DWH fact and dimension tables must exist

**Output:**

- Populates `dwh.datamartCountries` table
- One row per country with comprehensive metrics

### 4. cleanupDWH.sh - Cleanup Script

**Location:** `bin/dwh/cleanupDWH.sh`

**Purpose:** Removes data warehouse objects from the database and cleans up temporary files. Uses database configuration from `etc/properties.sh`.

**⚠️ WARNING:** This script can permanently delete data! Always use `--dry-run` first to see what will be removed.

**Usage:**

```bash
# Safe operations (no confirmation required):
./bin/dwh/cleanupDWH.sh --remove-temp-files    # Remove only temporary files
./bin/dwh/cleanupDWH.sh --dry-run              # Show what would be done (safe)

# Destructive operations (require confirmation):
./bin/dwh/cleanupDWH.sh                        # Full cleanup - REMOVES ALL DATA!
./bin/dwh/cleanupDWH.sh --remove-all-data      # Remove DWH schema and data only

# Help:
./bin/dwh/cleanupDWH.sh --help                # Show detailed help
```

**What it removes:**

**DWH Objects** (`--remove-all-data` or default behavior):

- Staging schema and all objects
- Datamart tables (countries and users)  
- DWH schema with all dimensions and facts
- All functions, procedures, and triggers
- **⚠️ PERMANENT DATA LOSS - requires confirmation**

**Temporary Files** (`--remove-temp-files` or default behavior):

- `/tmp/ETL_*` directories
- `/tmp/datamartCountries_*` directories  
- `/tmp/datamartUsers_*` directories
- `/tmp/profile_*` directories
- `/tmp/cleanupDWH_*` directories
- **✅ Safe operation - no confirmation required**

**When to use:**

- **Development/Testing:** Use `--remove-temp-files` to clean temporary files
- **Complete Reset:** Use default behavior to remove everything (with confirmation)
- **DWH Only:** Use `--remove-all-data` to remove only database objects
- **Safety First:** Always use `--dry-run` to preview operations

**Prerequisites:**

- Database configured in `etc/properties.sh`
- User must have DROP privileges on target database
- PostgreSQL client tools installed (`psql`)
- Script must be run from project root directory

**Use cases:**

- **Development:** Clean temporary files with `--remove-temp-files`
- **Testing:** Reset environment with `--dry-run` first, then full cleanup
- **Troubleshooting:** Remove corrupted DWH objects with `--remove-all-data`
- **Clean restart:** Remove all objects before running `ETL.sh --create`
- **Maintenance:** Regular cleanup of temporary files

### 5. datamartUsers.sh - User Datamart

**Location:** `bin/dwh/datamartUsers/datamartUsers.sh`

**Purpose:** Populates the user-level datamart with pre-computed analytics.

**Usage:**

```bash
./bin/dwh/datamartUsers/datamartUsers.sh
```

**Features:**

- Aggregates note statistics by user
- Processes incrementally (500 users per run)
- Computes yearly historical data
- Generates country rankings per user
- Tracks contribution patterns
- Classifies contributor types

**Execution time:**

- Per run: 5-10 minutes (500 users)
- Full initial load: ~5 days (incremental approach)

**Prerequisites:**

- ETL must be completed
- DWH fact and dimension tables must exist

**Output:**

- Populates `dwh.datamartUsers` table
- One row per active user with comprehensive metrics

**Note:** This script is designed to run incrementally to avoid overwhelming the database. Schedule
it to run regularly until all users are processed.

## Workflow

### Initial Setup (First Time)

```bash
# 1. Configure database connection
nano etc/properties.sh

# 2. Configure ETL settings
nano etc/etl.properties

# 3. Run initial ETL
./bin/dwh/ETL.sh --create
# Wait ~30 hours for completion

# 4. Populate country datamart
./bin/dwh/datamartCountries/datamartCountries.sh
# Wait ~20 minutes

# 5. Start populating user datamart (run multiple times)
./bin/dwh/datamartUsers/datamartUsers.sh
# Repeat daily until all users processed (~5 days)
```

### Regular Updates (Scheduled)

```bash
# Crontab example:

# Incremental ETL every hour
0 * * * * ~/OSM-Notes-Analytics/bin/dwh/ETL.sh --incremental

# Update country datamart daily at 2 AM
0 2 * * * ~/OSM-Notes-Analytics/bin/dwh/datamartCountries/datamartCountries.sh

# Update user datamart daily at 2:30 AM
30 2 * * * ~/OSM-Notes-Analytics/bin/dwh/datamartUsers/datamartUsers.sh
```

### Generating Profiles

```bash
# After datamarts are populated, generate profiles:

# User profile
./bin/dwh/profile.sh --user AngocA

# Country profile
./bin/dwh/profile.sh --country Colombia

# General statistics
./bin/dwh/profile.sh
```

## Configuration Files

### Database Configuration

Edit `etc/properties.sh`:

```bash
DBNAME="osm_notes"    # Database name
DB_USER="myuser"      # Database user
MAX_THREADS="4"       # Parallel processing threads
```

### ETL Configuration

Edit `etc/etl.properties`:

```bash
ETL_BATCH_SIZE=1000              # Records per batch
ETL_PARALLEL_ENABLED=true        # Enable parallel processing
ETL_MAX_PARALLEL_JOBS=4          # Max parallel jobs
ETL_RECOVERY_ENABLED=true        # Enable recovery
ETL_VALIDATE_INTEGRITY=true      # Validate data integrity
MAX_MEMORY_USAGE=80              # Memory usage threshold (%)
MAX_DISK_USAGE=90                # Disk usage threshold (%)
```

## Logging and Monitoring

All scripts create detailed logs in `/tmp/`:

```bash
# ETL logs
tail -f /tmp/ETL_*/ETL.log

# Country datamart logs
tail -f /tmp/datamartCountries_*/datamartCountries.log

# User datamart logs
tail -f /tmp/datamartUsers_*/datamartUsers.log

# Profile logs
tail -f /tmp/profile_*/profile.log
```

## Error Handling

### ETL Failures

If ETL fails:

1. Check logs in `/tmp/ETL_*/ETL.log`
2. Review error messages
3. Fix underlying issue
4. Restart: `./bin/dwh/ETL.sh --incremental`

### Resource Monitoring

Scripts monitor system resources:

- Memory usage (default: alert at 80%)
- Disk usage (default: alert at 90%)
- Execution timeout (default: 2 hours)

## Dependencies

### Required

- PostgreSQL 12+
- PostGIS 3.0+
- Bash 4.0+
- Base tables populated by OSM-Notes-Ingestion system

### Optional

- `jq` for JSON parsing (for recovery features)
- `parallel` for enhanced parallel processing

## Integration

These scripts integrate with:

1. **OSM-Notes-Ingestion** (upstream)
   - Reads base tables: `notes`, `note_comments`, `users`, `countries`
   - Requires ingestion system to run first

2. **Web Frontend** (downstream)
   - Provides data through datamarts
   - Profile scripts can generate reports

## Performance Tuning

### Increase Parallel Jobs

```bash
# Edit etc/etl.properties
ETL_MAX_PARALLEL_JOBS=8  # Increase for more cores
```

### Adjust Batch Size

```bash
# Edit etc/etl.properties
ETL_BATCH_SIZE=5000  # Increase for better throughput
```

### Database Optimization

```bash
# After initial load
psql -d osm_notes -c "VACUUM ANALYZE dwh.facts;"
psql -d osm_notes -c "REINDEX TABLE dwh.facts;"
```

## Troubleshooting

### "Base tables do not exist"

Ensure the OSM-Notes-Ingestion system has populated base tables:

```bash
psql -d osm_notes -c "SELECT COUNT(*) FROM notes;"
```

### "Lock file exists"

Another instance is running. Wait or remove lock:

```bash
rm /tmp/ETL_*.lock
```

### "Out of memory"

Reduce parallel jobs or batch size:

```bash
# Edit etc/etl.properties
ETL_MAX_PARALLEL_JOBS=2
ETL_BATCH_SIZE=500
```

### Database Connection Issues

Test connection:

```bash
psql -d osm_notes -c "SELECT version();"
```

## Development

### Adding New Scripts

1. Follow naming convention: `descriptiveName.sh`
2. Include header with purpose, author, version
3. Source common libraries from `lib/osm-common/`
4. Add error handling and logging
5. Include help text (`--help` flag)
6. Test with shellcheck: `shellcheck -x -o all script.sh`
7. Format with shfmt: `shfmt -w -i 1 -sr -bn script.sh`

### Code Style

- Use descriptive function names with `__` prefix
- Add comments for complex logic
- Include error codes in help text
- Use strict error handling (`set -euo pipefail`)

## References

- [ETL Enhanced Features](../docs/ETL_Enhanced_Features.md)
- [DWH Star Schema ERD](../docs/DWH_Star_Schema_ERD.md)
- [Data Dictionary](../docs/DWH_Star_Schema_Data_Dictionary.md)
- [Testing Guide](../tests/README.md)

## Support

For issues with scripts:

1. Check log files in `/tmp/`
2. Review error messages
3. Validate configuration files
4. Create an issue with logs and error details

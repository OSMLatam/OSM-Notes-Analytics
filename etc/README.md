# Etc Directory

This directory contains configuration files that control the behavior of the OSM-Notes-Analytics system.

## Overview

Configuration files in this directory define database connections, processing parameters, and system behavior. These files should be customized for your specific environment before running the ETL and datamart scripts.

## Configuration Files

### properties.sh

**Purpose:** Main configuration file for database connection and general processing parameters.

**Location:** `etc/properties.sh`

**Configuration Sections:**

#### 1. Database Configuration

```bash
# Database name (should match the ingestion system database)
DBNAME="notes"

# Database user with read/write access to DWH schema
DB_USER="myuser"
```

**Important Notes:**

- The database name must match the database used by the OSM-Notes-Ingestion system
- The database user needs permissions to:
  - Read from `public` schema (base tables)
  - Create objects in `dwh` schema
  - Create and manage staging schema

#### 2. Email Configuration

```bash
# Email addresses for reports and notifications (comma-separated)
EMAILS="username@domain.com"
```

**Note:** Email notifications are configured in `etl.properties` (`ETL_NOTIFICATION_ENABLED`, `ETL_NOTIFICATION_EMAIL`). This variable is inherited from the shared configuration but not currently used by Analytics scripts.

#### 3. API Configuration (Inherited, Not Used)

```bash
# OpenStreetMap API endpoint
OSM_API="https://api.openstreetmap.org/api/0.6"

# Planet dump URL
PLANET="https://planet.openstreetmap.org"

# Overpass API endpoint for downloading boundaries
OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"
```

**Note:** These settings are used by the OSM-Notes-Ingestion system (not Analytics). They are inherited from the shared `properties.sh` file but are not used by any Analytics scripts. You can ignore these for Analytics-only deployments.

#### 4. Rate Limiting (Inherited, Not Used)

```bash
# Seconds to wait between API requests to avoid "Too Many Requests" errors
SECONDS_TO_WAIT="30"
```

**Note:** Used by the Ingestion system, not Analytics. Can be ignored for Analytics-only deployments.

#### 5. Processing Configuration

```bash
# Number of notes to process per batch (inherited from shared config)
LOOP_SIZE="10000"

# Maximum notes to download from API (Ingestion only, not used by Analytics)
MAX_NOTES="10000"
```

**Note:** `LOOP_SIZE` is inherited but not actively used by Analytics ETL (which uses `ETL_BATCH_SIZE` from `etl.properties`). `MAX_NOTES` is used only by the Ingestion system.

#### 6. Parallel Processing

```bash
# Maximum number of parallel threads (auto-detected, capped at 16)
MAX_THREADS="4"

# Delay between launching parallel processes (seconds)
PARALLEL_PROCESS_DELAY="2"

# Minimum notes required to enable parallel processing
MIN_NOTES_FOR_PARALLEL="10"
```

**Auto-detection:**

- Automatically detects CPU cores using `nproc`
- Caps at 16 threads for production stability
- Falls back to 4 threads if detection fails

**Tuning Guide:**

- **2-4 threads**: For systems with limited CPU
- **8-16 threads**: For high-performance servers
- **Increase PARALLEL_PROCESS_DELAY** if experiencing memory pressure

#### 7. XSLT Processing (Inherited, Not Used)

```bash
# Enable XSLT profiling for performance analysis
ENABLE_XSLT_PROFILING="false"

# Maximum recursion depth for XSLT transformations
XSLT_MAX_DEPTH="4000"
```

**Note:** XSLT processing is used by the Ingestion system for XML transformation, not by Analytics. These settings can be ignored for Analytics-only deployments.

#### 8. Cleanup Configuration

```bash
# Clean up temporary files after successful execution
CLEAN="true"
```

- **true**: Delete temporary files (recommended for production)
- **false**: Keep temporary files (useful for debugging)

### etl.properties

**Purpose:** ETL-specific configuration for performance, recovery, and validation.

**Location:** `etc/etl.properties`

**Configuration Sections:**

#### 1. Performance Configuration

```bash
# Number of records to process in each batch
ETL_BATCH_SIZE=1000

# Commit transaction every N records
ETL_COMMIT_INTERVAL=100

# Run VACUUM after data load
ETL_VACUUM_AFTER_LOAD=true

# Run ANALYZE after data load
ETL_ANALYZE_AFTER_LOAD=true
```

**Tuning Guide:**

- **Increase ETL_BATCH_SIZE** (5000-10000) for faster processing on powerful systems
- **Decrease ETL_BATCH_SIZE** (500-1000) for systems with limited memory
- **Keep VACUUM/ANALYZE enabled** for optimal query performance

#### 2. Resource Control

```bash
# Maximum memory usage percentage before pausing
MAX_MEMORY_USAGE=80

# Maximum disk usage percentage before stopping
MAX_DISK_USAGE=90

# ETL execution timeout in seconds (2 hours)
ETL_TIMEOUT=7200
```

**Safety Features:**

- Monitors system resources during execution
- Pauses processing if memory exceeds threshold
- Stops execution if disk usage is critical
- Times out if ETL takes too long (prevents runaway processes)

#### 3. Recovery Configuration

```bash
# Enable recovery checkpoints for resuming after failure
ETL_RECOVERY_ENABLED=true
```

**Features:**

- Saves progress at key steps
- Allows resuming with `--resume` flag
- Stores recovery state in JSON format

#### 4. Data Integrity Validation

```bash
# Enable comprehensive data validation
ETL_VALIDATE_INTEGRITY=true

# Validate dimension tables are populated
ETL_VALIDATE_DIMENSIONS=true

# Validate fact table references
ETL_VALIDATE_FACTS=true
```

**Validation Checks:**

- Dimension tables contain data
- Fact table foreign keys are valid
- No orphaned records
- Data consistency across tables

#### 5. Notification Configuration

```bash
# Enable email notifications
ETL_NOTIFICATION_ENABLED=false

# Email address for notifications
ETL_NOTIFICATION_EMAIL=""
```

**Future Feature:** Email notifications for ETL completion and errors.

#### 6. Parallel Processing variables

```bash
# Enable parallel ETL processing by year
ETL_PARALLEL_ENABLED=true

# Maximum parallel jobs to run simultaneously
ETL_MAX_PARALLEL_JOBS=4
```

**How It Works:**

- Processes each year (2013-present) in parallel
- Each year runs as a separate background process
- Results merged after all years complete

**Tuning Guide:**

- Match `ETL_MAX_PARALLEL_JOBS` with `MAX_THREADS` in `properties.sh`
- Increase for multi-core systems (8-16)
- Decrease if experiencing memory issues (2-4)

#### 7. Logging Configuration

```bash
# Logging level: TRACE, DEBUG, INFO, WARN, ERROR, FATAL
ETL_LOG_LEVEL="INFO"

# Enable audit logging
ETL_AUDIT_ENABLED=true
```

**Log Levels:**

- **TRACE**: Very detailed debugging info
- **DEBUG**: Detailed debugging info
- **INFO**: General information (recommended)
- **WARN**: Warnings and potential issues
- **ERROR**: Errors only
- **FATAL**: Fatal errors only

#### 8. Database Configuration

```bash
# Database query timeout in seconds
ETL_DB_TIMEOUT=300

# Number of retry attempts for failed queries
ETL_DB_RETRY_ATTEMPTS=3
```

**Resilience:**

- Retries failed database operations
- Times out long-running queries
- Prevents hanging on network issues

#### 9. Monitoring Configuration

```bash
# Enable resource monitoring during execution
ETL_MONITOR_RESOURCES=true

# Check resources every N seconds
ETL_MONITOR_INTERVAL=30
```

Continuously monitors:

- Memory usage
- Disk usage
- CPU usage
- Execution time

#### 10. Large File Processing

```bash
# File size thresholds in MB
ETL_LARGE_FILE_THRESHOLD_MB=500
ETL_VERY_LARGE_FILE_THRESHOLD_MB=1000

# XML processing configuration
ETL_XML_VALIDATION_TIMEOUT=300
ETL_XML_BATCH_SIZE=1000
ETL_XML_MAX_BATCHES=10
ETL_XML_SAMPLE_SIZE=50
ETL_XML_MEMORY_LIMIT_MB=2048
```

**Optimizations for Large Files:**

- Batch processing for huge XML files
- Sampling for validation
- Memory limits to prevent OOM errors

#### 11. XSLT Processing

```bash
# Maximum recursion depth for XSLT transformations
ETL_XSLT_MAX_DEPTH=4000
```

Matches `XSLT_MAX_DEPTH` in `properties.sh`.

## Customization Guide

### Initial Setup

1. **Copy and edit properties.sh:**

```bash
cd etc/
nano properties.sh
```

2. **Set database credentials:**

```bash
DBNAME="your_database_name"
DB_USER="your_username"
```

3. **Adjust parallel processing:**

```bash
# For 8-core system:
MAX_THREADS="8"
```

4. **Save and test connection:**

```bash
psql -d your_database_name -U your_username -c "SELECT version();"
```

### Performance Optimization

#### For High-Performance Systems (16+ cores, 32GB+ RAM)

**properties.sh:**

```bash
MAX_THREADS="16"
LOOP_SIZE="50000"
PARALLEL_PROCESS_DELAY="1"
```

**etl.properties:**

```bash
ETL_BATCH_SIZE=10000
ETL_MAX_PARALLEL_JOBS=16
MAX_MEMORY_USAGE=90
```

#### For Limited Resources (4 cores, 8GB RAM)

**properties.sh:**

```bash
MAX_THREADS="2"
LOOP_SIZE="5000"
PARALLEL_PROCESS_DELAY="5"
```

**etl.properties:**

```bash
ETL_BATCH_SIZE=500
ETL_MAX_PARALLEL_JOBS=2
MAX_MEMORY_USAGE=70
```

### Development vs Production

#### Development Settings

**etl.properties:**

```bash
ETL_LOG_LEVEL="DEBUG"
CLEAN="false"  # Keep files for debugging
ETL_VALIDATE_INTEGRITY=true
ETL_VALIDATE_DIMENSIONS=true
ETL_VALIDATE_FACTS=true
```

#### Production Settings

**etl.properties:**

```bash
ETL_LOG_LEVEL="INFO"
CLEAN="true"  # Remove temporary files
ETL_VALIDATE_INTEGRITY=true
ETL_NOTIFICATION_ENABLED=true
ETL_NOTIFICATION_EMAIL="admin@domain.com"
```

## Environment Variables

Configuration can be overridden with environment variables:

```bash
# Override database name
export DBNAME="test_database"

# Override log level
export LOG_LEVEL="DEBUG"

# Run ETL
./bin/dwh/ETL.sh --incremental
```

**Priority Order:**

1. Environment variables (highest)
2. Configuration files
3. Script defaults (lowest)

## Security Considerations

### Database Credentials

**Do NOT commit sensitive credentials to Git:**

```bash
# Add to .gitignore (already done)
etc/properties.sh.local
```

**Use local override file:**

```bash
# Create local override
cp etc/properties.sh etc/properties.sh.local
nano etc/properties.sh.local

# Modify scripts to source local file first
```

### PostgreSQL Authentication

**Recommended: Use .pgpass file:**

```bash
# Create .pgpass in home directory
echo "localhost:5432:osm_notes:myuser:mypassword" >> ~/.pgpass
chmod 600 ~/.pgpass
```

**Or use PostgreSQL environment variables:**

```bash
export PGDATABASE="osm_notes"
export PGUSER="myuser"
export PGPASSWORD="mypassword"
```

## Validation

### Test Configuration

```bash
# Test database connection
psql -d "${DBNAME}" -U "${DB_USER}" -c "SELECT version();"

# Test properties.sh
bash -c "source etc/properties.sh && echo 'MAX_THREADS: ${MAX_THREADS}'"

# Validate ETL config
./bin/dwh/ETL.sh --dry-run
```

### Verify Settings

```bash
# Show current configuration
grep -v "^#" etc/properties.sh | grep -v "^$"
grep -v "^#" etc/etl.properties | grep -v "^$"
```

## Troubleshooting

### "Database does not exist"

Create database:

```bash
createdb "${DBNAME}"
psql -d "${DBNAME}" -c "CREATE EXTENSION postgis;"
```

### "Permission denied"

Grant permissions:

```bash
psql -d "${DBNAME}" -c "GRANT ALL ON SCHEMA dwh TO ${DB_USER};"
```

### "Out of memory" during ETL

Reduce resource usage:

```bash
# Edit etc/etl.properties
ETL_BATCH_SIZE=500
ETL_MAX_PARALLEL_JOBS=2
```

### Configuration not taking effect

Check environment variables:

```bash
env | grep -E '(DBNAME|ETL_|MAX_THREADS)'
```

Unset conflicting variables:

```bash
unset DBNAME
unset ETL_BATCH_SIZE
```

## Best Practices

1. **Always backup** configuration files before modifying
2. **Use environment-specific** settings (dev/staging/prod)
3. **Monitor resource usage** in logs during first runs
4. **Start with conservative** settings and tune gradually
5. **Document custom changes** in comments
6. **Test configuration** with `--dry-run` before full execution

## References

- [Main README](../README.md)
- [ETL Enhanced Features](../docs/ETL_Enhanced_Features.md)
- [Testing Guide](../tests/README.md)

## Support

For configuration issues:

1. Validate syntax: `bash -n etc/properties.sh`
2. Test database connection
3. Check log files for configuration errors
4. Create an issue with your (sanitized) configuration

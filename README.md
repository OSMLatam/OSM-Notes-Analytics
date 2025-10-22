# OSM-Notes-Analytics

![Tests](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Tests/badge.svg)
![Quality Checks](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Quality%20Checks/badge.svg)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-12%2B-blue)](https://www.postgresql.org/)
[![PostGIS](https://img.shields.io/badge/PostGIS-3.0%2B-green)](https://postgis.net/)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-orange)](https://www.gnu.org/software/bash/)

Data Warehouse, ETL, and Analytics for OpenStreetMap Notes

## Overview

This repository contains the analytics and data warehouse components for the OSM Notes profiling
system. It provides ETL (Extract, Transform, Load) processes, a star schema data warehouse, and
datamarts for analyzing OSM notes data.

## Features

- **Star Schema Data Warehouse**: Comprehensive dimensional model for notes analysis
- **Enhanced ETL Process**: Robust ETL with recovery, validation, and monitoring
- **Country Datamart**: Pre-computed analytics by country
- **User Datamart**: Pre-computed analytics by user
- **Profile Generator**: Generate country and user profiles
- **Advanced Dimensions**:
  - Timezones for local time analysis
  - Seasons based on date and latitude
  - Continents for geographical grouping
  - Application versions tracking
  - SCD2 for username changes

## Prerequisites

- **PostgreSQL** 12 or higher
- **PostGIS** 3.0 or higher
- **Bash** 4.0 or higher
- **OSM Notes Ingestion Database**: This analytics system reads from the base notes tables populated
  by the [OSM-Notes-Ingestion](https://github.com/OSMLatam/OSM-Notes-Ingestion) ingestion system

## Database Architecture

This system uses a **shared database** approach with separate schemas:

```text
Database: osm_notes
├── Schema: public          # Base tables (managed by Ingestion repo)
│   ├── notes
│   ├── note_comments
│   ├── note_comments_text
│   ├── users
│   └── countries
└── Schema: dwh             # Data Warehouse (managed by this repo)
    ├── facts               # Fact table
    ├── dimension_*         # Dimension tables
    └── datamart_*          # Datamart tables
```

## Quick Start

This guide walks you through the complete process from scratch to having exportable JSON datamarts.

### Process Overview

```
1. Base Data       → 2. ETL/DWH        → 3. Datamarts      → 4. JSON Export
   (notes)            (facts, dims)       (aggregations)      (web viewer)
```

### Step-by-Step Instructions

#### Step 1: Clone the Repository

```bash
git clone https://github.com/OSMLatam/OSM-Notes-Analytics.git
cd OSM-Notes-Analytics
```

#### Step 2: Configure Database Connection

Edit `etc/properties.sh` with your database credentials:

```bash
# Database configuration
DBNAME="osm_notes"          # Same database as Ingestion
DB_USER="myuser"
```

#### Step 3: Verify Base Tables

First, ensure you have the base OSM notes data:

```bash
psql -d notes -c "SELECT COUNT(*) FROM notes"
psql -d notes -c "SELECT COUNT(*) FROM note_comments"
psql -d notes -c "SELECT COUNT(*) FROM note_comments_text"
```

If these tables are empty or don't exist, you need to load the OSM notes data first using the [OSM-Notes-Ingestion](https://github.com/OSMLatam/OSM-Notes-Ingestion) system.

#### Step 4: Run the ETL Process

The ETL creates the data warehouse (schema `dwh`) with:
- Fact tables (partitioned by year for optimal performance)
- Dimension tables (users, countries, dates, etc.)
- All necessary transformations

```bash
cd bin/dwh
./ETL.sh --create
```

**This process can take several hours depending on data size.**

Expected output:
- Creates schema `dwh`
- Creates ~15+ tables
- Creates automatic partitions for facts table
- Populates dimension tables
- Loads facts from note_comments

#### Step 5: Verify DWH Creation

Check that the data warehouse was created:

```bash
# Check schema exists
psql -d notes -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'dwh'"

# Check tables exist
psql -d notes -c "SELECT tablename FROM pg_tables WHERE schemaname = 'dwh' ORDER BY tablename"

# Check fact counts
psql -d notes -c "SELECT COUNT(*) FROM dwh.facts"
psql -d notes -c "SELECT COUNT(*) FROM dwh.dimension_users"
psql -d notes -c "SELECT COUNT(*) FROM dwh.dimension_countries"
```

#### Step 6: Create and Populate Datamarts

The datamarts aggregate data for quick access:

**Users Datamart:**
```bash
cd bin/dwh/datamartUsers
./datamartUsers.sh
```

**Countries Datamart:**
```bash
cd bin/dwh/datamartCountries
./datamartCountries.sh
```

**Note**: These scripts process data incrementally (500 users/countries at a time), so you may need to run them multiple times until all entities are processed.

#### Step 7: Verify Datamart Creation

```bash
# Check datamart tables exist
psql -d notes -c "SELECT tablename FROM pg_tables WHERE schemaname = 'dwh' AND tablename LIKE 'datamart%'"

# Check counts
psql -d notes -c "SELECT COUNT(*) FROM dwh.datamartusers"
psql -d notes -c "SELECT COUNT(*) FROM dwh.datamartcountries"

# View sample user
psql -d notes -c "SELECT user_id, username, history_whole_open, history_whole_closed FROM dwh.datamartusers LIMIT 5"

# View sample country
psql -d notes -c "SELECT country_id, country_name_en, history_whole_open, history_whole_closed FROM dwh.datamartcountries LIMIT 5"
```

#### Step 8: Export to JSON (Optional)

Once datamarts are populated, export to JSON for the web viewer:

```bash
cd bin/dwh
./exportDatamartsToJSON.sh
```

This creates JSON files in `./output/json/`:
- Individual files per user: `users/{user_id}.json`
- Individual files per country: `countries/{country_id}.json`
- Index files: `indexes/users.json`, `indexes/countries.json`
- Metadata: `metadata.json`

See [JSON Export Documentation](bin/dwh/export_json_readme.md) for complete details.

### Incremental Updates

For ongoing updates, run these in sequence:

```bash
# 1. Update base data (your OSM notes import process)

# 2. Update DWH
cd bin/dwh
./ETL.sh --incremental

# 3. Update datamarts
cd datamartUsers
./datamartUsers.sh
cd ../datamartCountries
./datamartCountries.sh

# 4. Export JSON (optional)
cd ..
./exportDatamartsToJSON.sh
```

## Scheduling with Cron

For automated analytics updates:

```bash
# Update ETL every hour (after ingestion completes)
0 * * * * ~/OSM-Notes-Analytics/bin/dwh/ETL.sh --incremental

# Update country datamart daily
0 2 * * * ~/OSM-Notes-Analytics/bin/dwh/datamartCountries/datamartCountries.sh

# Update user datamart daily (processes 500 users per run)
30 2 * * * ~/OSM-Notes-Analytics/bin/dwh/datamartUsers/datamartUsers.sh
```

## Directory Structure

```text
OSM-Notes-Analytics/
├── bin/                    # Executable scripts
│   ├── dwh/               # ETL and datamart scripts
│   │   ├── ETL.sh         # Main ETL process
│   │   ├── profile.sh     # Profile generator
│   │   ├── cleanupDWH.sh  # Data warehouse cleanup script
│   │   ├── README.md      # DWH scripts documentation
│   │   ├── datamartCountries/
│   │   │   └── datamartCountries.sh
│   │   └── datamartUsers/
│   │       └── datamartUsers.sh
│   └── README.md          # Scripts documentation
├── etc/                    # Configuration files
│   ├── properties.sh      # Database configuration
│   ├── etl.properties     # ETL configuration
│   └── README.md          # Configuration documentation
├── sql/                    # SQL scripts
│   ├── dwh/               # DWH DDL and procedures
│   │   ├── ETL_*.sql      # ETL scripts
│   │   ├── Staging_*.sql  # Staging procedures
│   │   ├── datamartCountries/  # Country datamart SQL
│   │   └── datamartUsers/      # User datamart SQL
│   └── README.md          # SQL documentation
├── scripts/                # Utility scripts
│   ├── install-hooks.sh   # Git hooks installer
│   ├── setup_analytics.sh # Initial setup script
│   ├── validate-all.sh    # Validation script
│   └── README.md          # Scripts documentation
├── tests/                  # Test suites
│   ├── unit/              # Unit tests
│   │   ├── bash/          # Bash script tests
│   │   └── sql/           # SQL tests
│   ├── integration/       # Integration tests
│   ├── run_all_tests.sh   # Run all tests
│   ├── run_dwh_tests.sh   # Run DWH tests
│   ├── run_quality_tests.sh  # Run quality tests
│   └── README.md          # Testing documentation
├── docs/                   # Documentation
│   ├── DWH_Star_Schema_ERD.md           # Star schema diagrams
│   ├── DWH_Star_Schema_Data_Dictionary.md  # Data dictionary
│   ├── ETL_Enhanced_Features.md         # ETL features
│   ├── CI_CD_Guide.md                   # CI/CD workflows
│   └── README.md                        # Documentation index
└── lib/                    # Shared libraries
    ├── osm-common/         # Common OSM utilities
    │   ├── bash_logger.sh
    │   ├── commonFunctions.sh
    │   ├── validationFunctions.sh
    │   ├── errorHandlingFunctions.sh
    │   └── consolidatedValidationFunctions.sh
    └── README.md          # Library documentation
```

## ETL Execution Modes

### Create Mode (Initial Setup)

```bash
./bin/dwh/ETL.sh --create
```

Creates the complete data warehouse from scratch, including all dimensions and facts.

### Incremental Mode (Regular Updates)

```bash
./bin/dwh/ETL.sh --incremental
```

Processes only new data since the last ETL run. Use this for scheduled updates.

### Validate Mode (Data Quality Check)

```bash
./bin/dwh/ETL.sh --validate
```

Validates data integrity without making changes.

### Resume Mode (Recovery)

```bash
./bin/dwh/ETL.sh --resume
```

Resumes from the last successful step after a failure.

## Data Warehouse Schema

### Fact Table

- **`dwh.facts`**: Central fact table containing note actions and metrics
  - **Partitioned by year** (action_at) for optimal performance
  - Automatic partition creation for current and future years
  - Each year stored in separate partition (e.g., `facts_2024`, `facts_2025`)
  - 10-50x faster queries when filtering by date

### Dimension Tables

- **`dimension_users`**: User information with SCD2 support
- **`dimension_countries`**: Countries with ISO codes and regions
- **`dimension_regions`**: Geographic regions
- **`dimension_continents`**: Continental grouping
- **`dimension_days`**: Date dimension with enhanced attributes
- **`dimension_time_of_week`**: Hour of week with period of day
- **`dimension_applications`**: Applications used to create notes
- **`dimension_application_versions`**: Application version tracking
- **`dimension_hashtags`**: Hashtags found in notes
- **`dimension_timezones`**: Timezone information
- **`dimension_seasons`**: Seasons based on date and latitude

### Datamart Tables

- **`datamart_countries`**: Pre-computed country analytics
- **`datamart_users`**: Pre-computed user analytics

## Performance Considerations

### Table Partitioning

The `dwh.facts` table is **partitioned by year** using the `action_at` column:

- **Automatic partition management**: The ETL automatically creates partitions for:
  - Current year (always verified)
  - Next year (to prevent failures on year transition)
  - One additional year ahead (buffer)
- **Zero maintenance**: No manual intervention needed when the year changes
- **Performance benefits**:
  - 10-50x faster queries when filtering by date
  - Only scans relevant year partitions (PostgreSQL partition pruning)
  - Faster VACUUM and maintenance operations per partition
- **Easy archival**: Old year partitions can be detached/archived independently

See `docs/partitioning_strategy.md` for complete details.

### Initial Load Times

- **ETL Initial Load**: ~30 hours (parallel by year since 2013)
- **Country Datamart**: ~20 minutes
- **User Datamart**: ~5 days (500 users per run, asynchronous)

### Resource Requirements

- **Memory**: 4GB+ recommended for ETL
- **Disk Space**: Depends on notes volume (GB scale)
- **CPU**: Multi-core recommended for parallel processing

## Testing

### Quick Start testing

```bash
# Quality tests (fast, no database required)
./tests/run_quality_tests.sh

# DWH tests (requires database 'dwh')
./tests/run_dwh_tests.sh

# All tests
./tests/run_all_tests.sh
```

### CI/CD Integration

This project includes comprehensive CI/CD with:

- ✅ GitHub Actions workflows for automated testing
- ✅ Pre-commit hooks for code quality
- ✅ Pre-push hooks for full validation
- ✅ Automated dependency checking

**Install git hooks:**

```bash
./scripts/install-hooks.sh
```

**Full validation:**

```bash
./scripts/validate-all.sh
```

See [CI/CD Guide](docs/CI_CD_Guide.md) for complete documentation.

## Logging

The ETL process creates detailed logs:

```bash
# Follow ETL progress
tail -40f $(ls -1rtd /tmp/ETL_* | tail -1)/ETL.log

# Set log level
export LOG_LEVEL=DEBUG
./bin/dwh/ETL.sh --incremental
```

Available log levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL

## Maintenance and Cleanup

### Data Warehouse Cleanup Script

The project includes a cleanup script for maintenance and troubleshooting:

```bash
# Safe operations (no data loss):
./bin/dwh/cleanupDWH.sh --remove-temp-files    # Clean temporary files
./bin/dwh/cleanupDWH.sh --dry-run              # Preview operations

# Destructive operations (require confirmation):
./bin/dwh/cleanupDWH.sh                        # Full cleanup
./bin/dwh/cleanupDWH.sh --remove-all-data      # DWH objects only
```

**When to use:**
- **Development**: Clean temporary files regularly
- **Testing**: Reset environment between test runs
- **Troubleshooting**: Remove corrupted objects
- **Maintenance**: Free disk space

**⚠️ Warning**: Destructive operations permanently delete data! Always use `--dry-run` first.

For detailed maintenance procedures, see [DWH Maintenance Guide](docs/DWH_Maintenance_Guide.md).

## Troubleshooting

### Common Issues

#### "Schema 'dwh' does not exist"

**Solution**: Run `./bin/dwh/ETL.sh --create` first to create the data warehouse.

#### "Table 'dwh.datamartusers' does not exist"

**Solution**: Run the datamart scripts:
- `bin/dwh/datamartUsers/datamartUsers.sh`
- `bin/dwh/datamartCountries/datamartCountries.sh`

#### ETL takes too long

The ETL processes data by year in parallel. Adjust parallelism in `etc/properties.sh`:

```bash
MAX_THREADS=8  # Increase for more cores
```

#### Datamart not fully populated

Datamarts process entities incrementally (500 at a time). Run the script multiple times:

```bash
# Keep running until it says "0 users processed"
while true; do
  ./datamartUsers.sh
  sleep 5
done
```

Or check the `modified` flag:

```sql
SELECT COUNT(*) FROM dwh.dimension_users WHERE modified = TRUE;
```

When it returns 0, all users are processed.

#### JSON export is empty

Ensure datamarts have data:

```sql
SELECT COUNT(*) FROM dwh.datamartusers;
SELECT COUNT(*) FROM dwh.datamartcountries;
```

If counts are 0, re-run the datamart population scripts.

### ETL Fails to Start

Check that:

- Database connection is configured correctly
- Base tables exist (populated by Ingestion system)
- PostgreSQL is running and accessible

### Performance Issues

- Increase `ETL_MAX_PARALLEL_JOBS` in `etc/etl.properties`
- Adjust `ETL_BATCH_SIZE` for better throughput
- Run `VACUUM ANALYZE` on base tables

### Data Integrity Issues

```bash
# Validate data integrity
./bin/dwh/ETL.sh --validate

# Check for orphaned facts (example query)
psql -d osm_notes -c "SELECT COUNT(*) FROM dwh.facts f
  LEFT JOIN dwh.dimension_countries c ON f.dimension_id_country = c.dimension_country_id
  WHERE c.dimension_country_id IS NULL;"
```

## Integration with Ingestion System

This analytics system depends on the **OSM-Notes-Ingestion** ingestion system:

1. **Ingestion** ([OSM-Notes-Ingestion](https://github.com/OSMLatam/OSM-Notes-Ingestion))
   - Downloads notes from OSM Planet and API
   - Populates base tables: `notes`, `note_comments`, `note_comments_text`
   - Manages WMS layer publication

2. **Analytics** (this repository)
   - Reads from base tables
   - Transforms data into star schema
   - Generates datamarts and profiles

**Deployment Order:**

1. Deploy and run Ingestion system first
2. Wait for base tables to be populated
3. Deploy and run Analytics system

## Documentation

- **[DWH Star Schema ERD](docs/DWH_Star_Schema_ERD.md)**: Entity-relationship diagram
- **[Data Dictionary](docs/DWH_Star_Schema_Data_Dictionary.md)**: Complete schema documentation
- **[ETL Enhanced Features](docs/ETL_Enhanced_Features.md)**: Advanced ETL capabilities
- **[CI/CD Guide](docs/CI_CD_Guide.md)**: CI/CD workflows and git hooks
- **[Testing Guide](tests/README.md)**: Complete testing documentation

## Configuration

### Database Configuration (`etc/properties.sh`)

```bash
# Database configuration
DBNAME="osm_notes"
DB_USER="myuser"

# Processing configuration
LOOP_SIZE="10000"
MAX_THREADS="4"
```

### ETL Configuration (`etc/etl.properties`)

```bash
# Performance
ETL_BATCH_SIZE=1000
ETL_PARALLEL_ENABLED=true
ETL_MAX_PARALLEL_JOBS=4

# Resource Control
MAX_MEMORY_USAGE=80
MAX_DISK_USAGE=90
ETL_TIMEOUT=7200

# Recovery
ETL_RECOVERY_ENABLED=true

# Validation
ETL_VALIDATE_INTEGRITY=true
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.

## License

See [LICENSE](LICENSE) for license information.

## Acknowledgments

- **Andres Gomez (@AngocA)**: Main developer
- **Jose Luis Ceron Sarria**: Architecture design and infrastructure
- **OSM Community**: For the valuable notes data

## Related Projects

- **[OSM-Notes-Ingestion](https://github.com/OSMLatam/OSM-Notes-Ingestion)**: Ingestion and WMS
  system
- **OpenStreetMap**: [https://www.openstreetmap.org](https://www.openstreetmap.org)

## Support

- Create an issue in this repository
- Check the documentation in the `docs/` directory
- Review logs for error messages

## Version

Current Version: 2025-10-14

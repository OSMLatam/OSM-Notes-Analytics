# OSM-Notes-Analytics

![Tests](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Tests/badge.svg)
![Quality Checks](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Quality%20Checks/badge.svg)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-12%2B-blue)](https://www.postgresql.org/)
[![PostGIS](https://img.shields.io/badge/PostGIS-3.0%2B-green)](https://postgis.net/)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-orange)](https://www.gnu.org/software/bash/)

Data Warehouse, ETL, and Analytics for OpenStreetMap Notes

## Overview

This repository contains the analytics and data warehouse components for the OSM Notes profiling system. It provides ETL (Extract, Transform, Load) processes, a star schema data warehouse, and datamarts for analyzing OSM notes data.

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
- **OSM Notes Ingestion Database**: This analytics system reads from the base notes tables populated by the [OSM-Notes-profile](https://github.com/angoca/OSM-Notes-profile) ingestion system

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

### 1. Clone the Repository

```bash
git clone https://github.com/OSMLatam/OSM-Notes-Analytics.git
cd OSM-Notes-Analytics
```

### 2. Configure Database Connection

Edit `etc/properties.sh` with your database credentials:

```bash
# Database configuration
DBNAME="osm_notes"          # Same database as Ingestion
DB_USER="myuser"
```

### 3. Configure ETL Settings

Edit `etc/etl.properties` to customize ETL behavior:

```bash
# Performance Configuration
ETL_BATCH_SIZE=1000
ETL_PARALLEL_ENABLED=true
ETL_MAX_PARALLEL_JOBS=4
```

### 4. Run the ETL Process

```bash
# Initial DWH creation
./bin/dwh/ETL.sh --create

# Incremental updates (run periodically)
./bin/dwh/ETL.sh --incremental
```

### 5. Update Datamarts

```bash
# Update country datamart
./bin/dwh/datamartCountries/datamartCountries.sh

# Update user datamart (runs incrementally)
./bin/dwh/datamartUsers/datamartUsers.sh
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
│   │   └── datamart*/     # Datamart population scripts
│   └── *.sh               # Common function libraries
├── etc/                    # Configuration files
│   ├── properties.sh      # Database configuration
│   └── etl.properties     # ETL configuration
├── sql/                    # SQL scripts
│   └── dwh/               # DWH DDL and procedures
│       ├── ETL_*.sql      # ETL scripts
│       ├── Staging_*.sql  # Staging procedures
│       └── datamart*/     # Datamart SQL
├── tests/                  # Test suites
│   ├── unit/              # Unit tests
│   └── integration/       # Integration tests
├── docs/                   # Documentation
│   ├── DWH_Star_Schema_ERD.md
│   ├── DWH_Star_Schema_Data_Dictionary.md
│   └── ETL_Enhanced_Features.md
└── lib/                    # Shared libraries
    └── bash_logger.sh     # Logging library
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

## Troubleshooting

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

# Check for orphaned facts
psql -d osm_notes -f sql/dwh/validate_integrity.sql
```

## Integration with Ingestion System

This analytics system depends on the **OSM-Notes-profile** ingestion system:

1. **Ingestion** ([OSM-Notes-profile](https://github.com/angoca/OSM-Notes-profile))

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
- **[Testing Guide](docs/Testing_Guide.md)**: Testing guidelines and workflows

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

- **[OSM-Notes-profile](https://github.com/angoca/OSM-Notes-profile)**: Ingestion and WMS system
- **OpenStreetMap**: [https://www.openstreetmap.org](https://www.openstreetmap.org)

## Support

- Create an issue in this repository
- Check the documentation in the `docs/` directory
- Review logs for error messages

## Version

Current Version: 2025-10-13

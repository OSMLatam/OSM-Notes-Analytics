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

## Recommended Reading Path

**New to the project?** Follow this reading path to understand the system (~1.5-2 hours):

### For New Users

1. **Start Here** (20 min)
   - Read this README.md (you're here!)
   - Understand the project purpose and main features
   - Review the Quick Start guide below

2. **Project Context** (30 min)
   - Read [docs/Rationale.md](docs/Rationale.md) - Why this project exists
   - Understand the problem it solves and design decisions

3. **System Architecture** (30 min)
   - Read [docs/DWH_Star_Schema_ERD.md](docs/DWH_Star_Schema_ERD.md) - Data warehouse structure
   - Understand star schema design and table relationships

4. **Getting Started** (30 min)
   - Read [bin/dwh/ENTRY_POINTS.md](bin/dwh/ENTRY_POINTS.md) - Which scripts to use
   - Review [bin/dwh/ENVIRONMENT_VARIABLES.md](bin/dwh/ENVIRONMENT_VARIABLES.md) - Configuration
   - Follow the Quick Start guide in this README

5. **Troubleshooting** (10 min)
   - Bookmark [docs/Troubleshooting_Guide.md](docs/Troubleshooting_Guide.md) - Common issues and solutions

**Total time: ~2 hours** for a complete overview.

### For Developers

1. **Foundation** (1 hour)
   - [docs/Rationale.md](docs/Rationale.md) - Project context (30 min)
   - [docs/DWH_Star_Schema_ERD.md](docs/DWH_Star_Schema_ERD.md) - Data model (30 min)

2. **Implementation** (1 hour)
   - [docs/ETL_Enhanced_Features.md](docs/ETL_Enhanced_Features.md) - ETL capabilities (30 min)
   - [bin/dwh/ENTRY_POINTS.md](bin/dwh/ENTRY_POINTS.md) - Script entry points (15 min)
   - [bin/dwh/ENVIRONMENT_VARIABLES.md](bin/dwh/ENVIRONMENT_VARIABLES.md) - Configuration (15 min)

3. **Development Workflow** (45 min)
   - [tests/README.md](tests/README.md) - Testing guide (20 min)
   - [docs/CI_CD_Guide.md](docs/CI_CD_Guide.md) - CI/CD workflows (25 min)

4. **Deep Dive** (as needed)
   - [docs/DWH_Star_Schema_Data_Dictionary.md](docs/DWH_Star_Schema_Data_Dictionary.md) - Complete schema reference
   - [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
   - [docs/README.md](docs/README.md) - Complete documentation index

### For Data Analysts

1. **Data Model** (1 hour)
   - [docs/DWH_Star_Schema_ERD.md](docs/DWH_Star_Schema_ERD.md) - Schema overview (30 min)
   - [docs/DWH_Star_Schema_Data_Dictionary.md](docs/DWH_Star_Schema_Data_Dictionary.md) - Column definitions (30 min)

2. **Data Access** (30 min)
   - [bin/dwh/profile.sh](bin/dwh/profile.sh) - Profile generation
   - [docs/DASHBOARD_ANALYSIS.md](docs/DASHBOARD_ANALYSIS.md) - Available metrics

### For System Administrators

1. **Deployment** (45 min)
   - This README - Setup and deployment (20 min)
   - [bin/dwh/ENTRY_POINTS.md](bin/dwh/ENTRY_POINTS.md) - Script entry points (15 min)
   - [bin/dwh/ENVIRONMENT_VARIABLES.md](bin/dwh/ENVIRONMENT_VARIABLES.md) - Configuration (10 min)

2. **Operations** (1 hour)
   - [docs/ETL_Enhanced_Features.md](docs/ETL_Enhanced_Features.md) - ETL operations (30 min)
   - [docs/DWH_Maintenance_Guide.md](docs/DWH_Maintenance_Guide.md) - Maintenance procedures (30 min)

3. **Troubleshooting** (30 min)
   - [docs/Troubleshooting_Guide.md](docs/Troubleshooting_Guide.md) - Problem resolution

For complete navigation by role, see [docs/README.md](docs/README.md#recommended-reading-paths-by-role).

## Features

- **Star Schema Data Warehouse**: Comprehensive dimensional model for notes analysis
- **Enhanced ETL Process**: Robust ETL with recovery, validation, and monitoring
- **Partitioned Facts Table**: Automatic partitioning by year (2013-2025+)
- **Country Datamart**: Pre-computed analytics by country (70+ metrics)
- **User Datamart**: Pre-computed analytics by user (70+ metrics)
- **Profile Generator**: Generate country and user profiles
- **Advanced Dimensions**:
  - Timezones for local time analysis
  - Seasons based on date and latitude
  - Continents for geographical grouping
  - Application versions tracking
  - SCD2 for username changes
  - Automation level detection
  - User experience levels
  - Hashtags (unlimited via bridge table)
- **Enhanced Metrics** (October 2025):
  - Resolution metrics: avg/median days to resolution, resolution rate
  - Application statistics: mobile/desktop apps count, most used app
  - Content quality: comment length, URL/mention detection, engagement metrics
  - Community health: active notes, backlog, age distribution, recent activity
- **Comprehensive Testing**: 168+ automated tests (90%+ function coverage)

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

**What this does:** Downloads the analytics repository to your local machine.

**Verify:** Check that the directory was created:
```bash
ls -la OSM-Notes-Analytics/
# Should show: bin/, docs/, sql/, etc/, lib/, etc.
```

**Note:** If you need the shared libraries (OSM-Notes-Common submodule), initialize it:
```bash
git submodule update --init --recursive
```

#### Step 2: Configure Database Connection

**What this does:** Sets up database connection settings for all scripts.

Create the configuration file from the example:

```bash
cp etc/properties.sh.example etc/properties.sh
nano etc/properties.sh  # or use your preferred editor
```

Edit with your database credentials:

```bash
# Database configuration
DBNAME="osm_notes"          # Same database as Ingestion
DB_USER="myuser"           # Your PostgreSQL user
```

**Verify configuration:**
```bash
# Test database connection
psql -d "${DBNAME:-osm_notes}" -U "${DB_USER:-myuser}" -c "SELECT version();"
# Should show PostgreSQL version information
```

**Expected output:**
```
PostgreSQL 12.x or higher
```

**Troubleshooting:**
- If connection fails, check PostgreSQL is running: `sudo systemctl status postgresql`
- Verify database exists: `psql -l | grep osm_notes`
- Check user permissions: `psql -d osm_notes -c "SELECT current_user;"`

#### Step 3: Verify Base Tables

**What this does:** Ensures the base data from OSM-Notes-Ingestion exists before running ETL.

**Why this matters:** The analytics system reads from base tables populated by the ingestion system. Without this data, ETL cannot run.

Check that base tables exist and have data:

```bash
# Check notes table
psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM notes;"

# Check note_comments table
psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM note_comments;"

# Check note_comments_text table
psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM note_comments_text;"
```

**Expected output:**
```
 count
-------
 1234567
(1 row)
```

Each query should return a number > 0. If any table is empty or doesn't exist, you need to run the [OSM-Notes-Ingestion](https://github.com/OSMLatam/OSM-Notes-Ingestion) system first.

**Troubleshooting:**
- **"relation does not exist"**: Base tables not created. Run OSM-Notes-Ingestion first.
- **Count is 0**: Tables exist but empty. Run OSM-Notes-Ingestion to populate data.
- **Connection error**: Check Step 2 configuration and PostgreSQL service.

#### Step 4: Run the ETL Process

**What this does:** Transforms base data into a star schema data warehouse with pre-computed analytics.

**Why this matters:** The ETL process creates the dimensional model that enables fast analytical queries and generates the datamarts used for profiles and dashboards.

The ETL creates the data warehouse (schema `dwh`) with:
- Fact tables (partitioned by year for optimal performance)
- Dimension tables (users, countries, dates, etc.)
- All necessary transformations
- **Automatically updates datamarts**

**Initial Load** (first time, complete data):
```bash
cd bin/dwh
./ETL.sh --create
```

**Expected output:**
```
[INFO] Preparing environment.
[INFO] Process: From scratch.
[WARN] Starting process.
[INFO] Creating base tables...
[INFO] Processing years in parallel...
[INFO] Using 4 threads for parallel processing
[INFO] Processing year 2013...
[INFO] Processing year 2014...
...
[INFO] Consolidating partitions...
[INFO] Updating datamarts...
[WARN] Ending process.
```

**Incremental Update** (regular operations, new data only):
```bash
cd bin/dwh
./ETL.sh --incremental
```

**Expected output:**
```
[INFO] Preparing environment.
[INFO] Process: Incremental update.
[WARN] Starting process.
[INFO] Processing new data since last run...
[INFO] Updated 1234 facts
[INFO] Updating datamarts...
[WARN] Ending process.
```

**Time estimates:**
- **Initial load**: ~30 hours (processes all years from 2013 to present)
- **Incremental update**: 5-15 minutes (depends on new data volume)

**Monitor progress:**
```bash
# Follow ETL logs in real-time
tail -40f $(ls -1rtd /tmp/ETL_* | tail -1)/ETL.log
```

**What the ETL does automatically:**
- Creates schema `dwh` with all tables
- Creates automatic partitions for facts table (2013-2025+)
- Populates dimension tables
- Loads facts from note_comments
- Creates indexes and constraints
- Updates datamarts (countries and users)
- Creates specialized views for hashtag analytics
- Calculates automation levels for users
- Updates experience levels for users
- Creates note activity metrics (comment counts, reopenings)

**Troubleshooting:**
- **ETL fails immediately**: Check base tables exist (Step 3)
- **"Out of memory"**: Reduce `ETL_MAX_PARALLEL_JOBS` in `etc/etl.properties`
- **Takes too long**: Increase parallelism or check system resources
- **See [Troubleshooting Guide](docs/Troubleshooting_Guide.md#etl-issues) for more solutions**

#### Step 5: Verify DWH Creation

**What this does:** Confirms the data warehouse was created successfully with data.

**Why this matters:** Verifies ETL completed successfully before proceeding to datamarts.

Check that the data warehouse was created:

```bash
# Check schema exists
psql -d "${DBNAME:-osm_notes}" -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'dwh';"
```

**Expected output:**
```
 schema_name
-------------
 dwh
(1 row)
```

```bash
# Check tables exist (should show many tables)
psql -d "${DBNAME:-osm_notes}" -c "SELECT tablename FROM pg_tables WHERE schemaname = 'dwh' ORDER BY tablename;"
```

**Expected output:**
```
        tablename
------------------------
 dimension_applications
 dimension_countries
 dimension_days
 dimension_users
 facts
 facts_2013
 facts_2014
 ...
(20+ rows)
```

```bash
# Check fact counts (should be > 0)
psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM dwh.facts;"
psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM dwh.dimension_users;"
psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM dwh.dimension_countries;"
```

**Expected output:**
```
  count
---------
 1234567
(1 row)
```

**Troubleshooting:**
- **Schema doesn't exist**: ETL didn't complete. Check logs and re-run ETL.
- **Tables missing**: ETL failed partway through. Check error logs.
- **Count is 0**: ETL ran but no data loaded. Check base tables have data (Step 3).

#### Step 6: Create and Populate Datamarts

**What this does:** Creates pre-computed analytics tables for fast querying.

**Why this matters:** Datamarts contain pre-aggregated metrics (70+ per user/country) that enable instant profile generation without expensive queries.

**✅ Datamarts are automatically updated during ETL execution. No manual step needed!**

The datamarts aggregate data for quick access and are automatically populated after ETL completes.

**Verify datamarts were created automatically:**
```bash
# Check datamart tables exist
psql -d "${DBNAME:-osm_notes}" -c "SELECT tablename FROM pg_tables WHERE schemaname = 'dwh' AND tablename LIKE 'datamart%';"
```

**Expected output:**
```
     tablename
------------------
 datamartcountries
 datamartglobal
 datamartusers
(3 rows)
```

**Manual Update** (only if needed, or for incremental updates):
```bash
# Update users datamart
cd bin/dwh/datamartUsers
./datamartUsers.sh
```

**Expected output:**
```
[INFO] Starting process.
[INFO] Processing 500 users...
[INFO] Updated 500 users
[WARN] Ending process.
```

```bash
# Update countries datamart
cd bin/dwh/datamartCountries
./datamartCountries.sh
```

**Expected output:**
```
[INFO] Starting process.
[INFO] Processing countries...
[INFO] Updated 195 countries
[WARN] Ending process.
```

**Note**: Datamarts process incrementally (only modified entities) for optimal performance.

**Troubleshooting:**
- **Datamart tables don't exist**: ETL didn't complete datamart update. Run manually.
- **Count is 0**: Datamarts empty. Run datamart scripts manually.
- **See [Troubleshooting Guide](docs/Troubleshooting_Guide.md#datamart-issues) for more solutions**

#### Step 7: Verify Datamart Creation

**What this does:** Confirms datamarts are populated with data.

**Why this matters:** Ensures datamarts have data before generating profiles or exporting to JSON.

```bash
# Check datamart tables exist
psql -d "${DBNAME:-osm_notes}" -c "SELECT tablename FROM pg_tables WHERE schemaname = 'dwh' AND tablename LIKE 'datamart%';"
```

**Expected output:**
```
     tablename
------------------
 datamartcountries
 datamartglobal
 datamartusers
(3 rows)
```

```bash
# Check counts (should be > 0)
psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM dwh.datamartusers;"
psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM dwh.datamartcountries;"
```

**Expected output:**
```
 count
-------
  5000
(1 row)
```

```bash
# View sample user data
psql -d "${DBNAME:-osm_notes}" -c "SELECT user_id, username, history_whole_open, history_whole_closed FROM dwh.datamartusers LIMIT 5;"
```

**Expected output:**
```
 user_id | username | history_whole_open | history_whole_closed
---------+----------+--------------------+---------------------
    1234 | AngocA   |                150 |                 120
    5678 | User2    |                 50 |                  45
    ...
(5 rows)
```

```bash
# View sample country data
psql -d "${DBNAME:-osm_notes}" -c "SELECT country_id, country_name_en, history_whole_open, history_whole_closed FROM dwh.datamartcountries LIMIT 5;"
```

**Expected output:**
```
 country_id | country_name_en | history_whole_open | history_whole_closed
------------+------------------+--------------------+---------------------
          1 | Colombia         |               5000 |                4500
          2 | Germany          |               8000 |                7500
    ...
(5 rows)
```

**Troubleshooting:**
- **Count is 0**: Datamarts not populated. Run datamart scripts (Step 6).
- **Tables don't exist**: ETL didn't create datamarts. Check ETL logs.
- **See [Troubleshooting Guide](docs/Troubleshooting_Guide.md#datamart-issues) for more solutions**

#### Step 8: Export to JSON (Optional)

**What this does:** Exports datamart data to JSON files for OSM-Notes-Viewer (sister project) consumption.

**Why this matters:** The web viewer reads pre-computed JSON files instead of querying the database directly, enabling fast static hosting.

Once datamarts are populated, export to JSON:

```bash
cd bin/dwh
./exportDatamartsToJSON.sh
```

**Expected output:**
```
[INFO] Starting export process...
[INFO] Exporting users datamart...
[INFO] Exported 5000 users
[INFO] Exporting countries datamart...
[INFO] Exported 195 countries
[INFO] Validating JSON files...
[INFO] All files validated successfully
[INFO] Moving files to output directory...
[INFO] Export completed successfully
```

**Verify export:**
```bash
# Check output directory
ls -lh ./output/json/

# Check user files
ls -lh ./output/json/users/ | head -10

# Check country files
ls -lh ./output/json/countries/ | head -10

# Check index files
ls -lh ./output/json/indexes/
```

**Expected structure:**
```
output/json/
├── users/
│   ├── 1234.json
│   ├── 5678.json
│   └── ...
├── countries/
│   ├── 1.json
│   ├── 2.json
│   └── ...
├── indexes/
│   ├── users.json
│   └── countries.json
└── metadata.json
```

**Export Features:**
- **Atomic writes**: Files generated in temporary directory, validated, then moved atomically
- **Schema validation**: Each JSON file validated against schemas before export
- **Fail-safe**: On validation failure, keeps existing files and logs error
- **No partial updates**: Either all files are valid and moved, or none

**Troubleshooting:**
- **Export is empty**: Check datamarts have data (Step 7)
- **Validation fails**: Check schema files in `lib/osm-common/schemas/`
- **Permission errors**: Check `./output/json/` directory is writable
- **See [Troubleshooting Guide](docs/Troubleshooting_Guide.md#export-issues) for more solutions**

See [JSON Export Documentation](bin/dwh/export_json_readme.md) and [Atomic Validation Export](docs/ATOMIC_VALIDATION_EXPORT.md) for complete details.

### Quick Troubleshooting

If you encounter issues during setup, here are quick solutions:

**Problem: "Schema 'dwh' does not exist"**
- **Solution**: Run `./bin/dwh/ETL.sh --create` first

**Problem: "Base tables do not exist"**
- **Solution**: Run [OSM-Notes-Ingestion](https://github.com/OSMLatam/OSM-Notes-Ingestion) first to populate base tables

**Problem: "Cannot connect to database"**
- **Solution**: Check `etc/properties.sh` configuration and PostgreSQL service status

**Problem: "ETL takes too long"**
- **Solution**: Increase `ETL_MAX_PARALLEL_JOBS` in `etc/etl.properties` or reduce `ETL_BATCH_SIZE`

**Problem: "Datamart tables empty"**
- **Solution**: Run datamart scripts manually: `./bin/dwh/datamartUsers/datamartUsers.sh` and `./bin/dwh/datamartCountries/datamartCountries.sh`

**Problem: "JSON export fails validation"**
- **Solution**: Check datamarts have data and schema files exist in `lib/osm-common/schemas/`

For comprehensive troubleshooting, see [Troubleshooting Guide](docs/Troubleshooting_Guide.md).

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

# Note: The export script validates all JSON files before moving them to the final destination.
# If validation fails, it keeps existing files and exits with an error, ensuring data integrity.
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

# Export to JSON and push to GitHub Pages (every 15 minutes, after datamarts update)
# This script exports JSON files and automatically deploys them to GitHub Pages
45 2 * * * ~/OSM-Notes-Analytics/bin/dwh/exportAndPushToGitHub.sh
```

### Complete Workflow with JSON Export

For a complete automated pipeline that includes JSON export with validation:

```bash
# Create wrapper script: /opt/osm-analytics/update-and-export.sh
#!/bin/bash
cd /opt/osm-analytics/OSM-Notes-Analytics

# ETL incremental update
./bin/dwh/ETL.sh --incremental || exit 1

# Update datamarts
./bin/dwh/datamartUsers/datamartUsers.sh || exit 1
./bin/dwh/datamartCountries/datamartCountries.sh || exit 1

# Export to JSON and push to GitHub Pages
# The script exports JSON files and automatically deploys them to GitHub Pages
./bin/dwh/exportAndPushToGitHub.sh || exit 1

# If we get here, all files are valid and exported
echo "SUCCESS: All exports validated and moved to destination"
```

Then schedule this wrapper:

```bash
# Run complete pipeline every 15 minutes
*/15 * * * * /opt/osm-analytics/update-and-export.sh >> /var/log/osm-analytics.log 2>&1
```

**Key features of JSON export:**
- ✅ Atomic writes: Files are generated in temporary directory first
- ✅ Schema validation: Each JSON file is validated before final export
- ✅ Fail-safe: On validation failure, keeps existing files and exits with error
- ✅ No partial updates: Either all files are valid and moved, or none

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
    ├── osm-common/         # OSM-Notes-Common submodule (Git submodule)
    │   ├── bash_logger.sh
    │   ├── commonFunctions.sh
    │   ├── validationFunctions.sh
    │   ├── errorHandlingFunctions.sh
    │   ├── consolidatedValidationFunctions.sh
    │   └── schemas/        # JSON schemas for validation
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

- **`datamart_countries`**: Pre-computed country analytics (70+ metrics)
  - Historical metrics: notes opened/closed by country
  - Resolution metrics: avg/median days to resolution, resolution rate
  - Application statistics: mobile/desktop app usage, most used app
  - Content quality: comment length, URLs, mentions, engagement
  - Community health: active notes, backlog size, age distribution
  - Hashtag analysis: top hashtags, usage patterns
  
- **`datamart_users`**: Pre-computed user analytics (70+ metrics)
  - Historical metrics: notes opened/closed by user
  - Resolution metrics: avg/median days to resolution, resolution rate
  - Application statistics: mobile/desktop app usage
  - Content quality: comment length, URLs, mentions, engagement
  - Community health: active notes, recent activity
  - Automation level: human/automated detection
  - Experience level: beginner to legendary contributor

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

Check for orphaned facts (example query):
```bash
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

## Project Ecosystem

This analytics project is part of a larger ecosystem for OSM Notes analysis:

### Repository Structure

The OSM Notes ecosystem consists of three sister projects at the same organizational level:

```
OSMLatam/
├── OSM-Notes-Ingestion/     # Data ingestion from OSM API/Planet
├── OSM-Notes-Analytics/     # Data Warehouse & ETL (this repository)
├── OSM-Notes-Viewer/        # Web frontend visualization (web application)
└── OSM-Notes-Common/        # Shared Bash libraries (Git submodule)
```

**All three projects are independent repositories at the same level**, working together to provide a complete OSM Notes analysis solution.

### How Projects Work Together

```
┌─────────────────────────────────────┐
│  OSM-Notes-Ingestion                 │
│  - Downloads OSM notes                │
│  - Populates base tables              │
│  - Publishes WMS layer                │
└──────────────┬────────────────────────┘
               │ feeds data
               ▼
┌─────────────────────────────────────┐
│  OSM-Notes-Analytics                │
│  - ETL process (this repo)           │
│  - Star schema data warehouse        │
│  - Datamarts for analytics           │
│  - Export to JSON                    │
└──────────────┬────────────────────────┘
               │ exports JSON data
               ▼
┌─────────────────────────────────────┐
│  OSM-Notes-Viewer                    │
│  - Web dashboard                     │
│  - Interactive visualizations        │
│  - User & country profiles           │
└──────────────────────────────────────┘

       ┌─────────────────────┐
       │  OSM-Notes-Common/  │
       │  - Shared libraries │
       │  - bash_logger.sh   │
       │  - validation.sh   │
       │  - commonFunctions  │
       └─────────────────────┘
         ↑ used by all (via submodule)
```

### Related Projects

- **[OSM-Notes-Ingestion](https://github.com/OSMLatam/OSM-Notes-Ingestion)**: 
  - Downloads notes from OSM Planet and API
  - Populates base tables: `notes`, `note_comments`, `users`, `countries`
  - Publishes WMS layer for mapping applications
  - **Deploy this FIRST** - analytics needs base data

- **[OSM-Notes-Viewer](https://github.com/OSMLatam/OSM-Notes-Viewer)** (sister project):
  - Web application (web page) for visualizing analytics
  - Interactive dashboards and visualizations
  - User and country profiles
  - Reads JSON exports from this analytics system
  - **Sister project** at the same organizational level as Ingestion and Analytics

- **[OSM-Notes-Common](https://github.com/OSMLatam/OSM-Notes-Common)** (shared library):
  - Common Bash libraries and utilities (Git submodule)
  - Used by Ingestion and Analytics projects
  - Located at `lib/osm-common/` in each project
  - Provides: logging, validation, error handling, common functions, schemas
  - Shared via Git submodule across repositories

- **OpenStreetMap**: [https://www.openstreetmap.org](https://www.openstreetmap.org)

## Support

- Create an issue in this repository
- Check the documentation in the `docs/` directory
- Review logs for error messages

## Recent Enhancements (October 2025)

The following major enhancements have been implemented:

### Datamart Enhancements
- **21 new metrics** added to both `datamartCountries` and `datamartUsers`
- **Resolution tracking**: Days to resolution, resolution rates
- **Application analytics**: Mobile vs desktop usage, most popular apps
- **Content quality**: Comment analysis, URL/mention detection
- **Community health**: Active notes, backlog, temporal patterns
- **88+ new automated tests** added to validate all new metrics

### Enhanced Dimensions
- **Automation detection**: Identifies bot/automated notes vs human
- **Experience levels**: Classifies users from newcomer to legendary
- **Note activity metrics**: Tracks accumulated comments and reopenings
- **Hashtag bridge table**: Supports unlimited hashtags per note

### Performance
- **Partitioned facts table**: 10-50x faster date-based queries
- **Specialized indexes**: Optimized for common query patterns
- **Automated maintenance**: VACUUM and ANALYZE on partitions

See `docs/DASHBOARD_ANALYSIS.md` for complete details on available metrics.

## Version

Current Version: 2025-10-26

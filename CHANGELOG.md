# Changelog

All notable changes to this project will be documented in this file.

## [2025-12-15] - PostgreSQL Process Identification Enhancement

### Changed

- **PostgreSQL Application Name**: All scripts now set `PGAPPNAME` to display script names instead of "psql" in `pg_stat_activity`
  - `ETL.sh` processes show as `ETL` instead of `psql`
  - Parallel year loads show as `ETL-year-2017`, `ETL-year-2018`, etc. for better identification
  - `datamartUsers.sh` shows as `datamartUsers` with specific names for parallel batches (`datamartUsers-batch-1-1000`, `datamartUsers-user-123`)
  - `datamartCountries.sh` shows as `datamartCountries`
  - `datamartGlobal.sh` shows as `datamartGlobal`
- Improved process monitoring: All PostgreSQL connections now use descriptive application names for easier identification in `pg_stat_activity`

### Technical Details

- Added `__psql_with_appname()` helper function to all main scripts
- Function sets `PGAPPNAME` environment variable before executing `psql`
- Defaults to script basename (without `.sh` extension) if no custom name provided
- Parallel processes use descriptive names (e.g., `ETL-year-2017`, `datamartUsers-batch-1-1000`)

### Files Modified

- `bin/dwh/ETL.sh`: Added helper function and updated all `psql` calls
- `bin/dwh/datamartUsers/datamartUsers.sh`: Added helper function and updated all `psql` calls
- `bin/dwh/datamartCountries/datamartCountries.sh`: Added helper function and updated all `psql` calls
- `bin/dwh/datamartGlobal/datamartGlobal.sh`: Added helper function and updated all `psql` calls

### Documentation

- Updated `docs/Troubleshooting_Guide.md`: Enhanced monitoring queries to use new application names

---

## [2025-12-14] - User Behavior Metric Completion

### Added

- **User Behavior Metric**: Completed user behavior analysis with final missing metric
  - `notes_opened_but_not_closed_by_user` (INTEGER): Number of notes opened by user but never closed by same user (closed by others or still open)

### Changed

- Updated `datamartUsers` table: Added 1 new column (78+ total metrics)
- Updated datamartUsers procedure to calculate new metric automatically
- Updated documentation: `docs/Metric_Definitions.md`, `docs/Dashboard_Analysis.md`, `README.md`
- Updated metric counts: 77+ → 78+ metrics for users
- Updated `ToDo/ActionPlan.md`: Marked user behavior patterns as COMPLETED

### Testing

- Added 4 new tests for `notes_opened_but_not_closed_by_user` metric
- Tests validate column existence, non-negative values, logical constraints, and calculability
- Total test count: 166 → 170+ tests

### Technical Details

- Metric calculated using NOT EXISTS subquery to find notes opened by user but not closed by same user
- Includes notes closed by others and notes still open
- Relationship: `history_whole_open = notes_resolved_count + notes_opened_but_not_closed_by_user + notes_still_open_count`

### Documentation

- Added complete metric definition in `docs/Metric_Definitions.md`:
  - Section 8.4: `notes_opened_but_not_closed_by_user` with business definition, formula, interpretation, and use cases

---

## [2025-12-14] - High Priority Metrics Implementation

### Added

- **Application Usage Trends**: New metrics to track application usage patterns over time
  - `application_usage_trends` (JSON): Application usage trends by year for countries and users
  - `version_adoption_rates` (JSON): Version adoption rates by year for countries and users
- **Community Health Metrics** (Countries):
  - `notes_health_score` (DECIMAL): Overall notes health score (0-100) based on resolution rate, backlog size, and recent activity
  - `new_vs_resolved_ratio` (DECIMAL): Ratio of new notes created vs resolved notes (last 30 days)
- **User Behavior Metrics** (Users):
  - `user_response_time` (DECIMAL): Average time in days from note open to first comment by user
  - `days_since_last_action` (INTEGER): Days since user last performed any action
  - `collaboration_patterns` (JSON): Collaboration metrics including mentions given/received, replies count, and collaboration score

### Changed

- Updated `datamartCountries` table: Added 4 new columns (77+ total metrics)
- Updated `datamartUsers` table: Added 5 new columns (77+ total metrics)
- Updated datamart procedures to calculate new metrics automatically
- Updated documentation: `docs/Dashboard_Analysis.md`, `docs/Metric_Definitions.md`, `README.md`
- Updated metric counts: 70+ → 77+ metrics per user/country

### Testing

- Added comprehensive test suite: `tests/unit/bash/datamart_high_priority_metrics.test.bats`
- 23 new tests covering all new metrics
- Tests validate column existence, data types, ranges, and JSON structure
- Total test count: 168+ → 191+ tests

### Technical Details

- All new metrics are calculated during datamart update procedures
- JSON metrics (`application_usage_trends`, `version_adoption_rates`, `collaboration_patterns`) use PostgreSQL JSON aggregation
- Health score uses weighted formula: resolution_rate (40%) + backlog_ratio (30%) + recent_activity (30%)
- New metrics are automatically exported to JSON (schemas have `additionalProperties: true`)
- Schema hash detection will automatically detect changes for versioning

### Documentation

- Added complete metric definitions in `docs/Metric_Definitions.md`:
  - Section 3.5: `application_usage_trends`
  - Section 3.6: `version_adoption_rates`
  - Section 7.6: `notes_health_score`
  - Section 7.7: `new_vs_resolved_ratio`
  - Section 8: User Behavior Metrics (3 new metrics)
- Updated `docs/Dashboard_Analysis.md` with implementation status
- Updated `README.md` with new metric counts

### Files Modified

- `sql/dwh/datamartCountries/datamartCountries_12_createDatamarCountriesTable.sql`
- `sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql`
- `sql/dwh/datamartUsers/datamartUsers_12_createDatamartUsersTable.sql`
- `sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql`
- `tests/unit/bash/datamart_high_priority_metrics.test.bats` (new)
- `docs/Dashboard_Analysis.md`
- `docs/Metric_Definitions.md`
- `README.md`

## [2025-12-13] - Hybrid Strategy Improvements and Bug Fixes

### Fixed

- Fixed FDW setup logic to only configure Foreign Data Wrappers when Ingestion and Analytics databases are different
- Improved error handling when databases are the same (skips FDW setup to avoid conflicts)
- Enhanced database comparison logic in ETL incremental processing

### Changed

- Updated `sql/dwh/ETL_60_setupFDW.sql` version to 2025-12-13
- Improved logging in ETL process to show database configuration before FDW setup
- Enhanced `bin/dwh/copyBaseTables.sh` and `bin/dwh/dropCopiedBaseTables.sh` with better error handling and code formatting
- Updated test suite `tests/unit/bash/hybrid_strategy_copy_fdw.test.bats` with improved robustness and error handling

### Technical Details

- ETL now compares `DBNAME_INGESTION` and `DBNAME_DWH` before attempting FDW setup
- When databases are the same, FDW setup is skipped to prevent SQL errors
- Added explicit logging for database configuration to aid debugging

## [2025-10-27] - Hybrid Strategy: Database Separation with Table Copying and Remote Access

### Added

- Hybrid strategy for separating Ingestion and Analytics databases
- `bin/dwh/copyBaseTables.sh`: Script to copy base tables from Ingestion DB to Analytics DB for initial load
- `bin/dwh/dropCopiedBaseTables.sh`: Script to drop copied tables after DWH population
- `sql/dwh/ETL_60_setupFDW.sql`: SQL script to configure Foreign Data Wrappers (FDW) for incremental processing
- Support for separate database configuration:
  - `DBNAME_INGESTION` and `DBNAME_DWH` variables for separate databases
  - `DB_USER_INGESTION` and `DB_USER_DWH` variables for different database users
  - `FDW_INGESTION_*` variables for Foreign Data Wrappers configuration (host, dbname, port, user, password)
- Automatic detection of first execution vs incremental execution in ETL process
- Foreign Data Wrappers (postgres_fdw) support for remote table access
- Foreign tables for: `notes`, `note_comments`, `note_comments_text`, `users`, `countries`
- Performance optimization: Copy tables locally for initial load (avoids millions of cross-database queries)
- Row count verification after table copying
- Automatic index recreation on copied tables
- Comprehensive test suite: `tests/unit/bash/hybrid_strategy_copy_fdw.test.bats`

### Changed

- ETL process now supports hybrid execution mode:
  - Initial load: Copies base tables locally, processes without FDW overhead
  - Incremental execution: Uses Foreign Data Wrappers for accessing new data from remote database
- Improved ETL performance for initial loads by using local table copies instead of remote queries
- ETL automatically detects first execution and triggers table copying workflow
- ETL automatically detects incremental execution and configures FDW if needed

### Technical Details

- Copy method uses PostgreSQL COPY with piping for maximum performance (estimated 10-40 minutes for all tables)
- Tables copied in dependency order: `countries`, `users`, `notes`, `note_comments`, `note_comments_text`
- Foreign Data Wrappers configured with `fetch_size='10000'` and `use_remote_estimate='true'` for optimization
- Backward compatibility: Falls back to single database mode if separate databases are not configured
- Supports peer authentication when database users are not explicitly provided

### Documentation

- Added `docs/Hybrid_Strategy_Copy_FDW.md`: Complete guide for hybrid strategy implementation
- Added `docs/Hybrid_ETL_Execution_Guide.md`: Guide for testing hybrid ETL execution
- Updated `docs/README.md` with references to hybrid strategy documentation

### Testing

- Added unit tests for hybrid strategy: `tests/unit/bash/hybrid_strategy_copy_fdw.test.bats`
- Tests cover table copying, FDW setup, and incremental processing scenarios
- Tests validate row count verification and error handling


# Changelog

All notable changes to this project will be documented in this file.

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


# Contributing to OSM-Notes-Analytics

Thank you for your interest in contributing to the OSM-Notes-Analytics project!
This document provides comprehensive guidelines for contributing to this
OpenStreetMap notes analytics and data warehouse system.

## Table of Contents

- [Code Standards](#code-standards)
- [Development Workflow](#development-workflow)
- [Testing Requirements](#testing-requirements)
- [File Organization](#file-organization)
- [Naming Conventions](#naming-conventions)
- [Code Documentation](#code-documentation)
- [Quality Assurance](#quality-assurance)
- [Pull Request Process](#pull-request-process)

## Code Standards

### Bash Script Standards

All bash scripts must follow these standards:

#### Required Header Structure

```bash
#!/bin/bash

# Brief description of the script functionality
#
# This script [describe what it does]
# * [key feature 1]
# * [key feature 2]
# * [key feature 3]
#
# These are some examples to call this script:
# * [example 1]
# * [example 2]
#
# This is the list of error codes:
# [list all error codes with descriptions]
#
# For contributing, please execute these commands before submitting:
# * shellcheck -x -o all [SCRIPT_NAME].sh
# * shfmt -w -i 1 -sr -bn [SCRIPT_NAME].sh
#
# Author: Andres Gomez (AngocA)
# Version: [YYYY-MM-DD]
VERSION="[YYYY-MM-DD]"
```

#### Required Script Settings

```bash
#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with a non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E
```

#### Variable Declaration Standards

- **Global variables**: Use `declare -r` for readonly variables
- **Local variables**: Use `local` declaration
- **Integer variables**: Use `declare -i`
- **Arrays**: Use `declare -a`
- **All variables must be braced**: `${VAR}` instead of `$VAR`

#### Function Naming Convention

- **All functions must start with double underscore**: `__function_name`
- **Use descriptive names**: `__download_planet_notes`, `__validate_xml_file`
- **Include function documentation**:

```bash
# Downloads the planet notes file from OSM servers.
# Parameters: None
# Returns: 0 on success, non-zero on failure
function __download_planet_notes {
  # Function implementation
}
```

#### Error Handling

- **Define error codes at the top**:

```bash
# Error codes.
# 1: Help message.
declare -r ERROR_HELP_MESSAGE=1
# 241: Library or utility missing.
declare -r ERROR_MISSING_LIBRARY=241
# 242: Invalid argument for script invocation.
declare -r ERROR_INVALID_ARGUMENT=242
```

### SQL Standards

#### File Naming Convention

- **Process files**: `processAPINotes_21_createApiTables.sql`
- **ETL files**: `ETL_11_checkDWHTables.sql`
- **Function files**: `functionsProcess_21_createFunctionToGetCountry.sql`
- **Drop files**: `processAPINotes_12_dropApiTables.sql`

#### SQL Code Standards

- **Keywords in UPPERCASE**: `SELECT`, `INSERT`, `UPDATE`, `DELETE`
- **Identifiers in lowercase**: `table_name`, `column_name`
- **Use proper indentation**: 2 spaces
- **Include comments for complex queries**
- **Use parameterized queries when possible**

## Development Workflow

### 1. Environment Setup

Before contributing, ensure you have the required tools:

```bash
# Install development tools
sudo apt-get install shellcheck shfmt bats

# Install database tools
sudo apt-get install postgresql postgis

# Install XML processing tools
sudo apt-get install libxml2-utils xsltproc xmlstarlet

# Install geographic tools
sudo apt-get install gdal-bin ogr2ogr
```

### 2. Project Structure Understanding

Familiarize yourself with the project structure:

- **`bin/`**: Executable scripts (ETL, datamarts, profile generator)
- **`sql/`**: Database scripts (star schema, ETL procedures, datamarts)
- **`tests/`**: Comprehensive testing infrastructure (unit, integration)
- **`docs/`**: System documentation (ERD, data dictionary, guides)
- **`etc/`**: Configuration files (database, ETL settings)
- **`lib/`**: Shared libraries (logging, validation, error handling)
- **`scripts/`**: Utility scripts (setup, hooks, validation)

### 3. Development Process

1. **Create a feature branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Follow the established patterns**:
   - Use existing function names and patterns
   - Follow the error code numbering system
   - Maintain the logging structure
   - Use the established variable naming

3. **Test your changes**:

   ```bash
   # Run quality tests (fast, no database)
   ./tests/run_quality_tests.sh
   
   # Run DWH tests (requires database)
   ./tests/run_dwh_tests.sh
   
   # Run all tests
   ./tests/run_all_tests.sh
   ```

## Testing Requirements

### Overview

All contributions must include comprehensive testing. The project uses BATS testing suites and SQL tests covering all system components, including DWH functionality.

### Test Categories

#### Unit Tests

- **Bash Scripts**: BATS test suites for ETL and datamart scripts
  - `tests/unit/bash/ETL_enhanced.test.bats`
  - `tests/unit/bash/ETL_integration.test.bats`
  - `tests/unit/bash/datamartCountries_integration.test.bats`
  - `tests/unit/bash/datamartUsers_integration.test.bats`
- **SQL Tests**: SQL test suites for DWH functions and procedures
  - `tests/unit/sql/dwh_cleanup.test.sql`
  - `tests/unit/sql/dwh_dimensions_enhanced.test.sql`
  - `tests/unit/sql/dwh_functions_enhanced.test.sql`

#### Integration Tests

- **End-to-End Workflows**: Complete system integration testing
  - `tests/integration/ETL_enhanced_integration.test.bats`
  - `tests/integration/datamart_enhanced_integration.test.bats`

#### Quality Tests

- **Code Quality**: Shellcheck linting, shfmt formatting, code conventions
- **Configuration**: Validation of properties files and SQL syntax
- **Database**: PostgreSQL and PostGIS extension checks

### DWH Enhanced Testing Requirements

When contributing to DWH features, you must include tests for:

#### New Dimensions

- **`dimension_timezones`**: Timezone support testing
- **`dimension_seasons`**: Seasonal analysis testing
- **`dimension_continents`**: Continental grouping testing
- **`dimension_application_versions`**: Application version testing
- **`fact_hashtags`**: Bridge table testing

#### Enhanced Dimensions

- **`dimension_time_of_week`**: Renamed dimension with enhanced attributes
- **`dimension_users`**: SCD2 implementation testing
- **`dimension_countries`**: ISO codes testing
- **`dimension_days`**: Enhanced date attributes testing
- **`dimension_applications`**: Enhanced attributes testing

#### New Functions

- **`get_timezone_id_by_lonlat()`**: Timezone calculation testing
- **`get_season_id()`**: Season calculation testing
- **`get_application_version_id()`**: Application version management testing
- **`get_local_date_id()`**: Local date calculation testing
- **`get_local_hour_of_week_id()`**: Local hour calculation testing

#### Enhanced ETL

- **Staging Procedures**: New columns, SCD2, bridge tables
- **Datamart Compatibility**: Integration with new dimensions
- **Documentation**: Consistency with implementation

### Running Tests

#### Complete Test Suite

```bash
# Run all tests (quality + DWH)
./tests/run_all_tests.sh

# Run quality tests only (fast, no database)
./tests/run_quality_tests.sh

# Run DWH tests only (requires database)
./tests/run_dwh_tests.sh
```

#### Individual Test Categories

```bash
# Unit tests
bats tests/unit/bash/ETL_enhanced.test.bats
bats tests/unit/bash/datamartCountries_integration.test.bats
bats tests/unit/bash/datamartUsers_integration.test.bats

# Integration tests
bats tests/integration/ETL_enhanced_integration.test.bats
bats tests/integration/datamart_enhanced_integration.test.bats

# SQL tests (requires psql and database 'dwh')
psql -d dwh -f tests/unit/sql/dwh_cleanup.test.sql
psql -d dwh -f tests/unit/sql/dwh_dimensions_enhanced.test.sql
psql -d dwh -f tests/unit/sql/dwh_functions_enhanced.test.sql
```

#### Test Validation

```bash
# Validate all code (comprehensive check)
./scripts/validate-all.sh

# Install git hooks for automatic validation
./scripts/install-hooks.sh
```

### Test Documentation

All new tests must be documented in:

- [Tests README](./tests/README.md) - Complete testing guide and test suite documentation

### CI/CD Integration

Tests are automatically run in GitHub Actions workflows:

- **Quality Checks** (`.github/workflows/quality-checks.yml`):
  - Shellcheck linting on all Bash scripts
  - shfmt formatting validation
  - SQL syntax validation
  - Configuration file validation
  - Runs on every push and pull request
  
- **Tests** (`.github/workflows/tests.yml`):
  - Quality tests (no database required)
  - DWH tests (with PostgreSQL/PostGIS setup)
  - Integration tests
  - Runs on push to main branch
  
- **Dependency Check** (`.github/workflows/dependency-check.yml`):
  - Validates required tools are available
  - Checks for outdated dependencies

- **Git Hooks**:
  - **Pre-commit**: Fast checks on staged files only
  - **Pre-push**: Full validation before pushing

### Test Quality Standards

#### Test Requirements

- **Test all new ETL features** (dimensions, functions, procedures)
- **Test all new datamart features** (aggregations, calculations)
- **Test error handling** for edge cases and failures
- **Test data integrity** (referential integrity, constraints)

#### Test Quality

- **Descriptive test names** that explain what is being tested
- **Comprehensive assertions** that validate expected behavior
- **Independent tests** that don't depend on each other
- **Clean up after tests** to avoid side effects

#### Documentation

- **Test descriptions** in the test file comments
- **Setup requirements** documented in test README
- **Expected behavior** explained in assertions
- **Known issues** documented in test comments

## File Organization

### Directory Structure Standards

```text
OSM-Notes-Analytics/
├── bin/                    # Executable scripts
│   └── dwh/               # Data warehouse scripts
│       ├── ETL.sh         # Main ETL process
│       ├── profile.sh     # Profile generator
│       ├── datamartCountries/  # Country datamart
│       └── datamartUsers/      # User datamart
├── sql/                   # Database scripts
│   └── dwh/              # Data warehouse SQL
│       ├── ETL_*.sql     # ETL scripts
│       ├── Staging_*.sql # Staging procedures
│       ├── datamartCountries/  # Country datamart SQL
│       └── datamartUsers/      # User datamart SQL
├── tests/                # Testing infrastructure
│   ├── unit/            # Unit tests
│   │   ├── bash/        # Bash script tests
│   │   └── sql/         # SQL tests
│   ├── integration/     # Integration tests
│   ├── run_all_tests.sh       # Run all tests
│   ├── run_quality_tests.sh   # Quality tests
│   └── run_dwh_tests.sh       # DWH tests
├── scripts/              # Utility scripts
│   ├── install-hooks.sh       # Git hooks
│   ├── setup_analytics.sh     # Initial setup
│   └── validate-all.sh        # Validation
├── docs/                 # Documentation
│   ├── DWH_Star_Schema_ERD.md
│   ├── DWH_Star_Schema_Data_Dictionary.md
│   ├── ETL_Enhanced_Features.md
│   ├── CI_CD_Guide.md
│   └── Testing_*.md
├── etc/                  # Configuration
│   ├── properties.sh     # Database config
│   └── etl.properties    # ETL config
└── lib/                  # Shared libraries
    └── osm-common/       # Common utilities
        ├── bash_logger.sh
        ├── commonFunctions.sh
        ├── validationFunctions.sh
        └── errorHandlingFunctions.sh
```

### File Naming Conventions

#### Script Files

- **Main scripts**: `ETL.sh`, `profile.sh`, `datamartCountries.sh`, `datamartUsers.sh`
- **Utility scripts**: `install-hooks.sh`, `setup_analytics.sh`, `validate-all.sh`
- **Test runners**: `run_all_tests.sh`, `run_quality_tests.sh`, `run_dwh_tests.sh`

#### SQL Files

Follow the naming pattern: `<Component>_<Phase><Step>_<Description>.sql`

- **ETL scripts**: `ETL_22_createDWHTables.sql`, `ETL_25_populateDimensionTables.sql`
- **Staging scripts**: `Staging_31_createBaseStagingObjects.sql`, `Staging_61_loadNotes.sql`
- **Datamart scripts**: `datamartCountries_31_populateDatamartCountriesTable.sql`
- **Phase numbers**: 1x=validation, 2x=creation, 3x=population, 4x=constraints, 5x=finalization, 6x=incremental

#### Test Files

- **Unit tests**: `ETL_enhanced.test.bats`, `datamartCountries_integration.test.bats`
- **Integration tests**: `ETL_enhanced_integration.test.bats`, `datamart_enhanced_integration.test.bats`
- **SQL tests**: `dwh_cleanup.test.sql`, `dwh_dimensions_enhanced.test.sql`

## Naming Conventions

### Variables

- **Global variables**: `UPPERCASE_WITH_UNDERSCORES`
- **Local variables**: `lowercase_with_underscores`
- **Constants**: `UPPERCASE_WITH_UNDERSCORES`
- **Environment variables**: `UPPERCASE_WITH_UNDERSCORES`

### Functions

- **All functions**: `__function_name_with_underscores`
- **Private functions**: `__private_function_name`
- **Public functions**: `__public_function_name`

### Database Objects

- **Tables**: `lowercase_with_underscores`
- **Columns**: `lowercase_with_underscores`
- **Functions**: `function_name_with_underscores`
- **Procedures**: `procedure_name_with_underscores`

## Shared Libraries

### Library Organization

The project uses shared libraries in `lib/osm-common/` to eliminate code duplication and improve maintainability:

#### 1. Logging (`lib/osm-common/bash_logger.sh`)

- **Purpose**: Centralized logging framework with multiple log levels
- **Functions**: `__logt`, `__logd`, `__logi`, `__logw`, `__loge`, `__logf`, `__log_start`, `__log_finish`
- **Usage**: All scripts should source this for consistent logging
- **Log Levels**: TRACE, DEBUG, INFO, WARN, ERROR, FATAL

#### 2. Common Functions (`lib/osm-common/commonFunctions.sh`)

- **Purpose**: Shared utility functions used across scripts
- **Functions**: `__checkPrereqsCommands`, `__waitForJobs`, `__start_logger`
- **Usage**: Source this for common operations like prerequisite checks

#### 3. Validation Functions (`lib/osm-common/validationFunctions.sh`)

- **Purpose**: Validation functions for files, configuration, and database
- **Functions**: `__validate_sql_structure`, `__validate_config_file`, `__validate_database_connection`
- **Usage**: Use these for all validation operations

#### 4. Error Handling (`lib/osm-common/errorHandlingFunctions.sh`)

- **Purpose**: Centralized error handling and traps
- **Functions**: `__trapOn`, `__handle_error`, `__cleanup`
- **Usage**: Set up error traps for robust error handling

#### 5. Implementation Guidelines

- **New Functions**: Add to appropriate library file rather than duplicating
- **Consistent Usage**: All scripts should source and use these libraries
- **Testing**: Test library functions independently

## Code Documentation

### Required Documentation

1. **Script Headers**: Every script must have a comprehensive header (see template above)
2. **Function Documentation**: All functions must be documented with parameters and return values
3. **README Files**: Each major directory has a README.md (bin/, etc/, sql/, tests/, docs/, lib/, scripts/)
4. **SQL Documentation**: Document complex queries, procedures, and functions
5. **Configuration Documentation**: Document all configuration options in etc/README.md
6. **Test Documentation**: Document test purpose, setup, and expected results

### Documentation Standards

#### Script Documentation

```bash
# Brief description of what the script does
#
# Detailed explanation of functionality
# * Key feature 1
# * Key feature 2
# * Key feature 3
#
# Usage examples:
# * Example 1
# * Example 2
#
# Error codes:
# 1: Help message
# 241: Library missing
# 242: Invalid argument
#
# Author: [Your Name]
# Version: [YYYY-MM-DD]
```

#### Function Documentation

```bash
# Brief description of what the function does
# Parameters: [list of parameters]
# Returns: [return value description]
# Side effects: [any side effects]
function __function_name {
  # Implementation
}
```

## Quality Assurance

### Pre-Submission Checklist

Before submitting your contribution, ensure:

- [ ] **Code formatting**: Run `shfmt -w -i 1 -sr -bn` on all bash scripts
- [ ] **Linting**: Run `shellcheck -x -o all` on all bash scripts
- [ ] **Tests**: All tests pass (`./tests/run_tests.sh`)
- [ ] **Documentation**: All new code is documented
- [ ] **Error handling**: Proper error codes and handling
- [ ] **Logging**: Appropriate logging levels and messages
- [ ] **Performance**: No performance regressions
- [ ] **Security**: No security vulnerabilities

### Code Quality Tools

#### Required Tools

```bash
# Format bash scripts
shfmt -w -i 1 -sr -bn script.sh

# Lint bash scripts
shellcheck -x -o all script.sh

# Run tests
./tests/run_tests.sh

# Run advanced tests
./tests/advanced/run_advanced_tests.sh
```

#### Quality Standards

- **ShellCheck**: No warnings or errors
- **shfmt**: Consistent formatting
- **Test Coverage**: Minimum 80% coverage
- **Performance**: No significant performance degradation
- **Security**: No security vulnerabilities

## Pull Request Process

### 1. Preparation

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Make your changes following the standards above**
4. **Test thoroughly**: Run all test suites
5. **Update documentation**: Add/update relevant documentation

### 2. Submission

1. **Commit your changes**:

   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

2. **Push to your fork**:

   ```bash
   git push origin feature/your-feature
   ```

3. **Create a Pull Request** with:
   - **Clear title**: Describe the feature/fix
   - **Detailed description**: Explain what and why
   - **Test results**: Include test output
   - **Screenshots**: If applicable

### 3. Review Process

1. **Automated checks** must pass
2. **Code review** by maintainers
3. **Test verification** by maintainers
4. **Documentation review** for completeness
5. **Final approval** and merge

### 4. Commit Message Standards

Use conventional commit messages:

```text
type(scope): description

[optional body]

[optional footer]
```

**Types**:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Maintenance tasks

**Examples**:

```text
feat(process): add parallel processing for large datasets
fix(sql): correct country boundary import for Austria
docs(readme): update installation instructions
test(api): add integration tests for new endpoints
```

## Getting Help

### Resources

- **Project README**: Main project documentation
- **Directory READMEs**: Specific component documentation
- **Test Examples**: See existing tests for patterns
- **Code Examples**: Study existing scripts for patterns

### Contact

- **Issues**: Use GitHub Issues for bugs and feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Pull Requests**: For code contributions

### Development Environment

#### Database Setup

For local testing, you need PostgreSQL with PostGIS:

```bash
# Create test database
createdb dwh
psql -d dwh -c "CREATE EXTENSION postgis;"
psql -d dwh -c "CREATE EXTENSION btree_gist;"

# Configure connection in tests/properties.sh
DBNAME="dwh"
DB_USER="your_username"
```

### Local Configuration

To avoid accidentally committing local configuration changes:

```bash
# Tell Git to ignore changes to properties files (local development only)
git update-index --assume-unchanged etc/properties.sh
git update-index --assume-unchanged etc/etl.properties

# Verify that the files are now ignored
git ls-files -v | grep '^[[:lower:]]'

# To re-enable tracking (if needed)
git update-index --no-assume-unchanged etc/properties.sh
git update-index --no-assume-unchanged etc/etl.properties
```

This allows you to customize database settings, user names, and ETL configurations for local development without affecting the repository.

## Version Control

### Branch Strategy

- **main**: Production-ready code
- **develop**: Integration branch
- **feature/***: New features
- **bugfix/***: Bug fixes
- **hotfix/***: Critical fixes

### Release Process

1. **Feature complete**: All features implemented and tested
2. **Documentation complete**: All documentation updated
3. **Tests passing**: All test suites pass
4. **Code review**: All changes reviewed
5. **Release**: Tag and release

---

**Thank you for contributing to OSM-Notes-Analytics!**

Your contributions help make OpenStreetMap notes analytics and data warehouse more accessible and
powerful for the community.

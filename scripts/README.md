# Scripts Directory

This directory contains utility scripts for project setup, validation, and development workflow
automation.

## Overview

The scripts in this directory help with:

- Initial project setup and configuration
- Git hooks installation for code quality
- Comprehensive validation before commits and pushes
- Development environment preparation

## Scripts

### 1. setup_analytics.sh

**Purpose:** Initial setup script for configuring the OSM-Notes-Analytics project after cloning.

**Location:** `scripts/setup_analytics.sh`

**Usage:**

```bash
./scripts/setup_analytics.sh
```

**What It Does:**

1. **Checks Prerequisites:**
   - Bash 4.0+
   - PostgreSQL client (psql)
   - PostGIS
   - Git
   - Essential tools (shellcheck, shfmt, bats)

2. **Validates Directory Structure:**
   - Ensures all required directories exist
   - Checks for critical files
   - Validates permissions

3. **Verifies Configuration:**
   - Checks `etc/properties.sh` exists
   - Validates configuration syntax
   - Reviews ETL properties

4. **Tests Database Connection:**
   - Attempts connection to configured database
   - Verifies PostGIS extension
   - Checks schema access

5. **Provides Setup Summary:**
   - Lists missing prerequisites
   - Suggests next steps
   - Shows recommended actions

**Example Output:**

```text
========================================
OSM-Notes-Analytics Setup
========================================

Checking prerequisites...

✓ Bash version: 5.1.16
✓ PostgreSQL client installed
✓ Git installed
⚠ shellcheck not found (optional for development)
✓ BATS installed

Checking directory structure...
✓ bin/ directory exists
✓ etc/ directory exists
✓ sql/ directory exists
✓ tests/ directory exists

Next Steps:
1. Edit etc/properties.sh with your database credentials
2. Run: ./bin/dwh/ETL.sh --create
3. Install git hooks: ./scripts/install-hooks.sh
```

**When to Run:**

- After initial clone
- When setting up a new environment
- To verify installation integrity

### 2. install-hooks.sh

**Purpose:** Installs Git hooks for automated code quality checks.

**Location:** `scripts/install-hooks.sh`

**Usage:**

```bash
./scripts/install-hooks.sh
```

**What It Does:**

Installs two Git hooks:

#### Pre-commit Hook

- **Runs on:** Every `git commit`
- **Duration:** Fast (seconds)
- **Checks:**
  - Shell script syntax (shellcheck)
  - Bash code formatting (shfmt)
  - SQL syntax validation
  - File permissions
  - No debug code left in files

**Example:**

```bash
git commit -m "Add new feature"
```

```text
🔍 Running pre-commit checks...
✅ Checking shell scripts...
✅ Checking SQL files...
✅ All checks passed!
```

#### Pre-push Hook

- **Runs on:** Every `git push`
- **Duration:** Medium (1-2 minutes)
- **Checks:**
  - All pre-commit checks
  - Quality tests (no database required)
  - Code style consistency
  - Documentation updates

**Example:**

```bash
git push origin main
```

```text
🔍 Running pre-push validation...
✅ Shell script validation passed
✅ SQL validation passed
✅ Quality tests passed
✅ All checks passed! Pushing...
```

**Bypassing Hooks (Not Recommended):**

```bash
# Skip pre-commit (emergency only)
git commit --no-verify -m "Emergency fix"

# Skip pre-push (emergency only)
git push --no-verify
```

**Installation Verification:**

```bash
# Check if hooks are installed
ls -la .git/hooks/
# Should show symlinks to .git-hooks/pre-commit and pre-push
```

**Uninstalling Hooks:**

```bash
# Remove hooks
rm .git/hooks/pre-commit
rm .git/hooks/pre-push
```

### 3. validate-all.sh

**Purpose:** Comprehensive validation script that checks code quality, style, and project integrity.

**Location:** `scripts/validate-all.sh`

**Usage:**

```bash
./scripts/validate-all.sh
```

**What It Does:**

Runs multiple validation checks across the entire project:

1. **Shell Script Validation:**
   - Syntax checking with shellcheck
   - Style checking with shfmt
   - Best practices verification

2. **SQL Validation:**
   - SQL syntax checking
   - File structure validation
   - Query formatting

3. **Configuration Validation:**
   - Properties file syntax
   - Required settings present
   - Valid values

4. **File Structure Validation:**
   - All required files present
   - Correct permissions
   - No temporary files committed

5. **Documentation Validation:**
   - README files present
   - Links are valid
   - Version numbers consistent

**Example Output:**

```text
======================================
🔍 OSM-Notes-Analytics Validation
======================================

Checking shell scripts... ✅
Checking SQL files... ✅
Checking configuration... ✅
Checking file structure... ✅
Checking documentation... ✅

======================================
Summary:
  Total Checks: 25
  Passed: 25 ✅
  Failed: 0 ❌
======================================

✨ All validation checks passed!
```

**Exit Codes:**

- `0`: All checks passed
- `1`: One or more checks failed

**Use Cases:**

1. **Before Committing:**

   ```bash
   ./scripts/validate-all.sh && git commit -m "Feature complete"
   ```

1. **Before Creating PR:**

   ```bash
   ./scripts/validate-all.sh && git push origin feature-branch
   ```

1. **CI/CD Pipeline:**

   ```bash
   # In .github/workflows/quality-checks.yml
   - name: Validate code
     run: ./scripts/validate-all.sh
   ```

1. **Manual Code Review:**

   ```bash
   ./scripts/validate-all.sh > validation-report.txt
   ```

**Troubleshooting Failures:**

If validation fails:

1. **View detailed output:**

   ```bash
   ./scripts/validate-all.sh 2>&1 | tee validation.log
   ```

1. **Fix shellcheck issues:**

   ```bash
   shellcheck -x bin/dwh/*.sh
   ```

1. **Fix formatting:**

   ```bash
   shfmt -w -i 1 -sr -bn bin/dwh/*.sh
   ```

1. **Re-run validation:**

   ```bash
   ./scripts/validate-all.sh
   ```

## Workflow Integration

### Development Workflow

```bash
# 1. Initial setup (once)
./scripts/setup_analytics.sh
./scripts/install-hooks.sh

# 2. Make changes
nano bin/dwh/ETL.sh

# 3. Validate before commit (automatic with hooks)
git add bin/dwh/ETL.sh
git commit -m "Improve ETL performance"
# Pre-commit hook runs automatically

# 4. Push changes (automatic validation)
git push origin feature-branch
# Pre-push hook runs automatically
```

### Manual Validation

```bash
# Run full validation manually
./scripts/validate-all.sh

# Fix issues if needed
shellcheck bin/dwh/*.sh
shfmt -w -i 1 -sr -bn bin/dwh/*.sh

# Commit after fixing
git add .
git commit -m "Fix code quality issues"
```

### CI/CD Integration

These scripts are used in GitHub Actions:

**`.github/workflows/quality-checks.yml`:**

```yaml
- name: Run validation
  run: ./scripts/validate-all.sh
```

**`.github/workflows/tests.yml`:**

```yaml
- name: Setup environment
  run: ./scripts/setup_analytics.sh

- name: Run tests
  run: ./tests/run_all_tests.sh
```

## Script Configuration

### Environment Variables

Scripts respect these environment variables:

```bash
# Skip interactive prompts
export CI=true

# Verbose output
export VERBOSE=true

# Specific checks only
export VALIDATE_SHELL=true
export VALIDATE_SQL=false
export VALIDATE_DOCS=false
```

### Customization

**Modify validation rules:**

Edit `scripts/validate-all.sh`:

```bash
# Add custom check
run_check "Custom validation" "your_custom_command"
```

**Modify hook behavior:**

Edit `.git-hooks/pre-commit`:

```bash
# Add custom pre-commit check
if [ -f "custom_check.sh" ]; then
  ./custom_check.sh
fi
```

## Prerequisites

### Required Tools

1. **Bash 4.0+**

   ```bash
   bash --version
   ```

1. **Git**

   ```bash
   git --version
   ```

1. **PostgreSQL client**

   ```bash
   psql --version
   ```

### Optional Development Tools

1. **shellcheck** (shell script linter)

   ```bash
   # Ubuntu/Debian
   sudo apt-get install shellcheck

   # macOS
   brew install shellcheck
   ```

1. **shfmt** (shell script formatter)

   ```bash
   # Ubuntu/Debian
   sudo apt-get install shfmt

   # macOS
   brew install shfmt
   ```

1. **BATS** (test framework)

   ```bash
   # Ubuntu/Debian
   sudo apt-get install bats

   # macOS
   brew install bats-core
   ```

## Best Practices

1. **Always run setup_analytics.sh** after cloning the repository
2. **Install hooks immediately** after setup for automatic validation
3. **Run validate-all.sh** before creating pull requests
4. **Don't bypass hooks** unless absolutely necessary
5. **Fix validation issues** immediately rather than accumulating them
6. **Keep scripts executable:** `chmod +x scripts/*.sh`

## Troubleshooting

### "Permission denied" errors

Make scripts executable:

```bash
chmod +x scripts/*.sh
chmod +x .git-hooks/*
```

### Hooks not running

Reinstall hooks:

```bash
./scripts/install-hooks.sh
```

Verify installation:

```bash
ls -la .git/hooks/
```

### Validation fails but code looks correct

Update validation tools:

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get upgrade shellcheck shfmt

# macOS
brew upgrade shellcheck shfmt
```

### Setup script can't find database

Configure database first:

```bash
nano etc/properties.sh
# Set DBNAME and DB_USER
```

Create database if needed:

```bash
createdb osm_notes
psql -d osm_notes -c "CREATE EXTENSION postgis;"
```

## Script Maintenance

### Adding New Scripts

1. Create script in `scripts/` directory
2. Add shebang: `#!/bin/bash`
3. Include header with purpose, author, version
4. Make executable: `chmod +x scripts/newscript.sh`
5. Add to this README
6. Test script: `./scripts/newscript.sh`
7. Validate: `shellcheck scripts/newscript.sh`

### Updating Scripts

1. Test changes locally
2. Run validation: `./scripts/validate-all.sh`
3. Update version number in script header
4. Update documentation in this README
5. Commit changes with descriptive message

## References

- [Main README](../README.md)
- [CI/CD Guide](../docs/CI_CD_Guide.md)
- [Testing Guide](../tests/README.md)
- [Contributing Guide](../CONTRIBUTING.md)

## Support

For issues with setup scripts:

1. Run with verbose output: `bash -x scripts/scriptname.sh`
2. Check script logs
3. Verify prerequisites are installed
4. Create an issue with output and error messages

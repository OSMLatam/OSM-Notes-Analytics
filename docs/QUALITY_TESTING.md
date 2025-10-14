# Quality Testing Strategy

**Version:** 2025-10-13  
**Repository:** OSM-Notes-Analytics

---

## Overview

This repository implements quality testing for Analytics-specific scripts and the Common submodule integration.

## Quality Checks

### 1. Shellcheck (Static Analysis)

Runs on:
- ✅ `bin/dwh/*.sh` - Analytics scripts
- ✅ `lib/osm-common/*.sh` - Common submodule (integration check)

**Purpose:** Detect shell scripting issues, potential bugs, and best practice violations.

### 2. Shfmt (Code Formatting)

Runs on:
- ✅ `bin/dwh/*.sh` - Analytics scripts
- ✅ `lib/osm-common/*.sh` - Common submodule (integration check)

**Format:** `shfmt -i 1 -sr -bn` (1 space indent, space redirects, binary ops next line)

### 3. Code Quality Checks

- Trailing whitespace detection
- Proper shebang validation
- TODO/FIXME comment counting

---

## Why Test the Common Submodule?

The Common submodule (`lib/osm-common/`) is tested in **Analytics context** to:

1. **Detect Integration Issues:** Problems that only appear when Common is used with Analytics scripts
2. **Ensure Compatibility:** Verify Common works correctly with DWH/ETL scripts
3. **Early Detection:** Find issues before they reach production

**Note:** This is NOT duplication:
- OSM-Notes-profile tests Common in **Profile context** (ingestion)
- OSM-Notes-Analytics tests Common in **Analytics context** (ETL/DWH)
- Different contexts can reveal different issues

---

## CI/CD Workflow

### Triggered On

- Push to `main` or `develop` branches
- Pull requests
- Manual workflow dispatch

### Jobs

1. **shellcheck** - Static analysis
2. **shfmt** - Code formatting validation
3. **code-quality** - General quality checks

### Expected Duration

- Shellcheck: ~1 minute
- Shfmt: ~30 seconds
- Code Quality: ~30 seconds
- **Total:** ~2 minutes

---

## Running Quality Tests Locally

### Shellcheck

```bash
# Check Analytics scripts
find bin/dwh -name "*.sh" -exec shellcheck -x -o all {} \;

# Check Common submodule
find lib/osm-common -name "*.sh" -exec shellcheck -x -o all {} \;
```

### Shfmt

```bash
# Check formatting (dry run)
find bin/dwh -name "*.sh" -exec shfmt -d -i 1 -sr -bn {} \;

# Fix formatting
find bin/dwh -name "*.sh" -exec shfmt -w -i 1 -sr -bn {} \;
```

### Code Quality

```bash
# Check trailing whitespace
find bin -name "*.sh" -exec grep -l " $" {} \;

# Check shebangs
find bin -name "*.sh" -exec head -1 {} \; | grep -v "#!/bin/bash"
```

---

## Related Documentation

- [OSM-Notes-profile Quality Tests](https://github.com/angoca/OSM-Notes-profile/.github/workflows/quality-tests.yml)
- [OSM-Notes-Common](https://github.com/angoca/OSM-Notes-Common)

---

**Last Updated:** 2025-10-13


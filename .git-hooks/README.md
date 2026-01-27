# Git Hooks - OSM-Notes-Analytics

Unified Git hooks for Bash/SQL projects in the OSM-Notes ecosystem.

## Overview

This project uses unified Git hooks that ensure code quality before commits and pushes. The hooks are designed to be consistent across all Bash/SQL projects in the OSM-Notes ecosystem.

## Available Hooks

### Pre-commit Hook

**Location**: `.git-hooks/pre-commit`

**Checks before each commit:**

1. ✅ **Shellcheck** - Bash script linting
2. ✅ **Shfmt** - Bash code formatting validation
3. ✅ **Trailing whitespace** - Removes trailing spaces
4. ✅ **Shebang validation** - Ensures correct shebangs in scripts
5. ✅ **SQLFluff** - SQL code formatting validation
6. ✅ **Prettier** - Formatting for Markdown, JSON, YAML, CSS, HTML

**Installation:**

```bash
ln -sf ../../.git-hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Bypass (not recommended):**

```bash
git commit --no-verify
```

### Pre-push Hook

**Location**: `.git-hooks/pre-push`

**Executes before each push:**

1. ✅ **Quality tests** - Runs `tests/run_quality_tests.sh` (fast validation)

**Installation:**

```bash
ln -sf ../../.git-hooks/pre-push .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

**Bypass:**

```bash
git push --no-verify
```

## Unified Structure

All Bash/SQL projects in the OSM-Notes ecosystem use the same hook structure:

- **OSM-Notes-Analytics** ✅
- **OSM-Notes-Ingestion** ✅
- **OSM-Notes-WMS** ✅
- **OSM-Notes-Monitoring** ✅

This ensures consistent code quality standards across all projects.

## Requirements

The hooks require the following tools (optional - hooks skip checks if tools are not installed):

- `shellcheck` - Bash linting
- `shfmt` - Bash formatting
- `sqlfluff` - SQL formatting
- `prettier` - General formatting

## Notes

- Git hooks are optional and mainly useful for local development
- CI/CD uses GitHub Actions workflows for validation
- Hooks gracefully skip checks if required tools are not installed

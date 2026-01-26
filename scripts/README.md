# Scripts Directory

This directory contains utility scripts for project setup and development workflow automation.

## Overview

The scripts in this directory help with:

- Initial project setup and configuration
- Development environment preparation

## Available Scripts

Currently, this directory contains minimal utility scripts. The main project functionality is in
`bin/dwh/`.

## Setup

### Initial Configuration

After cloning the repository, create your configuration files:

```bash
# Copy example files to create your configuration
cp etc/properties.sh.example etc/properties.sh
cp etc/etl.properties.example etc/etl.properties

# Edit with your database credentials
nano etc/properties.sh
```

### Git Hooks (Optional)

If you want to use git hooks for code quality checks, you can install them manually:

```bash
# Install pre-commit hook (optional)
ln -sf ../../.git-hooks/pre-commit .git/hooks/pre-commit
chmod +x .git-hooks/pre-commit

# Install pre-push hook (optional)
ln -sf ../../.git-hooks/pre-push .git/hooks/pre-push
chmod +x .git-hooks/pre-push
```

## Prerequisites

### Required Tools

1. **Bash 4.0+**

   ```bash
   bash --version
   ```

2. **Git**

   ```bash
   git --version
   ```

3. **PostgreSQL client**
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

2. **shfmt** (shell script formatter)

   ```bash
   # Ubuntu/Debian
   sudo apt-get install shfmt

   # macOS
   brew install shfmt
   ```

3. **BATS** (test framework)

   ```bash
   # Ubuntu/Debian
   sudo apt-get install bats

   # macOS
   brew install bats-core
   ```

## Best Practices

1. **Create configuration files** by copying the example files after cloning the repository
2. **Keep scripts executable:** `chmod +x scripts/*.sh`
3. **Test scripts** before committing changes

## Related Documentation

- **[Main README](../README.md)** - Project overview and setup
- **[Contributing Guide](../CONTRIBUTING.md)** - Development workflow and standards
- **[etc/README.md](../etc/README.md)** - Configuration files and setup
- **[bin/dwh/ENTRY_POINTS.md](../bin/dwh/Entry_Points.md)** - Script entry points

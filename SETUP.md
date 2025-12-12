# Quick Setup Guide

## First Time Setup on a New Server

### 1. Clone the repository

```bash
git clone https://github.com/OSMLatam/OSM-Notes-Analytics.git
cd OSM-Notes-Analytics
```

### 2. Initialize Git submodules

This project uses a Git submodule for shared libraries. You must initialize it:

```bash
# Initialize and update submodules
git submodule update --init --recursive

# Or if you cloned with submodules already:
# git clone --recurse-submodules https://github.com/OSMLatam/OSM-Notes-Analytics.git
```

### 3. Create configuration files

```bash
# Run the automated setup script
./scripts/setup-local-config.sh

# This will create:
# - etc/properties.sh (from properties.sh.example)
# - etc/etl.properties (from etl.properties.example)
```

### 4. Configure your environment

```bash
# Edit database configuration
nano etc/properties.sh

# Set at minimum:
DBNAME="your_database_name"  # Default: "notes"
DB_USER="your_database_user"  # Default: "myuser"
```

```bash
# Edit ETL configuration (optional)
nano etc/etl.properties

# Example for testing:
ETL_TEST_MODE=true  # Process only 2013-2014
```

### 5. Run the ETL

```bash
# First time setup (creates data warehouse automatically)
./bin/dwh/ETL.sh

# Or with test mode (faster, only 2013-2014)
ETL_TEST_MODE=true ./bin/dwh/ETL.sh
```

## Updating on Existing Server

### After git pull or git clone updates

```bash
# Pull the latest changes
git pull

# Update submodules if they changed
git submodule update --init --recursive

# Your local configuration files (.local) are preserved automatically
# The scripts will load them automatically

# Run the ETL as usual (auto-detects mode)
./bin/dwh/ETL.sh
```

## Configuration Files

### Architecture

```
etc/
├── properties.sh                  # Your configuration (NOT in git)
├── properties.sh.example          # Template (in git)
├── properties.sh.local            # Optional override (NOT in git)
├── etl.properties                 # Your ETL config (NOT in git)
├── etl.properties.example         # ETL template (in git)
└── etl.properties.local           # Optional ETL override (NOT in git)
```

### Priority Order

1. Environment variables (highest priority)
2. Local override files (`*.local`) - loaded automatically if they exist
3. Main configuration files (`properties.sh`, `etl.properties`)
4. Script defaults (lowest)

### Safety

- ✅ Configuration files (`properties.sh`, `etl.properties`) are ignored by git
- ✅ Only `.example` files are versioned (no credentials in repository)
- ✅ Your credentials will never be committed to Git
- ✅ Each server maintains its own configuration files
- ✅ After `git pull`, your configuration files are preserved
- ✅ Optional: Use `*.local` files for environment-specific overrides

## Common Tasks

### Enable test mode for faster testing

```bash
# Edit configuration
nano etc/etl.properties

# Set to true
ETL_TEST_MODE=true

# Run ETL
./bin/dwh/ETL.sh
# This will process only 2013-2014
```

### Switch to production mode

```bash
# Edit configuration
nano etc/etl.properties

# Set to false (or remove the line)
ETL_TEST_MODE=false

# Run ETL
./bin/dwh/ETL.sh
# This will process all years from 2013 to current
```

### Multiple servers with different configs

Each server maintains its own configuration files independently:

```bash
# Server A (production) - etc/properties.sh
DBNAME="notes_prod"
DB_USER="prod_user"
ETL_TEST_MODE=false

# Server B (testing) - etc/properties.sh
DBNAME="notes_test"
DB_USER="test_user"
ETL_TEST_MODE=true
ETL_BATCH_SIZE=500
```

Configuration files are not versioned, so each server can have different settings.

## Troubleshooting

### "Required file not found: lib/osm-common/commonFunctions.sh"

This error means the Git submodule is not initialized. Run:

```bash
git submodule update --init --recursive
```

### Configuration not taking effect?

Check file priority:
```bash
# Verify local files exist
ls -la etc/*.local

# Check what's being loaded
./bin/dwh/ETL.sh --help
```

### Reset to defaults

```bash
# Remove configuration files to recreate from templates
rm etc/properties.sh
rm etc/etl.properties

# Run setup script to recreate from examples
./scripts/setup-local-config.sh
```

### Create configuration files from scratch

```bash
# Run setup script (recommended)
./scripts/setup-local-config.sh

# Or manually
cp etc/properties.sh.example etc/properties.sh
cp etc/etl.properties.example etc/etl.properties

# Then edit with your credentials
nano etc/properties.sh
nano etc/etl.properties
```

## Support

For more information, see:
- `etc/README.md` - Detailed configuration guide
- `docs/ETL_Enhanced_Features.md` - ETL features documentation
- `bin/dwh/ETL.sh --help` - Command-line help


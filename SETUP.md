# Quick Setup Guide

## First Time Setup on a New Server

### 1. Clone the repository

```bash
git clone https://github.com/OSMLatam/OSM-Notes-Analytics.git
cd OSM-Notes-Analytics
```

### 2. Create local configuration files

```bash
# Run the automated setup script
./scripts/setup-local-config.sh

# This will create:
# - etc/properties.sh.local
# - etc/etl.properties.local
```

### 3. Configure your environment

```bash
# Edit database configuration
nano etc/properties.sh.local

# Set at minimum:
DBNAME="your_database_name"
DB_USER="your_database_user"
```

```bash
# Edit ETL configuration (optional)
nano etc/etl.properties.local

# Example for testing:
ETL_TEST_MODE=true  # Process only 2013-2014
```

### 4. Run the ETL

```bash
# First time setup (creates data warehouse)
./bin/dwh/ETL.sh --create

# Or with test mode (faster)
ETL_TEST_MODE=true ./bin/dwh/ETL.sh --create
```

## Updating on Existing Server

### After git pull or git clone updates

```bash
# Just pull the latest changes
git pull

# Your local configuration files (.local) are preserved automatically
# The scripts will load them automatically

# Run the ETL as usual
./bin/dwh/ETL.sh --incremental
```

## Configuration Files

### Architecture

```
etc/
├── properties.sh                  # Default configuration (in git)
├── properties.sh.local            # Your config (NOT in git)
├── properties.sh.example          # Template (in git)
├── etl.properties                 # Default ETL config (in git)
├── etl.properties.local           # Your ETL config (NOT in git)
└── etl.properties.example         # ETL template (in git)
```

### Priority Order

1. Environment variables (highest priority)
2. Local files (`*.local`) - loaded automatically
3. Default files
4. Script defaults

### Safety

- ✅ `*.local` files are ignored by git
- ✅ Your configs won't be overwritten by git pull
- ✅ Each server can have different settings
- ✅ No manual copying needed after git pull

## Common Tasks

### Enable test mode for faster testing

```bash
# Edit local config
nano etc/etl.properties.local

# Set to true
ETL_TEST_MODE=true

# Run ETL
./bin/dwh/ETL.sh --create
# This will process only 2013-2014
```

### Switch to production mode

```bash
# Edit local config
nano etc/etl.properties.local

# Set to false (or remove the line)
ETL_TEST_MODE=false

# Run ETL
./bin/dwh/ETL.sh --create
# This will process all years from 2013 to current
```

### Multiple servers with different configs

```bash
# Server A (production)
DBNAME="notes_prod"
ETL_TEST_MODE=false

# Server B (testing)
DBNAME="notes_test"
ETL_TEST_MODE=true
ETL_BATCH_SIZE=500
```

Each server maintains its own `*.local` files independently.

## Troubleshooting

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
# Remove local files to use defaults
rm etc/properties.sh.local
rm etc/etl.properties.local

# Scripts will use default configuration
```

### Create local files from scratch

```bash
# Run setup script again
./scripts/setup-local-config.sh

# Or manually
cp etc/properties.sh.example etc/properties.sh.local
cp etc/etl.properties.example etc/etl.properties.local
```

## Support

For more information, see:
- `etc/README.md` - Detailed configuration guide
- `docs/ETL_Enhanced_Features.md` - ETL features documentation
- `bin/dwh/ETL.sh --help` - Command-line help


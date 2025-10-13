# Migration Guide - OSM-Notes-Analytics

**Version:** 2025-10-13  
**Author:** Andres Gomez (AngocA)

## Overview

This document describes how to migrate from the monolithic OSM-Notes-profile repository to the separated architecture with OSM-Notes-Analytics.

## Architecture Change

### Before (Monolithic)

```
OSM-Notes-profile/
├── bin/
│   ├── process/           # Ingestion
│   ├── wms/               # WMS
│   └── dwh/               # Analytics ← Now separated
├── sql/
│   ├── process/           # Ingestion
│   ├── wms/               # WMS
│   └── dwh/               # Analytics ← Now separated
```

### After (Separated)

```
OSM-Notes-profile/         OSM-Notes-Analytics/
(Ingestion & WMS)          (Analytics & DWH)
├── bin/process/           ├── bin/dwh/
├── bin/wms/               ├── sql/dwh/
├── sql/process/           └── tests/
├── sql/wms/
└── tests/
```

## Database Architecture

### Shared Database Approach

Both systems use the **same PostgreSQL database** with different schemas:

```sql
Database: osm_notes
├── Schema: public
│   ├── notes                    # Managed by Ingestion
│   ├── note_comments            # Managed by Ingestion
│   ├── note_comments_text       # Managed by Ingestion
│   ├── users                    # Managed by Ingestion
│   └── countries                # Managed by Ingestion
├── Schema: wms
│   └── notes_wms                # Managed by Ingestion (WMS)
└── Schema: dwh
    ├── facts                    # Managed by Analytics
    ├── dimension_*              # Managed by Analytics
    └── datamart_*               # Managed by Analytics
```

**Key Points:**
- ✅ Same database, different schemas
- ✅ Analytics **reads** from `public` schema (base tables)
- ✅ Analytics **writes** to `dwh` schema (warehouse tables)
- ✅ No data duplication
- ✅ No synchronization needed

## Migration Steps

### Step 1: Backup Current System

```bash
# Backup database
pg_dump -d osm_notes -F c -f osm_notes_backup_$(date +%Y%m%d).dump

# Backup current repository
cd ~/github
tar -czf OSM-Notes-profile_backup_$(date +%Y%m%d).tar.gz OSM-Notes-profile/
```

### Step 2: Clone Analytics Repository

```bash
cd ~/github
git clone https://github.com/OSMLatam/OSM-Notes-Analytics.git
cd OSM-Notes-Analytics
```

### Step 3: Configure Analytics

#### Edit Database Configuration

```bash
cd ~/github/OSM-Notes-Analytics
cp etc/properties.sh etc/properties.sh_local
nano etc/properties.sh_local
```

Update with your database credentials:

```bash
#!/bin/bash
# Database configuration - MUST match Ingestion database
declare -r DBNAME="osm_notes"      # Same database as Ingestion
declare -r DB_USER="myuser"         # Your database user

# Email configuration
declare EMAILS="your-email@domain.com"
```

#### Edit ETL Configuration

```bash
nano etc/etl.properties
```

Adjust based on your server resources:

```bash
# Performance Configuration
ETL_BATCH_SIZE=1000              # Increase on powerful servers
ETL_PARALLEL_ENABLED=true
ETL_MAX_PARALLEL_JOBS=4          # Match CPU cores

# Resource Control
MAX_MEMORY_USAGE=80              # Adjust based on available RAM
MAX_DISK_USAGE=90
ETL_TIMEOUT=7200                 # 2 hours, increase if needed
```

### Step 4: Verify Prerequisites

```bash
# Check PostgreSQL connection
psql -d osm_notes -c "SELECT version();"

# Check base tables exist (populated by Ingestion)
psql -d osm_notes -c "SELECT COUNT(*) FROM notes;"
psql -d osm_notes -c "SELECT COUNT(*) FROM note_comments;"

# Check required tools
which bash
which psql
bash --version  # Should be 4.0 or higher
```

### Step 5: Initial ETL Run

```bash
cd ~/github/OSM-Notes-Analytics

# Set log level for detailed output
export LOG_LEVEL=INFO

# Run initial DWH creation
./bin/dwh/ETL.sh --create
```

This will:
1. Create `dwh` schema
2. Create all dimension tables
3. Create fact table
4. Populate dimensions from base tables
5. Load facts with note actions
6. Create indexes and constraints

**Expected Duration:** 30+ hours for full dataset (runs in parallel by year)

### Step 6: Verify Analytics Installation

```bash
# Check DWH schema exists
psql -d osm_notes -c "\dn dwh"

# Check dimension tables
psql -d osm_notes -c "
SELECT 
    schemaname, 
    tablename, 
    n_live_tup as row_count 
FROM pg_stat_user_tables 
WHERE schemaname = 'dwh' 
ORDER BY tablename;"

# Check facts table
psql -d osm_notes -c "SELECT COUNT(*) FROM dwh.facts;"
```

### Step 7: Setup Datamarts

```bash
cd ~/github/OSM-Notes-Analytics

# Populate country datamart
./bin/dwh/datamartCountries/datamartCountries.sh

# Start user datamart population (incremental)
./bin/dwh/datamartUsers/datamartUsers.sh
```

**Expected Duration:**
- Country datamart: ~20 minutes
- User datamart: ~5 days (processes 500 users per run)

### Step 8: Update Cron Jobs

#### Before (Old cron configuration)

```bash
# Remove or comment out old combined jobs
# */15 * * * * ~/OSM-Notes-profile/bin/process/processAPINotes.sh && ~/OSM-Notes-profile/bin/dwh/ETL.sh
```

#### After (Separated cron configuration)

```bash
# Ingestion (in OSM-Notes-profile)
*/15 * * * * ~/OSM-Notes-profile/bin/process/processAPINotes.sh

# Analytics (in OSM-Notes-Analytics) - run after ingestion
0 * * * * ~/OSM-Notes-Analytics/bin/dwh/ETL.sh --incremental
30 2 * * * ~/OSM-Notes-Analytics/bin/dwh/datamartCountries/datamartCountries.sh
0 3 * * * ~/OSM-Notes-Analytics/bin/dwh/datamartUsers/datamartUsers.sh
```

### Step 9: Test Integration

```bash
# Trigger ingestion manually
cd ~/OSM-Notes-profile
./bin/process/processAPINotes.sh

# Wait for completion, then run analytics
cd ~/OSM-Notes-Analytics
./bin/dwh/ETL.sh --incremental

# Check that new data appears in DWH
psql -d osm_notes -c "
SELECT 
    MAX(action_at) as latest_action,
    COUNT(*) as recent_facts
FROM dwh.facts 
WHERE processing_time > NOW() - INTERVAL '1 hour';"
```

## Rollback Plan

If migration fails, you can rollback:

```bash
# Step 1: Stop all cron jobs
crontab -e  # Comment out all new jobs

# Step 2: Drop Analytics schema (optional)
psql -d osm_notes -c "DROP SCHEMA IF EXISTS dwh CASCADE;"

# Step 3: Restore old cron configuration
# */15 * * * * ~/OSM-Notes-profile/bin/process/processAPINotes.sh && ~/OSM-Notes-profile/bin/dwh/ETL.sh

# Step 4: Use old monolithic repository
cd ~/OSM-Notes-profile
git pull  # Ensure you have latest version
```

## Troubleshooting

### Issue: ETL fails with "base tables not found"

**Solution:** Ensure Ingestion system has populated base tables first:

```bash
cd ~/OSM-Notes-profile
./bin/process/processPlanetNotes.sh --base
```

### Issue: Permission denied on dwh schema

**Solution:** Check database user permissions:

```bash
psql -d osm_notes -c "
GRANT USAGE ON SCHEMA dwh TO myuser;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA dwh TO myuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA dwh TO myuser;
"
```

### Issue: ETL is very slow

**Solution:** Adjust parallel processing:

```bash
# Edit etc/etl.properties
ETL_MAX_PARALLEL_JOBS=8  # Increase based on CPU cores
ETL_BATCH_SIZE=5000      # Increase batch size
```

### Issue: Out of memory during ETL

**Solution:** Reduce memory usage:

```bash
# Edit etc/etl.properties
ETL_MAX_PARALLEL_JOBS=2   # Reduce parallelism
ETL_BATCH_SIZE=500        # Reduce batch size
MAX_MEMORY_USAGE=70       # Lower threshold
```

## Post-Migration Checklist

- [ ] Both repositories cloned and configured
- [ ] Database credentials configured in both repos
- [ ] Base tables populated (notes, note_comments, etc.)
- [ ] DWH schema created with dimensions and facts
- [ ] Datamarts populated (countries and users)
- [ ] Cron jobs updated and separated
- [ ] Integration tested (ingestion → analytics)
- [ ] Monitoring in place for both systems
- [ ] Documentation updated
- [ ] Team trained on new architecture

## Performance Comparison

### Before (Monolithic)

```
Total test time: 45+ minutes
├── Ingestion tests: 15 min
├── WMS tests: 5 min
└── Analytics tests: 25+ min  ← Slow
```

### After (Separated)

```
Ingestion tests: 20 minutes     (can run independently)
Analytics tests: 25 minutes     (can run independently)

Total time if run in parallel: ~25 minutes (45% faster)
```

## Benefits Achieved

- ✅ **Faster CI/CD**: Tests can run in parallel
- ✅ **Independent deployment**: Deploy analytics without affecting ingestion
- ✅ **Clear responsibilities**: Ingestion vs Analytics
- ✅ **Easier maintenance**: Smaller, focused repositories
- ✅ **Better scalability**: Each system can scale independently
- ✅ **Same database**: No synchronization overhead

## Next Steps

After successful migration:

1. **Monitor both systems** for a week
2. **Update documentation** based on learnings
3. **Consider database separation** if needed in future (optional)
4. **Optimize ETL** based on performance data
5. **Add monitoring dashboards** for both systems

## Support

For issues during migration:

1. Check logs: `tail -f /tmp/ETL_*/ETL.log`
2. Review this guide
3. Check GitHub issues in both repositories
4. Contact: your-email@domain.com

## Version History

- **2025-10-13**: Initial migration guide


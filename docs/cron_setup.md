# Cron Setup Guide - OSM Notes Analytics

Complete guide for setting up automated ETL execution using cron.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Overview

Cron automation allows the ETL process to run automatically at regular intervals without manual intervention. This is essential for keeping the data warehouse up-to-date with new OSM notes.

### Why Use Cron?

- **Automated Updates**: Process new notes every 15 minutes
- **Consistent Data**: Always have fresh data available
- **Minimal Overhead**: Only processes new/changed data
- **Production Ready**: Suitable for production environments

---

## Prerequisites

### Required Components

1. **ETL Script**: `bin/dwh/ETL.sh` (already exists)
2. **Cron Wrapper**: `bin/dwh/cron_etl.sh` (created in this task)
3. **Monitor Script**: `bin/dwh/monitor_etl.sh` (created in this task)
4. **Cron Configuration**: `etc/cron.example` (template provided)

### System Requirements

- Linux/Unix system with cron installed
- Sufficient disk space for logs (/tmp)
- Database connectivity configured
- Write permissions to log directories

---

## Installation

### Step 1: Prepare Cron Wrapper

The cron wrapper script (`bin/dwh/cron_etl.sh`) is already created. Make it executable:

```bash
chmod +x bin/dwh/cron_etl.sh
```

### Step 2: Configure Log File

Edit `bin/dwh/cron_etl.sh` to set your log file location:

```bash
# Default is /var/log/osm-notes-etl.log
# Change if needed:
ETL_LOG_FILE="${ETL_LOG_FILE:-/var/log/osm-notes-etl.log}"
```

### Step 3: Create Cron Configuration

Copy the example configuration:

```bash
cp etc/cron.example /tmp/osm-notes-cron
```

### Step 4: Edit Configuration

Edit `/tmp/osm-notes-cron` and update the paths:

```bash
# Example configuration (production path):
*/15 * * * * export CLEAN=false ; export LOG_LEVEL=INFO ; export DBNAME=notes ; export DB_USER=notes ; /home/notes/OSM-Notes-Analytics/bin/dwh/ETL.sh
```

**Production Configuration**:
- `CLEAN=false`: Keeps temporary files for debugging (use `CLEAN=true` to save disk space)
- `LOG_LEVEL=INFO`: Balanced logging (use `ERROR` for less verbose, `DEBUG` for debugging)
- `DBNAME=notes`: Your database name
- `DB_USER=notes`: Your database user

Also update:
- `SHELL=/bin/bash` (if using different shell)
- `HOME=/home/your-username` (your actual home directory)
- Any other paths as needed

### Step 5: Install Cron Job

Install the cron configuration:

```bash
crontab /tmp/osm-notes-cron
```

### Step 6: Verify Installation

Check that cron is installed correctly:

```bash
crontab -l
```

You should see output like:
```
*/15 * * * * export CLEAN=false ; export LOG_LEVEL=INFO ; export DBNAME=notes ; export DB_USER=notes ; /home/notes/OSM-Notes-Analytics/bin/dwh/ETL.sh
0 2 15 * * /home/notes/OSM-Notes-Analytics/bin/dwh/exportAndPushCSVToGitHub.sh
0 4 1 * * /home/notes/OSM-Notes-Analytics/bin/dwh/ml_retrain.sh >> /tmp/ml-retrain.log 2>&1
```

---

## Configuration

### ETL Execution Frequency

Choose the appropriate frequency based on your needs:

| Frequency | Schedule | Use Case |
|-----------|----------|----------|
| **Every 15 minutes** | `*/15 * * * *` | Production, frequent updates |
| **Every hour** | `0 * * * *` | Standard updates |
| **Every 3 hours** | `0 */3 * * *` | Moderate updates |
| **Daily** | `0 2 * * *` | Low-frequency updates |

### Lock File Behavior

The ETL automatically creates lock files to prevent concurrent execution:

- **Lock exists**: New job skips execution
- **Lock older than 4 hours**: Considered stale, job proceeds
- **Lock created**: Current execution timestamp

This ensures that:
- If ETL takes >15 minutes, next job waits
- No duplicate executions
- System remains stable

### Log Management

ETL logs are stored in `/tmp/ETL_XXXXXX/` directories.

**Automatic cleanup** is configured in cron:
```cron
30 3 * * 0 find /tmp/ETL_* -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
```

This removes logs older than 7 days every Sunday at 3:30 AM.

---

## Monitoring

### Manual Monitoring

Run the monitor script to check ETL status:

```bash
./bin/dwh/monitor_etl.sh
```

Output includes:
- Process status (running/not running)
- Last execution log
- Database connection status
- Data warehouse statistics
- Disk space usage

### Automated Monitoring

Add to cron for automated monitoring:

```cron
# Daily report at 6 AM
0 6 * * * /home/notes/OSM-Notes-Analytics/bin/dwh/monitor_etl.sh > /tmp/etl_daily_report.txt
```

### Email Alerts

Configure email alerts in `bin/dwh/cron_etl.sh`:

```bash
# Uncomment and configure these lines:
if command -v mail &> /dev/null; then
  echo "ETL failed with exit code ${exit_code}. Check logs at ${ETL_LOG_FILE}" | \
    mail -s "ETL Failed - OSM Notes Analytics" notes@osm.lat
fi
```

---

## Troubleshooting

### Issue: Cron Job Not Running

**Check cron service**:
```bash
# Check if cron is running
systemctl status cron

# Start cron if needed
sudo systemctl start cron
```

**Check cron logs**:
```bash
# View cron execution logs
sudo tail -f /var/log/syslog | grep CRON

# On some systems:
sudo tail -f /var/log/cron
```

### Issue: "Permission Denied"

**Check permissions**:
```bash
# Script must be executable
chmod +x bin/dwh/cron_etl.sh
chmod +x bin/dwh/ETL.sh

# All scripts should be readable
ls -la bin/dwh/*.sh
```

### Issue: "Command Not Found"

**Check PATH**: Cron jobs have limited PATH. Use full paths:

```bash
# Good
/home/notes/OSM-Notes-Analytics/bin/dwh/cron_etl.sh

# Bad
bin/dwh/cron_etl.sh
```

### Issue: Database Connection Failed

**Check environment**: Cron doesn't inherit your shell environment. Add to cron:

```cron
# Load environment
. /home/your-username/.bashrc
```

Or explicitly set variables in cron:

```cron
DBHOST=localhost
DBPORT=5432
DBUSER=postgres
# Database configuration (recommended: use DBNAME_INGESTION and DBNAME_DWH)
DBNAME_INGESTION=osm_notes
DBNAME_DWH=notes_dwh
# Legacy/compatibility (use when both databases are the same):
# DBNAME=osm_notes
```

### Issue: Lock File Never Released

**Stale lock file**: If ETL crashes, lock file may remain:

```bash
# Find lock files
find /tmp/ETL_* -name "ETL.lock"

# Check age
ls -lh /tmp/ETL_*/ETL.lock

# Remove if stale (>4 hours old)
find /tmp/ETL_* -name "ETL.lock" -mmin +240 -delete
```

---

## Best Practices

### 1. Test Before Production

Test cron jobs manually first:

```bash
# Run wrapper manually
/home/notes/OSM-Notes-Analytics/bin/dwh/cron_etl.sh

# Check output
tail -f /var/log/osm-notes-etl.log
```

### 2. Start with Conservative Schedule

Begin with less frequent execution:

```cron
# Start with hourly updates
0 * * * * /home/notes/OSM-Notes-Analytics/bin/dwh/cron_etl.sh
```

Then increase frequency based on performance.

### 3. Monitor Disk Space

Watch log directory size:

```bash
# Check disk usage
du -sh /tmp/ETL_*

# Set up alert in cron
0 4 * * * du -sh /tmp/ETL_* | mail -s "ETL Log Size" notes@osm.lat
```

### 4. Regular Maintenance

Add these tasks to cron:

```cron
# Weekly VACUUM ANALYZE
0 3 * * 0 psql -U postgres -d osm_notes -c "VACUUM ANALYZE dwh.facts"

# Weekly log cleanup
30 3 * * 0 find /tmp/ETL_* -type d -mtime +7 -exec rm -rf {} \;
```

### 5. Backup Strategy

Implement backups:

```cron
# Daily DWH backup
0 1 * * * pg_dump -U postgres -d osm_notes -n dwh > /backups/dwh_$(date +\%Y\%m\%d).sql

# Keep last 30 days
0 2 * * * find /backups/dwh_*.sql -mtime +30 -delete
```

### 6. Error Handling

Monitor for failures:

```bash
# Check for errors in logs
grep -i error /var/log/osm-notes-etl.log | tail -20

# Set up daily error report
0 7 * * * grep -i error /var/log/osm-notes-etl.log | tail -50 | mail -s "ETL Errors" notes@osm.lat
```

---

## Advanced Configuration

### Running Multiple ETL Jobs

You can run different ETL operations at different times:

```cron
# Incremental updates every 15 minutes (production)
*/15 * * * * export CLEAN=false ; export LOG_LEVEL=INFO ; export DBNAME=notes ; export DB_USER=notes ; /home/notes/OSM-Notes-Analytics/bin/dwh/ETL.sh

# Export CSV monthly (15th day at 2 AM)
0 2 15 * * /home/notes/OSM-Notes-Analytics/bin/dwh/exportAndPushCSVToGitHub.sh

# ML training/retraining monthly (1st day at 4 AM)
0 4 1 * * /home/notes/OSM-Notes-Analytics/bin/dwh/ml_retrain.sh >> /tmp/ml-retrain.log 2>&1

# Full reload every Sunday at 2 AM (if needed)
0 2 * * 0 /home/notes/OSM-Notes-Analytics/bin/dwh/ETL.sh
```

### Custom Log Rotation

Configure custom log rotation:

```bash
# Create logrotate config
sudo vim /etc/logrotate.d/osm-notes-etl

# Add:
/var/log/osm-notes-etl.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
```

### Conditional Execution

Run ETL only during business hours:

```cron
# Only run 8 AM - 8 PM
*/15 8-20 * * * /home/notes/OSM-Notes-Analytics/bin/dwh/cron_etl.sh
```

---

## Related Documentation

- **[Deployment Diagram](Deployment_Diagram.md)**: Complete deployment architecture and operational workflows
- **[Troubleshooting Guide](Troubleshooting_Guide.md)**: Common cron and deployment issues
- **[DWH Maintenance Guide](DWH_Maintenance_Guide.md)**: Database maintenance procedures

## Conclusion

With cron automation configured, your OSM Notes Analytics data warehouse will stay current with minimal manual intervention. Regular monitoring and maintenance ensure optimal performance.

For complete deployment documentation including infrastructure, scheduling, and disaster recovery, see [Deployment Diagram](Deployment_Diagram.md).


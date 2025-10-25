#!/bin/bash

# Cron wrapper for ETL incremental execution
# Safe execution wrapper for cron environment
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-24

# Error handling
set -e
set -u
set -o pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SCRIPT_BASE_DIRECTORY="$(cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

# Default log file (can be overridden)
ETL_LOG_FILE="${ETL_LOG_FILE:-/var/log/osm-notes-etl.log}"

# Function to log messages
log_message() {
 local message="$1"
 local timestamp
 timestamp=$(date '+%Y-%m-%d %H:%M:%S')
 echo "[${timestamp}] ${message}" >> "${ETL_LOG_FILE}"
}

# Start execution
log_message "Starting ETL incremental execution"

# Load database properties if available
if [[ -f "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh" ]]; then
 # shellcheck disable=SC1091
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
fi

# Set minimal environment variables for cron
export LOG_LEVEL="${LOG_LEVEL:-ERROR}"
export CLEAN="${CLEAN:-true}"

# Execute ETL incremental
log_message "Executing: ${SCRIPT_DIR}/ETL.sh incremental"

# Redirect output to log file
if "${SCRIPT_DIR}/ETL.sh" incremental >> "${ETL_LOG_FILE}" 2>&1; then
 log_message "ETL completed successfully"
 exit 0
else
 exit_code=$?
 log_message "ETL failed with exit code: ${exit_code}"

 # Optional: Send alert (uncomment and configure)
 # if command -v mail &> /dev/null; then
 #   echo "ETL failed with exit code ${exit_code}. Check logs at ${ETL_LOG_FILE}" | \
 #     mail -s "ETL Failed - OSM Notes Analytics" admin@example.com
 # fi

 exit ${exit_code}
fi

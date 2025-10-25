#!/bin/bash

# Setup script for local configuration files
# This script helps create local configuration files from templates
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-25

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." &> /dev/null && pwd)"

echo "OSM-Notes-Analytics Local Configuration Setup"
echo "=============================================="
echo

# Check if local files already exist
if [[ -f "${PROJECT_ROOT}/etc/properties.sh.local" ]]; then
 echo "⚠️  Local properties file already exists: etc/properties.sh.local"
 read -p "Do you want to overwrite it? (y/N): " -n 1 -r
 echo
 if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Skipping properties.sh.local"
 else
  cp "${PROJECT_ROOT}/etc/properties.sh.example" "${PROJECT_ROOT}/etc/properties.sh.local"
  echo "✅ Created etc/properties.sh.local"
 fi
else
 cp "${PROJECT_ROOT}/etc/properties.sh.example" "${PROJECT_ROOT}/etc/properties.sh.local"
 echo "✅ Created etc/properties.sh.local"
fi

if [[ -f "${PROJECT_ROOT}/etc/etl.properties.local" ]]; then
 echo "⚠️  Local ETL properties file already exists: etc/etl.properties.local"
 read -p "Do you want to overwrite it? (y/N): " -n 1 -r
 echo
 if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Skipping etl.properties.local"
 else
  cp "${PROJECT_ROOT}/etc/etl.properties.example" "${PROJECT_ROOT}/etc/etl.properties.local"
  echo "✅ Created etc/etl.properties.local"
 fi
else
 cp "${PROJECT_ROOT}/etc/etl.properties.example" "${PROJECT_ROOT}/etc/etl.properties.local"
 echo "✅ Created etc/etl.properties.local"
fi

echo
echo "📝 Next steps:"
echo "1. Edit your local configuration files:"
echo "   - nano ${PROJECT_ROOT}/etc/properties.sh.local"
echo "   - nano ${PROJECT_ROOT}/etc/etl.properties.local"
echo
echo "2. Configure your database settings:"
echo "   - DBNAME: Your database name"
echo "   - DB_USER: Your database user"
echo
echo "3. Configure ETL settings if needed:"
echo "   - ETL_TEST_MODE: Set to 'true' for testing with 2013-2014 only"
echo "   - ETL_BATCH_SIZE: Adjust for your system performance"
echo
echo "4. Test your configuration:"
echo "   - ${PROJECT_ROOT}/bin/dwh/ETL.sh --help"
echo
echo "🔒 Note: Local files (*.local) are automatically ignored by Git"
echo "   Your personal settings will not be committed to the repository."
echo
echo "✨ Setup complete!"

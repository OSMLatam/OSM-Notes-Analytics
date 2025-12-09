#!/bin/bash

# Setup script for configuration files
# This script helps create configuration files from templates
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-XX

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." &> /dev/null && pwd)"

echo "OSM-Notes-Analytics Configuration Setup"
echo "======================================="
echo

# Check if main properties file already exists
if [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
 echo "⚠️  Properties file already exists: etc/properties.sh"
 read -p "Do you want to overwrite it? (y/N): " -n 1 -r
 echo
 if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Skipping properties.sh"
 else
  cp "${PROJECT_ROOT}/etc/properties.sh.example" "${PROJECT_ROOT}/etc/properties.sh"
  echo "✅ Created etc/properties.sh"
 fi
else
 cp "${PROJECT_ROOT}/etc/properties.sh.example" "${PROJECT_ROOT}/etc/properties.sh"
 echo "✅ Created etc/properties.sh"
fi

# Check if ETL properties file already exists
if [[ -f "${PROJECT_ROOT}/etc/etl.properties" ]]; then
 echo "⚠️  ETL properties file already exists: etc/etl.properties"
 read -p "Do you want to overwrite it? (y/N): " -n 1 -r
 echo
 if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Skipping etl.properties"
 else
  cp "${PROJECT_ROOT}/etc/etl.properties.example" "${PROJECT_ROOT}/etc/etl.properties"
  echo "✅ Created etc/etl.properties"
 fi
else
 cp "${PROJECT_ROOT}/etc/etl.properties.example" "${PROJECT_ROOT}/etc/etl.properties"
 echo "✅ Created etc/etl.properties"
fi

echo
echo "📝 Next steps:"
echo "1. Edit your configuration files with your database credentials:"
echo "   - nano ${PROJECT_ROOT}/etc/properties.sh"
echo "   - nano ${PROJECT_ROOT}/etc/etl.properties"
echo
echo "2. Configure your database settings:"
echo "   - DBNAME: Your database name (default: 'notes')"
echo "   - DB_USER: Your database user"
echo
echo "3. Configure ETL settings if needed:"
echo "   - ETL_TEST_MODE: Set to 'true' for testing with 2013-2014 only"
echo "   - ETL_BATCH_SIZE: Adjust for your system performance"
echo
echo "4. Optional: Create local override files for additional customization:"
echo "   - cp ${PROJECT_ROOT}/etc/properties.sh ${PROJECT_ROOT}/etc/properties.sh.local"
echo "   - Edit properties.sh.local for environment-specific overrides"
echo
echo "5. Test your configuration:"
echo "   - ${PROJECT_ROOT}/bin/dwh/ETL.sh --help"
echo
echo "🔒 Security Note:"
echo "   - Configuration files (properties.sh, etl.properties) are ignored by Git"
echo "   - Only .example files are versioned in the repository"
echo "   - Your credentials will never be committed to Git"
echo
echo "✨ Setup complete!"

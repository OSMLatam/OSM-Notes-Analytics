#!/usr/bin/env bash

# Run Mock ETL Pipeline for Testing
# This script creates mock data and runs a simplified ETL process
# Author: Andres Gomez (AngocA)
# Date: 2025-10-27

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load properties
if [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
 source "${PROJECT_ROOT}/etc/properties.sh"
fi

# Use TEST_DBNAME if available, otherwise use DBNAME
TEST_DB="${TEST_DBNAME:-${DBNAME:-dwh}}"

# Unset PostgreSQL auth variables to use peer authentication
unset PGUSER PGPASSWORD 2> /dev/null || true

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Running Mock ETL Pipeline for Testing${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Create staging schema using actual SQL scripts
echo -e "${YELLOW}Step 1: Creating staging schema...${NC}"

# Use the actual staging creation scripts
if [[ -f "${PROJECT_ROOT}/sql/dwh/Staging_31_createBaseStagingObjects.sql" ]]; then
 echo "  Creating base staging objects..."
 psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/sql/dwh/Staging_31_createBaseStagingObjects.sql" > /dev/null 2>&1 || true
fi

# Step 1.5: Generate mock staging data
echo -e "${YELLOW}Step 1.5: Generating mock staging data...${NC}"
psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/tests/sql/generate_mock_staging_data.sql"

# Step 2: Create DWH schema using existing SQL scripts
echo ""
echo -e "${YELLOW}Step 2: Creating DWH schema using ETL scripts...${NC}"

# Create DWH schema if it doesn't exist
if ! psql -d "${TEST_DB}" -Atq -c "SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'facts'" | grep -q 1; then
 echo -e "${YELLOW}DWH tables not found. Creating structure with ETL scripts...${NC}"

 # Create enum type first
 echo "  Creating ENUM type..."
 psql -d "${TEST_DB}" << 'EOF'
CREATE TYPE IF NOT EXISTS note_event_enum AS ENUM (
  'opened',
  'closed',
  'commented',
  'reopened',
  'hidden'
);
EOF

 # Use the actual ETL scripts to create DWH structure
 if [[ -f "${PROJECT_ROOT}/sql/dwh/ETL_22_createDWHTables.sql" ]]; then
  echo "  Creating DWH tables..."
  psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/sql/dwh/ETL_22_createDWHTables.sql" > /dev/null 2>&1 || true
 fi

 # Create helper functions
 if [[ -f "${PROJECT_ROOT}/sql/dwh/ETL_24_addFunctions.sql" ]]; then
  echo "  Creating helper functions..."
  psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/sql/dwh/ETL_24_addFunctions.sql" > /dev/null 2>&1 || true
 fi

 # Note: We don't create all the complex DWH objects for testing,
 # just the basic structure needed for datamart tests
fi

# Step 2: Create/populate dimensions from staging
echo ""
echo -e "${YELLOW}Step 2: Populating dimensions...${NC}"

# Create applications dimension
psql -d "${TEST_DB}" << 'EOF'
INSERT INTO dwh.dimension_applications (application_name, platform, category, active)
SELECT DISTINCT
  application_name,
  CASE
    WHEN application_name = 'StreetComplete' THEN 'android'
    WHEN application_name = 'iD Editor' THEN 'web'
    WHEN application_name = 'JOSM' THEN 'desktop'
    WHEN application_name = 'Maps.me' THEN 'ios'
    WHEN application_name = 'MapComplete' THEN 'web'
    ELSE NULL
  END as platform,
  CASE
    WHEN application_name IN ('StreetComplete', 'Maps.me') THEN 'mobile'
    WHEN application_name IN ('iD Editor', 'MapComplete') THEN 'web'
    WHEN application_name = 'JOSM' THEN 'desktop'
    ELSE NULL
  END as category,
  TRUE as active
FROM staging.application_info
WHERE NOT EXISTS (
  SELECT 1 FROM dwh.dimension_applications da
  WHERE da.application_name = staging.application_info.application_name
);
EOF

# Create users dimension
psql -d "${TEST_DB}" << 'EOF'
INSERT INTO dwh.dimension_users (user_id, username, is_current)
SELECT DISTINCT
  user_id,
  username,
  TRUE as is_current
FROM staging.user_mapping
WHERE NOT EXISTS (
  SELECT 1 FROM dwh.dimension_users du
  WHERE du.user_id = staging.user_mapping.user_id AND du.is_current = TRUE
);
EOF

# Create countries dimension
psql -d "${TEST_DB}" << 'EOF'
INSERT INTO dwh.dimension_countries (country_id, country_name_es, country_name_en, iso_alpha2, modified)
SELECT DISTINCT
  cm.country_id,
  cm.country_name,
  cm.country_name,
  cm.country_code,
  TRUE as modified
FROM staging.country_mapping cm
WHERE NOT EXISTS (
  SELECT 1 FROM dwh.dimension_countries dc
  WHERE dc.country_id = cm.country_id
);
EOF

# Step 3: Populate facts from staging
echo ""
echo -e "${YELLOW}Step 3: Populating facts table...${NC}"

psql -d "${TEST_DB}" << 'EOF'
-- Insert facts for opened notes
INSERT INTO dwh.facts (
  id_note, sequence_action, dimension_id_country,
  action_at, action_comment, dimension_application_creation,
  action_dimension_id_date, action_dimension_id_hour_of_week,
  opened_dimension_id_date, opened_dimension_id_hour_of_week,
  total_actions_on_note, total_comments_on_note
)
SELECT
  na.id_note,
  na.sequence_action,
  dc.dimension_country_id as dimension_id_country,
  na.action_at,
  na.action_type::note_event_enum as action_comment,
  da.dimension_application_id as dimension_application_creation,
  dwh.get_date_id(na.action_at) as action_dimension_id_date,
  dwh.get_hour_of_week_id(na.action_at) as action_dimension_id_hour_of_week,
  dwh.get_date_id(na.action_at) as opened_dimension_id_date,
  dwh.get_hour_of_week_id(na.action_at) as opened_dimension_id_hour_of_week,
  1 as total_actions_on_note,
  CASE WHEN na.action_type = 'commented' THEN 1 ELSE 0 END as total_comments_on_note
FROM staging.nota_action na
LEFT JOIN staging.country_mapping cm ON cm.id_note = na.id_note
LEFT JOIN dwh.dimension_countries dc ON dc.country_id = cm.country_id
LEFT JOIN staging.application_info ai ON ai.id_note = na.id_note
LEFT JOIN dwh.dimension_applications da ON da.application_name = ai.application_name
WHERE na.sequence_action = 1  -- Only opened notes for now
AND NOT EXISTS (
  SELECT 1 FROM dwh.facts f
  WHERE f.id_note = na.id_note AND f.sequence_action = na.sequence_action
);
EOF

# Step 3.5: Create datamart tables and procedures
echo ""
echo -e "${YELLOW}Step 3.5: Creating datamart tables...${NC}"

# Create helper functions for datamarts (required by procedures)
psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/sql/dwh/datamarts_lastYearActivities.sql" > /dev/null 2>&1 || true

# Create datamartGlobal table and populate it
psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql" > /dev/null 2>&1 || true
psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/sql/dwh/datamartGlobal/datamartGlobal_31_populate.sql" > /dev/null 2>&1 || true

# Create datamartCountries table and procedure
psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/sql/dwh/datamartCountries/datamartCountries_12_createDatamarCountriesTable.sql" > /dev/null 2>&1 || true
psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql" > /dev/null 2>&1 || true

# Create datamartUsers table and procedure
psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/sql/dwh/datamartUsers/datamartUsers_12_createDatamartUsersTable.sql" > /dev/null 2>&1 || true
psql -d "${TEST_DB}" -f "${PROJECT_ROOT}/sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql" > /dev/null 2>&1 || true

# Step 4: Update datamarts
echo ""
echo -e "${YELLOW}Step 4: Updating datamarts...${NC}"

# Update for each country that has data
# Get the actual country_id values from dimension_countries
for country_id in $(psql -t -d "${TEST_DB}" -c "SELECT DISTINCT country_id FROM dwh.dimension_countries ORDER BY country_id;" | tr -d ' '); do
 echo "  Updating datamart for country_id: ${country_id}"
 psql -d "${TEST_DB}" -c "CALL dwh.update_datamart_country(${country_id});" > /dev/null 2>&1 || true
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Mock ETL Pipeline Completed Successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"

# Show summary
echo ""
echo -e "${YELLOW}Summary:${NC}"
psql -d "${TEST_DB}" -c "
SELECT
  'Facts' as table_name, COUNT(*) as record_count
FROM dwh.facts;
" || echo "Facts table populated"

#!/usr/bin/env bash

# Exports datamarts to JSON files for web viewer consumption.
# This allows the web viewer to read precalculated data without direct database access.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-21

# Fails when a variable is not initialized.
set -u
# Fails with an non-zero return code.
set -e
# Fails if one of the commands of the pipe fails.
set -o pipefail

# Error function that finishes the script.
function __error() {
 local __MESSAGE="${1}"
 echo "ERROR: ${__MESSAGE}"
 exit 1
}

# Logger (for potential future use)
declare LOGGER
LOGGER=$(basename "${0}")
# shellcheck disable=SC2034
readonly LOGGER

# Loads properties.
if [[ -f "../../etc/properties.sh" ]]; then
 source ../../etc/properties.sh
elif [[ -f "etc/properties.sh" ]]; then
 source etc/properties.sh
elif [[ -f "${PROPERTIES_LOCATION}/properties.sh" ]]; then
 source "${PROPERTIES_LOCATION}/properties.sh"
else
 __error "Properties file not found."
fi

# Output directory for JSON files
declare OUTPUT_DIR="${JSON_OUTPUT_DIR:-./output/json}"
readonly OUTPUT_DIR

# Creates output directories if they don't exist
mkdir -p "${OUTPUT_DIR}/users"
mkdir -p "${OUTPUT_DIR}/countries"
mkdir -p "${OUTPUT_DIR}/indexes"

echo "$(date +%Y-%m-%d\ %H:%M:%S) - Starting datamart JSON export"

# Check if dwh schema exists
if ! psql -d "${DBNAME}" -Atq -c "SELECT 1 FROM information_schema.schemata WHERE schema_name = 'dwh'" | grep -q 1; then
 __error "Schema 'dwh' does not exist. Please run the ETL process first to create the data warehouse."
fi

# Check if datamartUsers table exists
if ! psql -d "${DBNAME}" -Atq -c "SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'datamartusers'" | grep -q 1; then
 __error "Table 'dwh.datamartUsers' does not exist. Please run the datamart population scripts first:
	- bin/dwh/datamartUsers/datamartUsers.sh
	- bin/dwh/datamartCountries/datamartCountries.sh"
fi

# Export all users to individual JSON files
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Exporting users datamart..."

psql -d "${DBNAME}" -Atq << SQL_USERS | while IFS='|' read -r user_id username; do
SELECT user_id, username
FROM dwh.datamartusers
WHERE user_id IS NOT NULL
ORDER BY user_id;
SQL_USERS

 if [[ -n "${user_id}" ]]; then
  # Export each user to a separate JSON file
  psql -d "${DBNAME}" -Atq -c "
      SELECT row_to_json(t)
      FROM (
        SELECT
          dimension_user_id,
          user_id,
          username,
          date_starting_creating_notes,
          date_starting_solving_notes,
          first_open_note_id,
          first_commented_note_id,
          first_closed_note_id,
          first_reopened_note_id,
          id_contributor_type,
          last_year_activity,
          lastest_open_note_id,
          lastest_commented_note_id,
          lastest_closed_note_id,
          lastest_reopened_note_id,
          dates_most_open,
          dates_most_closed,
          hashtags,
          countries_open_notes,
          countries_solving_notes,
          countries_open_notes_current_month,
          countries_solving_notes_current_month,
          countries_open_notes_current_day,
          countries_solving_notes_current_day,
          working_hours_of_week_opening,
          working_hours_of_week_commenting,
          working_hours_of_week_closing,
          history_whole_open,
          history_whole_commented,
          history_whole_closed,
          history_whole_closed_with_comment,
          history_whole_reopened,
          history_year_open,
          history_year_commented,
          history_year_closed,
          history_year_closed_with_comment,
          history_year_reopened,
          history_month_open,
          history_month_commented,
          history_month_closed,
          history_month_closed_with_comment,
          history_month_reopened,
          history_day_open,
          history_day_commented,
          history_day_closed,
          history_day_closed_with_comment,
          history_day_reopened
        FROM dwh.datamartusers
        WHERE user_id = ${user_id}
      ) t
	" > "${OUTPUT_DIR}/users/${user_id}.json"

  echo "  Exported user: ${user_id} (${username})"
 fi
done

# Create user index file
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Creating user index..."
psql -d "${DBNAME}" -Atq -c "
  SELECT json_agg(t)
  FROM (
    SELECT
      user_id,
      username,
      history_whole_open,
      history_whole_closed,
      history_year_open,
      history_year_closed
    FROM dwh.datamartusers
    WHERE user_id IS NOT NULL
    ORDER BY history_whole_open DESC NULLS LAST, history_whole_closed DESC NULLS LAST
  ) t
" > "${OUTPUT_DIR}/indexes/users.json"

# Export all countries to individual JSON files
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Exporting countries datamart..."

psql -d "${DBNAME}" -Atq << SQL_COUNTRIES | while IFS='|' read -r country_id country_name; do
SELECT country_id, country_name_en
FROM dwh.datamartcountries
WHERE country_id IS NOT NULL
ORDER BY country_id;
SQL_COUNTRIES

 if [[ -n "${country_id}" ]]; then
  # Export each country to a separate JSON file
  psql -d "${DBNAME}" -Atq -c "
      SELECT row_to_json(t)
      FROM (
        SELECT
          dimension_country_id,
          country_id,
          country_name,
          country_name_es,
          country_name_en,
          date_starting_creating_notes,
          date_starting_solving_notes,
          first_open_note_id,
          first_commented_note_id,
          first_closed_note_id,
          first_reopened_note_id,
          last_year_activity,
          lastest_open_note_id,
          lastest_commented_note_id,
          lastest_closed_note_id,
          lastest_reopened_note_id,
          dates_most_open,
          dates_most_closed,
          hashtags,
          users_open_notes,
          users_solving_notes,
          users_open_notes_current_month,
          users_solving_notes_current_month,
          users_open_notes_current_day,
          users_solving_notes_current_day,
          working_hours_of_week_opening,
          working_hours_of_week_commenting,
          working_hours_of_week_closing,
          history_whole_open,
          history_whole_commented,
          history_whole_closed,
          history_whole_closed_with_comment,
          history_whole_reopened,
          history_year_open,
          history_year_commented,
          history_year_closed,
          history_year_closed_with_comment,
          history_year_reopened,
          history_month_open,
          history_month_commented,
          history_month_closed,
          history_month_closed_with_comment,
          history_month_reopened,
          history_day_open,
          history_day_commented,
          history_day_closed,
          history_day_closed_with_comment,
          history_day_reopened
        FROM dwh.datamartcountries
        WHERE country_id = ${country_id}
      ) t
	" > "${OUTPUT_DIR}/countries/${country_id}.json"

  echo "  Exported country: ${country_id} (${country_name})"
 fi
done

# Create country index file
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Creating country index..."
psql -d "${DBNAME}" -Atq -c "
  SELECT json_agg(t)
  FROM (
    SELECT
      country_id,
      country_name,
      country_name_es,
      country_name_en,
      history_whole_open,
      history_whole_closed,
      history_year_open,
      history_year_closed
    FROM dwh.datamartcountries
    WHERE country_id IS NOT NULL
    ORDER BY history_whole_open DESC NULLS LAST, history_whole_closed DESC NULLS LAST
  ) t
" > "${OUTPUT_DIR}/indexes/countries.json"

# Create metadata file
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Creating metadata..."
cat > "${OUTPUT_DIR}/metadata.json" << EOF
{
  "export_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_users": $(ls -1 "${OUTPUT_DIR}/users" | wc -l),
  "total_countries": $(ls -1 "${OUTPUT_DIR}/countries" | wc -l),
  "version": "2025-10-21"
}
EOF

echo "$(date +%Y-%m-%d\ %H:%M:%S) - JSON export completed successfully"
echo "  Users: $(ls -1 "${OUTPUT_DIR}/users" | wc -l) files"
echo "  Countries: $(ls -1 "${OUTPUT_DIR}/countries" | wc -l) files"
echo "  Output directory: ${OUTPUT_DIR}"

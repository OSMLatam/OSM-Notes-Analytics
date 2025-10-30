#!/usr/bin/env bash

# Minimal mock ETL to prepare local test DB with required schemas/tables and sample data
# Uses local peer authentication (no password). Target DB defaults to 'notes'.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DBNAME="${TEST_DBNAME:-${DBNAME:-notes}}"

echo "[MOCK-ETL] Using database: ${DBNAME}"

psql_cmd=(psql -d "${DBNAME}" -v ON_ERROR_STOP=1)

echo "[MOCK-ETL] Ensuring enum type exists (mock scope only)..."
"${psql_cmd[@]}" << 'SQL'
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_event_enum') THEN
  CREATE TYPE note_event_enum AS ENUM ('opened','closed','commented','reopened','hidden');
 END IF;
END
$$;
SQL

echo "[MOCK-ETL] Applying base DWH DDL (stripping enum CREATE for compatibility)..."
TMP_DDL="$(mktemp)"
awk '
  BEGIN {skip=0; skip1=0}
  /CREATE[[:space:]]+TYPE[[:space:]]+(IF[[:space:]]+NOT[[:space:]]+EXISTS[[:space:]]+)?note_event_enum[[:space:]]+AS[[:space:]]+ENUM[[:space:]]*\(/ {skip=1; next}
  skip && /^\);/ {skip=0; next}
  skip {next}
  /COMMENT[[:space:]]+ON[[:space:]]+TYPE[[:space:]]+note_event_enum/ {skip1=1; next}
  skip1 {skip1=0; next}
  {print}
' "${PROJECT_ROOT}/sql/dwh/ETL_22_createDWHTables.sql" > "${TMP_DDL}"
"${psql_cmd[@]}" -f "${TMP_DDL}"
rm -f "${TMP_DDL}"
HAS_PKS=$(psql -d "${DBNAME}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='dwh' AND constraint_name='pk_users_dim')")
HAS_FKS=$(psql -d "${DBNAME}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='dwh' AND constraint_name='fk_region')")

MODE="ALL"
if [[ "${HAS_PKS}" == "t" && "${HAS_FKS}" == "t" ]]; then
 MODE="NO_PK_FK"
elif [[ "${HAS_PKS}" == "t" ]]; then
 MODE="NO_PK"
fi

if [[ "${MODE}" == "ALL" ]]; then
 "${psql_cmd[@]}" -f "${PROJECT_ROOT}/sql/dwh/ETL_24_addFunctions.sql"
else
 TMP_FUNCS_DDL="$(mktemp)"
 if [[ "${MODE}" == "NO_PK" ]]; then
  awk '
      BEGIN {skip=0; skipidx=0}
      /Creating primary keys/ {skip=1; next}
      skip && /Creating foreign keys/ {skip=0}
      skip {next}
      /^CREATE UNIQUE INDEX (dimension_country_id_uniq|dimension_day_id_uniq)/ {skipidx=1; next}
      skipidx && /;[[:space:]]*$/ {skipidx=0; next}
      skipidx {next}
      {print}
    ' "${PROJECT_ROOT}/sql/dwh/ETL_24_addFunctions.sql" > "${TMP_FUNCS_DDL}"
 else
  awk '
      BEGIN {skip=0; skip2=0; skipidx=0}
      /Creating primary keys/ {skip=1; next}
      skip && /Creating foreign keys/ {skip=0}
      skip {next}
      /Creating foreign keys/ {skip2=1; next}
      skip2 && /Creating indexes/ {skip2=0}
      skip2 {next}
      /^CREATE UNIQUE INDEX (dimension_country_id_uniq|dimension_day_id_uniq)/ {skipidx=1; next}
      skipidx && /;[[:space:]]*$/ {skipidx=0; next}
      skipidx {next}
      {print}
    ' "${PROJECT_ROOT}/sql/dwh/ETL_24_addFunctions.sql" > "${TMP_FUNCS_DDL}"
 fi
 "${psql_cmd[@]}" -f "${TMP_FUNCS_DDL}"
 rm -f "${TMP_FUNCS_DDL}"
fi
HAS_FACT_FK=$(psql -d "${DBNAME}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='dwh' AND table_name='facts' AND constraint_name='fk_country')")
HAS_FACT_IDX=$(psql -d "${DBNAME}" -tAc "SELECT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='dwh' AND indexname='facts_action_date')")
if [[ "${HAS_FACT_FK}" == "t" || "${HAS_FACT_IDX}" == "t" ]]; then
 TMP_41_DDL="$(mktemp)"
 awk -v skip_fk="${HAS_FACT_FK}" -v skip_idx="${HAS_FACT_IDX}" '
    BEGIN {s1=0; s2=0}
    /Creating foreign keys/ { if (skip_fk=="t") { s1=1; next } }
    s1 && /Creating indexes/ { s1=0 }
    s1 { next }
    /Creating indexes/ { if (skip_idx=="t") { s2=1; next } }
    s2 && /Creating triggers/ { s2=0; print "SELECT /* Notes-ETL */ clock_timestamp() AS Processing,"; print $0; next }
    /^SELECT .*Processing,/ { next }
    /Skipping primary key \(partitioned table\)/ { print "SELECT /* Notes-ETL */ clock_timestamp() AS Processing,"; print $0; next }
    s2 { next }
    { print }
  ' "${PROJECT_ROOT}/sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql" > "${TMP_41_DDL}"
 "${psql_cmd[@]}" -f "${TMP_41_DDL}"
 rm -f "${TMP_41_DDL}"
else
 "${psql_cmd[@]}" -f "${PROJECT_ROOT}/sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql"
fi

echo "[MOCK-ETL] Creating datamart tables..."
# datamartCountries: skip PK if it already exists
HAS_PK_DC=$(psql -d "${DBNAME}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='dwh' AND table_name='datamartcountries' AND constraint_type='PRIMARY KEY')")
if [[ "${HAS_PK_DC}" == "t" ]]; then
 TMP_DC12_DDL="$(mktemp)"
 awk '
    BEGIN {skip=0}
    /^ALTER TABLE dwh\.datamartCountries/ {skip=1; next}
    skip && /;[[:space:]]*$/ {skip=0; next}
    skip {next}
    {print}
  ' "${PROJECT_ROOT}/sql/dwh/datamartCountries/datamartCountries_12_createDatamarCountriesTable.sql" > "${TMP_DC12_DDL}"
 "${psql_cmd[@]}" -f "${TMP_DC12_DDL}"
 rm -f "${TMP_DC12_DDL}"
else
 "${psql_cmd[@]}" -f "${PROJECT_ROOT}/sql/dwh/datamartCountries/datamartCountries_12_createDatamarCountriesTable.sql"
fi

# datamartUsers: skip PK blocks that already exist
HAS_PK_DU=$(psql -d "${DBNAME}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='dwh' AND table_name='datamartusers' AND constraint_type='PRIMARY KEY')")
HAS_PK_BADGES=$(psql -d "${DBNAME}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='dwh' AND table_name='badges' AND constraint_type='PRIMARY KEY')")
HAS_PK_BADGE_USERS=$(psql -d "${DBNAME}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='dwh' AND table_name='badges_per_users' AND constraint_type='PRIMARY KEY')")
HAS_PK_CONTR_TYPES=$(psql -d "${DBNAME}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema='dwh' AND table_name='contributor_types' AND constraint_type='PRIMARY KEY')")
if [[ "${HAS_PK_DU}" == "t" || "${HAS_PK_BADGES}" == "t" || "${HAS_PK_BADGE_USERS}" == "t" || "${HAS_PK_CONTR_TYPES}" == "t" ]]; then
 TMP_DU12_DDL="$(mktemp)"
 awk -v pk_du="${HAS_PK_DU}" -v pk_b="${HAS_PK_BADGES}" -v pk_bu="${HAS_PK_BADGE_USERS}" -v pk_ct="${HAS_PK_CONTR_TYPES}" '
    BEGIN {skip=0}
    /^ALTER TABLE dwh\.datamartUsers/ { if (pk_du=="t") { skip=1; next } }
    /^ALTER TABLE dwh\.badges$/ { if (pk_b=="t") { skip=1; next } }
    /^ALTER TABLE dwh\.badges_per_users$/ { if (pk_bu=="t") { skip=1; next } }
    /^ALTER TABLE dwh\.contributor_types$/ { if (pk_ct=="t") { skip=1; next } }
    skip && /;[[:space:]]*$/ { skip=0; next }
    skip { next }
    { print }
  ' "${PROJECT_ROOT}/sql/dwh/datamartUsers/datamartUsers_12_createDatamartUsersTable.sql" > "${TMP_DU12_DDL}"
 "${psql_cmd[@]}" -f "${TMP_DU12_DDL}"
 rm -f "${TMP_DU12_DDL}"
else
 "${psql_cmd[@]}" -f "${PROJECT_ROOT}/sql/dwh/datamartUsers/datamartUsers_12_createDatamartUsersTable.sql"
fi

# Ensure new temporal resolution JSON columns exist (idempotent)
"${psql_cmd[@]}" -c "ALTER TABLE dwh.datamartCountries ADD COLUMN IF NOT EXISTS resolution_by_year JSON;"
"${psql_cmd[@]}" -c "ALTER TABLE dwh.datamartCountries ADD COLUMN IF NOT EXISTS resolution_by_month JSON;"
"${psql_cmd[@]}" -c "ALTER TABLE dwh.datamartUsers ADD COLUMN IF NOT EXISTS resolution_by_year JSON;"
"${psql_cmd[@]}" -c "ALTER TABLE dwh.datamartUsers ADD COLUMN IF NOT EXISTS resolution_by_month JSON;"

# Create global datamart if script exists (best effort)
if [[ -f "${PROJECT_ROOT}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql" ]]; then
 "${psql_cmd[@]}" -f "${PROJECT_ROOT}/sql/dwh/datamartGlobal/datamartGlobal_12_createTable.sql" || true
fi

echo "[MOCK-ETL] Loading sample test data..."
"${psql_cmd[@]}" -f "${PROJECT_ROOT}/tests/sql/setup_test_data.sql"

echo "[MOCK-ETL] Ensuring dimension flags are set for recalculation..."
"${psql_cmd[@]}" -c "UPDATE dwh.dimension_countries SET modified = TRUE;"
"${psql_cmd[@]}" -c "UPDATE dwh.dimension_users SET modified = TRUE;" || true

echo "[MOCK-ETL] Creating/refreshing datamart procedures (best effort) ..."
# Create procedures if needed; rely on existing files
if [[ -f "${PROJECT_ROOT}/sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql" ]]; then
 "${psql_cmd[@]}" -f "${PROJECT_ROOT}/sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql"
fi
if [[ -f "${PROJECT_ROOT}/sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql" ]]; then
 "${psql_cmd[@]}" -f "${PROJECT_ROOT}/sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql"
fi

echo "[MOCK-ETL] Populating datamartCountries..."
"${psql_cmd[@]}" -c '
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT DISTINCT dimension_id_country AS id
    FROM dwh.facts
    WHERE dimension_id_country IS NOT NULL
  ) LOOP
    BEGIN
      CALL dwh.update_datamart_country(r.id);
    EXCEPTION WHEN OTHERS THEN
      -- ignore test data gaps
      NULL;
    END;
  END LOOP;
END$$;
'

echo "[MOCK-ETL] Populating datamartUsers..."
"${psql_cmd[@]}" -c '
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT DISTINCT action_dimension_id_user AS id
    FROM dwh.facts
    WHERE action_dimension_id_user IS NOT NULL
  ) LOOP
    BEGIN
      CALL dwh.update_datamart_user(r.id);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;
END$$;
'

echo "[MOCK-ETL] Done."
echo "Mock ETL Pipeline Completed Successfully"

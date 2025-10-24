# Star model

Version: 2025-08-08

This document describes the star schema used by the data warehouse.
It includes the fact table, the dimensions, their relationships,
and the ETL flow that populates them.

## ETL flow (high level)

```mermaid
flowchart TD
  A[Base tables: notes, note_comments, note_comments_text, users, countries]
    --> B[Staging functions & procedures]
  B -->|process_notes_at_date / per-year variants| C[staging.facts_${YEAR}]
  C --> D[Unify]
  D --> E[dwh.facts]
  B --> F[Update dimensions]
  F --> E
```

- The staging procedures select note actions from base tables by date,
  resolve dimensional keys, and write to `staging.facts_${YEAR}` or
  directly to `dwh.facts` depending on the path.
- The unify step ensures `recent_opened_dimension_id_date` is filled for
  all facts before enforcing NOT NULL.
- A trigger computes resolution-day metrics when a closing action is
  inserted.

Key scripts:

- `sql/dwh/ETL_22_createDWHTables.sql`
- `sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql`
- `sql/dwh/ETL_25_populateDimensionTables.sql`
- `sql/dwh/ETL_26_updateDimensionTables.sql`
- `sql/dwh/Staging_31_createBaseStagingObjects.sql`
- `sql/dwh/Staging_32_createStagingObjects.sql`
- `sql/dwh/Staging_34_initialFactsLoadCreate.sql`
- `sql/dwh/Staging_35_initialFactsLoadExecute.sql`
- `sql/dwh/Staging_51_unify.sql`

### Fact table: dwh.facts

Columns:

- fact_id: Surrogate key (PK).
- id_note: OSM note identifier.
- sequence_action: Creation sequence per note action.
- dimension_id_country: Country (dimension key) where the note belongs.
- processing_time: Timestamp when the fact was inserted.
- action_at: Timestamp when the action occurred.
- action_comment: Action type: opened, closed, reopened, commented, hidden.
- action_dimension_id_date: Date (dimension key) of the action.
- action_dimension_id_hour_of_week: Hour-of-week (dimension key) of action.
- action_dimension_id_user: User (dimension key) who did the action.
- opened_dimension_id_date: Date (dimension key) when the note was created.
- opened_dimension_id_hour_of_week: Hour-of-week at note creation.
- opened_dimension_id_user: User (dimension key) who created the note.
- closed_dimension_id_date: Date (dimension key) when the note was closed.
- closed_dimension_id_hour_of_week: Hour-of-week at note closure.
- closed_dimension_id_user: User (dimension key) who closed the note.
- dimension_application_creation: Application (dimension key) used to open.
- recent_opened_dimension_id_date: Most recent open/reopen date (dimension).
- days_to_resolution: Days from first open to most recent close.
- days_to_resolution_active: Sum of days while the note was open
  across reopen periods.
- days_to_resolution_from_reopen: Days from last reopen to most recent close.
- hashtag_1..hashtag_5: Up to five hashtag dimension keys found in the
  action text (at open, or any action as parsed).
- hashtag_number: Total number of hashtags detected in the text.

Relationships and indexes (non-exhaustive):

- PK: `fact_id`.
- FKs to `dimension_countries`, `dimension_days`, `dimension_time_of_week`,
  `dimension_users`, and `dimension_applications`.
- Indexes on timestamps, user/date/action combinations, country/action, and
  reopen/recent fields for common analytics queries (see
  `ETL_41_addConstraintsIndexesTriggers.sql`).

Example fact (conceptual):

- id_note=12345, action_comment='closed', action_at='2024-05-11 14:03Z',
  action_dimension_id_date=20240511, action_dimension_id_hour_of_week=110,
  action_dimension_id_user=42, opened_dimension_id_date=20240501,
  closed_dimension_id_date=20240511, dimension_id_country=57,
  recent_opened_dimension_id_date=20240501,
  days_to_resolution=10, days_to_resolution_from_reopen=NULL,
  hashtag_1=301, hashtag_number=1.

### Dimensions

#### Users: dwh.dimension_users

Columns:

- dimension_user_id: Surrogate key (PK).
- user_id: OSM user id.
- username: Most recent username.
- modified: Flag used by datamart refreshes.

Example:

- { dimension_user_id: 42, user_id: 9876, username: "mapper123",
  modified: true }

#### Countries: dwh.dimension_countries

Columns:

- dimension_country_id: Surrogate key (PK).
- country_id: OSM relation id of the country.
- country_name: Local language name.
- country_name_es: Spanish name.
- country_name_en: English name.
- region_id: Region (dimension key).
- modified: Flag used by datamart refreshes.

Example:

- { dimension_country_id: 57, country_id: 51477, country_name: "Colombia",
  country_name_es: "Colombia", country_name_en: "Colombia",
  region_id: 14, modified: true }

#### Regions: dwh.dimension_regions

Columns:

- dimension_region_id: Surrogate key (PK).
- region_name_es: Spanish name.
- region_name_en: English name.

Example:

- { dimension_region_id: 14, region_name_es: "Sudamérica",
  region_name_en: "South America" }

#### Days: dwh.dimension_days

Columns:

- dimension_day_id: Surrogate key (PK).
- date_id: Date.
- year: Year component of the date.
- month: Month component of the date.
- day: Day of month of the date.

Example:

- { dimension_day_id: 20240511, date_id: "2024-05-11",
  year: 2024, month: 5, day: 11 }

#### Time of week: dwh.dimension_time_of_week

Columns:

- dimension_tow_id: Surrogate key (PK). Encodes day-of-week and hour.
- day_of_week: 1..7 (ISO).
- hour_of_day: 0..23.
- hour_of_week: 0..167.
- period_of_day: Night/Morning/Afternoon/Evening.

Example:

- { dimension_tow_id: 114, day_of_week: 4, hour_of_day: 14, hour_of_week: 86,
  period_of_day: "Afternoon" }

#### Applications: dwh.dimension_applications

Columns:

- dimension_application_id: Surrogate key (PK).
- application_name: Application name.
- pattern: Pattern used to detect the app in text (SIMILAR TO).
- platform: Optional platform discriminator.

Example:

- { dimension_application_id: 5, application_name: "StreetComplete",
  pattern: "%via StreetComplete%", platform: null }

#### Hashtags: dwh.dimension_hashtags

Columns:

- dimension_hashtag_id: Surrogate key (PK).
- description: Hashtag text.

Example:

- { dimension_hashtag_id: 301, description: "MapComplete" }

### Datamart tables

There are additional datamart tables with precomputed data for common
queries. See `sql/dwh/datamartCountries` and `sql/dwh/datamartUsers`.

### Operational files

- `bin/dwh/ETL.sh`: Orchestrates the ETL process, validates SQL, populates
  dimensions, and loads facts incrementally.
- `bin/dwh/profile.sh`: Generates profiles for a country or a user against
  the datamarts.
- `bin/dwh/exportDatamartsToJSON.sh`: Exports datamarts to JSON files for
  web viewer consumption with atomic writes and schema validation.

## JSON Export

The `exportDatamartsToJSON.sh` script exports datamart data to JSON files
for consumption by the web viewer. It provides:

### Features

- **Atomic writes**: Files generated in temporary directory, validated, then moved atomically
- **Schema validation**: Each JSON file validated against schemas before export
- **Fail-safe**: On validation failure, keeps existing files and logs error
- **No partial updates**: Either all files are valid and moved, or none

### Usage

```bash
# Basic export
./bin/dwh/exportDatamartsToJSON.sh

# With custom output directory
export JSON_OUTPUT_DIR=/var/www/osm-notes-data
./bin/dwh/exportDatamartsToJSON.sh
```

### Output Structure

```
output/json/
├── users/
│   ├── 123.json
│   ├── 456.json
│   └── ...
├── countries/
│   ├── 1.json
│   ├── 2.json
│   └── ...
├── indexes/
│   ├── users.json
│   └── countries.json
└── metadata.json
```

### Cron Integration

For automated exports:

```bash
# Export every 15 minutes after datamarts update
45 2 * * * ~/OSM-Notes-Analytics/bin/dwh/exportDatamartsToJSON.sh
```

Or use a complete workflow wrapper:

```bash
# Complete pipeline: ETL → Datamarts → JSON Export
*/15 * * * * /opt/osm-analytics/update-and-export.sh
```

See [Atomic Validation Export](docs/ATOMIC_VALIDATION_EXPORT.md) for detailed documentation.

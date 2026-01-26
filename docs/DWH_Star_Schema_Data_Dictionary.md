---
title: "DWH Star Schema Data Dictionary"
description: "This document provides a tabular data dictionary for the star schema used in the data warehouse. It"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "database"
audience:
  - "developers"
project: "OSM-Notes-Analytics"
status: "active"
---


# DWH Star Schema Data Dictionary

This document provides a tabular data dictionary for the star schema used in the data warehouse. It
covers the fact table and all dimensions, including data types, nullability, defaults, keys, and
functional descriptions.

Conventions:

- Types are PostgreSQL types.
- PK: Primary Key, FK: Foreign Key.
- N: NOT NULL, Y: NULL allowed.

## Table: dwh.facts

Central fact table with one row per note action (open, comment, reopen, close, hide).

| Column                           | Type            | Null | Default           | Key | Description                                        |
| -------------------------------- | --------------- | ---- | ----------------- | --- | -------------------------------------------------- |
| fact_id                          | SERIAL          | N    | auto              | PK  | Surrogate key                                      |
| id_note                          | INTEGER         | N    |                   |     | OSM note id                                        |
| sequence_action                  | INTEGER         | Y    |                   |     | Creation sequence per action                       |
| dimension_id_country             | INTEGER         | N    |                   | FK  | Country dimension key                              |
| processing_time                  | TIMESTAMP       | N    | CURRENT_TIMESTAMP |     | Insert timestamp                                   |
| action_at                        | TIMESTAMP       | N    |                   |     | Action timestamp                                   |
| action_comment                   | note_event_enum | N    |                   |     | Action type: opened/closed/...                     |
| action_dimension_id_date         | INTEGER         | N    |                   | FK  | Date dimension key of action                       |
| action_dimension_id_hour_of_week | SMALLINT        | N    |                   | FK  | Hour-of-week dimension key of action               |
| action_dimension_id_user         | INTEGER         | Y    |                   | FK  | User dimension key of action                       |
| opened_dimension_id_date         | INTEGER         | N    |                   | FK  | Date dimension key when note was opened            |
| opened_dimension_id_hour_of_week | SMALLINT        | N    |                   | FK  | Hour-of-week key when note was opened              |
| opened_dimension_id_user         | INTEGER         | Y    |                   | FK  | User dimension key who opened                      |
| closed_dimension_id_date         | INTEGER         | Y    |                   | FK  | Date dimension key when closed                     |
| closed_dimension_id_hour_of_week | SMALLINT        | Y    |                   | FK  | Hour-of-week key when closed                       |
| closed_dimension_id_user         | INTEGER         | Y    |                   | FK  | User dimension key who closed                      |
| dimension_application_creation   | INTEGER         | Y    |                   | FK  | Application dimension key used to open             |
| recent_opened_dimension_id_date  | INTEGER         | N    |                   | FK  | Most recent open/reopen date key                   |
| days_to_resolution               | INTEGER         | Y    |                   |     | Days from first open to most recent close          |
| days_to_resolution_active        | INTEGER         | Y    |                   |     | Total days in open status across reopens           |
| days_to_resolution_from_reopen   | INTEGER         | Y    |                   |     | Days from last reopen to most recent close         |
| hashtag_number                   | INTEGER         | Y    |                   |     | Total number of hashtags detected                  |
| comment_length                   | INTEGER         | Y    |                   |     | Length of comment text                             |
| has_url                          | BOOLEAN         | Y    | FALSE             |     | True if comment contains URL                       |
| has_mention                      | BOOLEAN         | Y    | FALSE             |     | True if comment mentions another user              |
| total_comments_on_note           | INTEGER         | Y    |                   |     | Total comments count UP TO this action (trigger)   |
| total_reopenings_count           | INTEGER         | Y    |                   |     | Total reopenings count UP TO this action (trigger) |
| total_actions_on_note            | INTEGER         | Y    |                   |     | Total actions count UP TO this action (trigger)    |

## Table: dwh.fact_hashtags

Bridge table linking facts to hashtags with action classification.

| Column                | Type            | Null | Default | Key | Description                        |
| --------------------- | --------------- | ---- | ------- | --- | ---------------------------------- |
| fact_id               | INTEGER         | N    |         | FK  | Reference to facts table           |
| dimension_hashtag_id  | INTEGER         | N    |         | FK  | Reference to hashtag dimension     |
| position              | SMALLINT        | Y    |         |     | Position of hashtag in comment     |
| used_in_action        | note_event_enum | Y    |         |     | Action type where hashtag was used |
| is_opening_hashtag    | BOOLEAN         | Y    | FALSE   |     | True if used in note opening       |
| is_resolution_hashtag | BOOLEAN         | Y    | FALSE   |     | True if used in note resolution    |

Notes:

- FKs: country → `dwh.dimension_countries.dimension_country_id`, date/hour/user → corresponding
  dimensions, application → `dwh.dimension_applications.dimension_application_id`.
- Hashtags are stored in bridge table `dwh.fact_hashtags` (see below).
- `recent_opened_dimension_id_date` is enforced NOT NULL after unify step.
- Resolution day metrics are maintained by trigger on insert of closing actions.
- `comment_length`, `has_url`, `has_mention` are calculated during ETL from comment text.
- `total_comments_on_note`, `total_reopenings_count`, `total_actions_on_note` are calculated by
  trigger BEFORE INSERT for historical accuracy (performance impact: 1 SELECT per row inserted).

## Hashtag Analysis Views

### dwh.v_hashtags_opening

Most used hashtags in note opening actions with usage statistics.

### dwh.v_hashtags_resolution

Most used hashtags in note resolution/closure actions with resolution metrics.

### dwh.v_hashtags_comments

Most used hashtags in comment actions with engagement metrics.

### dwh.v_hashtags_by_action

Hashtag usage breakdown by action type (opened/commented/closed/etc).

### dwh.v_hashtags_top_overall

Top hashtags overall with breakdown by action type and geographic/user distribution.

## Table: dwh.dimension_users

| Column            | Type         | Null | Default | Key | Description               |
| ----------------- | ------------ | ---- | ------- | --- | ------------------------- |
| dimension_user_id | SERIAL       | N    | auto    | PK  | Surrogate key             |
| user_id           | INTEGER      | N    |         |     | OSM user id               |
| username          | VARCHAR(256) | Y    |         |     | Most recent username      |
| modified          | BOOLEAN      | Y    |         |     | Flag for datamart updates |

## Table: dwh.dimension_regions

| Column              | Type        | Null | Default | Key | Description     |
| ------------------- | ----------- | ---- | ------- | --- | --------------- |
| dimension_region_id | SERIAL      | N    | auto    | PK  | Surrogate key   |
| region_name_es      | VARCHAR(60) | Y    |         |     | Name in Spanish |
| region_name_en      | VARCHAR(60) | Y    |         |     | Name in English |

## Table: dwh.dimension_countries

| Column               | Type         | Null | Default | Key | Description                      |
| -------------------- | ------------ | ---- | ------- | --- | -------------------------------- |
| dimension_country_id | SERIAL       | N    | auto    | PK  | Surrogate key                    |
| country_id           | INTEGER      | N    |         |     | OSM relation id                  |
| country_name         | VARCHAR(100) | Y    |         |     | Local name                       |
| country_name_es      | VARCHAR(100) | Y    |         |     | Spanish name                     |
| country_name_en      | VARCHAR(100) | Y    |         |     | English name                     |
| region_id            | INTEGER      | Y    |         | FK  | Region key → `dimension_regions` |
| modified             | BOOLEAN      | Y    |         |     | Flag for datamart updates        |

## Table: dwh.dimension_days

| Column           | Type        | Null | Default | Key | Description          |
| ---------------- | ----------- | ---- | ------- | --- | -------------------- |
| dimension_day_id | SERIAL      | N    | auto    | PK  | Surrogate key        |
| date_id          | DATE        | Y    |         |     | Full date            |
| year             | SMALLINT    | Y    |         |     | Year component       |
| month            | SMALLINT    | Y    |         |     | Month component      |
| day              | SMALLINT    | Y    |         |     | Day component        |
| iso_year         | SMALLINT    | Y    |         |     | ISO year             |
| iso_week         | SMALLINT    | Y    |         |     | ISO week (1..53)     |
| day_of_year      | SMALLINT    | Y    |         |     | Day of year (1..366) |
| quarter          | SMALLINT    | Y    |         |     | Quarter (1..4)       |
| month_name       | VARCHAR(16) | Y    |         |     | Month name (en)      |
| day_name         | VARCHAR(16) | Y    |         |     | Day name (en, ISO)   |
| is_weekend       | BOOLEAN     | Y    |         |     | Weekend flag (ISO)   |
| is_month_end     | BOOLEAN     | Y    |         |     | Month-end flag       |
| is_quarter_end   | BOOLEAN     | Y    |         |     | Quarter-end flag     |
| is_year_end      | BOOLEAN     | Y    |         |     | Year-end flag        |

## Table: dwh.dimension_time_of_week

| Column           | Type        | Null | Default | Key | Description                     |
| ---------------- | ----------- | ---- | ------- | --- | ------------------------------- |
| dimension_tow_id | SMALLINT    | Y    |         | PK  | Encodes day-of-week and hour    |
| day_of_week      | SMALLINT    | Y    |         |     | 1..7 (ISO)                      |
| hour_of_day      | SMALLINT    | Y    |         |     | 0..23                           |
| hour_of_week     | SMALLINT    | Y    |         |     | 0..167                          |
| period_of_day    | VARCHAR(16) | Y    |         |     | Night/Morning/Afternoon/Evening |

## Table: dwh.dimension_applications

| Column                   | Type        | Null | Default | Key | Description                            |
| ------------------------ | ----------- | ---- | ------- | --- | -------------------------------------- |
| dimension_application_id | SERIAL      | N    | auto    | PK  | Surrogate key                          |
| application_name         | VARCHAR(64) | N    |         |     | Application name                       |
| pattern                  | VARCHAR(64) | Y    |         |     | Pattern used to detect the app in text |
| pattern_type             | VARCHAR(16) | Y    |         |     | SIMILAR/LIKE/REGEXP                    |
| platform                 | VARCHAR(16) | Y    |         |     | Optional platform                      |
| vendor                   | VARCHAR(32) | Y    |         |     | Vendor/author                          |
| category                 | VARCHAR(32) | Y    |         |     | Category/type                          |
| active                   | BOOLEAN     | Y    |         |     | Active flag                            |

## Table: dwh.dimension_hashtags

| Column               | Type   | Null | Default | Key | Description   |
| -------------------- | ------ | ---- | ------- | --- | ------------- |
| dimension_hashtag_id | SERIAL | N    | auto    | PK  | Surrogate key |
| description          | TEXT   | Y    |         |     | Hashtag text  |

## Operational table: dwh.properties

## Table: dwh.dimension_timezones

| Column                | Type        | Null | Default | Key | Description                      |
| --------------------- | ----------- | ---- | ------- | --- | -------------------------------- |
| dimension_timezone_id | SERIAL      | N    | auto    | PK  | Surrogate key                    |
| tz_name               | VARCHAR(64) | N    |         |     | IANA timezone name or UTC±N band |
| utc_offset_minutes    | SMALLINT    | Y    |         |     | UTC offset in minutes            |

## Table: dwh.dimension_seasons

| Column              | Type        | Null | Default | Key | Description      |
| ------------------- | ----------- | ---- | ------- | --- | ---------------- |
| dimension_season_id | SMALLINT    | N    |         | PK  | Season id        |
| season_name_en      | VARCHAR(16) | Y    |         |     | Season name (en) |
| season_name_es      | VARCHAR(16) | Y    |         |     | Season name (es) |

## Table: dwh.dimension_automation_level

| Column                  | Type         | Null | Default           | Key | Description                                                                         |
| ----------------------- | ------------ | ---- | ----------------- | --- | ----------------------------------------------------------------------------------- |
| dimension_automation_id | SMALLINT     | N    |                   | PK  | Automation level id                                                                 |
| automation_level        | VARCHAR(30)  | N    |                   |     | Level name: human/probably_human/uncertain/probably_automated/automated/bulk_import |
| confidence_score        | DECIMAL(3,2) | N    |                   |     | Confidence 0.00-1.00                                                                |
| description             | TEXT         | Y    |                   |     | Human-readable description                                                          |
| detection_criteria      | JSONB        | Y    |                   |     | Criteria that triggered classification                                              |
| created_at              | TIMESTAMP    | Y    | CURRENT_TIMESTAMP |     | Creation timestamp                                                                  |

## Table: dwh.dimension_experience_levels

| Column                  | Type        | Null | Default | Key | Description                                                              |
| ----------------------- | ----------- | ---- | ------- | --- | ------------------------------------------------------------------------ |
| dimension_experience_id | SMALLINT    | N    |         | PK  | Experience level id                                                      |
| experience_level        | VARCHAR(30) | N    |         |     | Level name: newcomer/beginner/intermediate/advanced/expert/master/legend |
| min_notes_opened        | INTEGER     | N    |         |     | Minimum notes opened to qualify                                          |
| min_notes_closed        | INTEGER     | N    |         |     | Minimum notes closed to qualify                                          |
| min_days_active         | INTEGER     | N    |         |     | Minimum days active to qualify                                           |
| level_order             | SMALLINT    | N    |         |     | Sort order (1=newcomer, 7=legend)                                        |
| description             | TEXT        | Y    |         |     | Human-readable description                                               |

## Table: dwh.dimension_continents

| Column                 | Type        | Null | Default | Key | Description    |
| ---------------------- | ----------- | ---- | ------- | --- | -------------- |
| dimension_continent_id | SERIAL      | N    | auto    | PK  | Surrogate key  |
| continent_name_es      | VARCHAR(32) | Y    |         |     | Continent (es) |
| continent_name_en      | VARCHAR(32) | Y    |         |     | Continent (en) |

## Updates to existing tables

### dwh.dimension_countries (added columns)

| Column     | Type       | Description        |
| ---------- | ---------- | ------------------ |
| iso_alpha2 | VARCHAR(2) | ISO 3166-1 alpha-2 |
| iso_alpha3 | VARCHAR(3) | ISO 3166-1 alpha-3 |

### dwh.dimension_users (SCD2 columns)

| Column     | Type      | Description      |
| ---------- | --------- | ---------------- |
| valid_from | TIMESTAMP | Validity start   |
| valid_to   | TIMESTAMP | Validity end     |
| is_current | BOOLEAN   | Current row flag |

### dwh.dimension_users (Experience columns)

| Column                   | Type         | Description                               |
| ------------------------ | ------------ | ----------------------------------------- |
| experience_level_id      | SMALLINT     | FK to experience level                    |
| total_notes_opened       | INTEGER      | Total notes opened by user                |
| total_notes_closed       | INTEGER      | Total notes closed by user                |
| days_active              | INTEGER      | Days between first and last activity      |
| resolution_ratio         | DECIMAL(4,2) | % of opened notes that were closed        |
| last_activity_date       | DATE         | Date of most recent activity              |
| experience_calculated_at | TIMESTAMP    | When experience level was last calculated |

### dwh.facts (added columns)

| Column                                 | Type     | Description            |
| -------------------------------------- | -------- | ---------------------- |
| action_timezone_id                     | INTEGER  | FK to timezone         |
| local_action_dimension_id_date         | INTEGER  | Local date id          |
| local_action_dimension_id_hour_of_week | SMALLINT | Local time-of-week id  |
| action_dimension_id_season             | SMALLINT | Season id              |
| dimension_application_version          | INTEGER  | FK to app version      |
| comment_length                         | INTEGER  | Length of comment text |
| has_url                                | BOOLEAN  | Comment contains URL   |
| has_mention                            | BOOLEAN  | Comment mentions user  |
| dimension_id_automation                | SMALLINT | FK to automation level |

## Table: dwh.dimension_application_versions

| Column                           | Type        | Null | Default | Key | Description    |
| -------------------------------- | ----------- | ---- | ------- | --- | -------------- |
| dimension_application_version_id | SERIAL      | N    | auto    | PK  | Surrogate key  |
| dimension_application_id         | INTEGER     | N    |         | FK  | Application    |
| version                          | VARCHAR(32) | N    |         |     | Version string |

| Column               | Type     | Description              |
| -------------------- | -------- | ------------------------ |
| fact_id              | INTEGER  | FK to facts              |
| dimension_hashtag_id | INTEGER  | FK to hashtags           |
| position             | SMALLINT | Positional order in text |

Used internally by ETL orchestration.

| Column | Type        | Null | Default | Key | Description    |
| ------ | ----------- | ---- | ------- | --- | -------------- |
| key    | VARCHAR(16) | Y    |         |     | Property name  |
| value  | VARCHAR(26) | Y    |         |     | Property value |

---

## Datamarts

The data warehouse includes pre-computed datamarts that aggregate metrics from the star schema for
fast analytics queries. These datamarts are updated incrementally and provide ready-to-use metrics
for dashboards and reports.

### Table: dwh.datamartCountries

Pre-computed analytics aggregated by country. Contains **77+ metrics** covering:

- Historical counts (whole history, by year, by month)
- Resolution metrics (average/median days to resolution, resolution rates)
- Application statistics (usage patterns, mobile vs desktop)
- Content quality metrics (comment length, URLs, mentions)
- Community health metrics (backlog, health score, activity trends)
- Temporal patterns (hour-of-week, day-of-week distributions)
- Geographic patterns
- Hashtag metrics

**Key Columns:**

- `dimension_country_id` (PK): Reference to country dimension
- `country_name`, `country_name_en`, `country_name_es`: Country names
- `iso_alpha2`, `iso_alpha3`: ISO codes
- **77+ metric columns**: See [Metric Definitions](Metric_Definitions.md) for complete list

**Update Procedure:** `dwh.update_datamart_country(dimension_country_id)`

**Full Documentation:** See
[Metric Definitions](Metric_Definitions.md#country-datamart-metrics-77-metrics)

### Table: dwh.datamartUsers

Pre-computed analytics aggregated by user. Contains **78+ metrics** covering:

- Historical counts (whole history, by year, by month)
- Resolution metrics (average/median days to resolution, resolution rates)
- Application statistics (usage patterns, trends)
- Content quality metrics (comment length, URLs, mentions)
- User behavior patterns (response time, collaboration, activity)
- Temporal patterns (hour-of-week, day-of-week distributions)
- Geographic patterns
- Hashtag metrics
- User classification (experience level)

**Key Columns:**

- `dimension_user_id` (PK): Reference to user dimension
- `user_id`: OSM user ID
- `username`: Most recent username
- **78+ metric columns**: See [Metric Definitions](Metric_Definitions.md) for complete list

**Update Procedure:** `dwh.update_datamart_user(dimension_user_id)`

**Full Documentation:** See
[Metric Definitions](Metric_Definitions.md#user-datamart-metrics-78-metrics)

### Table: dwh.datamartGlobal

Pre-computed global statistics aggregating all countries and users.

**Key Metrics:**

- Total notes globally
- Active countries/users
- Global resolution rates
- Global activity trends

**Update Procedure:** `dwh.update_datamart_global()`

---

## Metric Categories

The datamarts organize metrics into the following categories:

1. **Historical Count Metrics**: Activity counts by time period (whole history, by year, by month)
2. **Resolution Metrics**: Time to resolution, resolution rates, resolution trends
3. **Application Statistics**: Tool usage patterns, version adoption, mobile vs desktop
4. **Content Quality Metrics**: Comment analysis, URL usage, mentions
5. **Temporal Pattern Metrics**: Hour-of-week, day-of-week distributions
6. **Geographic Pattern Metrics**: Country-level aggregations
7. **Community Health Metrics**: Backlog size, health score, activity trends
8. **User Behavior Metrics**: Response time, collaboration patterns, activity levels
9. **Hashtag Metrics**: Hashtag usage and trends
10. **First/Last Action Metrics**: Temporal boundaries of activity
11. **Current Period Metrics**: Recent activity (last 30 days, etc.)
12. **User Classification Metrics**: Experience levels, activity classifications

For complete metric definitions, formulas, and use cases, see
[Metric Definitions](Metric_Definitions.md).

---

## Related Documentation

- **Complete Metric Reference**: [Metric Definitions](Metric_Definitions.md) - Business definitions
  for all 77+ (countries) and 78+ (users) metrics
- **Dashboard Analysis**: [Dashboard Analysis](Dashboard_Analysis.md) - Implementation status and
  recommendations
- **Data Flow**: [Data Flow Diagrams](Data_Flow_Diagrams.md) - How data flows from base tables to
  datamarts
- **Improvements History**: [DWH Improvements History](DWH_Improvements_History.md) - Evolution of
  the data warehouse

# OSM-Notes-Analytics - Project Rationale

## Why This Project Exists

OpenStreetMap Notes have been an integral part of the OSM ecosystem since 2013. They represent valuable feedback from users about discrepancies between reality and what's mapped. The resolution of notes demonstrates that the map is alive, that feedback is considered, and that OSM mappers are listening to users.

As more mappers engage with notes and new contributors join the process, questions arise about:
- How effective are different communities at resolving notes?
- Which users are most active in note resolution?
- What patterns exist in note creation and resolution?
- How can we measure and improve note resolution performance?

## The Problem with Current Note Analytics

### Limited Analytics Capabilities

While the [OSM-Notes-Ingestion](https://github.com/OSMLatam/OSM-Notes-Ingestion) system successfully collects and stores note data, raw data alone is not sufficient for meaningful analysis. The base tables contain millions of records, making it difficult to:

- **Analyze user contributions**: Understand individual mapper performance and patterns
- **Compare communities**: See how different countries/regions handle notes
- **Track trends**: Identify patterns over time (by year, season, time of day)
- **Measure effectiveness**: Calculate resolution rates, response times, and engagement metrics
- **Generate profiles**: Create comprehensive user and country profiles similar to GitHub contribution graphs

### Current Third-Party Alternatives

Several tools exist for note visualization, but they have limitations:

* **[ResultMaps from Pascal Neis](https://resultmaps.neis-one.org/osm-notes)** provides basic statistics per country and user leaderboards, but lacks detailed analytics and historical trends.

* **[HDYC (How Did You Contribute)](https://hdyc.neis-one.org/)** offers comprehensive user profiles but has very limited note information - only showing counts of opened and closed notes.

* **OSM Website**: The official OSM website shows notes but doesn't provide analytics, profiles, or community comparisons.

### The Gap

**What's missing:**
- Detailed user profiles showing note activity over time
- Country/community profiles with comprehensive metrics
- Historical trend analysis (by year, season, time patterns)
- Resolution metrics (average time to resolution, resolution rates)
- Application usage analytics (mobile vs desktop, most used apps)
- Content quality metrics (comment length, engagement)
- Community health indicators (backlog size, active notes, age distribution)
- Hashtag campaign tracking and performance

## Understanding the Need for Analytics

### Why Analytics Matter

1. **Motivation**: Mappers need to see their contributions to stay motivated. Visual profiles and statistics help demonstrate impact.

2. **Community Engagement**: Country-level analytics help communities understand their note resolution performance and identify areas for improvement.

3. **Resource Allocation**: Understanding patterns helps communities allocate resources effectively (e.g., focusing on high-priority areas or times).

4. **Quality Improvement**: Analytics reveal patterns in note creation and resolution that can inform best practices.

5. **Campaign Tracking**: Hashtag-based campaigns need metrics to measure success and engagement.

### Historical Context

The analytics system was developed as a natural evolution of the ingestion system:

1. **2013-2022**: Notes existed but had limited tooling
2. **2022-2023**: OSM-Notes-Ingestion system developed to collect and store note data
3. **2023-2024**: Initial analytics system created with basic datamarts
4. **2024-2025**: Enhanced analytics with star schema, advanced dimensions, and comprehensive metrics

## Project Goals

This analytics project seeks to provide:

### 1. User Profiles

Similar to GitHub contribution graphs, but for OSM notes:
- Activity timeline showing notes opened/closed by year
- Geographic distribution of contributions
- Working hours heatmap
- Rankings and leaderboards
- First and most recent actions
- Experience level classification (newcomer to legendary)
- Automation level detection

### 2. Country/Community Profiles

Comprehensive analytics for geographic communities:
- Historical metrics by year (2013-present)
- Resolution metrics (average/median days to resolution, resolution rates)
- Application statistics (mobile vs desktop usage, most popular apps)
- Content quality metrics (comment analysis, engagement)
- Community health indicators (active notes, backlog, age distribution)
- Top contributors and hashtag usage

### 3. Advanced Analytics

- **Temporal Analysis**: Patterns by time of day, day of week, season
- **Geographic Analysis**: Performance by country, region, continent
- **Application Analytics**: Usage patterns by application and version
- **Hashtag Campaigns**: Track campaign performance and engagement
- **Content Quality**: Analyze comment patterns, URLs, mentions
- **Community Health**: Monitor backlog, resolution rates, engagement

### 4. Data Export

- JSON exports for web viewer consumption
- Pre-computed datamarts for fast querying
- Atomic, validated exports with schema validation

## How This Project Works

### Architecture Overview

The analytics system builds on top of the ingestion system and provides data to the viewer:

```
OSM-Notes-Ingestion (Base Data)
    ↓
OSM-Notes-Analytics (ETL & DWH)
    ↓
Datamarts (Pre-computed Analytics)
    ↓
JSON Export → OSM-Notes-Viewer (Web Application)
```

**Note**: All three projects (Ingestion, Analytics, Viewer) are sister projects at the same organizational level, working together to provide a complete OSM Notes analysis ecosystem.

### Data Flow

1. **Base Data**: The ingestion system populates base tables (`notes`, `note_comments`, `users`, `countries`)

2. **ETL Process**: The analytics system transforms base data into a [star schema](DWH_Star_Schema_ERD.md):
   - **Fact Table**: `dwh.facts` - One row per note action (open, comment, close, reopen) - see [Data Dictionary](DWH_Star_Schema_Data_Dictionary.md#table-dwhfacts)
   - **Dimension Tables**: Users, countries, dates, times, applications, hashtags, etc. - see [ERD](DWH_Star_Schema_ERD.md)
   - **Partitioning**: Facts table partitioned by year for optimal performance - see [Partitioning Strategy](partitioning_strategy.md)

3. **Datamarts**: Pre-computed aggregations:
   - `dwh.datamartUsers` - One row per user with 78+ metrics
   - `dwh.datamartCountries` - One row per country with 77+ metrics
   - `dwh.datamartGlobal` - Global statistics

4. **Export**: Datamarts exported to JSON for web viewer consumption

### Key Design Decisions

#### Star Schema Design

**Why a star schema?** (See [DWH Star Schema ERD](DWH_Star_Schema_ERD.md) for complete schema documentation)

- **Performance**: Pre-aggregated datamarts enable fast queries
- **Flexibility**: Easy to add new dimensions without changing fact table
- **Clarity**: Clear separation between facts (events) and dimensions (descriptors)
- **Scalability**: Partitioning by year allows efficient querying of large datasets

#### Partitioning Strategy

**Why partition by year?**
- **Performance**: 10-50x faster queries when filtering by date
- **Maintenance**: Can VACUUM and ANALYZE individual partitions
- **Archival**: Old year partitions can be detached/archived independently
- **Parallel Processing**: Can process multiple years in parallel

#### Incremental Processing

**Why incremental updates?**
- **Efficiency**: Only process new data since last run
- **Speed**: Incremental updates take 5-15 minutes vs 30 hours for full load
- **Resource Usage**: Lower memory and CPU requirements
- **Real-time**: Runs every 15 minutes for near real-time analytics

#### Pre-computed Datamarts

**Why pre-compute aggregations?**
- **Performance**: Instant queries instead of expensive aggregations
- **Consistency**: Same metrics for all users/countries
- **Scalability**: Can serve many concurrent requests
- **Simplicity**: Web viewer doesn't need complex SQL knowledge

## Technical Implementation

### Technology Choices

#### PostgreSQL + PostGIS

**Why PostgreSQL?**
- **Mature**: Battle-tested database with excellent performance
- **PostGIS**: Native support for geographic data
- **Partitioning**: Built-in table partitioning support
- **Extensibility**: Easy to add custom functions and procedures

#### Bash Scripts

**Why Bash?**
- **Consistency**: Matches the ingestion system (same language)
- **Minimal Dependencies**: Uses standard Unix tools
- **Proven**: Already working well in ingestion system
- **Maintainability**: Single developer has strong Bash expertise

#### Star Schema

**Why dimensional modeling?** (See [DWH Star Schema ERD](DWH_Star_Schema_ERD.md) for schema details)

- **Industry Standard**: Proven approach for analytics
- **Performance**: Optimized for read-heavy workloads
- **Flexibility**: Easy to add new dimensions
- **Clarity**: Clear data model for analysts

### Data Warehouse Structure

```
dwh schema
├── facts (partitioned by year)
│   ├── facts_2013
│   ├── facts_2014
│   ├── ...
│   └── facts_2025
├── dimension_users (SCD2 for username changes)
├── dimension_countries
├── dimension_days (date dimension)
├── dimension_time_of_week
├── dimension_applications
├── dimension_application_versions
├── dimension_hashtags
├── dimension_timezones
├── dimension_seasons
├── dimension_automation_level
├── dimension_experience_levels
├── datamartusers (pre-computed user analytics)
├── datamartcountries (pre-computed country analytics)
└── datamartglobal (global statistics)
```

## Services Provided

Once the data warehouse is populated, the system provides:

1. **data warehouse**: Star schema for analytical queries
2. **Datamarts**: Pre-computed analytics for fast access
3. **Profile Generator**: Command-line tool to generate user/country profiles
4. **JSON Export**: Validated JSON files for OSM-Notes-Viewer (sister project)
5. **API-Ready Data**: Structured data ready for web APIs

**Note**: The JSON exports are consumed by the OSM-Notes-Viewer sister project, which provides the web interface for visualizing these analytics.

## Relationship to Other Projects

The OSM-Notes-Analytics project is part of a three-project ecosystem, all at the same organizational level:

### Project Ecosystem Structure

```
OSMLatam/
├── OSM-Notes-Ingestion/     # Data ingestion from OSM API/Planet
├── OSM-Notes-Analytics/     # data warehouse & ETL (this repository)
├── OSM-Notes-Viewer/        # Web frontend visualization
└── OSM-Notes-Common/        # Shared Bash libraries (Git submodule)
```

### OSM-Notes-Ingestion (Sister Project - Upstream)

- **Purpose**: Collects and stores raw note data from OSM
- **Relationship**: Analytics reads from ingestion base tables
- **Dependency**: Analytics requires ingestion to run first
- **Level**: Sister project at same organizational level

### OSM-Notes-Viewer (Sister Project - Downstream)

- **Purpose**: Web interface (web page) for visualizing analytics
- **Relationship**: Viewer reads JSON exports from analytics
- **Dependency**: Viewer requires analytics to generate JSON files
- **Level**: Sister project at same organizational level
- **Technology**: Web application (HTML/CSS/JavaScript)

### OSM-Notes-Common (Shared Library)

- **Purpose**: Shared Bash libraries and utilities
- **Repository**: [OSM-Notes-Common](https://github.com/OSMLatam/OSM-Notes-Common)
- **Relationship**: All three projects use common libraries via Git submodule
- **Dependency**: Shared via Git submodule (located at `lib/osm-common/` in each project)
- **Used by**: Ingestion, Analytics, and potentially Viewer (for any server-side scripts)
- **Components**: Common functions, validation, error handling, logging, schemas

## Success Metrics

The project is successful when:

1. **Users can see their contributions**: User profiles show comprehensive note activity
2. **Communities can track performance**: Country profiles show community metrics
3. **Trends are visible**: Historical data shows patterns over time
4. **Queries are fast**: Pre-computed datamarts enable instant queries
5. **Data is reliable**: Validation ensures data integrity
6. **System is maintainable**: Clear structure and documentation

## Future Vision

The analytics system continues to evolve:

- **More Metrics**: Additional analytics as needs arise
- **Better Performance**: Optimizations for faster processing
- **Enhanced Dimensions**: New ways to analyze data
- **Real-time Analytics**: Near real-time updates for current data
- **API Access**: Direct database access for custom queries
- **Machine Learning**: Pattern detection and predictions

## Conclusion

The OSM-Notes-Analytics project fills a critical gap in the OSM Notes ecosystem by providing comprehensive analytics capabilities. It transforms raw note data into meaningful insights that help mappers understand their contributions, communities track their performance, and the OSM ecosystem improve note resolution effectiveness.

By building on the solid foundation of the ingestion system and using proven data warehouse techniques, the project provides a scalable, maintainable solution for OSM Notes analytics.

## References

- [OSM-Notes-Ingestion](https://github.com/OSMLatam/OSM-Notes-Ingestion) - Sister project (upstream)
- [OSM-Notes-Viewer](https://github.com/OSMLatam/OSM-Notes-Viewer) - Sister project (downstream)
- [OSM-Notes-Common](https://github.com/OSMLatam/OSM-Notes-Common) - Shared library (Git submodule)
- [DWH Star Schema ERD](DWH_Star_Schema_ERD.md) - Data warehouse design
- [ETL Enhanced Features](ETL_Enhanced_Features.md) - ETL capabilities
- [Main README](../README.md) - Project overview


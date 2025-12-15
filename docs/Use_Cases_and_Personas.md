# User Personas and Use Cases

This document describes the typical users of the OSM Notes Analytics system, their goals, motivations, and specific use cases. Understanding these personas helps guide feature development, dashboard design, and documentation.

## Table of Contents

- [Overview](#overview)
- [User Personas](#user-personas)
  - [1. Individual Contributor (Mapper)](#1-individual-contributor-mapper)
  - [2. Community Leader](#2-community-leader)
  - [3. Data Analyst](#3-data-analyst)
  - [4. Campaign Organizer](#4-campaign-organizer)
  - [5. Researcher](#5-researcher)
  - [6. System Administrator](#6-system-administrator)
- [Use Cases by Persona](#use-cases-by-persona)
- [Common Workflows](#common-workflows)
- [Query Patterns by Persona](#query-patterns-by-persona)
- [Dashboard Recommendations](#dashboard-recommendations)

---

## Overview

The OSM Notes Analytics system serves multiple user types, each with different goals and technical expertise levels. Understanding these personas helps:

- **Design better dashboards**: Tailor visualizations to user needs
- **Prioritize features**: Focus on high-value use cases
- **Write better documentation**: Target explanations to user expertise
- **Improve user experience**: Match interface complexity to user needs

### User Categories

1. **End Users** (Individual Contributors, Community Leaders): Use pre-built dashboards and profiles
2. **Power Users** (Data Analysts, Campaign Organizers): Write custom queries and build reports
3. **Technical Users** (Researchers, System Administrators): Access raw data and system internals

---

## User Personas

### 1. Individual Contributor (Mapper)

**Name**: Maria  
**Age**: 28  
**Location**: Bogotá, Colombia  
**OSM Experience**: 3 years  
**Technical Level**: Beginner to Intermediate

#### Background

Maria is an active OSM contributor who regularly opens and resolves notes in her city. She uses the OSM Notes Analytics system to:
- Track her personal contributions
- See her activity patterns over time
- Compare her activity with other contributors
- Stay motivated by seeing her impact

#### Goals

- **Primary**: See her contribution statistics and activity history
- **Secondary**: Understand her working patterns (when she's most active)
- **Tertiary**: Compare her activity with top contributors

#### Pain Points

- Doesn't know SQL or database queries
- Wants quick, visual feedback
- Needs mobile-friendly interfaces
- Wants to share her profile with others

#### Technical Skills

- **Database**: None
- **Programming**: Basic (can use web interfaces)
- **Analytics**: Basic (understands charts and graphs)

#### Tools Used

- Web dashboard (user profile view)
- JSON exports (via web viewer)
- Mobile-friendly interfaces

#### Typical Queries

Maria doesn't write queries directly. Instead, she:
- Views her user profile dashboard
- Checks her activity heatmap
- Reviews her contribution statistics
- Compares her metrics with others

#### Success Metrics

- Can quickly see her total contributions
- Understands her activity patterns
- Feels motivated by seeing her impact
- Can share her profile link with others

---

### 2. Community Leader

**Name**: Carlos  
**Age**: 45  
**Location**: Medellín, Colombia  
**OSM Experience**: 8 years  
**Technical Level**: Intermediate

#### Background

Carlos is a community leader for the Colombian OSM community. He organizes mapping events, coordinates note resolution efforts, and monitors community health. He uses analytics to:
- Monitor community performance
- Identify areas needing attention
- Track campaign effectiveness
- Report to community members

#### Goals

- **Primary**: Monitor country/community health metrics
- **Secondary**: Track resolution rates and backlog
- **Tertiary**: Identify top contributors and recognize them
- **Quaternary**: Measure campaign success (hashtag tracking)

#### Pain Points

- Needs to compare multiple countries/regions
- Wants to track trends over time
- Needs exportable reports for presentations
- Requires both high-level and detailed views

#### Technical Skills

- **Database**: Basic (can write simple SQL queries)
- **Programming**: Intermediate (can use APIs)
- **Analytics**: Intermediate (understands metrics and trends)

#### Tools Used

- Country profile dashboard
- Community health dashboard
- Custom SQL queries (occasionally)
- JSON exports for reports

#### Typical Queries

```sql
-- Monitor community health
SELECT 
  country_name_en,
  notes_health_score,
  new_vs_resolved_ratio,
  notes_backlog_size,
  resolution_rate
FROM dwh.datamartcountries
WHERE dimension_country_id = 42;  -- Colombia

-- Track recent activity
SELECT 
  notes_created_last_30_days,
  notes_resolved_last_30_days,
  currently_open_count
FROM dwh.datamartcountries
WHERE dimension_country_id = 42;

-- Top contributors
SELECT 
  username,
  history_whole_closed,
  notes_resolved_last_30_days
FROM dwh.datamartusers
WHERE dimension_country_id = 42
ORDER BY history_whole_closed DESC
LIMIT 10;
```

#### Success Metrics

- Can quickly assess community health
- Identifies areas needing attention
- Tracks campaign effectiveness
- Can generate reports for community meetings

---

### 3. Data Analyst

**Name**: Sarah  
**Age**: 32  
**Location**: Remote (works for OSM Foundation)  
**OSM Experience**: 5 years  
**Technical Level**: Advanced

#### Background

Sarah is a data analyst who studies OSM notes patterns to understand community behavior, identify trends, and provide insights to the OSM Foundation. She uses analytics to:
- Analyze resolution patterns
- Study application usage trends
- Identify problem areas
- Generate reports for stakeholders

#### Goals

- **Primary**: Perform deep analysis of note patterns
- **Secondary**: Compare metrics across countries/regions
- **Tertiary**: Identify correlations and trends
- **Quaternary**: Generate publication-quality reports

#### Pain Points

- Needs access to raw data (facts table)
- Requires complex aggregations
- Wants to export data for external analysis
- Needs reproducible queries

#### Technical Skills

- **Database**: Advanced (expert SQL)
- **Programming**: Advanced (Python, R, JavaScript)
- **Analytics**: Advanced (statistical analysis, visualization)

#### Tools Used

- Direct database queries (star schema)
- Custom SQL scripts
- Python/R for analysis
- Data export tools
- Visualization libraries (D3.js, Plotly, etc.)

#### Typical Queries

```sql
-- Resolution time distribution
SELECT 
  CASE 
    WHEN days_to_resolution < 1 THEN 'Same day'
    WHEN days_to_resolution < 7 THEN 'Within week'
    WHEN days_to_resolution < 30 THEN 'Within month'
    WHEN days_to_resolution < 90 THEN 'Within quarter'
    ELSE 'Over 90 days'
  END as resolution_bucket,
  COUNT(*) as note_count,
  AVG(days_to_resolution) as avg_days
FROM dwh.facts
WHERE action_comment = 'closed'
  AND days_to_resolution IS NOT NULL
  AND action_at >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY resolution_bucket
ORDER BY 
  CASE resolution_bucket
    WHEN 'Same day' THEN 1
    WHEN 'Within week' THEN 2
    WHEN 'Within month' THEN 3
    WHEN 'Within quarter' THEN 4
    ELSE 5
  END;

-- Application usage trends
SELECT 
  da.application_name,
  COUNT(*) as usage_count,
  COUNT(DISTINCT f.dimension_id_country) as countries_count
FROM dwh.facts f
JOIN dwh.dimension_applications da ON f.dimension_application_creation = da.dimension_application_id
WHERE f.action_comment = 'opened'
  AND f.action_at >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY da.application_name
ORDER BY usage_count DESC;

-- Problem notes (multiple reopens)
SELECT 
  f.id_note,
  COUNT(*) FILTER (WHERE f.action_comment = 'reopened') as reopen_count,
  MAX(f.total_comments_on_note) as max_comments
FROM dwh.facts f
WHERE f.action_comment IN ('opened', 'reopened', 'closed')
GROUP BY f.id_note
HAVING COUNT(*) FILTER (WHERE f.action_comment = 'reopened') >= 3
ORDER BY reopen_count DESC
LIMIT 20;
```

#### Success Metrics

- Can answer complex analytical questions
- Generates insights for stakeholders
- Creates publication-quality visualizations
- Reproduces analyses reliably

---

### 4. Campaign Organizer

**Name**: Ahmed  
**Age**: 35  
**Location**: Cairo, Egypt  
**OSM Experience**: 6 years  
**Technical Level**: Intermediate

#### Background

Ahmed organizes mapping campaigns using hashtags (e.g., `#MapCairo2025`, `#MissingMapsEgypt`). He uses analytics to:
- Track campaign participation
- Measure campaign success
- Identify active contributors
- Report campaign results

#### Goals

- **Primary**: Track hashtag usage and engagement
- **Secondary**: Measure campaign impact (notes created/resolved)
- **Tertiary**: Identify top campaign contributors
- **Quaternary**: Compare campaign performance over time

#### Pain Points

- Needs to filter by specific hashtags
- Wants to see campaign metrics in real-time
- Needs to export campaign reports
- Wants to compare multiple campaigns

#### Technical Skills

- **Database**: Basic (can write simple queries with help)
- **Programming**: Basic (can use web interfaces)
- **Analytics**: Intermediate (understands campaign metrics)

#### Tools Used

- Hashtag filtering in dashboards
- Campaign-specific queries
- JSON exports for reports
- Web interfaces for visualization

#### Typical Queries

```sql
-- Campaign participation (hashtag usage)
SELECT 
  dc.country_name_en,
  COUNT(DISTINCT f.id_note) as campaign_notes,
  COUNT(DISTINCT f.dimension_id_user) as participants
FROM dwh.facts f
JOIN dwh.dimension_countries dc ON f.dimension_id_country = dc.dimension_country_id
JOIN dwh.fact_hashtags fh ON f.fact_id = fh.fact_id
JOIN dwh.dimension_hashtags dh ON fh.dimension_hashtag_id = dh.dimension_hashtag_id
WHERE dh.hashtag = '#MapCairo2025'
  AND f.action_comment = 'opened'
  AND f.action_at >= '2025-01-01'
GROUP BY dc.country_name_en;

-- Campaign contributors
SELECT 
  du.username,
  COUNT(DISTINCT f.id_note) as notes_opened,
  COUNT(DISTINCT f2.id_note) as notes_closed
FROM dwh.facts f
JOIN dwh.dimension_users du ON f.dimension_id_user = du.dimension_user_id
JOIN dwh.fact_hashtags fh ON f.fact_id = fh.fact_id
JOIN dwh.dimension_hashtags dh ON fh.dimension_hashtag_id = dh.dimension_hashtag_id
LEFT JOIN dwh.facts f2 ON f2.id_note = f.id_note 
  AND f2.action_comment = 'closed' 
  AND f2.dimension_id_user = f.dimension_id_user
WHERE dh.hashtag = '#MapCairo2025'
  AND f.action_comment = 'opened'
  AND f.action_at >= '2025-01-01'
GROUP BY du.username
ORDER BY notes_opened DESC
LIMIT 20;

-- Campaign resolution rate
SELECT 
  COUNT(DISTINCT f1.id_note) FILTER (WHERE f1.action_comment = 'opened') as opened,
  COUNT(DISTINCT f2.id_note) FILTER (WHERE f2.action_comment = 'closed') as closed,
  ROUND(
    100.0 * COUNT(DISTINCT f2.id_note) FILTER (WHERE f2.action_comment = 'closed') /
    NULLIF(COUNT(DISTINCT f1.id_note) FILTER (WHERE f1.action_comment = 'opened'), 0),
    2
  ) as resolution_rate_pct
FROM dwh.facts f1
JOIN dwh.fact_hashtags fh ON f1.fact_id = fh.fact_id
JOIN dwh.dimension_hashtags dh ON fh.dimension_hashtag_id = dh.dimension_hashtag_id
LEFT JOIN dwh.facts f2 ON f2.id_note = f1.id_note AND f2.action_comment = 'closed'
WHERE dh.hashtag = '#MapCairo2025'
  AND f1.action_at >= '2025-01-01';
```

#### Success Metrics

- Can track campaign participation
- Measures campaign impact accurately
- Identifies top contributors
- Generates campaign reports

---

### 5. Researcher

**Name**: Dr. James  
**Age**: 42  
**Location**: University of London  
**OSM Experience**: 10 years (research focus)  
**Technical Level**: Advanced

#### Background

Dr. James is an academic researcher studying open data communities and collaborative mapping. He uses analytics to:
- Study community behavior patterns
- Analyze temporal patterns (time of day, seasonality)
- Research application adoption
- Publish academic papers

#### Goals

- **Primary**: Access comprehensive historical data
- **Secondary**: Perform statistical analysis
- **Tertiary**: Export data for external analysis tools
- **Quaternary**: Reproduce analyses for peer review

#### Pain Points

- Needs access to raw, unaggregated data
- Requires detailed metadata
- Wants reproducible queries
- Needs to export large datasets

#### Technical Skills

- **Database**: Advanced (complex SQL, data modeling)
- **Programming**: Advanced (Python, R, statistical analysis)
- **Analytics**: Expert (statistical methods, research design)

#### Tools Used

- Direct database access (full star schema)
- Python/R scripts for analysis
- Statistical software (SPSS, Stata, R)
- Data export tools
- Version control for queries

#### Typical Queries

```sql
-- Temporal pattern analysis
SELECT 
  dd.year,
  dd.month,
  dd.day_name,
  dtow.hour_of_day,
  COUNT(*) as action_count,
  COUNT(DISTINCT f.id_note) as unique_notes,
  COUNT(DISTINCT f.dimension_id_user) as unique_users
FROM dwh.facts f
JOIN dwh.dimension_days dd ON f.action_dimension_id_date = dd.dimension_day_id
JOIN dwh.dimension_time_of_week dtow ON f.action_dimension_id_hour_of_week = dtow.dimension_time_of_week_id
WHERE f.action_at >= '2020-01-01'
  AND f.action_at < '2025-01-01'
GROUP BY dd.year, dd.month, dd.day_name, dtow.hour_of_day
ORDER BY dd.year, dd.month, dd.day_name, dtow.hour_of_day;

-- User behavior patterns
SELECT 
  du.username,
  COUNT(*) FILTER (WHERE f.action_comment = 'opened') as notes_opened,
  COUNT(*) FILTER (WHERE f.action_comment = 'closed') as notes_closed,
  COUNT(*) FILTER (WHERE f.action_comment = 'commented') as comments_made,
  AVG(f.days_to_resolution) FILTER (WHERE f.action_comment = 'closed') as avg_resolution_time,
  AVG(f.comment_length) FILTER (WHERE f.action_comment = 'commented') as avg_comment_length
FROM dwh.facts f
JOIN dwh.dimension_users du ON f.dimension_id_user = du.dimension_user_id
WHERE f.action_at >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY du.username
HAVING COUNT(*) FILTER (WHERE f.action_comment = 'opened') >= 10;

-- Application adoption trends
SELECT 
  dd.year,
  dd.quarter,
  da.application_name,
  COUNT(*) as usage_count,
  COUNT(DISTINCT f.dimension_id_country) as countries_count
FROM dwh.facts f
JOIN dwh.dimension_days dd ON f.action_dimension_id_date = dd.dimension_day_id
JOIN dwh.dimension_applications da ON f.dimension_application_creation = da.dimension_application_id
WHERE f.action_comment = 'opened'
  AND f.action_at >= '2015-01-01'
GROUP BY dd.year, dd.quarter, da.application_name
ORDER BY dd.year, dd.quarter, usage_count DESC;
```

#### Success Metrics

- Can access all necessary data
- Performs rigorous statistical analysis
- Reproduces results reliably
- Publishes research findings

---

### 6. System Administrator

**Name**: Alex  
**Age**: 38  
**Location**: Server room (manages infrastructure)  
**OSM Experience**: 7 years (technical focus)  
**Technical Level**: Expert

#### Background

Alex is responsible for maintaining the OSM Notes Analytics infrastructure. They use analytics to:
- Monitor system performance
- Ensure data quality
- Troubleshoot issues
- Optimize queries

#### Goals

- **Primary**: Ensure system reliability and performance
- **Secondary**: Monitor data freshness and completeness
- **Tertiary**: Optimize slow queries
- **Quaternary**: Maintain data quality

#### Pain Points

- Needs to monitor ETL performance
- Must ensure data consistency
- Wants to identify performance bottlenecks
- Needs to troubleshoot data issues

#### Technical Skills

- **Database**: Expert (PostgreSQL administration, query optimization)
- **Programming**: Advanced (Bash, Python, system administration)
- **Analytics**: Intermediate (understands metrics for monitoring)

#### Tools Used

- ETL monitoring scripts
- Database performance tools
- Query analysis tools (EXPLAIN ANALYZE)
- System monitoring dashboards
- Log analysis tools

#### Typical Queries

```sql
-- Monitor datamart freshness
SELECT 
  'datamartCountries' as datamart,
  COUNT(*) as total_records,
  COUNT(*) FILTER (WHERE json_exported = FALSE) as pending_export,
  MAX(last_updated_at) as last_update
FROM dwh.datamartcountries
UNION ALL
SELECT 
  'datamartUsers' as datamart,
  COUNT(*) as total_records,
  COUNT(*) FILTER (WHERE json_exported = FALSE) as pending_export,
  MAX(last_updated_at) as last_update
FROM dwh.datamartusers;

-- Check data quality (missing metrics)
SELECT 
  dimension_country_id,
  country_name_en,
  CASE 
    WHEN avg_days_to_resolution IS NULL THEN 'Missing resolution metric'
    WHEN resolution_rate IS NULL THEN 'Missing resolution rate'
    WHEN notes_health_score IS NULL THEN 'Missing health score'
    ELSE 'OK'
  END as data_quality_issue
FROM dwh.datamartcountries
WHERE avg_days_to_resolution IS NULL
   OR resolution_rate IS NULL
   OR notes_health_score IS NULL
LIMIT 20;

-- Identify slow queries (using pg_stat_statements)
SELECT 
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
WHERE query LIKE '%datamart%'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

#### Success Metrics

- System runs reliably
- Data is fresh and complete
- Queries perform well
- Issues are identified quickly

---

## Use Cases by Persona

### Individual Contributor Use Cases

#### UC-1.1: View Personal Profile
**Actor**: Individual Contributor  
**Goal**: See personal contribution statistics  
**Steps**:
1. Navigate to user profile page
2. Enter OSM username or user ID
3. View profile with activity heatmap, statistics, and trends

**Data Source**: `dwh.datamartUsers` or JSON export

#### UC-1.2: Compare Activity with Others
**Actor**: Individual Contributor  
**Goal**: See how their activity compares to top contributors  
**Steps**:
1. View personal profile
2. Navigate to "Compare" section
3. See ranking and comparison charts

**Data Source**: `dwh.datamartUsers` (aggregated)

#### UC-1.3: Share Profile
**Actor**: Individual Contributor  
**Goal**: Share profile link with others  
**Steps**:
1. View personal profile
2. Copy profile URL
3. Share on social media or forums

**Data Source**: JSON export (public URL)

---

### Community Leader Use Cases

#### UC-2.1: Monitor Community Health
**Actor**: Community Leader  
**Goal**: Assess overall community health  
**Steps**:
1. Navigate to country profile
2. Review health score, resolution rate, backlog
3. Identify areas needing attention

**Data Source**: `dwh.datamartCountries`

#### UC-2.2: Track Campaign Progress
**Actor**: Community Leader  
**Goal**: Monitor hashtag campaign effectiveness  
**Steps**:
1. Filter notes by hashtag
2. View campaign metrics (participation, resolution rate)
3. Export campaign report

**Data Source**: `dwh.facts` + `dwh.fact_hashtags`

#### UC-2.3: Identify Top Contributors
**Actor**: Community Leader  
**Goal**: Recognize active contributors  
**Steps**:
1. Query top users by country
2. Review contributor statistics
3. Generate recognition list

**Data Source**: `dwh.datamartUsers` (filtered by country)

---

### Data Analyst Use Cases

#### UC-3.1: Analyze Resolution Patterns
**Actor**: Data Analyst  
**Goal**: Understand resolution time distributions  
**Steps**:
1. Query facts table for closed notes
2. Calculate resolution time buckets
3. Generate distribution histogram
4. Identify outliers and patterns

**Data Source**: `dwh.facts`

#### UC-3.2: Compare Countries
**Actor**: Data Analyst  
**Goal**: Compare metrics across countries  
**Steps**:
1. Query datamartCountries for multiple countries
2. Aggregate metrics
3. Create comparison visualizations
4. Identify best/worst performers

**Data Source**: `dwh.datamartCountries`

#### UC-3.3: Export Data for Analysis
**Actor**: Data Analyst  
**Goal**: Export data for external tools  
**Steps**:
1. Write SQL query
2. Export results to CSV/JSON
3. Import into Python/R/Excel
4. Perform analysis

**Data Source**: Any (facts, datamarts, dimensions)

---

### Campaign Organizer Use Cases

#### UC-4.1: Track Campaign Participation
**Actor**: Campaign Organizer  
**Goal**: Measure campaign engagement  
**Steps**:
1. Filter notes by campaign hashtag
2. Count participants and notes
3. Track participation over time

**Data Source**: `dwh.facts` + `dwh.fact_hashtags`

#### UC-4.2: Measure Campaign Impact
**Actor**: Campaign Organizer  
**Goal**: Assess campaign success  
**Steps**:
1. Query campaign notes (opened/resolved)
2. Calculate resolution rate
3. Compare with baseline metrics
4. Generate campaign report

**Data Source**: `dwh.facts` + `dwh.fact_hashtags`

---

### Researcher Use Cases

#### UC-5.1: Study Temporal Patterns
**Actor**: Researcher  
**Goal**: Analyze activity patterns over time  
**Steps**:
1. Query facts with time dimensions
2. Aggregate by hour, day, season
3. Perform statistical analysis
4. Identify significant patterns

**Data Source**: `dwh.facts` + time dimensions

#### UC-5.2: Research Application Adoption
**Actor**: Researcher  
**Goal**: Study application usage trends  
**Steps**:
1. Query facts with application dimensions
2. Track usage over time
3. Analyze adoption patterns
4. Compare applications

**Data Source**: `dwh.facts` + `dwh.dimension_applications`

---

### System Administrator Use Cases

#### UC-6.1: Monitor ETL Performance
**Actor**: System Administrator  
**Goal**: Ensure ETL runs successfully  
**Steps**:
1. Check ETL logs
2. Monitor datamart update times
3. Verify data completeness
4. Troubleshoot failures

**Data Source**: System logs, database metadata

#### UC-6.2: Optimize Query Performance
**Actor**: System Administrator  
**Goal**: Improve slow queries  
**Steps**:
1. Identify slow queries
2. Analyze query plans
3. Add indexes if needed
4. Optimize queries

**Data Source**: `pg_stat_statements`, query logs

---

## Common Workflows

### Workflow 1: New User Onboarding

1. User discovers OSM Notes Analytics
2. Views their profile (if exists)
3. Explores country/community metrics
4. Learns about available dashboards
5. Becomes regular user

### Workflow 2: Campaign Planning and Execution

1. Campaign organizer plans campaign
2. Creates campaign hashtag
3. Launches campaign
4. Monitors campaign metrics
5. Measures campaign success
6. Reports results

### Workflow 3: Community Health Monitoring

1. Community leader checks health dashboard
2. Identifies issues (high backlog, low resolution rate)
3. Investigates root causes
4. Takes action (organizes event, recruits contributors)
5. Monitors improvement

### Workflow 4: Research Study

1. Researcher defines research question
2. Designs analysis approach
3. Queries data warehouse
4. Exports data for analysis
5. Performs statistical analysis
6. Publishes findings

---

## Query Patterns by Persona

### Individual Contributor

**Pattern**: Single-row lookup by user ID
```sql
SELECT * FROM dwh.datamartusers WHERE dimension_user_id = ?;
```

**Frequency**: High (multiple times per day)  
**Performance**: < 10ms (primary key lookup)

### Community Leader

**Pattern**: Single-row lookup by country ID + aggregations
```sql
SELECT * FROM dwh.datamartcountries WHERE dimension_country_id = ?;
SELECT * FROM dwh.datamartusers WHERE dimension_country_id = ? ORDER BY ...;
```

**Frequency**: Medium (daily/weekly)  
**Performance**: < 50ms (primary key lookup), 100-500ms (aggregations)

### Data Analyst

**Pattern**: Complex aggregations, joins, filters
```sql
SELECT ... FROM dwh.facts f
JOIN dwh.dimension_... d ON ...
WHERE ... AND ... AND ...
GROUP BY ...
HAVING ...
ORDER BY ...;
```

**Frequency**: Low to Medium (as needed)  
**Performance**: 2-20s (depends on complexity)

### Campaign Organizer

**Pattern**: Filtered queries with hashtag joins
```sql
SELECT ... FROM dwh.facts f
JOIN dwh.fact_hashtags fh ON ...
JOIN dwh.dimension_hashtags dh ON ...
WHERE dh.hashtag = ? AND ...;
```

**Frequency**: Medium (during campaigns)  
**Performance**: 1-5s (depends on campaign size)

### Researcher

**Pattern**: Large-scale aggregations, time-series analysis
```sql
SELECT ... FROM dwh.facts f
JOIN dwh.dimension_days dd ON ...
WHERE f.action_at >= ? AND f.action_at < ?
GROUP BY dd.year, dd.month, ...;
```

**Frequency**: Low (for specific studies)  
**Performance**: 5-30s (large time ranges)

### System Administrator

**Pattern**: Metadata queries, performance monitoring
```sql
SELECT ... FROM pg_stat_... WHERE ...;
SELECT ... FROM information_schema... WHERE ...;
```

**Frequency**: Low to Medium (monitoring)  
**Performance**: < 100ms (metadata queries)

---

## Dashboard Recommendations

### For Individual Contributors

**Recommended Dashboards**:
1. **User Profile Dashboard** (Primary)
   - Activity heatmap
   - Contribution statistics
   - Working hours patterns
   - Geographic distribution

**Design Principles**:
- Simple, visual, mobile-friendly
- Focus on personal metrics
- Easy sharing

### For Community Leaders

**Recommended Dashboards**:
1. **Country Profile Dashboard** (Primary)
2. **Community Health Dashboard** (Secondary)
3. **Campaign Tracking Dashboard** (As needed)

**Design Principles**:
- High-level metrics visible
- Drill-down capabilities
- Export functionality
- Comparison views

### For Data Analysts

**Recommended Dashboards**:
1. **Custom Analysis Dashboard** (Primary)
2. **Resolution Time Dashboard** (Secondary)
3. **Application Usage Dashboard** (As needed)

**Design Principles**:
- Flexible, customizable
- Raw data access
- Export capabilities
- Advanced filtering

### For Campaign Organizers

**Recommended Dashboards**:
1. **Campaign Dashboard** (Primary)
   - Hashtag filtering
   - Participation metrics
   - Resolution tracking

**Design Principles**:
- Campaign-focused
- Real-time updates
- Shareable reports

### For Researchers

**Recommended Dashboards**:
1. **Temporal Analysis Dashboard** (Primary)
2. **User Behavior Dashboard** (Secondary)
3. **Application Adoption Dashboard** (As needed)

**Design Principles**:
- Data export focus
- Statistical summaries
- Reproducible queries
- Academic-quality visualizations

### For System Administrators

**Recommended Dashboards**:
1. **System Health Dashboard** (Primary)
   - ETL status
   - Data freshness
   - Query performance
   - Error monitoring

**Design Principles**:
- Technical metrics
- Alerting capabilities
- Performance indicators
- Troubleshooting tools

---

## Related Documentation

- [Dashboard Implementation Guide](Dashboard_Implementation_Guide.md) - How to build dashboards
- [Metric Definitions](Metric_Definitions.md) - What metrics mean
- [Performance Baselines](PERFORMANCE_BASELINES.md) - Query performance expectations
- [JSON Export Schema](JSON_Export_Schema.md) - API for frontend developers

---

**Last Updated**: 2025-12-14  
**Version**: 1.0


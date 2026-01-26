---
title: "Dashboard Implementation Guide"
description:
  "The OSM Notes Analytics system provides multiple data sources for building dashboards:"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "monitoring"
  - "guide"
audience:
  - "developers"
project: "OSM-Notes-Analytics"
status: "active"
---

# Dashboard Implementation Guide

This guide provides step-by-step instructions for building dashboards using the OSM Notes Analytics
data warehouse. It includes SQL queries, frontend integration examples, and best practices for
creating effective visualizations.

## Table of Contents

- [Overview](#overview)
- [Dashboard Architecture](#dashboard-architecture)
- [Data Sources](#data-sources)
- [Dashboard Types](#dashboard-types)
  - [1. Global Overview Dashboard](#1-global-overview-dashboard)
  - [2. Country Activity Dashboard](#2-country-activity-dashboard)
  - [3. User Profile Dashboard](#3-user-profile-dashboard)
  - [4. Resolution Time Dashboard](#4-resolution-time-dashboard)
  - [5. Application Usage Dashboard](#5-application-usage-dashboard)
  - [6. Community Health Dashboard](#6-community-health-dashboard)
  - [7. Temporal Analysis Dashboard](#7-temporal-analysis-dashboard)
  - [8. Geographic Analysis Dashboard](#8-geographic-analysis-dashboard)
- [Frontend Integration](#frontend-integration)
- [Performance Optimization](#performance-optimization)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Overview

The OSM Notes Analytics system provides multiple data sources for building dashboards:

1. **Pre-computed Datamarts** (Fast, recommended for most dashboards)
   - `dwh.datamartCountries`: 77+ metrics per country
   - `dwh.datamartUsers`: 78+ metrics per user
   - `dwh.datamartGlobal`: 42 global metrics

2. **JSON Exports** (Fast, no database connection needed)
   - User/country profiles (complete metrics)
   - Index files (summary data)
   - Global statistics

3. **Star Schema** (Flexible, slower for complex queries)
   - `dwh.facts`: Note-level detail
   - Dimension tables for filtering and grouping

**Recommendation**: Start with datamarts or JSON exports for best performance. Use star schema only
when you need note-level detail or custom aggregations.

---

## Dashboard Architecture

### Four-Level Architecture

```
Level 1: Global Overview
  └─ Uses: datamartGlobal, aggregated datamartCountries
  └─ Purpose: High-level statistics, trends, comparisons

Level 2: Country Drill-Down
  └─ Uses: datamartCountries
  └─ Purpose: Country-specific metrics, rankings, comparisons

Level 3: User Profiles
  └─ Uses: datamartUsers
  └─ Purpose: Individual user statistics, contributions, badges

Level 4: Deep Analytics
  └─ Uses: dwh.facts + dimensions
  └─ Purpose: Note-level analysis, custom queries, problem identification
```

### Data Flow

```
ETL Process
  └─> Populates dwh.facts and dimensions
      └─> Updates datamarts (incremental)
          └─> Exports to JSON (optional)
              └─> Dashboard consumes data
```

---

## Data Sources

### 1. Direct Database Queries

**Best for**: Real-time dashboards, custom queries, admin tools

```sql
-- Example: Get country profile
SELECT * FROM dwh.datamartcountries
WHERE dimension_country_id = 42;
```

**Performance**: < 10ms for single row lookups

### 2. JSON Exports

**Best for**: Static dashboards, frontend applications, CDN-hosted dashboards

```javascript
// Example: Load country profile from JSON
fetch("/json/countries/colombia.json")
  .then((response) => response.json())
  .then((data) => {
    // Use data.country_name_en, data.history_whole_open, etc.
  });
```

**Performance**: < 50ms (network dependent)

**File Locations**:

- User profiles: `output/json/users/{user_id}.json`
- Country profiles: `output/json/countries/{country_name}.json`
- Indexes: `output/json/users_index.json`, `output/json/countries_index.json`
- Global stats: `output/json/global_stats.json`, `output/json/global_stats_summary.json`

### 3. REST API (Future)

**Best for**: Dynamic dashboards, real-time updates, mobile apps

_Note: API endpoints are planned but not yet implemented_

---

## Dashboard Types

### 1. Global Overview Dashboard

**Purpose**: High-level statistics for the entire OSM Notes system

**Data Source**: `dwh.datamartGlobal` or `output/json/global_stats.json`

#### SQL Query

```sql
-- Get global statistics
SELECT
  currently_open_count,
  currently_closed_count,
  history_whole_open,
  history_whole_closed,
  notes_created_last_30_days,
  notes_resolved_last_30_days,
  notes_backlog_size,
  avg_days_to_resolution,
  resolution_rate,
  active_users_count,
  top_countries,
  applications_used
FROM dwh.datamartglobal
WHERE dimension_global_id = 1;
```

#### Frontend Example (JavaScript)

```javascript
// Load global stats from JSON
async function loadGlobalStats() {
  const response = await fetch("/json/global_stats.json");
  const data = await response.json();

  // Display key metrics
  document.getElementById("total-notes").textContent = data.history_whole_open.toLocaleString();
  document.getElementById("resolved-notes").textContent =
    data.history_whole_closed.toLocaleString();
  document.getElementById("open-notes").textContent = data.currently_open_count.toLocaleString();
  document.getElementById("resolution-rate").textContent =
    (data.resolution_rate * 100).toFixed(1) + "%";
  document.getElementById("avg-resolution").textContent =
    Math.round(data.avg_days_to_resolution) + " days";

  // Parse and display top countries
  const topCountries = JSON.parse(data.top_countries);
  displayTopCountries(topCountries);

  // Parse and display applications
  const apps = JSON.parse(data.applications_used);
  displayApplicationChart(apps);
}

function displayTopCountries(countries) {
  // Example: Create a bar chart with top 10 countries
  const top10 = countries.slice(0, 10);
  // Use your charting library (Chart.js, D3.js, etc.)
}
```

#### Visualizations

- **Key Metrics Cards**: Total notes, resolved, open, resolution rate
- **Trend Chart**: Notes created/resolved over time (last 12 months)
- **Top Countries Bar Chart**: Top 10 countries by activity
- **Application Pie Chart**: Application usage breakdown
- **Resolution Time Distribution**: Histogram of resolution times

---

### 2. Country Activity Dashboard

**Purpose**: Detailed statistics for a specific country

**Data Source**: `dwh.datamartCountries` or `output/json/countries/{country_name}.json`

#### SQL Query

```sql
-- Get country profile
SELECT
  country_name_en,
  iso_alpha2,
  history_whole_open,
  history_whole_closed,
  history_whole_commented,
  notes_created_last_30_days,
  notes_resolved_last_30_days,
  avg_days_to_resolution,
  resolution_rate,
  notes_health_score,
  new_vs_resolved_ratio,
  application_usage_trends,
  version_adoption_rates,
  activity_by_year,
  activity_by_month,
  last_year_activity,
  working_hours_of_week_opening,
  hashtags,
  users_open_notes,
  users_solving_notes
FROM dwh.datamartcountries
WHERE dimension_country_id = 42;  -- Replace with actual country ID
```

#### Frontend Example (JavaScript)

```javascript
// Load country profile from JSON
async function loadCountryProfile(countryName) {
  const response = await fetch(`/json/countries/${countryName}.json`);
  const data = await response.json();

  // Display basic metrics
  displayCountryMetrics(data);

  // Parse and display activity heatmap
  const activityHeatmap = parseActivityHeatmap(data.last_year_activity);
  displayActivityHeatmap(activityHeatmap);

  // Parse and display yearly trends
  const yearlyActivity = JSON.parse(data.activity_by_year);
  displayYearlyChart(yearlyActivity);

  // Parse and display monthly trends
  const monthlyActivity = JSON.parse(data.activity_by_month);
  displayMonthlyChart(monthlyActivity);

  // Parse and display working hours
  const workingHours = JSON.parse(data.working_hours_of_week_opening);
  displayWorkingHoursChart(workingHours);

  // Parse and display top users
  const topOpeners = JSON.parse(data.users_open_notes);
  const topSolvers = JSON.parse(data.users_solving_notes);
  displayUserRankings(topOpeners, topSolvers);

  // Parse and display hashtags
  const hashtags = JSON.parse(data.hashtags);
  displayHashtags(hashtags);
}

function parseActivityHeatmap(activityString) {
  // last_year_activity is a 371-character string (53 weeks * 7 days)
  // Each character represents activity level: '0'-'9' or 'A'-'Z'
  const weeks = [];
  for (let i = 0; i < 53; i++) {
    const week = activityString.substring(i * 7, (i + 1) * 7);
    weeks.push(
      week.split("").map((char) => {
        // Convert character to number (0-9 = 0-9, A-Z = 10-35)
        if (char >= "0" && char <= "9") return parseInt(char);
        return char.charCodeAt(0) - "A".charCodeAt(0) + 10;
      }),
    );
  }
  return weeks;
}

function displayActivityHeatmap(weeks) {
  // Use GitHub-style heatmap library (e.g., cal-heatmap, D3.js)
  // Each cell represents a day, color intensity = activity level
}
```

#### Visualizations

- **Activity Heatmap**: GitHub-style contribution graph (last 53 weeks)
- **Yearly Trend Chart**: Line chart showing activity by year
- **Monthly Trend Chart**: Bar chart showing activity by month
- **Working Hours Chart**: Heatmap showing activity by hour-of-week
- **Resolution Metrics**: Cards showing resolution rate, average time, health score
- **User Rankings**: Tables showing top openers and solvers
- **Application Usage**: Bar chart showing application breakdown
- **Hashtag Cloud**: Word cloud of popular hashtags

---

### 3. User Profile Dashboard

**Purpose**: Individual user statistics and contributions

**Data Source**: `dwh.datamartUsers` or `output/json/users/{user_id}.json`

#### SQL Query

```sql
-- Get user profile
SELECT
  username,
  user_id,
  history_whole_open,
  history_whole_closed,
  history_whole_commented,
  notes_created_last_30_days,
  notes_resolved_last_30_days,
  avg_days_to_resolution,
  user_response_time,
  days_since_last_action,
  notes_opened_but_not_closed_by_user,
  collaboration_patterns,
  activity_by_year,
  activity_by_month,
  last_year_activity,
  working_hours_of_week_opening,
  working_hours_of_week_commenting,
  working_hours_of_week_closing,
  countries_where_opened_notes,
  countries_where_solved_notes,
  hashtags,
  id_contributor_type,
  date_starting_creating_notes,
  date_starting_solving_notes
FROM dwh.datamartusers
WHERE dimension_user_id = 1234;  -- Replace with actual user ID
```

#### Frontend Example (JavaScript)

```javascript
// Load user profile from JSON
async function loadUserProfile(userId) {
  const response = await fetch(`/json/users/${userId}.json`);
  const data = await response.json();

  // Display user header
  document.getElementById("username").textContent = data.username;
  document.getElementById("user-id").textContent = `OSM User #${data.user_id}`;
  document.getElementById("contributor-type").textContent = getContributorTypeLabel(
    data.id_contributor_type,
  );

  // Display activity summary
  displayActivitySummary(data);

  // Parse and display activity heatmap
  const activityHeatmap = parseActivityHeatmap(data.last_year_activity);
  displayActivityHeatmap(activityHeatmap);

  // Parse and display yearly trends
  const yearlyActivity = JSON.parse(data.activity_by_year);
  displayYearlyChart(yearlyActivity);

  // Parse and display working hours
  const openingHours = JSON.parse(data.working_hours_of_week_opening);
  const commentingHours = JSON.parse(data.working_hours_of_week_commenting);
  const closingHours = JSON.parse(data.working_hours_of_week_closing);
  displayWorkingHoursComparison(openingHours, commentingHours, closingHours);

  // Parse and display geographic distribution
  const countriesOpened = JSON.parse(data.countries_where_opened_notes);
  const countriesSolved = JSON.parse(data.countries_where_solved_notes);
  displayGeographicMap(countriesOpened, countriesSolved);

  // Display user behavior metrics
  displayUserBehaviorMetrics(data);
}

function displayUserBehaviorMetrics(data) {
  // User response time
  if (data.user_response_time) {
    const avgResponseHours = data.user_response_time / 3600; // Convert seconds to hours
    document.getElementById("avg-response-time").textContent =
      `${avgResponseHours.toFixed(1)} hours`;
  }

  // Days since last action
  if (data.days_since_last_action !== null) {
    document.getElementById("days-since-action").textContent =
      `${data.days_since_last_action} days`;
  }

  // Notes opened but not closed
  document.getElementById("opened-not-closed").textContent =
    data.notes_opened_but_not_closed_by_user || 0;

  // Collaboration patterns
  if (data.collaboration_patterns) {
    const collab = JSON.parse(data.collaboration_patterns);
    displayCollaborationChart(collab);
  }
}
```

#### Visualizations

- **User Header**: Username, OSM user ID, contributor type, badges
- **Activity Heatmap**: GitHub-style contribution graph
- **Activity Summary Cards**: Total opened, closed, commented notes
- **Yearly Trend Chart**: Activity over years
- **Working Hours Comparison**: Three heatmaps (opening, commenting, closing)
- **Geographic Map**: Countries where user opened/solved notes
- **User Behavior Metrics**: Response time, collaboration patterns
- **Hashtag List**: Hashtags used by user

---

### 4. Resolution Time Dashboard

**Purpose**: Analyze note resolution times and patterns

**Data Source**: `dwh.datamartCountries`, `dwh.datamartUsers`, or `dwh.facts` for detailed analysis

#### SQL Query (Using Datamarts)

```sql
-- Resolution metrics by country
SELECT
  country_name_en,
  avg_days_to_resolution,
  median_days_to_resolution,
  resolution_rate,
  notes_resolved_count,
  notes_still_open_count,
  notes_backlog_size
FROM dwh.datamartcountries
WHERE history_whole_open > 100  -- Filter active countries
ORDER BY avg_days_to_resolution ASC;
```

#### SQL Query (Using Facts for Detailed Analysis)

```sql
-- Resolution time distribution
SELECT
  CASE
    WHEN days_to_resolution < 1 THEN 'Same day'
    WHEN days_to_resolution < 7 THEN 'Within week'
    WHEN days_to_resolution < 30 THEN 'Within month'
    WHEN days_to_resolution < 90 THEN 'Within quarter'
    WHEN days_to_resolution < 365 THEN 'Within year'
    ELSE 'Over a year'
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
    WHEN 'Within year' THEN 5
    ELSE 6
  END;
```

#### Frontend Example (JavaScript)

```javascript
// Load resolution data
async function loadResolutionData() {
  // Option 1: Use country datamart (faster)
  const countriesResponse = await fetch("/json/countries_index.json");
  const countries = await countriesResponse.json();

  // Filter and sort by resolution time
  const resolutionData = countries
    .filter((c) => c.history_whole_open > 100)
    .map((c) => ({
      country: c.country_name_en,
      avgDays: c.avg_days_to_resolution,
      resolutionRate: c.resolution_rate,
      resolved: c.notes_resolved_count,
      open: c.notes_still_open_count,
    }))
    .sort((a, b) => a.avgDays - b.avgDays);

  displayResolutionChart(resolutionData);
}

function displayResolutionChart(data) {
  // Create bar chart: X = country, Y = avg_days_to_resolution
  // Color bars by resolution_rate (green = high, red = low)
}
```

#### Visualizations

- **Resolution Time by Country**: Bar chart sorted by average resolution time
- **Resolution Rate Comparison**: Scatter plot (resolution rate vs. average time)
- **Resolution Time Distribution**: Histogram showing distribution of resolution times
- **Backlog Size**: Bar chart showing unresolved notes by country
- **Trend Analysis**: Line chart showing resolution time trends over time

---

### 5. Application Usage Dashboard

**Purpose**: Analyze which applications are used to create notes

**Data Source**: `dwh.datamartCountries`, `dwh.datamartUsers` (JSON fields)

#### SQL Query

```sql
-- Application usage by country
SELECT
  country_name_en,
  application_usage_trends,
  version_adoption_rates
FROM dwh.datamartcountries
WHERE application_usage_trends IS NOT NULL
ORDER BY history_whole_open DESC
LIMIT 20;
```

#### Frontend Example (JavaScript)

```javascript
// Load application usage data
async function loadApplicationUsage() {
  const countriesResponse = await fetch("/json/countries_index.json");
  const countries = await countriesResponse.json();

  // Aggregate application usage across all countries
  const appUsage = {};

  countries.forEach((country) => {
    if (country.application_usage_trends) {
      const trends = JSON.parse(country.application_usage_trends);
      Object.keys(trends).forEach((appId) => {
        if (!appUsage[appId]) {
          appUsage[appId] = 0;
        }
        appUsage[appId] += trends[appId];
      });
    }
  });

  // Convert to array and sort
  const appUsageArray = Object.entries(appUsage)
    .map(([appId, count]) => ({ appId, count }))
    .sort((a, b) => b.count - a.count);

  displayApplicationChart(appUsageArray);
}

function displayApplicationChart(data) {
  // Create pie chart or bar chart
  // Top 10 applications by usage
  const top10 = data.slice(0, 10);
  // Use your charting library
}
```

#### Visualizations

- **Application Usage Pie Chart**: Breakdown by application
- **Application Trends**: Line chart showing usage over time
- **Version Adoption**: Bar chart showing version distribution
- **Mobile vs Desktop**: Comparison chart
- **Geographic Application Usage**: Map showing most used app per country

---

### 6. Community Health Dashboard

**Purpose**: Monitor community health indicators

**Data Source**: `dwh.datamartCountries`, `dwh.datamartGlobal`

#### SQL Query

```sql
-- Community health metrics by country
SELECT
  country_name_en,
  notes_health_score,
  new_vs_resolved_ratio,
  notes_backlog_size,
  notes_created_last_30_days,
  notes_resolved_last_30_days,
  currently_open_count,
  resolution_rate
FROM dwh.datamartcountries
WHERE history_whole_open > 50
ORDER BY notes_health_score DESC;
```

#### Frontend Example (JavaScript)

```javascript
// Load community health data
async function loadCommunityHealth() {
  const countriesResponse = await fetch("/json/countries_index.json");
  const countries = await countriesResponse.json();

  // Calculate health indicators
  const healthData = countries
    .filter((c) => c.history_whole_open > 50)
    .map((c) => ({
      country: c.country_name_en,
      healthScore: c.notes_health_score,
      newVsResolved: c.new_vs_resolved_ratio,
      backlog: c.notes_backlog_size,
      created30d: c.notes_created_last_30_days,
      resolved30d: c.notes_resolved_last_30_days,
      open: c.currently_open_count,
      resolutionRate: c.resolution_rate,
    }))
    .sort((a, b) => b.healthScore - a.healthScore);

  displayHealthDashboard(healthData);
}

function displayHealthDashboard(data) {
  // Health score gauge chart
  // New vs resolved ratio scatter plot
  // Backlog size bar chart
  // Recent activity comparison (created vs resolved)
}
```

#### Visualizations

- **Health Score Gauge**: Overall community health (0-100)
- **New vs Resolved Ratio**: Scatter plot (healthy = ratio close to 1)
- **Backlog Size**: Bar chart showing unresolved notes
- **Recent Activity**: Comparison of created vs resolved (last 30 days)
- **Health Trends**: Line chart showing health score over time

---

### 7. Temporal Analysis Dashboard

**Purpose**: Analyze activity patterns over time

**Data Source**: `dwh.datamartCountries`, `dwh.datamartUsers` (JSON fields)

#### SQL Query

```sql
-- Activity trends by country
SELECT
  country_name_en,
  activity_by_year,
  activity_by_month,
  last_year_activity,
  working_hours_of_week_opening,
  working_hours_of_week_commenting,
  working_hours_of_week_closing
FROM dwh.datamartcountries
WHERE dimension_country_id = 42;
```

#### Frontend Example (JavaScript)

```javascript
// Load temporal data
async function loadTemporalAnalysis(countryId) {
  const response = await fetch(`/json/countries/${countryId}.json`);
  const data = await response.json();

  // Parse yearly activity
  const yearlyActivity = JSON.parse(data.activity_by_year);
  displayYearlyTrendChart(yearlyActivity);

  // Parse monthly activity
  const monthlyActivity = JSON.parse(data.activity_by_month);
  displayMonthlyTrendChart(monthlyActivity);

  // Parse activity heatmap
  const heatmap = parseActivityHeatmap(data.last_year_activity);
  displayActivityHeatmap(heatmap);

  // Parse working hours
  const openingHours = JSON.parse(data.working_hours_of_week_opening);
  const commentingHours = JSON.parse(data.working_hours_of_week_commenting);
  const closingHours = JSON.parse(data.working_hours_of_week_closing);
  displayWorkingHoursComparison(openingHours, commentingHours, closingHours);
}

function displayYearlyTrendChart(yearlyData) {
  // Line chart: X = year, Y = activity count
  // Show trends over multiple years
}

function displayMonthlyTrendChart(monthlyData) {
  // Line chart: X = month (YYYY-MM), Y = activity count
  // Show seasonal patterns
}
```

#### Visualizations

- **Yearly Trend Chart**: Line chart showing activity by year
- **Monthly Trend Chart**: Line chart showing activity by month (seasonal patterns)
- **Activity Heatmap**: GitHub-style contribution graph
- **Working Hours Heatmap**: Activity by hour-of-week (168 cells)
- **Day-of-Week Analysis**: Bar chart showing activity by day
- **Hour-of-Day Analysis**: Bar chart showing activity by hour

---

### 8. Geographic Analysis Dashboard

**Purpose**: Compare countries and regions

**Data Source**: `dwh.datamartCountries` or `output/json/countries_index.json`

#### SQL Query

```sql
-- Country comparison
SELECT
  country_name_en,
  iso_alpha2,
  history_whole_open,
  history_whole_closed,
  resolution_rate,
  avg_days_to_resolution,
  notes_health_score,
  active_users_count
FROM dwh.datamartcountries
WHERE history_whole_open > 100
ORDER BY history_whole_open DESC
LIMIT 50;
```

#### Frontend Example (JavaScript)

```javascript
// Load geographic comparison data
async function loadGeographicComparison() {
  const response = await fetch("/json/countries_index.json");
  const countries = await response.json();

  // Filter and prepare data
  const comparisonData = countries
    .filter((c) => c.history_whole_open > 100)
    .map((c) => ({
      country: c.country_name_en,
      iso: c.iso_alpha2,
      opened: c.history_whole_open,
      closed: c.history_whole_closed,
      resolutionRate: c.resolution_rate,
      avgResolution: c.avg_days_to_resolution,
      healthScore: c.notes_health_score,
      activeUsers: c.active_users_count,
    }))
    .sort((a, b) => b.opened - a.opened);

  displayGeographicMap(comparisonData);
  displayComparisonTable(comparisonData);
}

function displayGeographicMap(data) {
  // Use a mapping library (Leaflet, D3.js, etc.)
  // Color countries by health score or resolution rate
  // Size markers by total activity
}
```

#### Visualizations

- **World Map**: Choropleth map colored by health score or resolution rate
- **Comparison Table**: Sortable table with all metrics
- **Top Countries Chart**: Bar chart showing top countries by activity
- **Regional Comparison**: Aggregate by region/continent
- **Country Rankings**: Multiple rankings (by activity, resolution rate, health score)

---

## Frontend Integration

### Using JSON Exports

#### 1. Load User Profile

```javascript
async function loadUserProfile(userId) {
  try {
    const response = await fetch(`/json/users/${userId}.json`);
    if (!response.ok) throw new Error("User not found");

    const profile = await response.json();
    return profile;
  } catch (error) {
    console.error("Error loading user profile:", error);
    return null;
  }
}
```

#### 2. Load Country Profile

```javascript
async function loadCountryProfile(countryName) {
  try {
    // Normalize country name (lowercase, replace spaces with underscores)
    const normalized = countryName.toLowerCase().replace(/\s+/g, "_");
    const response = await fetch(`/json/countries/${normalized}.json`);
    if (!response.ok) throw new Error("Country not found");

    const profile = await response.json();
    return profile;
  } catch (error) {
    console.error("Error loading country profile:", error);
    return null;
  }
}
```

#### 3. Load Index Files

```javascript
async function loadCountriesIndex() {
  const response = await fetch("/json/countries_index.json");
  const index = await response.json();
  return index; // Array of country summaries
}

async function loadUsersIndex() {
  const response = await fetch("/json/users_index.json");
  const index = await response.json();
  return index; // Array of user summaries
}
```

#### 4. Parse JSON Fields

Many metrics are stored as JSON strings and need to be parsed:

```javascript
function parseJSONField(jsonString) {
  if (!jsonString) return null;
  try {
    return JSON.parse(jsonString);
  } catch (error) {
    console.error("Error parsing JSON field:", error);
    return null;
  }
}

// Usage
const activityByYear = parseJSONField(profile.activity_by_year);
const workingHours = parseJSONField(profile.working_hours_of_week_opening);
const hashtags = parseJSONField(profile.hashtags);
```

### Using Direct Database Queries

#### 1. REST API Endpoint (Example)

```javascript
// Backend endpoint (Node.js/Express example)
app.get("/api/countries/:countryId", async (req, res) => {
  const { countryId } = req.params;

  const query = `
    SELECT * FROM dwh.datamartcountries
    WHERE dimension_country_id = $1
  `;

  const result = await db.query(query, [countryId]);
  res.json(result.rows[0]);
});

// Frontend usage
async function loadCountryProfile(countryId) {
  const response = await fetch(`/api/countries/${countryId}`);
  return await response.json();
}
```

#### 2. GraphQL Endpoint (Example)

```javascript
// GraphQL schema
type Country {
  id: Int!
  name: String!
  historyWholeOpen: Int!
  historyWholeClosed: Int!
  resolutionRate: Float!
  activityByYear: JSON
}

// Frontend usage (Apollo Client)
const GET_COUNTRY = gql`
  query GetCountry($id: Int!) {
    country(id: $id) {
      name
      historyWholeOpen
      historyWholeClosed
      resolutionRate
      activityByYear
    }
  }
`;
```

---

## Performance Optimization

### 1. Use Datamarts Instead of Facts

**❌ Slow (2-10s):**

```sql
SELECT COUNT(*) FROM dwh.facts WHERE action_comment = 'opened';
```

**✅ Fast (< 50ms):**

```sql
SELECT SUM(history_whole_open) FROM dwh.datamartcountries;
```

### 2. Use JSON Exports for Static Dashboards

**❌ Requires database connection:**

```javascript
const profile = await loadFromDatabase(userId);
```

**✅ No database connection needed:**

```javascript
const profile = await fetch(`/json/users/${userId}.json`).then((r) => r.json());
```

### 3. Cache JSON Files

```javascript
// Cache JSON files in browser
const cache = new Map();

async function loadCachedProfile(userId) {
  if (cache.has(userId)) {
    return cache.get(userId);
  }

  const profile = await loadUserProfile(userId);
  cache.set(userId, profile);
  return profile;
}
```

### 4. Lazy Load Heavy Visualizations

```javascript
// Only load heatmap when user scrolls to it
const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      loadActivityHeatmap();
      observer.unobserve(entry.target);
    }
  });
});

observer.observe(document.getElementById("heatmap-container"));
```

### 5. Paginate Large Lists

```javascript
// Load countries index in pages
async function loadCountriesPage(page = 1, pageSize = 50) {
  const index = await loadCountriesIndex();
  const start = (page - 1) * pageSize;
  const end = start + pageSize;
  return index.slice(start, end);
}
```

---

## Best Practices

### 1. Error Handling

```javascript
async function loadProfileWithErrorHandling(userId) {
  try {
    const response = await fetch(`/json/users/${userId}.json`);

    if (!response.ok) {
      if (response.status === 404) {
        showError("User not found");
        return null;
      }
      throw new Error(`HTTP ${response.status}`);
    }

    const profile = await response.json();
    return profile;
  } catch (error) {
    console.error("Error loading profile:", error);
    showError("Failed to load profile. Please try again.");
    return null;
  }
}
```

### 2. Loading States

```javascript
async function loadProfileWithLoading(userId) {
  showLoadingSpinner();

  try {
    const profile = await loadUserProfile(userId);
    displayProfile(profile);
  } finally {
    hideLoadingSpinner();
  }
}
```

### 3. Data Validation

```javascript
function validateProfile(profile) {
  if (!profile || !profile.user_id) {
    throw new Error("Invalid profile data");
  }

  // Validate required fields
  const required = ["username", "history_whole_open", "history_whole_closed"];
  for (const field of required) {
    if (profile[field] === undefined) {
      console.warn(`Missing required field: ${field}`);
    }
  }

  return profile;
}
```

### 4. Responsive Design

```javascript
// Adjust chart size based on screen size
function resizeChart() {
  const width = window.innerWidth;
  const height = window.innerHeight;

  if (width < 768) {
    // Mobile: smaller charts, stacked layout
    chart.resize(width - 20, 200);
  } else {
    // Desktop: larger charts, side-by-side layout
    chart.resize(width / 2 - 30, 400);
  }
}

window.addEventListener("resize", resizeChart);
```

### 5. Accessibility

```javascript
// Add ARIA labels and keyboard navigation
function createAccessibleChart(data) {
  const chart = document.createElement("div");
  chart.setAttribute("role", "img");
  chart.setAttribute("aria-label", `Chart showing ${data.length} data points`);
  chart.setAttribute("tabindex", "0");

  // Add keyboard navigation
  chart.addEventListener("keydown", (e) => {
    if (e.key === "ArrowRight") {
      // Navigate to next data point
    }
  });

  return chart;
}
```

---

## Troubleshooting

### Common Issues

#### 1. JSON Parse Errors

**Problem**: `JSON.parse()` fails on JSON fields

**Solution**: Check if field is null/undefined before parsing

```javascript
const activity = profile.activity_by_year ? JSON.parse(profile.activity_by_year) : {};
```

#### 2. Missing Data

**Problem**: Some metrics are `null` in JSON

**Solution**: Provide default values

```javascript
const resolutionRate = profile.resolution_rate ?? 0;
const healthScore = profile.notes_health_score ?? 50;
```

#### 3. Slow Dashboard Load

**Problem**: Loading too much data at once

**Solution**:

- Use index files for lists (not full profiles)
- Lazy load heavy visualizations
- Paginate large datasets
- Cache frequently accessed data

#### 4. Activity Heatmap Not Displaying

**Problem**: `last_year_activity` string format not understood

**Solution**: Use the `parseActivityHeatmap()` function provided in examples

#### 5. Working Hours Data Format

**Problem**: `working_hours_of_week_*` is a JSON array of 168 numbers (hours in a week)

**Solution**:

```javascript
const hours = JSON.parse(profile.working_hours_of_week_opening);
// hours is an array of 168 numbers (0-167)
// Each index represents an hour-of-week (0 = Monday 00:00, 167 = Sunday 23:00)
```

---

## Related Documentation

- [Dashboard Analysis](Dashboard_Analysis.md) - Data availability analysis
- [Metric Definitions](Metric_Definitions.md) - Complete metric reference
- [Performance Baselines](Performance_Baselines.md) - Query performance expectations
- [JSON Export Schema](JSON_Export_Schema.md) - JSON file structure
- [DWH Star Schema Data Dictionary](DWH_Star_Schema_Data_Dictionary.md) - Database schema

---

**Last Updated**: 2025-12-14  
**Version**: 1.0

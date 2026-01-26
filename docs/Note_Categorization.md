---
title: "Note Categorization and Classification"
description: "This document describes how the OSM Notes Analytics project helps categorize and classify"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "documentation"
audience:
  - "developers"
project: "OSM-Notes-Analytics"
status: "active"
---


# Note Categorization and Classification

**Status**: Documentation  
**Related Articles**:
[AngocA's Diary - Note Types](https://www.openstreetmap.org/user/AngocA/diary/398472)

---

## 📋 Overview

This document describes how the OSM Notes Analytics project helps categorize and classify
OpenStreetMap notes. The project provides metrics and analytics that enable automatic and manual
categorization of notes based on their characteristics, outcomes, and patterns.

---

## 🎯 Purpose

The OSM Notes Analytics system helps categorize notes by:

1. **Analyzing note outcomes**: Which notes were processed, simply closed, or need more data
2. **Identifying note types**: Classifying notes based on their content and purpose
3. **Tracking patterns**: Understanding how different types of notes behave over time
4. **Supporting resolution**: Helping mappers prioritize and process notes effectively

---

## 📊 Note Classification System

Based on the comprehensive classification system described in
[AngocA's diary article on note types](https://www.openstreetmap.org/user/AngocA/diary/398472),
notes can be categorized into two main groups:

### 1. Notes that Contribute with a Change

These notes lead to actual changes in the map. They can be further classified as:

#### 1.1 Add Something to Map

- **Description**: Notes indicating new places not yet mapped
- **Examples**: New restaurant, neighborhood name, complementing existing data (road surface,
  building address)
- **Characteristics**:
  - Often created via assisted applications (Maps.me, StreetComplete, OrganicMaps, OnOSM.org)
  - Clear, actionable descriptions
  - Specific location information

#### 1.2 Modify Map

- **Description**: Notes that correct existing map data
- **Examples**: Incorrect street name, wrong road surface (paved vs grass)
- **Characteristics**:
  - Created by users aware of the map who want to improve it
- **Value**: Very valuable for map quality

#### 1.3 Delete from Map

- **Description**: Notes that help keep the map updated by removing outdated data
- **Examples**: Closed restaurant, changed business hours (no longer 24 hours)
- **Characteristics**:
  - Users verify on-site and report discrepancies
  - Reflect responsibility for keeping map current
  - Common during events like COVID-19 (business closures)

#### 1.4 More than a Map Modification

- **Description**: Notes used for advertising purposes
- **Examples**: Overly detailed descriptions ("best Italian restaurant")
- **Characteristics**: Marketing language, excessive explanations

#### 1.5 Associated with Imagery

- **Description**: Notes referencing satellite imagery issues
- **Examples**: Cloud coverage preventing mapping, new imagery available
- **Characteristics**: May reference Bing imagery, Strava Heatmap, GPX traces, OpenAerialMap, etc.

#### 1.6 Innocent Note

- **Description**: Notes describing correctable problems in large areas
- **Examples**: Many buildings with "ele" instead of "height" tag
- **Characteristics**: Systematic errors affecting many features

#### 1.7 Large Description

- **Description**: Notes requiring extensive mapping
- **Examples**: Intermunicipal route following national route, missing river (kilometers of mapping)
- **Characteristics**: Large-scale changes

### 2. Notes that Don't Contribute with a Change

These notes should typically be closed without making map changes. They include:

#### 2.1 Personal Data

- **Description**: Notes containing personal information
- **Examples**: "Casa de Andrés Gómez", phone numbers, "Casa de los Gómez", "casa mamá"
- **Action**: Should be closed and not added to map (privacy concern)
- **Recommendation**: Should be deletable/hideable to protect privacy

#### 2.2 Empty Notes

- **Description**: Notes with no content
- **Action**: Should be closed

#### 2.3 Personal Observation

- **Description**: Notes expressing opinions or perceptions
- **Examples**: "Nice place", "cozy place", "unsafe area", "robbery at night"
- **Characteristics**: Subjective, not mappable

#### 2.4 Service Description

- **Description**: Notes describing services that can't be mapped
- **Examples**: Hair salon services (men's cuts, children's cuts, manicure), restaurant menu
- **Characteristics**: Information that doesn't belong in OSM

#### 2.5 Advertising

- **Description**: Notes promoting services or quality
- **Examples**: Service quality descriptions, promotions
- **Action**: Should be closed (doesn't contribute to map)

#### 2.6 Obsolete

- **Description**: Notes indicating changes already mapped
- **Causes**:
  - Notes not processed in time
  - Conditions changed for other reasons
  - Satellite imagery or Strava Heatmap shows changes already reflected
- **Action**: Should be closed

#### 2.7 Lack of Precision

- **Description**: Notes created without proper pin location
- **Examples**: Pin in middle of road when note refers to building interior (shop)
- **Action**: Request more details and close
- **Characteristics**: Common issue, needs clarification

#### 2.8 Device Precision Problem

- **Description**: Notes created due to device positioning issues, not map problems
- **Characteristics**: User believes it's a map problem, but it's a device issue

#### 2.9 Repetition

- **Description**: Notes indicating what's already in the map
- **Examples**: City or town names already mapped
- **Action**: Should be closed

#### 2.10 Unnecessary or Incomprehensible

- **Description**: Notes that don't contribute to the map
- **Characteristics**: Unclear purpose, no actionable information

#### 2.11 Abstract

- **Description**: Notes indicating map problems but lacking details for correction
- **Examples**: Missing river without route details, area-based features (postal codes)
- **Characteristics**: Problem exists but can't be mapped without more information

---

## 🔍 How the Analytics System Helps Categorize Notes

### Available Metrics for Categorization

The OSM Notes Analytics system provides metrics that help identify note types:

#### Resolution Metrics

- **`avg_days_to_resolution`**: Notes that take longer may be problematic
- **`resolution_rate`**: Country/user patterns indicate note quality
- **`notes_still_open_count`**: Backlog indicates unresolved issues

#### Content Quality Metrics

- **`comment_length`**: Very short notes may be empty or lack precision
- **`has_url`**: Notes with URLs may be advertising or have more context
- **`has_mention`**: Notes with mentions may need collaboration
- **`avg_comments_per_note`**: High comment count may indicate discussion or lack of clarity

#### User Behavior Metrics

- **`user_response_time`**: Fast responders may handle different note types
- **`notes_opened_but_not_closed_by_user`**: Users who report but don't resolve
- **`collaboration_patterns`**: Notes requiring collaboration

#### Application Statistics

- **`applications_used`**: Notes from assisted apps (Maps.me, etc.) are more likely to be actionable
- **`mobile_apps_count` vs `desktop_apps_count`**: Different note types from different platforms

#### Community Health Metrics

- **`notes_health_score`**: Overall community note quality
- **`new_vs_resolved_ratio`**: Balance between new notes and resolutions
- **`notes_age_distribution`**: Old notes may be obsolete or problematic

### Classification Queries

#### Identify Notes That Need More Data

```sql
-- Notes with lack of precision or abstract descriptions
SELECT
  id_note,
  opened_dimension_id_date,
  comment_length,
  has_url,
  has_mention,
  total_comments_on_note
FROM dwh.facts
WHERE action_comment = 'opened'
  AND comment_length < 50  -- Very short notes
  AND total_comments_on_note > 2  -- Multiple comments (discussion)
ORDER BY opened_dimension_id_date DESC;
```

#### Identify Notes Likely to Be Processed

```sql
-- Notes from assisted applications with good content
SELECT
  f.id_note,
  f.opened_dimension_id_date,
  f.comment_length,
  f.has_url,
  a.application_name
FROM dwh.facts f
JOIN dwh.dimension_applications a
  ON f.dimension_application_creation = a.dimension_application_id
WHERE f.action_comment = 'opened'
  AND a.application_name IN ('Maps.me', 'StreetComplete', 'OrganicMaps', 'OnOSM.org')
  AND f.comment_length > 30  -- Has sufficient description
ORDER BY f.opened_dimension_id_date DESC;
```

#### Identify Notes Likely to Be Simply Closed

```sql
-- Notes with characteristics of non-actionable types
SELECT
  f.id_note,
  f.opened_dimension_id_date,
  f.comment_length,
  f.has_url,
  dc.notes_health_score
FROM dwh.facts f
JOIN dwh.datamartCountries dc
  ON f.dimension_id_country = dc.dimension_country_id
WHERE f.action_comment = 'opened'
  AND (
    f.comment_length < 20  -- Very short (empty or minimal)
    OR (f.comment_length > 200 AND f.has_url)  -- Long with URL (advertising)
  )
  AND f.total_comments_on_note = 0  -- No discussion
ORDER BY f.opened_dimension_id_date DESC;
```

#### Identify Obsolete Notes

```sql
-- Notes that are very old and still open
SELECT
  f.id_note,
  f.opened_dimension_id_date,
  EXTRACT(DAY FROM CURRENT_DATE - d.date_id) as days_open,
  f.total_comments_on_note
FROM dwh.facts f
JOIN dwh.dimension_days d
  ON f.opened_dimension_id_date = d.dimension_day_id
WHERE f.action_comment = 'opened'
  AND NOT EXISTS (
    SELECT 1
    FROM dwh.facts f2
    WHERE f2.id_note = f.id_note
      AND f2.action_comment = 'closed'
  )
  AND EXTRACT(DAY FROM CURRENT_DATE - d.date_id) > 180  -- More than 6 months
ORDER BY days_open DESC;
```

---

## 📈 Using Analytics for Note Resolution Campaigns

The analytics system supports note resolution campaigns by:

1. **Identifying Priority Notes**:
   - Notes that contribute with changes (high priority)
   - Notes needing more data (medium priority)
   - Notes that should be closed (low priority)

2. **Tracking Campaign Progress**:
   - Resolution rates by country
   - Notes resolved vs created
   - Community health scores

3. **Understanding Patterns**:
   - Which note types are most common
   - Which applications generate most actionable notes
   - User behavior patterns

4. **Resource Allocation**:
   - Focus efforts on notes that will have impact
   - Identify areas needing more mappers
   - Track resolution efficiency

---

## 🔗 Related Resources

### Articles and Documentation

1. **[Tipos de notas](https://www.openstreetmap.org/user/AngocA/diary/398472)** (AngocA's Diary)
   - Comprehensive classification of note types
   - Examples and characteristics of each type
   - Basis for this categorization system

2. **[Manipulación de notas](https://www.openstreetmap.org/user/AngocA/diary/397284)** (AngocA's
   Diary)
   - How to create, view, and resolve notes
   - Tools and workflows for note management
   - Visual examples of note workflows

3. **[Análisis de notas](https://www.openstreetmap.org/user/AngocA/diary/397548)** (AngocA's Diary)
   - Analysis techniques for notes
   - Patterns and insights

4. **[Técnicas de creación y resolución de notas](https://www.openstreetmap.org/user/AngocA/diary/398514)**
   (AngocA's Diary)
   - Best practices for creating notes
   - Resolution techniques and strategies

5. **[Proyecto de resolución de notas - Preparación premios](https://wiki.openstreetmap.org/wiki/ES:LatAm/Proyectos/Resoluci%C3%B3n_de_notas/Preparaci%C3%B3n_premios)**
   (OSM Wiki)
   - Note resolution project documentation
   - Campaign organization and recognition

### Related Documentation in This Project

- **[Metric Definitions](Metric_Definitions.md)**: Complete reference for all metrics
- **[Dashboard Analysis](Dashboard_Analysis.md)**: Available metrics and dashboards
- **[Use Cases and Personas](Use_Cases_And_Personas.md)**: User scenarios and queries
- **[ML Implementation Plan](ML_Implementation_Plan.md)**: Automated note classification using ML

---

## 🎯 Use Cases

### For Mappers

- **Identify actionable notes**: Find notes that will lead to map improvements
- **Prioritize work**: Focus on notes that contribute with changes
- **Understand patterns**: Learn which note types are common in your area

### For Community Leaders

- **Organize campaigns**: Use metrics to plan note resolution campaigns
- **Track progress**: Monitor resolution rates and community health
- **Identify issues**: Find areas with problematic note patterns

### For Data Analysts

- **Analyze note types**: Understand distribution of note categories
- **Study patterns**: Identify trends in note creation and resolution
- **Measure impact**: Track how different note types affect map quality

---

## 📝 Future Enhancements

### Automated Classification

The [ML Implementation Plan](ML_Implementation_Plan.md) describes plans for automated note
classification using machine learning:

- **Action prediction**: Will note be processed, closed, or need more data?
- **Type classification**: Automatically categorize notes by type
- **Priority scoring**: Identify high-priority notes automatically

### Enhanced Metrics

Future metrics could include:

- **Note type distribution**: Percentage of each note type
- **Resolution success rate**: By note type
- **Time to resolution**: By note type
- **User expertise**: By note type handled

---

**Maintained By**: OSM Notes Analytics Project  
**Contributions**: Based on AngocA's comprehensive note classification system

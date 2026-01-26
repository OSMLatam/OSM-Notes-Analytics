---
title: "External Note Classification Strategies"
description: "Research and analysis of external tools and strategies for note classification in OSM Notes Analytics"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "research"
audience:
  - "developers"
project: "OSM-Notes-Analytics"
status: "active"
---


# External Note Classification Strategies

**Status**: Research and Analysis  
**Purpose**: Analyze external tools and strategies for note classification

---

## 📋 Overview

This document analyzes external tools and strategies used for classifying OpenStreetMap notes, with
the goal of identifying techniques that could enhance our ML classification system.

---

## 🔍 DE:Notes Map v2.5

### Tool Information

**URL**: https://greymiche.lima-city.de/osm_notes/index.html  
**Name**: DE:Notes Map v2.5  
**Language**: German  
**Purpose**: Recognize what a note is about based on keywords or special markers

### Classification Strategy

Based on the tool's description, it uses:

1. **Keyword-based Classification** (Schlagworten):
   - Identifies keywords in note text
   - Maps keywords to note categories
   - Example categories mentioned: firefighter, airplane, wheelchair

2. **Hashtag-based Classification** (#...):
   - Uses hashtags as special markers
   - Hashtags indicate note categories or topics
   - This aligns with our existing hashtag tracking in the DWH

3. **Text Search Functionality**:
   - **Single word search**: Searches all notes for a specific word (worldwide)
   - **Category word search**: Searches for entire categories of words
     - Examples: firefighter, airplane, wheelchair
     - Returns >800 notes for some categories
   - **Note ID lookup**: Load specific notes by ID

### Features

1. **Interactive Map**:
   - Displays notes on a map
   - Shows current position (lat, lon, zoom)
   - Permalink functionality for reloading notes

2. **Search Capabilities**:
   - Text search across all notes
   - Category-based search (BETA)
   - Note ID lookup

3. **Integration**:
   - QR codes for Osmand and Google Maps
   - OSM Forum discussion link about "notes nach Dringlichkeit kategorisieren" (categorizing notes
     by urgency)

### Technical Approach

**Classification Method**: Rule-based keyword matching

- Identifies keywords in note text
- Maps keywords to predefined categories
- Uses hashtags as category markers

**Data Source**: OpenStreetMap Notes API (via Overpass or direct API)

**Limitations**:

- Rule-based approach (may miss context)
- Requires predefined keyword lists
- May not handle multilingual notes well

---

## 💡 How This Could Help Our ML System

### 1. Keyword Lists for Feature Engineering

**Application**: Use keyword lists from tools like DE:Notes Map to create features

**Implementation**:

```python
# Example: Category keywords from DE:Notes Map
category_keywords = {
    'firefighter': ['firefighter', 'fire station', 'feuerwehr', 'bomberos'],
    'airplane': ['airplane', 'airport', 'aircraft', 'avión', 'flugzeug'],
    'wheelchair': ['wheelchair', 'accessible', 'silla de ruedas', 'rollstuhl'],
    # ... more categories
}

# Feature: presence of category keywords
def extract_category_features(text):
    features = {}
    for category, keywords in category_keywords.items():
        features[f'has_{category}_keyword'] = any(
            keyword.lower() in text.lower()
            for keyword in keywords
        )
    return features
```

**Benefits**:

- Leverages existing keyword research
- Can identify domain-specific notes
- Complements our text analysis features

### 2. Hashtag-based Classification

**Application**: Enhance our existing hashtag tracking with classification

**Current State**: We already track hashtags in `dwh.facts.hashtag_number` and `dwh.fact_hashtags`

**Enhancement**:

```sql
-- Classify notes by hashtag patterns
SELECT
  f.id_note,
  f.hashtag_number,
  h.hashtag_name,
  CASE
    WHEN h.hashtag_name LIKE '%fire%' THEN 'firefighter'
    WHEN h.hashtag_name LIKE '%air%' THEN 'airplane'
    WHEN h.hashtag_name LIKE '%wheel%' THEN 'wheelchair'
    -- ... more patterns
  END as hashtag_category
FROM dwh.facts f
JOIN dwh.fact_hashtags fh ON f.fact_id = fh.fact_id
JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
WHERE f.action_comment = 'opened';
```

**Benefits**:

- Hashtags are explicit category markers
- Users intentionally add hashtags for organization
- High precision for hashtag-based classification

### 3. Category Word Lists for Training Data

**Application**: Use category word lists to improve training data labeling

**Implementation**:

- Extract keyword lists from tools like DE:Notes Map
- Use keywords to pre-label training data
- Refine labels with manual review

**Benefits**:

- Faster training data preparation
- More consistent labeling
- Better coverage of domain-specific notes

### 4. Multi-level Classification

**Application**: Combine keyword-based and ML-based classification

**Architecture**:

```
Level 1: Keyword/Hashtag Classification (Rule-based)
  ↓
Level 2: ML Classification (Context-aware)
  ↓
Level 3: Action Recommendation
```

**Benefits**:

- Keyword classification for clear cases (high precision)
- ML classification for ambiguous cases (better recall)
- Hybrid approach leverages strengths of both

---

## 🔗 Related Resources

### OSM Forum Discussion

**Topic**: "notes nach Dringlichkeit kategorisieren" (categorizing notes by urgency)  
**Link**: Mentioned in DE:Notes Map but specific URL not provided

**Potential Topics**:

- How to categorize notes by urgency
- Community strategies for note prioritization
- Tools and techniques for note classification

**Action**: Search OSM Forum for this discussion to learn about urgency-based classification

### Other Classification Tools

**Potential Sources**:

- OSM Wiki pages on note management
- Community tools for note analysis
- Academic papers on OSM note classification

---

## 📊 Integration with Our ML Plan

### Enhanced Feature Engineering

**Add Keyword-based Features**:

```python
# In ML feature extraction
text_features = {
    # Existing features...

    # New: Category keyword presence
    'has_firefighter_keywords': check_keywords(text, firefighter_keywords),
    'has_airplane_keywords': check_keywords(text, airplane_keywords),
    'has_wheelchair_keywords': check_keywords(text, wheelchair_keywords),
    # ... more categories

    # New: Hashtag category
    'hashtag_category': get_hashtag_category(hashtags),

    # New: Keyword density
    'category_keyword_density': count_category_keywords(text) / word_count,
}
```

### Enhanced Training Data Labeling

**Use Keywords for Pre-labeling**:

```sql
-- Pre-label training data using keywords
WITH keyword_labels AS (
  SELECT
    f.id_note,
    CASE
      WHEN LOWER(nct.body) LIKE '%firefighter%' OR
           LOWER(nct.body) LIKE '%fire station%' THEN 'firefighter'
      WHEN LOWER(nct.body) LIKE '%airplane%' OR
           LOWER(nct.body) LIKE '%airport%' THEN 'airplane'
      -- ... more keyword patterns
    END as keyword_category
  FROM dwh.facts f
  JOIN public.note_comments_text nct
    ON f.id_note = nct.note_id
    AND f.sequence_action = nct.sequence_action
  WHERE f.action_comment = 'opened'
)
SELECT * FROM keyword_labels;
```

### Hybrid Classification System

**Combine Rule-based and ML**:

1. **Rule-based (Keywords/Hashtags)**:
   - High precision for clear cases
   - Fast inference
   - Use for common categories

2. **ML-based (Context-aware)**:
   - Better recall for ambiguous cases
   - Handles context and nuance
   - Use for complex classification

3. **Ensemble**:
   - Use rule-based when confidence is high
   - Fall back to ML for ambiguous cases
   - Combine predictions for best results

---

## 🎯 Recommendations

### Short-term (Immediate)

1. **Extract Keyword Lists**:
   - Document common keywords for each note type
   - Create keyword dictionaries for our 18+ note types
   - Use for feature engineering

2. **Enhance Hashtag Analysis**:
   - Analyze existing hashtags in our data
   - Identify hashtag patterns for each note type
   - Create hashtag-to-type mapping

3. **Research OSM Forum Discussion**:
   - Find the discussion on "notes nach Dringlichkeit kategorisieren"
   - Extract urgency classification strategies
   - Integrate urgency into our classification

### Medium-term (ML Development)

1. **Hybrid Classification**:
   - Implement rule-based classification for clear cases
   - Use ML for ambiguous cases
   - Combine both approaches

2. **Keyword Feature Engineering**:
   - Add keyword-based features to ML model
   - Train model with keyword features
   - Evaluate improvement in accuracy

3. **Category-specific Models**:
   - Train specialized models for common categories
   - Use general model for rare categories
   - Ensemble predictions

### Long-term (Advanced)

1. **Community Keyword Curation**:
   - Maintain keyword lists based on community feedback
   - Update keywords as note patterns evolve
   - Share keyword lists with community

2. **Multilingual Support**:
   - Expand keyword lists to multiple languages
   - Handle language detection
   - Support multilingual classification

3. **Dynamic Keyword Learning**:
   - Learn new keywords from ML model
   - Update keyword lists automatically
   - Continuous improvement

---

## 📝 Next Steps

1. **Analyze Existing Hashtags**:

   ```sql
   -- Find most common hashtags in our data
   SELECT
     h.hashtag_name,
     COUNT(*) as usage_count
   FROM dwh.fact_hashtags fh
   JOIN dwh.dimension_hashtags h ON fh.dimension_hashtag_id = h.dimension_hashtag_id
   GROUP BY h.hashtag_name
   ORDER BY usage_count DESC
   LIMIT 100;
   ```

2. **Extract Keywords from Note Text**:
   - Analyze note text for common keywords
   - Map keywords to note types
   - Create keyword dictionaries

3. **Research OSM Forum**:
   - Search for urgency classification discussions
   - Document community strategies
   - Integrate findings into our system

4. **Test Keyword-based Classification**:
   - Implement simple keyword classifier
   - Compare with ML classifier
   - Measure accuracy and coverage

---

## 🔗 References

- **DE:Notes Map**: https://greymiche.lima-city.de/osm_notes/index.html
- **OSM Forum**: Discussion on "notes nach Dringlichkeit kategorisieren" (to be located)
- **Our Classification System**: [Note_Categorization.md](Note_Categorization.md)
- **Our ML Plan**: [ML_Implementation_Plan.md](ML_Implementation_Plan.md)

---

**Status**: Research Phase  
**Next Review**: After keyword extraction and hashtag analysis

# Machine Learning with pgml

This directory contains SQL scripts for implementing Machine Learning classification of OSM notes using **pgml** (PostgreSQL Machine Learning).

## Overview

**pgml** allows us to train and use ML models directly in PostgreSQL, eliminating the need for external Python services. This approach:

- ✅ **Simplifies deployment**: No separate ML service needed
- ✅ **Integrates seamlessly**: Uses existing PostgreSQL infrastructure
- ✅ **Leverages existing data**: Builds on our star schema and datamarts
- ✅ **SQL-native**: Everything done in SQL, no language switching
- ✅ **Real-time predictions**: Fast inference directly in database

## Prerequisites

1. **PostgreSQL 14, 15, 16, or 17** (pgml requires PostgreSQL 14+)
   - ⚠️ **Note**: While this project works with PostgreSQL 12+, **pgml specifically requires 14+**
   - If you're using PostgreSQL 12 or 13, you'll need to upgrade to 14+ to use pgml
   - Check your current version: `SELECT version();`
2. **pgml extension installed** at system level (see Installation section)
3. **Training data**: Minimum 1000+ resolved notes (more is better)
4. **Features prepared**: Views with training features (see `ml_01_setupPgML.sql`)

## Installation

### ⚠️ Important: Two-Step Installation Process

**pgml requires TWO steps** - it's NOT just SQL commands:

1. **System-level installation** (install pgml extension on server)
2. **Database-level activation** (enable extension in database)

### Step 1: System-Level Installation

**This must be done FIRST** - installing pgml at the operating system level:

⚠️ **IMPORTANT**: pgml is **NOT available** as a standard apt/deb package. You must use one of the methods below.

#### Option A: Automated Installation Script (RECOMMENDED for existing databases)

If you already have a PostgreSQL database with data, use the automated installation script:

```bash
# Run the installation script (requires sudo)
cd sql/dwh/ml
sudo ./install_pgml.sh
```

This script will:
- Install all required dependencies
- Install Rust compiler
- Clone and compile pgml from source
- Install pgml extension in your existing PostgreSQL
- Verify the installation

**After installation**, enable the extension in your database:
```bash
# Restart PostgreSQL
sudo systemctl restart postgresql

# Enable extension
psql -d osm_notes -c "CREATE EXTENSION IF NOT EXISTS pgml;"

# Verify
psql -d osm_notes -c "SELECT pgml.version();"
```

#### Option B: Using Docker (Only if starting fresh)

⚠️ **Not recommended if you already have a database** - Docker requires migrating your entire database.

This is only practical if you're starting a new project:

```bash
# Use official pgml Docker image
docker run -d \
  --name postgres-pgml \
  -e POSTGRES_PASSWORD=yourpassword \
  -e POSTGRES_DB=osm_notes \
  -p 5432:5432 \
  ghcr.io/postgresml/postgresml:latest

# Connect to the containerized database
docker exec -it postgres-pgml psql -U postgres -d osm_notes
```

**Note**: If using Docker with an existing database, you'll need to:
1. Export your database: `pg_dump osm_notes > backup.sql`
2. Import into Docker container: `docker exec -i postgres-pgml psql -U postgres -d osm_notes < backup.sql`
3. Update all connection strings to point to the Docker container

#### Option C: Manual Compilation from Source

**Prerequisites**:
- PostgreSQL 14+ development headers
- Rust compiler (pgml is written in Rust)
- Python 3.8+ with development headers
- Build tools (make, gcc, etc.)

```bash
# Install build dependencies (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  postgresql-server-dev-15 \
  libpython3-dev \
  python3-pip \
  curl \
  git

# Install Rust (required for pgml)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Clone pgml repository
git clone https://github.com/postgresml/postgresml.git
cd postgresml

# Build and install
# This will take 10-30 minutes depending on your system
cargo build --release

# Install the extension
sudo make install

# Verify installation
ls /usr/share/postgresql/15/extension/pgml*
```

**For detailed build instructions**, see:
- https://github.com/postgresml/postgresml#installation
- https://postgresml.org/docs/guides/getting-started/installation

#### Option D: Using Pre-built Binaries (If Available)

Check the pgml releases page for pre-built binaries:
- https://github.com/postgresml/postgresml/releases

**Note**: Pre-built binaries may not be available for all platforms/PostgreSQL versions.

**Check system installation**:

```bash
# Verify pgml files are installed
ls /usr/share/postgresql/*/extension/pgml*
```

### Step 2: Database-Level Activation

**After system installation**, enable the extension in your database:

```sql
-- Connect to your database
\c osm_notes

-- Enable pgml extension
CREATE EXTENSION IF NOT EXISTS pgml;

-- Verify installation
SELECT * FROM pg_extension WHERE extname = 'pgml';
SELECT pgml.version();
```

**Expected output**:
```
 extname | extversion 
---------+------------
 pgml    | 2.8.0      (or similar version)
```

### Step 3: Verify Full Installation

```sql
-- Test pgml functions
SELECT pgml.version();
SELECT pgml.available_algorithms();
```

If you see errors, the system-level installation may be missing.

## Setup Steps

### Step 0: Install pgml (System Level) ⚠️ REQUIRED FIRST

**This is NOT just SQL - you must install pgml at the OS level first:**

⚠️ **pgml is NOT available as a standard apt package**. Use the automated script or compile from source.

```bash
# Check PostgreSQL version (must be 14+)
psql -d osm_notes -c "SELECT version();"

# Option 1: Use automated installation script (RECOMMENDED for existing databases)
cd sql/dwh/ml
sudo ./install_pgml.sh

# Option 2: Compile from source manually (see Installation section above)

# Verify installation (after compiling from source)
ls /usr/share/postgresql/*/extension/pgml*
```

### Step 1: Enable Extension in Database

```sql
-- Connect to database
\c osm_notes

-- Enable pgml extension (this is the SQL part)
CREATE EXTENSION IF NOT EXISTS pgml;

-- Verify
SELECT pgml.version();
```

### Step 2: Create Feature Views

```bash
psql -d osm_notes -f sql/dwh/ml/ml_01_setupPgML.sql
```

This creates:
- `dwh.v_note_ml_training_features`: Features + target variables for training
- `dwh.v_note_ml_prediction_features`: Features for new notes (no targets)

### Step 3: Train Models

```bash
psql -d osm_notes -f sql/dwh/ml/ml_02_trainPgMLModels.sql
```

**⚠️ Training takes time** (several minutes to hours depending on data size):
- This trains three hierarchical models:
  1. **Main Category** (2 classes): `contributes_with_change` vs `doesnt_contribute`
  2. **Specific Type** (18+ classes): `adds_to_map`, `modifies_map`, `personal_data`, etc.
  3. **Action Recommendation** (3 classes): `process`, `close`, `needs_more_data`

**Monitor training**:
```sql
-- Check training status
SELECT * FROM pgml.training_runs ORDER BY created_at DESC LIMIT 5;

-- Check deployed models
SELECT * FROM pgml.deployed_models WHERE project_name LIKE 'note_classification%';
```

### Step 4: Make Predictions

```bash
psql -d osm_notes -f sql/dwh/ml/ml_03_predictWithPgML.sql
```

Or use the helper function:
```sql
-- Classify a single note
SELECT * FROM dwh.predict_note_category_pgml(12345);

-- Classify new notes in batch
CALL dwh.classify_new_notes_pgml(1000);
```

## Architecture

### Feature Engineering

Features are derived from existing analysis patterns:

1. **Text Features**: `comment_length`, `has_url`, `has_mention`, `hashtag_number`
2. **Hashtag Features**: From `dwh.v_note_hashtag_features` (see `ml_00_analyzeHashtagsForClassification.sql`)
3. **Application Features**: `is_assisted_app`, `is_mobile_app`
4. **Geographic Features**: `country_resolution_rate`, `country_notes_health_score`
5. **User Features**: `user_response_time`, `user_experience_level`
6. **Temporal Features**: `day_of_week`, `hour_of_day`, `month`
7. **Age Features**: `days_open`

**Total**: ~24 features (all informed by existing analysis)

### Model Hierarchy

```
Level 1: Main Category (2 classes)
  ↓
Level 2: Specific Type (18+ classes)
  ↓
Level 3: Action Recommendation (3 classes)
```

Each level is a separate model, allowing:
- Independent optimization
- Different algorithms per level
- Easier debugging and interpretation

## Usage Examples

### Check Training Data

```sql
SELECT 
  COUNT(*) as total_notes,
  COUNT(DISTINCT main_category) as categories,
  COUNT(DISTINCT specific_type) as types
FROM dwh.v_note_ml_training_features
WHERE main_category IS NOT NULL;
```

### Train a Model

```sql
-- This will take several minutes
SELECT * FROM pgml.train(
  project_name => 'note_classification_main_category',
  task => 'classification',
  relation_name => 'dwh.v_note_ml_training_features',
  y_column_name => 'main_category',
  algorithm => 'xgboost'
);
```

### Make Predictions (How to Consume)

#### Option 1: Direct SQL Query

```sql
-- Single note prediction
SELECT 
  id_note,
  pgml.predict(
    'note_classification_main_category',
    ARRAY[
      comment_length, has_url_int, has_mention_int, hashtag_number,
      total_comments_on_note, hashtag_count, has_fire_keyword,
      has_air_keyword, has_access_keyword, has_campaign_keyword,
      has_fix_keyword, is_assisted_app, is_mobile_app,
      country_resolution_rate, country_avg_resolution_days,
      country_notes_health_score, user_response_time,
      user_total_notes, user_experience_level,
      day_of_week, hour_of_day, month, days_open
    ]
  )::VARCHAR as predicted_category
FROM dwh.v_note_ml_prediction_features
WHERE id_note = 12345;
```

#### Option 2: Using Helper Function

```sql
-- Simpler interface
SELECT * FROM dwh.predict_note_category_pgml(12345);
```

#### Option 3: Batch Classification

```sql
-- Classify all new notes
CALL dwh.classify_new_notes_pgml(1000);
```

#### Option 4: In Dashboard Queries

```sql
-- Get high-priority notes for dashboard
SELECT 
  f.id_note,
  f.opened_dimension_id_date,
  c.country_name_en,
  pgml.predict('note_classification_main_category', ...)::VARCHAR as category,
  pgml.predict('note_classification_action', ...)::VARCHAR as action
FROM dwh.facts f
JOIN dwh.v_note_ml_prediction_features pf ON f.id_note = pf.id_note
JOIN dwh.dimension_countries c ON f.dimension_id_country = c.dimension_country_id
WHERE pgml.predict('note_classification_action', ...)::VARCHAR = 'process'
ORDER BY f.opened_dimension_id_date DESC;
```

### View Model Performance

```sql
SELECT 
  project_name,
  algorithm,
  metrics->>'accuracy' as accuracy,
  metrics->>'f1' as f1_score
FROM pgml.deployed_models
WHERE project_name LIKE 'note_classification%';
```

### Get Predictions with Confidence

```sql
-- Get prediction probabilities
SELECT 
  id_note,
  pgml.predict('note_classification_main_category', ...)::VARCHAR as prediction,
  pgml.predict_proba('note_classification_main_category', ...) as probabilities
FROM dwh.v_note_ml_prediction_features
WHERE id_note = 12345;
```

## Integration with Existing System

### Classification Table

Predictions are stored in `dwh.note_type_classifications` (see `ML_Implementation_Plan.md`):

```sql
SELECT 
  id_note,
  main_category,
  specific_type,
  recommended_action,
  priority_score,
  type_method  -- Will be 'ml_based'
FROM dwh.note_type_classifications
WHERE type_method = 'ml_based';
```

### ETL Integration

Add to ETL pipeline:

```bash
# After datamart updates
psql -d osm_notes -c "
  INSERT INTO dwh.note_type_classifications (...)
  SELECT ... FROM dwh.v_note_ml_prediction_features
  WHERE id_note NOT IN (SELECT id_note FROM dwh.note_type_classifications);
"
```

## Model Maintenance

### Retrain Models

Models should be retrained periodically (monthly/quarterly):

```sql
-- Retrain with latest data
SELECT * FROM pgml.train(
  project_name => 'note_classification_main_category',
  ...
);
```

### Monitor Performance

```sql
-- Track accuracy over time
SELECT 
  created_at,
  metrics->>'accuracy' as accuracy
FROM pgml.deployed_models
WHERE project_name = 'note_classification_main_category'
ORDER BY created_at DESC;
```

### Compare Models

```sql
-- Compare different algorithms
SELECT 
  algorithm,
  AVG((metrics->>'accuracy')::numeric) as avg_accuracy
FROM pgml.deployed_models
WHERE project_name = 'note_classification_main_category'
GROUP BY algorithm;
```

## Advantages of pgml Approach

1. **No External Services**: Everything in PostgreSQL
2. **SQL-Native**: No Python/API calls needed
3. **Real-time**: Fast predictions directly in queries
4. **Integrated**: Uses existing DWH infrastructure
5. **Simple Deployment**: Just install extension
6. **Version Control**: Models tracked in database

## Limitations

1. **Limited Algorithms**: pgml supports fewer algorithms than scikit-learn
2. **Text Features**: Basic text features only (no advanced NLP)
3. **Model Size**: Large models may impact database performance
4. **Training Time**: Training happens in database (may slow down other queries)

## Next Steps

1. **Enhance Features**: Add more text features (word counts, semantic patterns)
2. **Tune Hyperparameters**: Optimize model performance
3. **Add Text Embeddings**: Use pgml's text embedding features
4. **Hybrid Approach**: Combine pgml with rule-based classification
5. **Monitor Performance**: Track accuracy and update models regularly

## Related Documentation

- [ML Implementation Plan](../docs/ML_Implementation_Plan.md): Overall ML strategy
- [Note Categorization](../docs/Note_Categorization.md): Classification system
- [External Classification Strategies](../docs/External_Classification_Strategies.md): Keyword/hashtag approaches
- [Hashtag Analysis](ml_00_analyzeHashtagsForClassification.sql): Hashtag feature extraction

## References

- **pgml Documentation**: https://postgresml.org/
- **pgml GitHub**: https://github.com/postgresml/postgresml
- **pgml Examples**: https://postgresml.org/docs/guides/

---

**Status**: Implementation Ready  
**Dependencies**: pgml extension, training data, feature views


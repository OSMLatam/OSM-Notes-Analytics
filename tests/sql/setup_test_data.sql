-- Setup minimal test data for datamarts testing
-- Creates minimal star schema data for testing purposes
--
-- Author: Andres Gomez (AngocA)
-- Date: 2025-10-26

\echo 'Creating minimal test data for datamarts...'

-- Check if dimension_applications exists, if not create it
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_applications') THEN
    CREATE TABLE dwh.dimension_applications (
      dimension_application_id SERIAL PRIMARY KEY,
      application_name VARCHAR(64) NOT NULL,
      pattern VARCHAR(64),
      pattern_type VARCHAR(16),
      platform VARCHAR(16),
      vendor VARCHAR(32),
      category VARCHAR(32),
      active BOOLEAN
    );

    INSERT INTO dwh.dimension_applications (application_name, platform) VALUES
      ('Unknown', NULL),
      ('StreetComplete', 'android'),
      ('iD Editor', 'web'),
      ('JOSM', 'desktop'),
      ('MapComplete', 'web'),
      ('Maps.me', 'ios');
  END IF;
END $$;

-- Check if dimension_users exists, if not create it
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_users') THEN
    CREATE TABLE dwh.dimension_users (
      dimension_user_id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL,
      username VARCHAR(256),
      modified BOOLEAN DEFAULT TRUE,
      is_current BOOLEAN DEFAULT TRUE
    );

    INSERT INTO dwh.dimension_users (user_id, username) VALUES
      (1, 'test_user_1'),
      (2, 'test_user_2'),
      (3, 'test_user_3');
  END IF;
END $$;

-- Check if dimension_countries exists, if not create it
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_countries') THEN
    CREATE TABLE dwh.dimension_countries (
      dimension_country_id SERIAL PRIMARY KEY,
      country_id INTEGER NOT NULL,
      country_name VARCHAR(100),
      country_name_es VARCHAR(100),
      country_name_en VARCHAR(100),
      modified BOOLEAN DEFAULT TRUE
    );

    INSERT INTO dwh.dimension_countries (country_id, country_name, country_name_es, country_name_en) VALUES
      (1, 'TestCountry1', 'TestCountry1', 'TestCountry1'),
      (2, 'TestCountry2', 'TestCountry2', 'TestCountry2'),
      (3, 'TestCountry3', 'TestCountry3', 'TestCountry3');
  END IF;
END $$;

-- Check if dimension_days exists, if not create it
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_days') THEN
    CREATE TABLE dwh.dimension_days (
      dimension_day_id SERIAL PRIMARY KEY,
      date_id DATE
    );

    INSERT INTO dwh.dimension_days (date_id) VALUES
      ('2023-01-01'),
      ('2023-01-02'),
      ('2024-01-01'),
      ('2024-06-15'),
      ('2025-01-01');
  END IF;
END $$;

-- Check if facts exists, if not create it and populate with minimal data
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'facts') THEN
    EXECUTE '
    CREATE TABLE dwh.facts (
      fact_id BIGSERIAL PRIMARY KEY,
      id_note INTEGER NOT NULL,
      sequence_action INTEGER DEFAULT 1,
      dimension_id_country INTEGER,
      processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      action_at TIMESTAMP NOT NULL,
      action_comment TEXT,
      action_dimension_id_date INTEGER,
      action_dimension_id_hour_of_week SMALLINT DEFAULT 1,
      action_dimension_id_user INTEGER,
      opened_dimension_id_date INTEGER,
      opened_dimension_id_hour_of_week SMALLINT DEFAULT 1,
      opened_dimension_id_user INTEGER,
      closed_dimension_id_date INTEGER,
      closed_dimension_id_hour_of_week SMALLINT,
      closed_dimension_id_user INTEGER,
      dimension_application_creation INTEGER,
      days_to_resolution INTEGER,
      total_actions_on_note INTEGER DEFAULT 1,
      total_comments_on_note INTEGER DEFAULT 0,
      total_reopenings_count INTEGER DEFAULT 0,
      comment_length INTEGER,
      has_url BOOLEAN,
      has_mention BOOLEAN
    )';

    -- Insert minimal test data
    INSERT INTO dwh.facts (
      id_note, action_at, action_comment,
      dimension_id_country, dimension_id_user,
      action_dimension_id_date,
      opened_dimension_id_date, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_user,
      dimension_application_creation, days_to_resolution,
      comment_length, has_url, has_mention
    ) VALUES
      -- Country 1: 3 opened, 2 closed (1 resolved in 5 days, 1 in 10 days), 1 still open
      -- Comments: avg length 20, 1 with URL, 1 with mention
      (1001, '2023-01-01 10:00:00', 'opened', 1, 1, 1, 1, 1, NULL, NULL, 1, NULL, 15, FALSE, FALSE),
      (1001, '2023-01-06 14:00:00', 'closed', 1, 2, 2, 1, 1, 2, 2, NULL, 5, 25, TRUE, TRUE),
      (1002, '2023-01-02 11:00:00', 'opened', 1, 1, 2, 2, 1, NULL, NULL, 2, NULL, 10, FALSE, FALSE),
      (1002, '2023-01-12 15:00:00', 'closed', 1, 2, 3, 2, 1, 3, 2, NULL, 10, 30, FALSE, FALSE),
      (1003, '2023-01-03 12:00:00', 'opened', 1, 1, 3, 3, 1, NULL, NULL, 3, NULL, 20, FALSE, FALSE),

      -- Country 2: 2 opened, 2 closed (100% resolution)
      -- Comments: avg length 40, 2 with URL, 1 with mention
      (2001, '2024-01-01 10:00:00', 'opened', 2, 2, 3, 3, 2, NULL, NULL, 4, NULL, 30, TRUE, FALSE),
      (2001, '2024-01-05 14:00:00', 'closed', 2, 2, 4, 3, 2, 4, 2, NULL, 4, 50, TRUE, TRUE),
      (2002, '2024-01-02 11:00:00', 'opened', 2, 3, 4, 4, 3, NULL, NULL, 5, NULL, 35, FALSE, FALSE),
      (2002, '2024-01-06 15:00:00', 'closed', 2, 2, 5, 4, 3, 5, 2, NULL, 4, 45, FALSE, FALSE),

      -- Country 3: 1 opened, not closed (0% resolution)
      -- Comments: avg length 15, no URLs, no mentions
      (3001, '2024-06-15 10:00:00', 'opened', 3, 3, 4, 4, 3, NULL, NULL, 6, NULL, 15, FALSE, FALSE);
  END IF;
END $$;

\echo 'Test data setup complete!'
SELECT 'Test data created successfully' AS result;


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

-- Check if dimension_days exists, if not create it with enhanced attributes
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'dimension_days') THEN
    CREATE TABLE dwh.dimension_days (
      dimension_day_id SERIAL PRIMARY KEY,
      date_id DATE,
      year SMALLINT,
      month SMALLINT,
      day SMALLINT,
      iso_year SMALLINT,
      iso_week SMALLINT,
      day_of_year SMALLINT,
      quarter SMALLINT,
      month_name VARCHAR(16),
      day_name VARCHAR(16),
      is_weekend BOOLEAN,
      is_month_end BOOLEAN,
      is_quarter_end BOOLEAN,
      is_year_end BOOLEAN
    );

    -- Populate dimension_days with enhanced attributes using get_date_id function if available
    -- Otherwise insert manually with calculated values
    INSERT INTO dwh.dimension_days (
      date_id, year, month, day, iso_year, iso_week, day_of_year, quarter,
      month_name, day_name, is_weekend, is_month_end, is_quarter_end, is_year_end
    ) VALUES
      ('2023-01-01', 2023, 1, 1, 2022, 52, 1, 1, 'Jan', 'Sun', TRUE, FALSE, FALSE, FALSE),
      ('2023-01-02', 2023, 1, 2, 2023, 1, 2, 1, 'Jan', 'Mon', FALSE, FALSE, FALSE, FALSE),
      ('2023-01-06', 2023, 1, 6, 2023, 1, 6, 1, 'Jan', 'Fri', FALSE, FALSE, FALSE, FALSE),
      ('2023-01-12', 2023, 1, 12, 2023, 2, 12, 1, 'Jan', 'Thu', FALSE, FALSE, FALSE, FALSE),
      ('2023-02-01', 2023, 2, 1, 2023, 5, 32, 1, 'Feb', 'Wed', FALSE, FALSE, FALSE, FALSE),
      ('2023-02-15', 2023, 2, 15, 2023, 7, 46, 1, 'Feb', 'Wed', FALSE, FALSE, FALSE, FALSE),
      ('2023-03-01', 2023, 3, 1, 2023, 9, 60, 1, 'Mar', 'Wed', FALSE, FALSE, FALSE, FALSE),
      ('2023-03-20', 2023, 3, 20, 2023, 12, 79, 1, 'Mar', 'Mon', FALSE, FALSE, FALSE, FALSE),
      ('2024-01-01', 2024, 1, 1, 2024, 1, 1, 1, 'Jan', 'Mon', FALSE, FALSE, FALSE, FALSE),
      ('2024-01-02', 2024, 1, 2, 2024, 1, 2, 1, 'Jan', 'Tue', FALSE, FALSE, FALSE, FALSE),
      ('2024-01-05', 2024, 1, 5, 2024, 1, 5, 1, 'Jan', 'Fri', FALSE, FALSE, FALSE, FALSE),
      ('2024-01-06', 2024, 1, 6, 2024, 1, 6, 1, 'Jan', 'Sat', TRUE, FALSE, FALSE, FALSE),
      ('2024-02-01', 2024, 2, 1, 2024, 5, 32, 1, 'Feb', 'Thu', FALSE, FALSE, FALSE, FALSE),
      ('2024-02-10', 2024, 2, 10, 2024, 6, 41, 1, 'Feb', 'Sat', TRUE, FALSE, FALSE, FALSE),
      ('2024-06-15', 2024, 6, 15, 2024, 24, 167, 2, 'Jun', 'Sat', TRUE, FALSE, FALSE, FALSE),
      ('2024-07-01', 2024, 7, 1, 2024, 27, 183, 3, 'Jul', 'Mon', FALSE, FALSE, FALSE, FALSE),
      ('2024-07-15', 2024, 7, 15, 2024, 29, 197, 3, 'Jul', 'Mon', FALSE, FALSE, FALSE, FALSE),
      ('2025-01-01', 2025, 1, 1, 2025, 1, 1, 1, 'Jan', 'Wed', FALSE, FALSE, FALSE, FALSE);
  ELSE
    -- If table exists, ensure enhanced attributes are populated for test dates
    -- Update existing rows to have enhanced attributes if they're NULL
    UPDATE dwh.dimension_days
    SET
      year = EXTRACT(YEAR FROM date_id),
      month = EXTRACT(MONTH FROM date_id),
      day = EXTRACT(DAY FROM date_id),
      iso_year = EXTRACT(ISOYEAR FROM date_id),
      iso_week = EXTRACT(WEEK FROM date_id),
      day_of_year = EXTRACT(DOY FROM date_id),
      quarter = EXTRACT(QUARTER FROM date_id),
      month_name = TO_CHAR(date_id, 'Mon'),
      day_name = TO_CHAR(date_id, 'Dy'),
      is_weekend = (EXTRACT(ISODOW FROM date_id) IN (6,7)),
      is_month_end = ((DATE_TRUNC('month', date_id) + INTERVAL '1 month - 1 day')::DATE = date_id),
      is_quarter_end = (EXTRACT(MONTH FROM date_id) IN (3,6,9,12) AND date_id = (DATE_TRUNC('quarter', date_id) + INTERVAL '3 month - 1 day')::DATE),
      is_year_end = ((DATE_TRUNC('year', date_id) + INTERVAL '1 year - 1 day')::DATE = date_id)
    WHERE date_id IN ('2023-01-01', '2023-01-02', '2023-01-06', '2023-01-12',
                      '2023-02-01', '2023-02-15', '2023-03-01', '2023-03-20',
                      '2024-01-01', '2024-01-02', '2024-01-05', '2024-01-06',
                      '2024-02-01', '2024-02-10', '2024-06-15', '2024-07-01',
                      '2024-07-15', '2025-01-01')
      AND (year IS NULL OR iso_week IS NULL OR quarter IS NULL OR month_name IS NULL);
  END IF;
END $$;

-- Ensure dimension_time_of_week has entries for test data
-- This ensures that action_dimension_id_hour_of_week values in facts table are valid
DO $$
DECLARE
  test_timestamp TIMESTAMP;
  test_tow_id SMALLINT;
  test_day_of_week SMALLINT;
  test_hour_of_day SMALLINT;
  test_hour_of_week SMALLINT;
  test_period_of_day VARCHAR(16);
BEGIN
  -- Populate dimension_time_of_week for timestamps used in test data
  -- Using the same logic as get_hour_of_week_id function
  FOR test_timestamp IN 
    SELECT unnest(ARRAY[
      '2023-01-01 10:00:00'::TIMESTAMP,
      '2023-01-01 12:00:00'::TIMESTAMP,
      '2023-01-02 11:00:00'::TIMESTAMP,
      '2023-01-06 14:00:00'::TIMESTAMP,
      '2023-01-12 15:00:00'::TIMESTAMP,
      '2023-02-01 10:00:00'::TIMESTAMP,
      '2023-02-15 14:00:00'::TIMESTAMP,
      '2023-03-01 10:00:00'::TIMESTAMP,
      '2023-03-20 14:00:00'::TIMESTAMP,
      '2024-01-01 10:00:00'::TIMESTAMP,
      '2024-01-01 12:00:00'::TIMESTAMP,
      '2024-01-02 11:00:00'::TIMESTAMP,
      '2024-01-05 14:00:00'::TIMESTAMP,
      '2024-01-06 15:00:00'::TIMESTAMP,
      '2024-02-01 10:00:00'::TIMESTAMP,
      '2024-02-10 14:00:00'::TIMESTAMP,
      '2024-06-15 10:00:00'::TIMESTAMP,
      '2024-07-01 10:00:00'::TIMESTAMP,
      '2024-07-15 14:00:00'::TIMESTAMP
    ])
  LOOP
    test_day_of_week := EXTRACT(ISODOW FROM test_timestamp);
    test_hour_of_day := EXTRACT(HOUR FROM test_timestamp);
    test_tow_id := test_day_of_week * 100 + test_hour_of_day;
    test_hour_of_week := (test_day_of_week - 1) * 24 + test_hour_of_day;
    
    IF test_hour_of_day BETWEEN 0 AND 5 THEN
      test_period_of_day := 'Night';
    ELSIF test_hour_of_day BETWEEN 6 AND 11 THEN
      test_period_of_day := 'Morning';
    ELSIF test_hour_of_day BETWEEN 12 AND 17 THEN
      test_period_of_day := 'Afternoon';
    ELSE
      test_period_of_day := 'Evening';
    END IF;
    
    INSERT INTO dwh.dimension_time_of_week (
      dimension_tow_id, day_of_week, hour_of_day, hour_of_week, period_of_day
    ) VALUES (
      test_tow_id, test_day_of_week, test_hour_of_day, test_hour_of_week, test_period_of_day
    ) ON CONFLICT (dimension_tow_id) DO NOTHING;
  END LOOP;
END $$;

-- Check if facts exists, if not create it and populate with minimal data
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dwh' AND table_name = 'facts') THEN
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
    );

    -- Insert minimal test data with resolution metrics
    -- Note: Using action_dimension_id_user instead of dimension_id_user
    -- Using calculated hour_of_week IDs: dimension_tow_id = ISODOW * 100 + hour
    -- Values: 710 (Sun 10:00), 712 (Sun 12:00), 111 (Mon 11:00), 514 (Fri 14:00), 415 (Thu 15:00),
    --         310 (Wed 10:00), 314 (Wed 14:00), 114 (Mon 14:00), 210 (Tue 11:00), 615 (Sat 15:00),
    --         410 (Thu 10:00), 614 (Sat 14:00), 610 (Sat 10:00)
    INSERT INTO dwh.facts (
      id_note, action_at, action_comment,
      dimension_id_country, action_dimension_id_user,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      opened_dimension_id_date, opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week, closed_dimension_id_user,
      dimension_application_creation, days_to_resolution,
      comment_length, has_url, has_mention
    ) VALUES
      -- Country 1: Multiple notes with resolution data across different years/months
      -- Note 1001: Opened 2023-01-01 10:00 (Sun), closed 2023-01-06 14:00 (Fri) - 5 days
      (1001, '2023-01-01 10:00:00', 'opened', 1, 1, 1, 710, 1, 710, 1, NULL, NULL, NULL, 1, NULL, 15, FALSE, FALSE),
      (1001, '2023-01-06 14:00:00', 'closed', 1, 2, 3, 514, 1, 710, 1, 3, 514, 2, NULL, 5, 25, TRUE, TRUE),
      -- Note 1002: Opened 2023-01-02 11:00 (Mon), closed 2023-01-12 15:00 (Thu) - 10 days
      (1002, '2023-01-02 11:00:00', 'opened', 1, 1, 2, 111, 2, 111, 1, NULL, NULL, NULL, 2, NULL, 10, FALSE, FALSE),
      (1002, '2023-01-12 15:00:00', 'closed', 1, 2, 4, 415, 2, 111, 1, 4, 415, 2, NULL, 10, 30, FALSE, FALSE),
      -- Note 1003: Opened 2023-02-01 10:00 (Wed), closed 2023-02-15 14:00 (Wed) - 14 days, different month
      (1003, '2023-02-01 10:00:00', 'opened', 1, 1, 5, 310, 5, 310, 1, NULL, NULL, NULL, 1, NULL, 20, FALSE, FALSE),
      (1003, '2023-02-15 14:00:00', 'closed', 1, 2, 6, 314, 5, 310, 1, 6, 314, 2, NULL, 14, 35, TRUE, FALSE),
      -- Note 1004: Opened 2023-03-01 10:00 (Wed), closed 2023-03-20 14:00 (Mon) - 19 days, different month
      (1004, '2023-03-01 10:00:00', 'opened', 1, 1, 7, 310, 7, 310, 1, NULL, NULL, NULL, 2, NULL, 25, FALSE, TRUE),
      (1004, '2023-03-20 14:00:00', 'closed', 1, 2, 8, 114, 7, 310, 1, 8, 114, 2, NULL, 19, 40, FALSE, FALSE),
      -- Note 1005: Opened 2023-01-01 12:00 (Sun), still open (no resolution)
      (1005, '2023-01-01 12:00:00', 'opened', 1, 1, 1, 712, 1, 712, 1, NULL, NULL, NULL, 3, NULL, 20, FALSE, FALSE),

      -- Country 2: Multiple notes with resolution data in 2024
      -- Note 2001: Opened 2024-01-01 10:00 (Mon), closed 2024-01-05 14:00 (Fri) - 4 days
      (2001, '2024-01-01 10:00:00', 'opened', 2, 2, 9, 110, 9, 110, 2, NULL, NULL, NULL, 4, NULL, 30, TRUE, FALSE),
      (2001, '2024-01-05 14:00:00', 'closed', 2, 2, 11, 514, 9, 110, 2, 11, 514, 2, NULL, 4, 50, TRUE, TRUE),
      -- Note 2002: Opened 2024-01-02 11:00 (Tue), closed 2024-01-06 15:00 (Sat) - 4 days
      (2002, '2024-01-02 11:00:00', 'opened', 2, 3, 10, 211, 10, 211, 3, NULL, NULL, NULL, 5, NULL, 35, FALSE, FALSE),
      (2002, '2024-01-06 15:00:00', 'closed', 2, 2, 12, 615, 10, 211, 3, 12, 615, 2, NULL, 4, 45, FALSE, FALSE),
      -- Note 2003: Opened 2024-02-01 10:00 (Thu), closed 2024-02-10 14:00 (Sat) - 9 days, different month
      (2003, '2024-02-01 10:00:00', 'opened', 2, 2, 13, 410, 13, 410, 2, NULL, NULL, NULL, 4, NULL, 40, TRUE, FALSE),
      (2003, '2024-02-10 14:00:00', 'closed', 2, 3, 14, 614, 13, 410, 2, 14, 614, 3, NULL, 9, 55, FALSE, TRUE),
      -- Note 2004: Opened 2024-01-01 12:00 (Mon), still open (no resolution)
      (2004, '2024-01-01 12:00:00', 'opened', 2, 3, 9, 112, 9, 112, 3, NULL, NULL, NULL, 6, NULL, 20, FALSE, FALSE),

      -- Country 3: One opened note, not closed (0% resolution)
      (3001, '2024-06-15 10:00:00', 'opened', 3, 3, 15, 610, 15, 610, 3, NULL, NULL, NULL, 6, NULL, 15, FALSE, FALSE),
      -- Note 3002: Opened 2024-07-01 10:00 (Mon) and closed 2024-07-15 14:00 (Mon) for resolution_by_year/month testing
      (3002, '2024-07-01 10:00:00', 'opened', 3, 3, 16, 110, 16, 110, 3, NULL, NULL, NULL, 1, NULL, 20, FALSE, FALSE),
      (3002, '2024-07-15 14:00:00', 'closed', 3, 3, 17, 114, 16, 110, 3, 17, 114, 3, NULL, 14, 30, FALSE, FALSE);
  END IF;
END $$;

\echo 'Test data setup complete!'
SELECT 'Test data created successfully' AS result;


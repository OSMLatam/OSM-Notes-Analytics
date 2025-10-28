-- Generate Mock Staging Data for Testing
-- Creates realistic staging data that simulates real notes ingestion
-- Author: Andres Gomez (AngocA)
-- Date: 2025-10-27

\echo 'Generating mock staging data for testing...'

-- Create staging schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS staging;

-- Note actions (staging.nota_action table)
CREATE TABLE IF NOT EXISTS staging.nota_action (
  id_note INTEGER NOT NULL,
  sequence_action INTEGER NOT NULL,
  action_at TIMESTAMP NOT NULL,
  action_type TEXT NOT NULL,
  action_comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Country mapping (staging.country_mapping)
CREATE TABLE IF NOT EXISTS staging.country_mapping (
  id_note INTEGER NOT NULL,
  country_id INTEGER NOT NULL,
  country_code VARCHAR(2),
  country_name VARCHAR(100),
  lat DECIMAL(10,8),
  lon DECIMAL(11,8)
);

-- User mapping (staging.user_mapping)
CREATE TABLE IF NOT EXISTS staging.user_mapping (
  id_note INTEGER NOT NULL,
  sequence_action INTEGER NOT NULL,
  user_id INTEGER,
  username VARCHAR(256)
);

-- Application creation info
CREATE TABLE IF NOT EXISTS staging.application_info (
  id_note INTEGER NOT NULL,
  application_comment TEXT,
  application_name VARCHAR(64),
  created_at TIMESTAMP NOT NULL
);

-- Clear existing data
TRUNCATE TABLE staging.nota_action, staging.country_mapping, staging.user_mapping, staging.application_info;

-- Insert mock data

-- Country 1: USA - Active notes, good resolution rate
-- Note 1: Opened with StreetComplete (android), closed by user 2
INSERT INTO staging.nota_action VALUES
  (1001, 1, '2023-01-01 10:00:00', 'opened', 'Test note from StreetComplete app', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (1001, 2, '2023-01-06 14:00:00', 'commented', 'Investigating issue', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (1001, 3, '2023-01-06 15:00:00', 'closed', 'Issue fixed', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO staging.country_mapping VALUES (1001, 1, 'US', 'United States', 40.7128, -74.0060);
INSERT INTO staging.user_mapping VALUES
  (1001, 1, 101, 'test_user_a'),
  (1001, 2, 102, 'test_user_b'),
  (1001, 3, 102, 'test_user_b');
INSERT INTO staging.application_info VALUES (1001, 'StreetComplete', 'StreetComplete', '2023-01-01 10:00:00');

-- Note 2: Opened with iD Editor (web), closed quickly
INSERT INTO staging.nota_action VALUES
  (1002, 1, '2023-01-02 11:00:00', 'opened', 'Minor map issue', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (1002, 2, '2023-01-04 12:00:00', 'closed', 'Fixed', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO staging.country_mapping VALUES (1002, 1, 'US', 'United States', 34.0522, -118.2437);
INSERT INTO staging.user_mapping VALUES
  (1002, 1, 103, 'test_user_c'),
  (1002, 2, 103, 'test_user_c');
INSERT INTO staging.application_info VALUES (1002, 'iD Editor', 'iD Editor', '2023-01-02 11:00:00');

-- Note 3: Opened with JOSM (desktop), still open
INSERT INTO staging.nota_action VALUES
  (1003, 1, '2023-01-03 12:00:00', 'opened', 'Complex issue', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (1003, 2, '2023-01-05 10:00:00', 'commented', 'Still investigating', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO staging.country_mapping VALUES (1003, 1, 'US', 'United States', 29.7604, -95.3698);
INSERT INTO staging.user_mapping VALUES
  (1003, 1, 104, 'test_user_d'),
  (1003, 2, 105, 'test_user_e');
INSERT INTO staging.application_info VALUES (1003, 'JOSM', 'JOSM', '2023-01-03 12:00:00');

-- Country 2: UK - High mobile app usage
-- Note 4: Opened with Maps.me (ios), closed
INSERT INTO staging.nota_action VALUES
  (2001, 1, '2024-01-01 10:00:00', 'opened', 'Missing POI', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (2001, 2, '2024-01-03 14:00:00', 'closed', 'Added POI', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO staging.country_mapping VALUES (2001, 2, 'GB', 'United Kingdom', 51.5074, -0.1278);
INSERT INTO staging.user_mapping VALUES
  (2001, 1, 201, 'test_user_f'),
  (2001, 2, 201, 'test_user_f');
INSERT INTO staging.application_info VALUES (2001, 'Maps.me', 'Maps.me', '2024-01-01 10:00:00');

-- Note 5: Opened with StreetComplete (android), closed
INSERT INTO staging.nota_action VALUES
  (2002, 1, '2024-01-02 11:00:00', 'opened', 'Road needs updating', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (2002, 2, '2024-01-06 15:00:00', 'closed', 'Updated', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO staging.country_mapping VALUES (2002, 2, 'GB', 'United Kingdom', 52.4862, -1.8904);
INSERT INTO staging.user_mapping VALUES
  (2002, 1, 202, 'test_user_g'),
  (2002, 2, 202, 'test_user_g');
INSERT INTO staging.application_info VALUES (2002, 'StreetComplete', 'StreetComplete', '2024-01-02 11:00:00');

-- Country 3: Germany - Poor resolution rate
-- Note 6: Opened with MapComplete (web), still open
INSERT INTO staging.nota_action VALUES
  (3001, 1, '2024-06-15 10:00:00', 'opened', 'Complex area issue', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT INTO staging.country_mapping VALUES (3001, 3, 'DE', 'Germany', 52.5200, 13.4050);
INSERT INTO staging.user_mapping VALUES (3001, 1, 301, 'test_user_h');
INSERT INTO staging.application_info VALUES (3001, 'MapComplete', 'MapComplete', '2024-06-15 10:00:00');

\echo 'Mock staging data generated successfully!'
SELECT 'Staging tables' AS table_name, COUNT(*) AS record_count FROM staging.nota_action
UNION ALL
SELECT 'Country mapping', COUNT(*) FROM staging.country_mapping
UNION ALL
SELECT 'User mapping', COUNT(*) FROM staging.user_mapping
UNION ALL
SELECT 'Application info', COUNT(*) FROM staging.application_info;



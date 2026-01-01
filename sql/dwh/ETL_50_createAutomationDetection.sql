-- Create automation detection system
-- Detects bot/script patterns in OSM notes
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-24

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating automation detection dimension' AS Task;

-- Create dimension table
CREATE TABLE IF NOT EXISTS dwh.dimension_automation_level (
  dimension_automation_id SMALLINT PRIMARY KEY,
  automation_level VARCHAR(30) NOT NULL,
  confidence_score DECIMAL(3,2) NOT NULL,
  description TEXT,
  detection_criteria JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE dwh.dimension_automation_level IS
  'Automation level dimension for detecting bot/script patterns';
COMMENT ON COLUMN dwh.dimension_automation_level.dimension_automation_id IS
  'Primary key';
COMMENT ON COLUMN dwh.dimension_automation_level.automation_level IS
  'Level name: human, probably_human, uncertain, probably_automated, automated, bulk_import';
COMMENT ON COLUMN dwh.dimension_automation_level.confidence_score IS
  'Confidence level 0.00 to 1.00 (higher = more confident)';
COMMENT ON COLUMN dwh.dimension_automation_level.description IS
  'Human-readable description';
COMMENT ON COLUMN dwh.dimension_automation_level.detection_criteria IS
  'JSON with criteria that triggered this classification';

-- Populate with automation levels
INSERT INTO dwh.dimension_automation_level (dimension_automation_id, automation_level, confidence_score, description) VALUES
  (1, 'human', 0.90, 'Very likely human user - normal patterns detected'),
  (2, 'probably_human', 0.70, 'Probably human with some unusual patterns'),
  (3, 'uncertain', 0.50, 'Cannot determine - mixed signals'),
  (4, 'probably_automated', 0.70, 'Shows automation patterns - likely bot/script'),
  (5, 'automated', 0.90, 'Very likely bot/script - clear automation patterns'),
  (6, 'bulk_import', 0.95, 'Bulk data import detected - massive automated upload')
ON CONFLICT (dimension_automation_id) DO NOTHING;

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Adding automation column to facts table' AS Task;

-- Add foreign key column to facts table
ALTER TABLE dwh.facts
  ADD COLUMN IF NOT EXISTS dimension_id_automation SMALLINT;

COMMENT ON COLUMN dwh.facts.dimension_id_automation IS
  'Automation level detected for this action/user';

-- Add foreign key constraint (with IF NOT EXISTS check)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_facts_automation'
  ) THEN
    ALTER TABLE dwh.facts
      ADD CONSTRAINT fk_facts_automation
      FOREIGN KEY (dimension_id_automation)
      REFERENCES dwh.dimension_automation_level(dimension_automation_id);
  END IF;
END $$;

-- Create index for queries filtering by automation level
CREATE INDEX IF NOT EXISTS facts_automation_idx
  ON dwh.facts (dimension_id_automation)
  WHERE dimension_id_automation IS NOT NULL;

COMMENT ON INDEX dwh.facts_automation_idx IS
  'Improves queries filtering by automation level';

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating automation detection function' AS Task;

-- Function to detect automation patterns for a user
CREATE OR REPLACE FUNCTION dwh.detect_user_automation(
  p_dimension_user_id INTEGER,
  p_time_window_hours INTEGER DEFAULT 24
) RETURNS TABLE (
  automation_id SMALLINT,
  confidence_score DECIMAL(3,2),
  detection_criteria JSONB
)
LANGUAGE plpgsql
AS $func$
DECLARE
  v_criteria JSONB := '{}'::JSONB;
  v_score DECIMAL(5,3) := 0.0;
  v_weight DECIMAL(5,3);
  v_value DECIMAL(5,3);

  -- Criterion 1: Velocity
  v_notes_opened INTEGER;
  v_time_span_minutes DECIMAL;
  v_notes_per_minute DECIMAL;

  -- Criterion 2: Geographic distance
  v_countries_count INTEGER;
  v_time_span_hours DECIMAL;

  -- Criterion 3: Temporal pattern
  v_avg_active_hours DECIMAL;
  v_days_active INTEGER;

  -- Criterion 4: Action distribution
  v_total_opened INTEGER;
  v_total_commented INTEGER;
  v_total_closed INTEGER;
  v_total_actions INTEGER;
  v_pct_opened DECIMAL;
  v_pct_commented DECIMAL;
BEGIN
  -- CRITERION 1: Velocity of note creation (25% weight)
  SELECT
    COUNT(*) FILTER (WHERE action_comment = 'opened'),
    EXTRACT(EPOCH FROM (MAX(action_at) - MIN(action_at))) / 60.0
  INTO v_notes_opened, v_time_span_minutes
  FROM dwh.facts
  WHERE opened_dimension_id_user = p_dimension_user_id
    AND action_at > NOW() - (p_time_window_hours || ' hours')::INTERVAL;

  IF v_notes_opened > 5 AND v_time_span_minutes > 0 THEN
    v_notes_per_minute := v_notes_opened / v_time_span_minutes;

    IF v_notes_per_minute > 10 THEN
      v_value := 0.8;
      v_criteria := v_criteria || jsonb_build_object('velocity', 'extreme');
    ELSIF v_notes_per_minute > 5 THEN
      v_value := 0.6;
      v_criteria := v_criteria || jsonb_build_object('velocity', 'high');
    ELSIF v_notes_per_minute > 2 THEN
      v_value := 0.3;
      v_criteria := v_criteria || jsonb_build_object('velocity', 'moderate');
    ELSE
      v_value := 0.0;
      v_criteria := v_criteria || jsonb_build_object('velocity', 'normal');
    END IF;

    v_weight := 0.25;
    v_score := v_score + (v_value * v_weight);
    v_criteria := v_criteria || jsonb_build_object('velocity_score', v_value);
  END IF;

  -- CRITERION 2: Geographic distance (20% weight)
  SELECT
    COUNT(DISTINCT dimension_id_country),
    EXTRACT(EPOCH FROM (MAX(action_at) - MIN(action_at))) / 3600.0
  INTO v_countries_count, v_time_span_hours
  FROM dwh.facts
  WHERE opened_dimension_id_user = p_dimension_user_id
    AND action_comment = 'opened'
    AND action_at > NOW() - (p_time_window_hours || ' hours')::INTERVAL;

  IF v_countries_count > 1 AND v_time_span_hours > 0 THEN
    IF v_countries_count > 5 AND v_time_span_hours < 6 THEN
      v_value := 0.7;
      v_criteria := v_criteria || jsonb_build_object('geography', 'extreme_jump');
    ELSIF v_countries_count > 3 AND v_time_span_hours < 12 THEN
      v_value := 0.5;
      v_criteria := v_criteria || jsonb_build_object('geography', 'suspicious_jump');
    ELSIF v_countries_count > 2 AND v_time_span_hours < 24 THEN
      v_value := 0.2;
      v_criteria := v_criteria || jsonb_build_object('geography', 'moderate_jump');
    ELSE
      v_value := 0.0;
      v_criteria := v_criteria || jsonb_build_object('geography', 'normal');
    END IF;

    v_weight := 0.20;
    v_score := v_score + (v_value * v_weight);
    v_criteria := v_criteria || jsonb_build_object('geography_score', v_value);
  END IF;

  -- CRITERION 3: Temporal pattern (20% weight)
  SELECT
    AVG(active_hours),
    COUNT(DISTINCT action_dimension_id_date)
  INTO v_avg_active_hours, v_days_active
  FROM (
    SELECT
      action_dimension_id_date,
      COUNT(DISTINCT action_dimension_id_hour_of_week) as active_hours
    FROM dwh.facts
    WHERE action_dimension_id_user = p_dimension_user_id
      AND action_at > NOW() - INTERVAL '7 days'
    GROUP BY action_dimension_id_date
  ) daily_patterns;

  IF v_avg_active_hours > 20 AND v_days_active >= 5 THEN
    IF v_avg_active_hours > 22 THEN
      v_value := 0.6;
      v_criteria := v_criteria || jsonb_build_object('temporal', 'extreme_24_7');
    ELSIF v_avg_active_hours > 20 THEN
      v_value := 0.4;
      v_criteria := v_criteria || jsonb_build_object('temporal', 'high_24_7');
    ELSE
      v_value := 0.0;
      v_criteria := v_criteria || jsonb_build_object('temporal', 'normal');
    END IF;

    v_weight := 0.20;
    v_score := v_score + (v_value * v_weight);
    v_criteria := v_criteria || jsonb_build_object('temporal_score', v_value);
  END IF;

  -- CRITERION 4: Action distribution (35% weight)
  SELECT
    COUNT(*) FILTER (WHERE action_comment = 'opened'),
    COUNT(*) FILTER (WHERE action_comment = 'commented'),
    COUNT(*) FILTER (WHERE action_comment = 'closed'),
    COUNT(*)
  INTO v_total_opened, v_total_commented, v_total_closed, v_total_actions
  FROM dwh.facts
  WHERE action_dimension_id_user = p_dimension_user_id
    AND action_at > NOW() - INTERVAL '30 days';

  IF v_total_actions > 20 THEN
    v_pct_opened := 100.0 * v_total_opened / v_total_actions;
    v_pct_commented := 100.0 * v_total_commented / v_total_actions;

    IF v_pct_opened > 90 AND v_pct_commented < 5 THEN
      v_value := 0.5;
      v_criteria := v_criteria || jsonb_build_object('action_distribution', 'only_open');
    ELSIF v_pct_opened > 80 AND v_pct_commented < 10 THEN
      v_value := 0.3;
      v_criteria := v_criteria || jsonb_build_object('action_distribution', 'mostly_open');
    ELSE
      v_value := 0.0;
      v_criteria := v_criteria || jsonb_build_object('action_distribution', 'balanced');
    END IF;

    v_weight := 0.35;
    v_score := v_score + (v_value * v_weight);
    v_criteria := v_criteria || jsonb_build_object('action_distribution_score', v_value);
  END IF;

  -- Determine final automation level based on combined score
  IF v_score >= 0.80 THEN
    RETURN QUERY SELECT 5::SMALLINT, 0.90::DECIMAL(3,2), v_criteria;
  ELSIF v_score >= 0.60 THEN
    RETURN QUERY SELECT 4::SMALLINT, 0.70::DECIMAL(3,2), v_criteria;
  ELSIF v_score >= 0.40 THEN
    RETURN QUERY SELECT 3::SMALLINT, 0.50::DECIMAL(3,2), v_criteria;
  ELSIF v_score >= 0.20 THEN
    RETURN QUERY SELECT 2::SMALLINT, 0.70::DECIMAL(3,2), v_criteria;
  ELSE
    RETURN QUERY SELECT 1::SMALLINT, 0.90::DECIMAL(3,2), v_criteria;
  END IF;

END;
$func$;

COMMENT ON FUNCTION dwh.detect_user_automation IS
  'Detects automation patterns for a user based on velocity, geography, temporal patterns, and action distribution';

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating automation update procedures' AS Task;

-- Procedure to update automation levels for modified users
CREATE OR REPLACE PROCEDURE dwh.update_automation_levels_for_modified_users()
LANGUAGE plpgsql
AS $proc$
DECLARE
  rec_user RECORD;
  m_automation_id SMALLINT;
  m_confidence DECIMAL(3,2);
  m_criteria JSONB;
  m_updated_count INTEGER := 0;
BEGIN
  RAISE NOTICE 'Starting automation level detection for modified users...';

  FOR rec_user IN
    SELECT DISTINCT action_dimension_id_user as user_id
    FROM dwh.facts
    WHERE dimension_id_automation IS NULL
      AND action_dimension_id_user IS NOT NULL
      AND action_at > NOW() - INTERVAL '7 days'
    LIMIT 1000
  LOOP
    SELECT automation_id, confidence_score, detection_criteria
    INTO m_automation_id, m_confidence, m_criteria
    FROM dwh.detect_user_automation(rec_user.user_id, 24);

    UPDATE dwh.facts
    SET dimension_id_automation = m_automation_id
    WHERE action_dimension_id_user = rec_user.user_id
      AND dimension_id_automation IS NULL;

    m_updated_count := m_updated_count + 1;

    IF m_updated_count % 100 = 0 THEN
      RAISE NOTICE 'Processing automation levels for % users...', m_updated_count;
    END IF;
  END LOOP;

  RAISE NOTICE 'Completed automation level detection. Processed % users.', m_updated_count;
END;
$proc$;

COMMENT ON PROCEDURE dwh.update_automation_levels_for_modified_users IS
  'Updates automation levels for recently active users';

-- Procedure to update automation level for a specific user
CREATE OR REPLACE PROCEDURE dwh.update_automation_level_for_user(
  p_dimension_user_id INTEGER
)
LANGUAGE plpgsql
AS $proc$
DECLARE
  m_automation_id SMALLINT;
  m_confidence DECIMAL(3,2);
  m_criteria JSONB;
BEGIN
  SELECT automation_id, confidence_score, detection_criteria
  INTO m_automation_id, m_confidence, m_criteria
  FROM dwh.detect_user_automation(p_dimension_user_id, 24);

  UPDATE dwh.facts
  SET dimension_id_automation = m_automation_id
  WHERE action_dimension_id_user = p_dimension_user_id;

  RAISE NOTICE 'Updated automation level % for user %', m_automation_id, p_dimension_user_id;
END;
$proc$;

COMMENT ON PROCEDURE dwh.update_automation_level_for_user IS
  'Updates automation level for a specific user';

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Automation detection system created successfully' AS Task;


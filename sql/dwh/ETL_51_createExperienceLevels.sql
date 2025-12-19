-- Create user experience level system
-- Classifies users by their activity level and contribution patterns
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-24

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating experience levels dimension' AS Task;

-- Create dimension table
CREATE TABLE IF NOT EXISTS dwh.dimension_experience_levels (
  dimension_experience_id SMALLINT PRIMARY KEY,
  experience_level VARCHAR(30) NOT NULL,
  min_notes_opened INTEGER NOT NULL,
  min_notes_closed INTEGER NOT NULL,
  min_days_active INTEGER NOT NULL,
  level_order SMALLINT NOT NULL,
  description TEXT
);

COMMENT ON TABLE dwh.dimension_experience_levels IS
  'User experience level classification based on activity patterns';
COMMENT ON COLUMN dwh.dimension_experience_levels.dimension_experience_id IS
  'Primary key';
COMMENT ON COLUMN dwh.dimension_experience_levels.experience_level IS
  'Level name: newcomer/beginner/intermediate/advanced/expert/master/legend';
COMMENT ON COLUMN dwh.dimension_experience_levels.min_notes_opened IS
  'Minimum notes opened to qualify for this level';
COMMENT ON COLUMN dwh.dimension_experience_levels.min_notes_closed IS
  'Minimum notes closed to qualify for this level';
COMMENT ON COLUMN dwh.dimension_experience_levels.min_days_active IS
  'Minimum days active to qualify for this level';
COMMENT ON COLUMN dwh.dimension_experience_levels.level_order IS
  'Order for sorting (1=newcomer, 7=legend)';
COMMENT ON COLUMN dwh.dimension_experience_levels.description IS
  'Human-readable description';

-- Populate with experience levels
INSERT INTO dwh.dimension_experience_levels (
  dimension_experience_id, experience_level, min_notes_opened,
  min_notes_closed, min_days_active, level_order, description
) VALUES
  (1, 'newcomer', 0, 0, 0, 1, 'First time user'),
  (2, 'beginner', 1, 0, 1, 2, '1-10 notes opened'),
  (3, 'intermediate', 11, 5, 30, 3, '11-50 notes, some closed'),
  (4, 'advanced', 51, 25, 90, 4, '51-200 notes, good resolution rate'),
  (5, 'expert', 201, 100, 180, 5, '200+ notes, active resolver'),
  (6, 'master', 500, 300, 365, 6, '500+ notes, veteran user'),
  (7, 'legend', 1000, 600, 730, 7, '1000+ notes, legendary contributor')
ON CONFLICT (dimension_experience_id) DO NOTHING;

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Adding experience columns to dimension_users' AS Task;

-- Add columns to dimension_users
ALTER TABLE dwh.dimension_users
  ADD COLUMN IF NOT EXISTS experience_level_id SMALLINT,
  ADD COLUMN IF NOT EXISTS total_notes_opened INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_notes_closed INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS days_active INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS resolution_ratio DECIMAL(5,2),
  ADD COLUMN IF NOT EXISTS last_activity_date DATE,
  ADD COLUMN IF NOT EXISTS experience_calculated_at TIMESTAMP;

COMMENT ON COLUMN dwh.dimension_users.experience_level_id IS
  'FK to experience level dimension';
COMMENT ON COLUMN dwh.dimension_users.total_notes_opened IS
  'Total count of notes opened by this user';
COMMENT ON COLUMN dwh.dimension_users.total_notes_closed IS
  'Total count of notes closed by this user';
COMMENT ON COLUMN dwh.dimension_users.days_active IS
  'Number of days between first and last activity';
COMMENT ON COLUMN dwh.dimension_users.resolution_ratio IS
  'Percentage of opened notes that were closed (closed/opened * 100)';
COMMENT ON COLUMN dwh.dimension_users.last_activity_date IS
  'Date of most recent activity';
COMMENT ON COLUMN dwh.dimension_users.experience_calculated_at IS
  'Timestamp when experience level was last calculated';

-- Add foreign key constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_dimension_users_experience'
  ) THEN
    ALTER TABLE dwh.dimension_users
      ADD CONSTRAINT fk_dimension_users_experience
      FOREIGN KEY (experience_level_id)
      REFERENCES dwh.dimension_experience_levels(dimension_experience_id);
  END IF;
END $$;

-- Create index for experience level queries
CREATE INDEX IF NOT EXISTS dimension_users_experience_idx
  ON dwh.dimension_users (experience_level_id)
  WHERE experience_level_id IS NOT NULL;

COMMENT ON INDEX dwh.dimension_users_experience_idx IS
  'Improves queries filtering by experience level';

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating experience calculation function' AS Task;

-- Function to calculate user experience level
CREATE OR REPLACE FUNCTION dwh.calculate_user_experience(
  p_dimension_user_id INTEGER
) RETURNS SMALLINT
LANGUAGE plpgsql
AS $func$
DECLARE
  v_notes_opened INTEGER;
  v_notes_closed INTEGER;
  v_days_active INTEGER;
  v_experience_id SMALLINT;
  v_resolution_ratio DECIMAL(5,2);
  v_last_activity_date DATE;
BEGIN
  -- Calculate user metrics
  SELECT
    COUNT(*) FILTER (WHERE action_comment = 'opened'),
    COUNT(*) FILTER (WHERE action_comment = 'closed'),
    EXTRACT(DAYS FROM MAX(action_at) - MIN(action_at)),
    MAX(action_at)::DATE
  INTO v_notes_opened, v_notes_closed, v_days_active, v_last_activity_date
  FROM dwh.facts
  WHERE action_dimension_id_user = p_dimension_user_id;

  -- Calculate resolution ratio
  IF v_notes_opened > 0 THEN
    -- Calculate ratio and cap at 100 (users can close more notes than they opened)
    v_resolution_ratio := LEAST(ROUND((v_notes_closed::DECIMAL / v_notes_opened * 100), 2), 100.00);
  ELSE
    v_resolution_ratio := 0;
  END IF;

  -- Determine experience level
  SELECT dimension_experience_id INTO v_experience_id
  FROM dwh.dimension_experience_levels
  WHERE v_notes_opened >= min_notes_opened
    AND v_notes_closed >= min_notes_closed
    AND v_days_active >= min_days_active
  ORDER BY level_order DESC
  LIMIT 1;

  -- Default to newcomer if no match
  IF v_experience_id IS NULL THEN
    v_experience_id := 1;
  END IF;

  -- Update dimension_users
  UPDATE dwh.dimension_users SET
    total_notes_opened = v_notes_opened,
    total_notes_closed = v_notes_closed,
    days_active = v_days_active,
    resolution_ratio = v_resolution_ratio,
    last_activity_date = v_last_activity_date,
    experience_level_id = v_experience_id,
    experience_calculated_at = CURRENT_TIMESTAMP
  WHERE dimension_user_id = p_dimension_user_id;

  RETURN v_experience_id;
END;
$func$;

COMMENT ON FUNCTION dwh.calculate_user_experience IS
  'Calculates and updates user experience level based on activity metrics';

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating experience update procedures' AS Task;

-- Procedure to update experience levels for modified users
CREATE OR REPLACE PROCEDURE dwh.update_experience_levels_for_modified_users()
LANGUAGE plpgsql
AS $proc$
DECLARE
  rec_user RECORD;
  m_updated_count INTEGER := 0;
BEGIN
  RAISE NOTICE 'Starting experience level calculation for modified users...';

  FOR rec_user IN
    SELECT DISTINCT dimension_user_id
    FROM dwh.dimension_users
    WHERE modified = TRUE
      AND experience_level_id IS NULL
    LIMIT 1000
  LOOP
    PERFORM dwh.calculate_user_experience(rec_user.dimension_user_id);

    m_updated_count := m_updated_count + 1;

    IF m_updated_count % 100 = 0 THEN
      COMMIT;
      RAISE NOTICE 'Updated experience levels for % users...', m_updated_count;
    END IF;
  END LOOP;

  COMMIT;
  RAISE NOTICE 'Completed experience level calculation. Updated % users.', m_updated_count;
END;
$proc$;

COMMENT ON PROCEDURE dwh.update_experience_levels_for_modified_users IS
  'Updates experience levels for recently modified users';

-- Procedure to update experience level for a specific user
CREATE OR REPLACE PROCEDURE dwh.update_experience_level_for_user(
  p_dimension_user_id INTEGER
)
LANGUAGE plpgsql
AS $proc$
DECLARE
  m_experience_id SMALLINT;
BEGIN
  m_experience_id := dwh.calculate_user_experience(p_dimension_user_id);
  RAISE NOTICE 'Updated experience level % for user %', m_experience_id, p_dimension_user_id;
END;
$proc$;

COMMENT ON PROCEDURE dwh.update_experience_level_for_user IS
  'Updates experience level for a specific user';

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Experience level system created successfully' AS Task;


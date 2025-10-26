-- Populate resolution metrics for existing datamartCountries records
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-26

DO $$
DECLARE
  country_record RECORD;
  avg_resolution DECIMAL(10,2);
  median_resolution DECIMAL(10,2);
  resolved_count INTEGER;
  still_open_count INTEGER;
  resolution_rate DECIMAL(5,2);
BEGIN
  RAISE NOTICE 'Starting to populate resolution metrics for all countries...';

  FOR country_record IN
    SELECT dimension_country_id
    FROM dwh.datamartCountries
  LOOP
    -- Calculate average resolution time
    SELECT COALESCE(AVG(days_to_resolution), 0)
    INTO avg_resolution
    FROM dwh.facts
    WHERE dimension_id_country = country_record.dimension_country_id
      AND days_to_resolution IS NOT NULL
      AND action_comment = 'closed'; -- Only count when closed

    -- Calculate median resolution time using percentile
    SELECT COALESCE(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_resolution), 0)
    INTO median_resolution
    FROM dwh.facts
    WHERE dimension_id_country = country_record.dimension_country_id
      AND days_to_resolution IS NOT NULL
      AND action_comment = 'closed';

    -- Count notes that were resolved (have been closed)
    SELECT COUNT(DISTINCT f1.id_note)
    INTO resolved_count
    FROM dwh.facts f1
    WHERE f1.dimension_id_country = country_record.dimension_country_id
      AND f1.action_comment = 'closed';

    -- Count notes that are still open (opened but never closed)
    SELECT COUNT(DISTINCT f2.id_note)
    INTO still_open_count
    FROM dwh.facts f2
    WHERE f2.dimension_id_country = country_record.dimension_country_id
      AND f2.action_comment = 'opened'
      AND NOT EXISTS (
        SELECT 1
        FROM dwh.facts f3
        WHERE f3.id_note = f2.id_note
          AND f3.action_comment = 'closed'
          AND f3.dimension_id_country = f2.dimension_id_country
      );

    -- Calculate resolution rate (resolved / (resolved + still_open))
    -- Avoid division by zero
    IF (resolved_count + still_open_count) > 0 THEN
      resolution_rate := (resolved_count::DECIMAL / (resolved_count + still_open_count)) * 100;
    ELSE
      resolution_rate := 0;
    END IF;

    -- Update the datamart
    UPDATE dwh.datamartCountries
    SET
      avg_days_to_resolution = avg_resolution,
      median_days_to_resolution = median_resolution,
      notes_resolved_count = resolved_count,
      notes_still_open_count = still_open_count,
      resolution_rate = resolution_rate
    WHERE dimension_country_id = country_record.dimension_country_id;

    -- Log progress every 10 countries
    IF country_record.dimension_country_id % 10 = 0 THEN
      RAISE NOTICE 'Processed country % - avg: %, median: %, resolved: %, open: %, rate: %%',
        country_record.dimension_country_id,
        avg_resolution,
        median_resolution,
        resolved_count,
        still_open_count,
        resolution_rate;
    END IF;
  END LOOP;

  RAISE NOTICE 'Finished populating resolution metrics for all countries';
END $$;

SELECT clock_timestamp() AS Processing,
  'Resolution metrics populated for all countries' AS Task;

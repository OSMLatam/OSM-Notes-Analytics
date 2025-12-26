-- Checks if data warehouse tables exist and are properly initialized.
-- Validates that initial load has been completed successfully.
-- For incremental executions, allows execution if facts exist even if flag is missing.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-25

  DO /* Notes-ETL-checkTables */
  $$
  DECLARE
   qty INT;
   facts_count INT;
   flag_value TEXT;
  BEGIN

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'facts'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.facts.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_users'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_users.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_regions'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_regions.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_countries'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_countries.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_days'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_days.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
    AND TABLE_NAME = 'dimension_time_of_week'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_time_of_week.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_applications'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_applications.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_hashtags'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_hashtags.';
   END IF;

   SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'properties'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.properties.';
   END IF;

   -- Check if initial load flag exists and is either 'true' (in progress) or 'completed' (finished)
   -- For incremental executions, if facts exist, we allow execution even if flag is missing
   -- This handles cases where the flag might not have been set correctly but data exists
   
   -- Check if there are facts in the DWH
   SELECT /* Notes-ETL */ COUNT(1)
    INTO facts_count
   FROM dwh.facts;
   
   -- Get the flag value if it exists
   SELECT /* Notes-ETL */ value
    INTO flag_value
   FROM dwh.properties
   WHERE key = 'initial load'
   LIMIT 1;
   
   -- If facts exist, allow execution even if flag is missing or has unexpected value
   -- This handles incremental executions where flag might not be set correctly
   IF (facts_count > 0) THEN
    -- Facts exist, allow incremental execution
    -- Only warn if flag is missing or has unexpected value
    IF (flag_value IS NULL) THEN
     RAISE WARNING 'Initial load flag is missing, but facts exist in DWH. Proceeding with incremental execution.';
    ELSIF (flag_value NOT IN ('true', 'completed')) THEN
     RAISE WARNING 'Initial load flag has unexpected value: %. Expected ''true'' or ''completed''. Proceeding with incremental execution.', flag_value;
    END IF;
   ELSE
    -- No facts exist, flag must be present and valid
    IF (flag_value IS NULL) THEN
     RAISE EXCEPTION 'Initial load flag is missing and no facts exist in DWH. Cannot proceed.';
    ELSIF (flag_value NOT IN ('true', 'completed')) THEN
     RAISE EXCEPTION 'Previous initial load was not completed correctly. Expected flag with value ''true'' or ''completed'', but found: %', flag_value;
    END IF;
   END IF;
  END;
  $$;

-- Checks if base ingestion tables exist.
-- These tables should be created and populated by OSM-Notes-Ingestion system.
-- Reference: https://github.com/OSM-Notes/OSM-Notes-Ingestion
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-14

DO /* Notes-ETL-checkBaseTables */
$$
DECLARE
 qty INT;
 missing_tables TEXT := '';
BEGIN
 -- Check notes table
 SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
  INTO qty
 FROM INFORMATION_SCHEMA.TABLES
 WHERE TABLE_SCHEMA = 'public'
 AND TABLE_TYPE = 'BASE TABLE'
 AND TABLE_NAME = 'notes'
 ;
 IF (qty <> 1) THEN
  missing_tables := missing_tables || 'public.notes, ';
 END IF;

 -- Check note_comments table
 SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
  INTO qty
 FROM INFORMATION_SCHEMA.TABLES
 WHERE TABLE_SCHEMA = 'public'
 AND TABLE_TYPE = 'BASE TABLE'
 AND TABLE_NAME = 'note_comments'
 ;
 IF (qty <> 1) THEN
  missing_tables := missing_tables || 'public.note_comments, ';
 END IF;

 -- Check note_comments_text table
 SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
  INTO qty
 FROM INFORMATION_SCHEMA.TABLES
 WHERE TABLE_SCHEMA = 'public'
 AND TABLE_TYPE = 'BASE TABLE'
 AND TABLE_NAME = 'note_comments_text'
 ;
 IF (qty <> 1) THEN
  missing_tables := missing_tables || 'public.note_comments_text, ';
 END IF;

 -- Check users table
 SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
  INTO qty
 FROM INFORMATION_SCHEMA.TABLES
 WHERE TABLE_SCHEMA = 'public'
 AND TABLE_TYPE = 'BASE TABLE'
 AND TABLE_NAME = 'users'
 ;
 IF (qty <> 1) THEN
  missing_tables := missing_tables || 'public.users, ';
 END IF;

 -- Check countries table
 SELECT /* Notes-ETL */ COUNT(TABLE_NAME)
  INTO qty
 FROM INFORMATION_SCHEMA.TABLES
 WHERE TABLE_SCHEMA = 'public'
 AND TABLE_TYPE = 'BASE TABLE'
 AND TABLE_NAME = 'countries'
 ;
 IF (qty <> 1) THEN
  missing_tables := missing_tables || 'public.countries, ';
 END IF;

 -- If any table is missing, raise an error with details
 IF (missing_tables <> '') THEN
  -- Remove trailing comma and space
  missing_tables := RTRIM(missing_tables, ', ');
  RAISE EXCEPTION 'Base ingestion tables are missing: %. Please run OSM-Notes-Ingestion system first: https://github.com/OSM-Notes/OSM-Notes-Ingestion', missing_tables;
 END IF;

 -- Verify that tables have data
 SELECT /* Notes-ETL */ COUNT(*)
  INTO qty
 FROM notes
 ;
 IF (qty = 0) THEN
  RAISE WARNING 'Table public.notes exists but has no data. Run ingestion system to populate data.';
 END IF;

 RAISE NOTICE 'Base tables validation passed. Found % notes in database.', qty;
END;
$$;


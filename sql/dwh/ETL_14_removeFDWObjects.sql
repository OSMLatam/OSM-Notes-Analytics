-- Drop Foreign Data Wrapper objects (foreign tables and foreign server).
-- This script removes foreign tables and foreign servers created for incremental ETL processing.
-- It only drops objects if they exist as foreign tables (not regular tables).
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-30

SELECT /* Notes-cleanup */ clock_timestamp() AS Processing,
 'Removing Foreign Data Wrapper objects' AS Task;

-- Drop foreign tables only if they exist as foreign tables
-- This ensures we don't accidentally drop regular tables with the same names
DO $$
BEGIN
 -- Drop foreign table: note_comments (only if it's a foreign table)
 IF EXISTS (SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'note_comments') THEN
  DROP FOREIGN TABLE IF EXISTS public.note_comments CASCADE;
  RAISE NOTICE 'Dropped foreign table: public.note_comments';
 END IF;

 -- Drop foreign table: notes (only if it's a foreign table)
 IF EXISTS (SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'notes') THEN
  DROP FOREIGN TABLE IF EXISTS public.notes CASCADE;
  RAISE NOTICE 'Dropped foreign table: public.notes';
 END IF;

 -- Drop foreign table: note_comments_text (only if it's a foreign table)
 IF EXISTS (SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'note_comments_text') THEN
  DROP FOREIGN TABLE IF EXISTS public.note_comments_text CASCADE;
  RAISE NOTICE 'Dropped foreign table: public.note_comments_text';
 END IF;

 -- Drop foreign table: users (only if it's a foreign table)
 IF EXISTS (SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'users') THEN
  DROP FOREIGN TABLE IF EXISTS public.users CASCADE;
  RAISE NOTICE 'Dropped foreign table: public.users';
 END IF;

 -- Drop foreign table: countries (only if it's a foreign table)
 IF EXISTS (SELECT 1 FROM information_schema.foreign_tables WHERE foreign_table_schema = 'public' AND foreign_table_name = 'countries') THEN
  DROP FOREIGN TABLE IF EXISTS public.countries CASCADE;
  RAISE NOTICE 'Dropped foreign table: public.countries';
 END IF;
END $$;

-- Drop foreign server (this will also drop user mappings)
DROP SERVER IF EXISTS ingestion_server CASCADE;

SELECT /* Notes-cleanup */ clock_timestamp() AS Processing,
 'Foreign Data Wrapper objects removed' AS Task;

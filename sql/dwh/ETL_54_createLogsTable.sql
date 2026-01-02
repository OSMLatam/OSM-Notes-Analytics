-- Creates logs table for debugging dynamic SQL queries in datamart procedures.
-- This table is only needed when Ingestion and Analytics databases are different.
-- Used by datamartCountries and datamartUsers procedures for debugging.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2026-01-01

CREATE TABLE IF NOT EXISTS dwh.logs (
  log_id BIGSERIAL PRIMARY KEY,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_logs_created_at 
  ON dwh.logs(created_at DESC);

-- Comments
COMMENT ON TABLE dwh.logs IS
  'Debugging logs for dynamic SQL queries in datamart procedures. Only used when Ingestion and Analytics databases are different.';

COMMENT ON COLUMN dwh.logs.log_id IS
  'Primary key for log entries';

COMMENT ON COLUMN dwh.logs.message IS
  'SQL statement or debug message being logged';

COMMENT ON COLUMN dwh.logs.created_at IS
  'Timestamp when the log entry was created';

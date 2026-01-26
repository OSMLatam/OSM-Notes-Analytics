---
title: "Real-Time Streaming Analytics Implementation Plan"
description: "Future enhancement plan for real-time streaming analytics implementation in OSM Notes Analytics (LOW Priority)"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "streaming"
audience:
  - "developers"
project: "OSM-Notes-Analytics"
status: "active"
---


# Real-Time Streaming Analytics Implementation Plan

**Version**: 1.0  
**Status**: Future Enhancement (LOW Priority)  
**Author**: OSM-Notes-Analytics Team

---

## Executive Summary

This document outlines a plan to implement real-time streaming analytics for the OSM Notes Analytics
system using a **pure Bash approach with event queue table**. This would enable near-instantaneous
processing of notes as they arrive, reducing latency from the current 15 minutes to seconds.

**Current State**:

- Ingestion: Daemon runs every minute
- ETL: Runs every 15 minutes
- **Latency**: ~15 minutes maximum

**Proposed State**:

- Ingestion: Daemon runs every minute + trigger writes to event queue
- Streaming Processor: Polls event queue and processes immediately (pure Bash)
- **Latency**: 2-5 seconds (polling interval)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Event Queue Mechanism](#event-queue-mechanism)
4. [Implementation Details](#implementation-details)
5. [Code Examples](#code-examples)
6. [Integration Points](#integration-points)
7. [Performance Considerations](#performance-considerations)
8. [Error Handling and Resilience](#error-handling-and-resilience)
9. [Monitoring and Observability](#monitoring-and-observability)
10. [Migration Strategy](#migration-strategy)
11. [Testing Strategy](#testing-strategy)
12. [Cost-Benefit Analysis](#cost-benefit-analysis)

---

## Overview

### Current Architecture

```
OSM API → Ingestion Daemon (every 1 min) → Base Tables → ETL (every 15 min) → DWH
```

**Latency**: Up to 15 minutes from note creation to DWH availability

### Proposed Architecture

```
OSM API → Ingestion Daemon (every 1 min) → Base Tables → Trigger → Event Queue
                                                                    ↓
                                              Streaming Processor (Polling, Bash)
                                                                    ↓
                                                                  DWH (real-time)
```

**Latency**: 2-5 seconds from note creation to DWH availability (polling interval)

### Key Benefits

1. **Reduced Latency**: Notes appear in analytics within seconds
2. **Better User Experience**: Real-time dashboards and alerts
3. **Event-Driven**: Processes only when new data arrives
4. **Efficient**: Uses native PostgreSQL features (no external message queue needed)
5. **Scalable**: Can handle bursts of activity

### Trade-offs

1. **Complexity**: Additional service to maintain
2. **Resource Usage**: Continuous connection to database
3. **Error Recovery**: More complex failure scenarios
4. **Testing**: More complex testing requirements

---

## Architecture

### High-Level Architecture

```mermaid
graph TB
    subgraph "OSM-Notes-Ingestion"
        API[OSM API]
        DAEMON[Ingestion Daemon<br/>Every 1 minute]
        BASE[Base Tables<br/>public.notes<br/>public.note_comments]
    end

    subgraph "PostgreSQL"
        TRIGGER[Database Trigger<br/>AFTER INSERT]
        QUEUE[Event Queue Table<br/>dwh.note_event_queue]
    end

    subgraph "OSM-Notes-Analytics"
        POLLER[Streaming Processor<br/>Polling daemon (Bash)]
        ETL[Micro-ETL<br/>Process single note]
        DWH[DWH Schema<br/>dwh.facts]
        DATAMART[Datamarts<br/>Incremental update]
    end

    API --> DAEMON
    DAEMON --> BASE
    BASE --> TRIGGER
    TRIGGER --> QUEUE
    QUEUE --> POLLER
    POLLER --> ETL
    ETL --> DWH
    DWH --> DATAMART
```

### Component Details

#### 1. Database Trigger (Ingestion Side)

A PostgreSQL trigger that writes events to the queue table when new notes or comments are inserted:

```sql
CREATE OR REPLACE FUNCTION notify_note_insert()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO dwh.note_event_queue (
        note_id, sequence_action, event_type, payload, status
    ) VALUES (
        NEW.note_id,
        NEW.sequence_action,
        NEW.event,
        jsonb_build_object(
            'note_id', NEW.note_id,
            'sequence_action', NEW.sequence_action,
            'event', NEW.event,
            'created_at', NEW.created_at
        ),
        'pending'
    )
    ON CONFLICT (note_id, sequence_action, status) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER note_insert_notify
    AFTER INSERT ON public.note_comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_note_insert();
```

#### 2. Streaming Processor (Analytics Side)

A pure Bash daemon process that:

- Polls the event queue table periodically (every 2-5 seconds)
- Processes pending events in batches
- Marks events as processed or failed
- Handles errors and retries

#### 3. Micro-ETL

A lightweight ETL process that:

- Processes a single note/comment
- Updates dimensions if needed
- Inserts fact row
- Updates affected datamarts incrementally

---

## PostgreSQL Event Queue Mechanism

### Approach: Event Table + Polling (Pure Bash)

Since the project uses primarily Bash and we want to avoid Python dependencies, we'll use a **hybrid
approach**:

1. **Event Table**: Database trigger writes events to a queue table
2. **Polling**: Bash script polls the table periodically
3. **Processing**: Process events and mark them as processed

### Advantages

- **Pure Bash**: No external dependencies (Python, etc.)
- **Simple**: Easy to understand and maintain
- **Reliable**: Events are persisted in database
- **Resilient**: Can recover from failures (events remain in queue)
- **Acknowledgment**: Built-in delivery confirmation via status column

### Trade-offs

- **Latency**: Slight delay due to polling interval (1-5 seconds)
- **Polling Overhead**: Periodic database queries
- **Still Real-time**: For practical purposes, 1-5 second latency is near real-time

### Alternative: LISTEN/NOTIFY with psql (Possible but Complex)

PostgreSQL's LISTEN/NOTIFY **does NOT require Python** - it's a native PostgreSQL feature. However,
using it from Bash is complex:

**Option 1: LISTEN/NOTIFY with psql (Complex)**

```bash
# This is possible but requires:
# 1. Running psql in background
# 2. Parsing psql output for notifications
# 3. Complex signal/process handling
# 4. Less reliable (notifications can be lost)

psql -d "${DBNAME}" <<EOF &
LISTEN note_inserted;
\watch 1
EOF

# Parse output for notifications - complex!
```

**Option 2: Event Table (Recommended)**

- Simpler implementation
- More reliable (events persist)
- Easier to debug
- Better error handling

**Recommendation**: Use event table approach for simplicity and reliability, even though
LISTEN/NOTIFY is technically possible in Bash.

### Channel Design

We'll use multiple channels for different event types:

```sql
-- New note comment inserted
'note_inserted'

-- Note status changed (opened/closed/reopened)
'note_status_changed'

-- Bulk import completed (for initial loads)
'bulk_import_completed'
```

### Notification Payload Format

JSON structure for `note_inserted`:

```json
{
  "note_id": 12345,
  "sequence_action": 1,
  "event": "opened",
  "created_at": "2025-01-21T10:30:00Z",
  "id_user": 67890,
  "id_country": 42
}
```

---

## Implementation Details

### Phase 1: Database Setup (Ingestion Side)

#### Step 1.1: Create Notification Function

```sql
-- File: sql/ingestion/notify_note_insert.sql
-- This should be added to OSM-Notes-Ingestion project

CREATE OR REPLACE FUNCTION public.notify_note_insert()
RETURNS TRIGGER AS $$
DECLARE
    v_payload JSONB;
BEGIN
    -- Build notification payload
    v_payload := jsonb_build_object(
        'note_id', NEW.note_id,
        'sequence_action', NEW.sequence_action,
        'event', NEW.event,
        'created_at', NEW.created_at::text,
        'id_user', NEW.id_user,
        'table_name', TG_TABLE_NAME
    );

    -- Send notification
    PERFORM pg_notify('note_inserted', v_payload::text);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.notify_note_insert() IS
    'Sends NOTIFY to note_inserted channel when new note comments are inserted';
```

#### Step 1.2: Create Trigger

```sql
-- File: sql/ingestion/create_note_notify_trigger.sql

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS note_insert_notify ON public.note_comments;

-- Create trigger
CREATE TRIGGER note_insert_notify
    AFTER INSERT ON public.note_comments
    FOR EACH ROW
    WHEN (NEW.event IN ('opened', 'closed', 'reopened', 'commented'))
    EXECUTE FUNCTION public.notify_note_insert();

COMMENT ON TRIGGER note_insert_notify ON public.note_comments IS
    'Notifies analytics system when new note events occur';
```

#### Step 1.3: Enable Notifications (Optional Configuration)

```sql
-- Check if notifications are enabled
SHOW max_listener_connections;

-- Default is usually sufficient, but can be increased if needed
-- ALTER SYSTEM SET max_listener_connections = 100;
```

### Phase 2: Event Queue Table Setup

#### Step 2.1: Create Event Queue Table

```sql
-- File: sql/dwh/streaming/create_event_queue.sql

-- Create event queue table for streaming processing
CREATE TABLE IF NOT EXISTS dwh.note_event_queue (
    event_id BIGSERIAL PRIMARY KEY,
    note_id BIGINT NOT NULL,
    sequence_action INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0,
    UNIQUE (note_id, sequence_action, status)
);

-- Index for efficient polling
CREATE INDEX IF NOT EXISTS idx_note_event_queue_status_created
    ON dwh.note_event_queue(status, created_at)
    WHERE status = 'pending';

-- Index for cleanup
CREATE INDEX IF NOT EXISTS idx_note_event_queue_processed
    ON dwh.note_event_queue(processed_at)
    WHERE status = 'processed';

COMMENT ON TABLE dwh.note_event_queue IS
    'Queue table for streaming note processing. Events are inserted by trigger and processed by streaming processor.';

COMMENT ON COLUMN dwh.note_event_queue.status IS
    'Status: pending, processing, processed, failed';
```

#### Step 2.2: Update Trigger to Write to Queue

```sql
-- File: sql/ingestion/create_note_notify_trigger.sql
-- Updated to write to event queue instead of NOTIFY

CREATE OR REPLACE FUNCTION public.notify_note_insert()
RETURNS TRIGGER AS $$
DECLARE
    v_payload JSONB;
BEGIN
    -- Build notification payload
    v_payload := jsonb_build_object(
        'note_id', NEW.note_id,
        'sequence_action', NEW.sequence_action,
        'event', NEW.event,
        'created_at', NEW.created_at::text,
        'id_user', NEW.id_user,
        'table_name', TG_TABLE_NAME
    );

    -- Insert into event queue (if analytics DB is accessible)
    -- This requires dblink or FDW to access analytics DB
    -- Alternative: Write to local table, streaming processor reads via FDW

    -- For same database, direct insert:
    INSERT INTO dwh.note_event_queue (
        note_id,
        sequence_action,
        event_type,
        payload,
        status
    ) VALUES (
        NEW.note_id,
        NEW.sequence_action,
        NEW.event,
        v_payload,
        'pending'
    )
    ON CONFLICT (note_id, sequence_action, status)
    DO UPDATE SET
        payload = EXCLUDED.payload,
        created_at = EXCLUDED.created_at,
        retry_count = 0;

    -- Also send NOTIFY for optional real-time listeners
    PERFORM pg_notify('note_inserted', v_payload::text);

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- If analytics schema doesn't exist, just send NOTIFY
        PERFORM pg_notify('note_inserted', v_payload::text);
        RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Phase 3: Streaming Processor (Pure Bash)

#### Step 3.1: Create Streaming Processor Script (Pure Bash)

```bash
#!/bin/bash
# File: bin/dwh/streaming_processor.sh

# Streaming processor for real-time note processing using event queue polling
# Pure Bash implementation - no Python dependencies

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../etc/properties.sh" || exit 1
source "${SCRIPT_DIR}/../../lib/osm-common/logging.sh" || exit 1

# Configuration
POLL_INTERVAL=2  # seconds between polls
BATCH_SIZE=10
MAX_RETRIES=3
PROCESSING_TIMEOUT=300  # 5 minutes per event

# Logging
LOG_DIR="${LOG_DIR:-/tmp/streaming_processor}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/streaming_processor_$(date +%Y%m%d_%H%M%S).log"

__log_start() {
    __logi "Starting streaming processor..."
    __logi "Poll interval: ${POLL_INTERVAL}s, Batch size: ${BATCH_SIZE}"
}

__log_event() {
    local event_id=$1
    local note_id=$2
    __logi "Processing event_id=${event_id}, note_id=${note_id}"
}

__log_error() {
    __loge "$1"
}

__log_finish() {
    __logi "Streaming processor stopped."
}

# Mark event as processing
mark_event_processing() {
    local event_id=$1
    psql -d "${DBNAME_DWH}" -v ON_ERROR_STOP=1 -t -A <<EOF
        UPDATE dwh.note_event_queue
        SET status = 'processing',
            processed_at = NOW()
        WHERE event_id = ${event_id}
          AND status = 'pending'
        RETURNING event_id;
EOF
}

# Mark event as processed
mark_event_processed() {
    local event_id=$1
    psql -d "${DBNAME_DWH}" -v ON_ERROR_STOP=1 -t -A <<EOF
        UPDATE dwh.note_event_queue
        SET status = 'processed',
            processed_at = NOW()
        WHERE event_id = ${event_id};
EOF
}

# Mark event as failed
mark_event_failed() {
    local event_id=$1
    local error_msg=$2
    psql -d "${DBNAME_DWH}" -v ON_ERROR_STOP=1 -t -A <<EOF
        UPDATE dwh.note_event_queue
        SET status = 'failed',
            error_message = '${error_msg}',
            retry_count = retry_count + 1,
            processed_at = NOW()
        WHERE event_id = ${event_id};
EOF
}

# Process a single event
process_event() {
    local event_id=$1
    local note_id=$2
    local sequence_action=$3
    local event_type=$4

    __log_event "${event_id}" "${note_id}"

    # Call micro-ETL to process this note
    if "${SCRIPT_DIR}/micro_etl.sh" \
        --note-id "${note_id}" \
        --sequence-action "${sequence_action}" \
        --event-type "${event_type}" \
        2>&1 | tee -a "${LOG_FILE}"; then
        mark_event_processed "${event_id}"
        return 0
    else
        local error_msg="Processing failed for note_id=${note_id}, sequence=${sequence_action}"
        mark_event_failed "${event_id}" "${error_msg}"
        return 1
    fi
}

# Get pending events
get_pending_events() {
    psql -d "${DBNAME_DWH}" -v ON_ERROR_STOP=1 -t -A -F'|' <<EOF
        SELECT
            event_id,
            note_id,
            sequence_action,
            event_type,
            payload::text
        FROM dwh.note_event_queue
        WHERE status = 'pending'
        ORDER BY created_at ASC
        LIMIT ${BATCH_SIZE}
        FOR UPDATE SKIP LOCKED;
EOF
}

# Reset stuck events (processing for too long)
reset_stuck_events() {
    psql -d "${DBNAME_DWH}" -v ON_ERROR_STOP=1 <<EOF
        UPDATE dwh.note_event_queue
        SET status = 'pending',
            processed_at = NULL
        WHERE status = 'processing'
          AND processed_at < NOW() - INTERVAL '${PROCESSING_TIMEOUT} seconds'
          AND retry_count < ${MAX_RETRIES};
EOF
}

# Main polling loop
poll_loop() {
    __log_start

    while true; do
        # Reset stuck events
        reset_stuck_events

        # Get pending events
        local events
        events=$(get_pending_events) || {
            __log_error "Failed to get pending events"
            sleep ${POLL_INTERVAL}
            continue
        }

        # Process events if any
        if [ -n "${events}" ]; then
            local processed_count=0
            local failed_count=0

            while IFS='|' read -r event_id note_id sequence_action event_type payload; do
                # Mark as processing
                if mark_event_processing "${event_id}" > /dev/null 2>&1; then
                    # Process event
                    if process_event "${event_id}" "${note_id}" "${sequence_action}" "${event_type}"; then
                        ((processed_count++))
                    else
                        ((failed_count++))
                    fi
                fi
            done <<< "${events}"

            if [ ${processed_count} -gt 0 ] || [ ${failed_count} -gt 0 ]; then
                __logi "Processed: ${processed_count}, Failed: ${failed_count}"
            fi
        fi

        # Sleep before next poll
        sleep ${POLL_INTERVAL}
    done
}

# Signal handling
trap '__log_finish; exit 0' SIGTERM SIGINT

# Start polling
poll_loop
```

#### Step 3.2: Cleanup Old Events (Optional)

```bash
#!/bin/bash
# File: bin/dwh/cleanup_event_queue.sh

# Cleanup old processed events from queue table

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../etc/properties.sh" || exit 1

# Keep events for 7 days
RETENTION_DAYS=7

psql -d "${DBNAME_DWH}" -v ON_ERROR_STOP=1 <<EOF
    DELETE FROM dwh.note_event_queue
    WHERE status = 'processed'
      AND processed_at < NOW() - INTERVAL '${RETENTION_DAYS} days';

    -- Also cleanup old failed events (keep for 30 days)
    DELETE FROM dwh.note_event_queue
    WHERE status = 'failed'
      AND processed_at < NOW() - INTERVAL '30 days';
EOF

echo "Event queue cleanup completed"
```

#### Step 3.3: Batch Processing Script (Optional - for efficiency)

```bash
#!/bin/bash
# File: bin/dwh/process_batch.sh

# Process a batch of events (optional - for batch processing mode)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../etc/properties.sh" || exit 1

# Get batch of events from queue
BATCH_SIZE="${1:-10}"

psql -d "${DBNAME_DWH}" -v ON_ERROR_STOP=1 -t -A -F'|' <<EOF | while IFS='|' read -r event_id note_id sequence_action event_type; do
    SELECT
        event_id,
        note_id,
        sequence_action,
        event_type
    FROM dwh.note_event_queue
    WHERE status = 'pending'
    ORDER BY created_at ASC
    LIMIT ${BATCH_SIZE}
    FOR UPDATE SKIP LOCKED;
EOF
    if [ -n "${event_id}" ]; then
        "${SCRIPT_DIR}/micro_etl.sh" \
            --note-id "${note_id}" \
            --sequence-action "${sequence_action}" \
            --event-type "${event_type}"
    fi
done
```

#### Step 2.4: Micro-ETL Script

```bash
#!/bin/bash
# File: bin/dwh/micro_etl.sh

# Micro-ETL: Process a single note/comment in real-time

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../etc/properties.sh" || exit 1

# Parse arguments
NOTE_ID=""
SEQUENCE_ACTION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --note-id)
            NOTE_ID="$2"
            shift 2
            ;;
        --sequence-action)
            SEQUENCE_ACTION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "${NOTE_ID}" ] || [ -z "${SEQUENCE_ACTION}" ]; then
    echo "ERROR: --note-id and --sequence-action are required"
    exit 1
fi

# Process single note using SQL procedure
psql -d "${DBNAME_DWH}" -v ON_ERROR_STOP=1 <<EOF
-- Process single note into DWH
CALL dwh.process_single_note(
    p_note_id := ${NOTE_ID},
    p_sequence_action := ${SEQUENCE_ACTION}
);
EOF
```

### Phase 3: SQL Procedures for Micro-ETL

#### Step 3.1: Create Single Note Processing Procedure

```sql
-- File: sql/dwh/streaming/process_single_note.sql

CREATE OR REPLACE PROCEDURE dwh.process_single_note(
    p_note_id BIGINT,
    p_sequence_action INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_note_record RECORD;
    v_dimension_keys RECORD;
    v_fact_id BIGINT;
BEGIN
    -- Get note data from base tables
    SELECT
        c.note_id,
        c.sequence_action,
        c.event AS action_comment,
        c.id_user AS action_id_user,
        c.created_at AS action_at,
        n.created_at AS note_created_at,
        n.id_user AS created_id_user,
        n.id_country,
        n.latitude,
        n.longitude,
        t.body AS comment_text
    INTO v_note_record
    FROM public.note_comments c
    JOIN public.notes n ON c.note_id = n.note_id
    LEFT JOIN public.note_comments_text t
        ON c.note_id = t.note_id
        AND c.sequence_action = t.sequence_action
    WHERE c.note_id = p_note_id
      AND c.sequence_action = p_sequence_action;

    -- If note not found, raise error
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Note % sequence % not found', p_note_id, p_sequence_action;
    END IF;

    -- Resolve dimension keys
    SELECT
        dwh.get_or_create_user_dimension(v_note_record.action_id_user) AS action_user_id,
        dwh.get_or_create_user_dimension(v_note_record.created_id_user) AS created_user_id,
        dwh.get_or_create_country_dimension(v_note_record.id_country) AS country_id,
        dwh.get_or_create_date_dimension(v_note_record.action_at::DATE) AS action_date_id,
        dwh.get_or_create_date_dimension(v_note_record.note_created_at::DATE) AS opened_date_id,
        dwh.get_or_create_application_dimension(
            COALESCE((v_note_record.comment_text::jsonb->>'created_by'), 'unknown')
        ) AS application_id
    INTO v_dimension_keys;

    -- Calculate metrics
    DECLARE
        v_comment_length INTEGER := COALESCE(LENGTH(v_note_record.comment_text), 0);
        v_has_url BOOLEAN := v_note_record.comment_text LIKE '%http%';
        v_has_mention BOOLEAN := v_note_record.comment_text LIKE '%@%';
    BEGIN
        -- Insert fact row
        INSERT INTO dwh.facts (
            id_note,
            sequence_action,
            action_comment,
            opened_dimension_id_date,
            opened_dimension_id_user,
            dimension_id_country,
            dimension_id_application_creation,
            action_dimension_id_date,
            action_dimension_id_user,
            action_at,
            comment_length,
            has_url,
            has_mention
        ) VALUES (
            v_note_record.note_id,
            v_note_record.sequence_action,
            v_note_record.action_comment,
            v_dimension_keys.opened_date_id,
            v_dimension_keys.created_user_id,
            v_dimension_keys.country_id,
            v_dimension_keys.application_id,
            v_dimension_keys.action_date_id,
            v_dimension_keys.action_user_id,
            v_note_record.action_at,
            v_comment_length,
            v_has_url,
            v_has_mention
        )
        ON CONFLICT (id_note, sequence_action) DO UPDATE SET
            action_comment = EXCLUDED.action_comment,
            action_at = EXCLUDED.action_at,
            comment_length = EXCLUDED.comment_length,
            has_url = EXCLUDED.has_url,
            has_mention = EXCLUDED.has_mention;

        -- Update affected datamarts incrementally
        -- (This would call incremental update procedures)
        PERFORM dwh.update_datamart_country_incremental(v_dimension_keys.country_id);
        PERFORM dwh.update_datamart_user_incremental(v_dimension_keys.action_user_id);

    END;

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
$$;

COMMENT ON PROCEDURE dwh.process_single_note IS
    'Processes a single note/comment into DWH in real-time';
```

---

## Integration Points

### Integration with Existing ETL

The streaming processor should work alongside the existing batch ETL:

1. **Streaming**: Handles real-time processing for immediate availability
2. **Batch ETL**: Continues to run every 15 minutes as a safety net
3. **Idempotency**: Both systems can process the same note safely (ON CONFLICT handling)

### Integration with Ingestion System

The trigger should be added to the OSM-Notes-Ingestion project:

1. **Minimal Changes**: Only add trigger, no changes to ingestion logic
2. **Optional**: Can be enabled/disabled via configuration
3. **Backward Compatible**: Doesn't affect existing ingestion functionality

---

## Performance Considerations

### Database Connection Management

- **Persistent Connection**: Streaming processor maintains one connection
- **Connection Pooling**: Consider using pgbouncer for connection management
- **Resource Limits**: Monitor connection count and adjust `max_listener_connections` if needed

### Batch Processing

- **Batch Size**: Process notifications in batches (default: 10)
- **Batch Timeout**: Process batch after timeout even if not full (default: 5 seconds)
- **Parallel Processing**: Can run multiple streaming processors for different channels

### Database Load

- **Trigger Overhead**: Minimal (just JSON building and NOTIFY)
- **Micro-ETL Load**: Similar to batch ETL but for single notes
- **Monitoring**: Track processing time and database load

### Scalability

- **Horizontal Scaling**: Can run multiple streaming processors
- **Channel Partitioning**: Use different channels for different regions/types
- **Load Balancing**: Distribute notifications across processors

---

## Error Handling and Resilience

### Connection Failures

- **Automatic Reconnection**: Retry with exponential backoff
- **Max Retries**: Limit reconnection attempts before alerting
- **Health Checks**: Periodic health check queries

### Processing Failures

- **Retry Logic**: Retry failed notifications with backoff
- **Dead Letter Queue**: Store failed notifications for manual review
- **Error Logging**: Comprehensive error logging with context

### Data Consistency

- **Idempotency**: Same note can be processed multiple times safely
- **Transaction Safety**: Use transactions for atomic operations
- **Conflict Resolution**: Handle ON CONFLICT scenarios gracefully

### Example Error Handling

```bash
# In streaming_processor.sh

# Process event with retry logic
process_event_with_retry() {
    local event_id=$1
    local note_id=$2
    local sequence_action=$3
    local max_retries=3
    local attempt=0

    while [ ${attempt} -lt ${max_retries} ]; do
        if process_event "${event_id}" "${note_id}" "${sequence_action}"; then
            return 0
        fi

        attempt=$((attempt + 1))
        if [ ${attempt} -lt ${max_retries} ]; then
            local backoff=$((2 ** attempt))
            __logi "Retrying event_id=${event_id} in ${backoff} seconds (attempt ${attempt}/${max_retries})"
            sleep ${backoff}
        fi
    done

    # Max retries reached, mark as failed
    mark_event_failed "${event_id}" "Max retries (${max_retries}) exceeded"
    return 1
}
```

---

## Monitoring and Observability

### Metrics to Track

1. **Notification Rate**: Notifications received per minute
2. **Processing Rate**: Notes processed per minute
3. **Latency**: Time from notification to DWH availability
4. **Error Rate**: Failed processing attempts
5. **Connection Status**: Uptime and reconnection events
6. **Batch Statistics**: Average batch size and processing time

### Logging

- **Structured Logging**: JSON format for easy parsing
- **Log Levels**: DEBUG, INFO, WARN, ERROR
- **Context**: Include note_id, sequence_action, timestamps

### Health Checks

```bash
#!/bin/bash
# File: bin/dwh/check_streaming_health.sh

# Check if streaming processor is healthy

DBNAME="${DBNAME_DWH}"

# Check pending events count
psql -d "${DBNAME}" -t -A -c "
    SELECT COUNT(*) as pending_events
    FROM dwh.note_event_queue
    WHERE status = 'pending';
"

# Check processing events (should be low)
psql -d "${DBNAME}" -t -A -c "
    SELECT COUNT(*) as processing_events
    FROM dwh.note_event_queue
    WHERE status = 'processing';
"

# Check recent processing rate
psql -d "${DBNAME}" -t -A -c "
    SELECT
        COUNT(*) as processed_last_5min,
        MAX(processed_at) as last_processed
    FROM dwh.note_event_queue
    WHERE status = 'processed'
      AND processed_at > NOW() - INTERVAL '5 minutes';
"

# Check for stuck events
psql -d "${DBNAME}" -t -A -c "
    SELECT COUNT(*) as stuck_events
    FROM dwh.note_event_queue
    WHERE status = 'processing'
      AND processed_at < NOW() - INTERVAL '10 minutes';
"
```

### Alerting

- **Queue Backlog**: Alert if pending events > 100
- **High Error Rate**: Alert if failed events > 5% of processed
- **Processing Lag**: Alert if oldest pending event > 5 minutes
- **Stuck Events**: Alert if processing events > 10
- **Processor Down**: Alert if no events processed in last 10 minutes

---

## Migration Strategy

### Phase 1: Setup (Week 1)

1. Add trigger to Ingestion system (optional, can be disabled)
2. Create streaming processor infrastructure
3. Test in development environment

### Phase 2: Pilot (Week 2)

1. Enable streaming for subset of notes (e.g., specific country)
2. Run in parallel with batch ETL
3. Monitor performance and errors

### Phase 3: Gradual Rollout (Week 3-4)

1. Enable streaming for all notes
2. Keep batch ETL as safety net
3. Monitor for issues

### Phase 4: Optimization (Week 5+)

1. Tune batch sizes and timeouts
2. Optimize micro-ETL procedures
3. Consider reducing batch ETL frequency

### Rollback Plan

- **Disable Trigger**: Set trigger to disabled state
- **Stop Processor**: Gracefully shutdown streaming processor
- **Rely on Batch**: Batch ETL continues to work normally

---

## Testing Strategy

### Unit Tests

- Test notification parsing
- Test micro-ETL procedure with sample data
- Test error handling and retries

### Integration Tests

- Test full flow: Ingestion → NOTIFY → LISTEN → Process
- Test batch processing
- Test reconnection logic

### Load Tests

- Test with high notification rate
- Test with burst of notifications
- Test database connection limits

### Example Test

```bash
#!/bin/bash
# File: tests/integration/streaming_processor.test.bats

@test "Streaming processor processes notification" {
    # Insert test note
    psql -d "${TEST_DBNAME}" -c "
        INSERT INTO public.note_comments (note_id, sequence_action, event, id_user, created_at)
        VALUES (999999, 1, 'opened', 1, NOW());
    "

    # Wait for processing
    sleep 2

    # Verify fact was created
    run psql -d "${TEST_DBNAME}" -t -c "
        SELECT COUNT(*) FROM dwh.facts WHERE id_note = 999999;
    "

    [ "$output" -eq 1 ]
}
```

---

## Cost-Benefit Analysis

### Benefits

1. **Reduced Latency**: 15 minutes → seconds
2. **Better UX**: Real-time dashboards and alerts
3. **Event-Driven**: More efficient resource usage
4. **Scalability**: Can handle bursts better

### Costs

1. **Development**: ~20 hours initial development
2. **Maintenance**: Ongoing monitoring and maintenance
3. **Complexity**: Additional system to manage
4. **Resources**: Persistent database connection

### ROI

- **High Value**: For use cases requiring real-time data
- **Low Value**: For batch analytics that don't need real-time
- **Recommendation**: Implement if real-time is a requirement, otherwise current system is
  sufficient

---

## Conclusion

The LISTEN/NOTIFY approach provides a native, efficient way to implement real-time streaming
analytics without external dependencies. While it adds complexity, it offers significant benefits
for use cases requiring low-latency data availability.

**Recommendation**:

- **Priority**: LOW (current 15-minute latency is acceptable for most use cases)
- **Implementation**: Consider if real-time requirements emerge
- **Alternative**: Could reduce batch ETL frequency to 5 minutes as simpler alternative

---

## References

- [PostgreSQL LISTEN/NOTIFY Documentation](https://www.postgresql.org/docs/current/sql-notify.html)
- [psycopg2 Async Notifications](https://www.psycopg.org/docs/advanced.html#asynchronous-notifications)
- [Event-Driven Architecture Patterns](https://martinfowler.com/articles/201701-event-driven.html)

---

**Next Review**: When real-time requirements are identified

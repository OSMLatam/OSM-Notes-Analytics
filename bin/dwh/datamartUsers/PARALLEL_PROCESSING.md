# Parallel Processing with Intelligent Prioritization - DatamartUsers

## Overview

The datamart user processing system implements an **intelligent prioritization** scheme that processes the most relevant users first, followed by parallel processing to maximize performance. This ensures that active user data is available quickly, even when there are thousands of modified users.

## Problem Solved

**Before:** Sequential processing without prioritization resulted in:
- Days of processing without completion
- Active users waiting hours/days for updated data
- Inactive users consuming valuable resources

**Now:** With intelligent prioritization and parallel processing:
- Active users processed in minutes
- Fresh data available quickly for queries
- Inactive users processed in background without affecting active users

## Prioritization System

### 6-Level Criteria

The system orders users using multiple cascading criteria:

#### **Level 1: Activity Recency** (Primary Criterion)

```sql
CASE 
  WHEN MAX(f.action_at) >= CURRENT_DATE - INTERVAL '7 days' THEN 1   -- CRITICAL
  WHEN MAX(f.action_at) >= CURRENT_DATE - INTERVAL '30 days' THEN 2  -- HIGH
  WHEN MAX(f.action_at) >= CURRENT_DATE - INTERVAL '90 days' THEN 3 -- MEDIUM
  ELSE 4                                                              -- LOW/LOWEST
END
```

- **CRITICAL (1):** Users with activity in last 7 days
- **HIGH (2):** Users with activity in last 30 days
- **MEDIUM (3):** Users with activity in last 90 days
- **LOW/LOWEST (4):** Users without recent activity

#### **Level 2: Historical Activity** (Secondary Criterion)

```sql
CASE 
  WHEN COUNT(*) > 100 THEN 1   -- Very active historically
  WHEN COUNT(*) > 10 THEN 2    -- Moderately active
  ELSE 3                        -- Low activity
END
```

- **Very active (>100 actions):** Frequently queried users
- **Moderately active (10-100 actions):** Occasional users
- **Low activity (<10 actions):** Rarely queried users

#### **Level 3: Total Actions** (Tiebreaker)

```sql
COUNT(*) DESC
```

- Orders by total actions (highest to lowest)
- Most active users first within the same level

#### **Level 4: Most Recent Date** (Final Tiebreaker)

```sql
MAX(f.action_at) DESC NULLS LAST
```

- Orders by last action date (most recent first)
- Users without actions at the end

### Complete Prioritization Query

```sql
SELECT DISTINCT 
  f.action_dimension_id_user
FROM dwh.facts f
JOIN dwh.dimension_users u
  ON (f.action_dimension_id_user = u.dimension_user_id)
WHERE u.modified = TRUE
GROUP BY f.action_dimension_id_user
ORDER BY 
  -- Priority 1: Very recent activity (last 7 days) = highest
  CASE WHEN MAX(f.action_at) >= CURRENT_DATE - INTERVAL '7 days' THEN 1
       WHEN MAX(f.action_at) >= CURRENT_DATE - INTERVAL '30 days' THEN 2
       WHEN MAX(f.action_at) >= CURRENT_DATE - INTERVAL '90 days' THEN 3
       ELSE 4 END,
  -- Priority 2: High activity users (>100 actions) get priority
  CASE WHEN COUNT(*) > 100 THEN 1
       WHEN COUNT(*) > 10 THEN 2
       ELSE 3 END,
  -- Priority 3: Most active users historically
  COUNT(*) DESC,
  -- Priority 4: Most recent activity first
  MAX(f.action_at) DESC NULLS LAST
```

## Parallel Processing

### Architecture

The system processes users in parallel using multiple bash processes, each executing an independent PostgreSQL transaction.

```
┌─────────────────────────────────────────┐
│  Prioritized User Query                  │
│  (Ordered by relevance)                  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Parallel Process Pool                   │
│  (Maximum: nproc - 1 threads)            │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴───────┐
       │               │
       ▼               ▼
┌──────────┐    ┌──────────┐
│ Process 1│    │ Process 2│    ...
│ User A   │    │ User B   │
└──────────┘    └──────────┘
```

### Concurrency Control

```bash
# Adjust threads based on available CPU
adjusted_threads=$((MAX_THREADS - 1))

# Limit concurrent processes
if [[ ${#pids[@]} -ge ${adjusted_threads} ]]; then
  wait "${pids[0]}"  # Wait for oldest
  pids=("${pids[@]:1}")  # Remove from pool
fi
```

**Features:**
- Uses `nproc - 1` threads to leave one core free
- Dynamic process pool with limit
- Processes users in priority order
- Waits for completed processes before starting new ones

### Atomic Transactions

Each user is processed in an explicit transaction:

```sql
BEGIN;
  CALL dwh.update_datamart_user(user_id);
  UPDATE dwh.dimension_users 
    SET modified = FALSE 
    WHERE dimension_user_id = user_id;
COMMIT;
```

**Benefits:**
- **Atomicity:** If `update_datamart_user()` fails, user is not marked as processed
- **Consistency:** The `modified` flag is only updated if processing succeeds
- **Isolation:** Each user is processed independently
- **Durability:** Changes are only committed with successful COMMIT

## Error Handling

### In SQL (Procedure)

```sql
BEGIN
  CALL dwh.update_datamart_user(r.dimension_user_id);
  UPDATE dwh.dimension_users SET modified = FALSE 
    WHERE dimension_user_id = r.dimension_user_id;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to process user %: %', r.dimension_user_id, SQLERRM;
  -- Continue with next user instead of failing entire batch
END;
```

**Features:**
- Captures errors without stopping entire process
- Logs warnings for debugging
- Continues with next user
- User remains `modified = TRUE` for retry

### In Bash (Main Script)

```bash
# Each background process verifies its own success
(
  if ! __psql_with_appname ... -c "BEGIN; ... COMMIT;"; then
    __loge "ERROR: Failed to process user ${user_id}"
    exit 1
  fi
) &

# Wait and count errors
for pid in "${pids[@]}"; do
  if ! wait "${pid}"; then
    failed_count=$((failed_count + 1))
  fi
done
```

**Features:**
- Each process reports its own status
- Errors don't stop other processes
- Failure counter for final report
- Detailed logging per user

## Logging and Monitoring

### Logged Information

1. **Processing Start:**
   ```
   Found X users to process (prioritized by relevance)
   Using Y parallel threads for user processing
   ```

2. **Progress (every 1000 users):**
   ```
   Progress: Processed 1000/5000 users (batch 1)
   Progress: Processed 2000/5000 users (batch 2)
   ```

3. **Individual Errors:**
   ```
   ERROR: Failed to process user 12345
   ```

4. **Final Summary:**
   ```
   SUCCESS: Datamart users population completed successfully
   Processed 5000 users in parallel (5000 total)
   All users processed with intelligent prioritization
   ```

### Recommended Metrics

- **Processing time:** Total and per batch
- **Throughput:** Users processed per minute
- **Success rate:** Percentage of successfully processed users
- **Priority distribution:** How many users in each level
- **Average time per user:** By priority level

## Configuration

### Environment Variables

```bash
# Maximum number of threads (default: nproc)
MAX_THREADS="${MAX_THREADS:-$(nproc)}"

# Batch size for logging (default: 1000)
batch_size=1000
```

### Recommended Adjustments

**For systems with many users:**
- Increase `MAX_THREADS` if resources are available
- Monitor `max_connections` in PostgreSQL
- Adjust `batch_size` based on volume

**For systems with limited resources:**
- Reduce `MAX_THREADS` to `nproc - 2`
- Increase `batch_size` for less logging
- Consider processing in multiple runs

## Expected Performance

### Typical Scenarios

**Case 1: 1000 modified users**
- Active users (7 days): ~50 users → **2-5 minutes**
- Active users (30 days): ~200 users → **10-15 minutes**
- Inactive users: ~750 users → **30-60 minutes**
- **Total:** ~1 hour (vs. days without prioritization)

**Case 2: 10000 modified users**
- Active users (7 days): ~500 users → **10-20 minutes**
- Active users (30 days): ~2000 users → **1-2 hours**
- Inactive users: ~7500 users → **5-10 hours**
- **Total:** ~6-12 hours (vs. days/weeks without prioritization)

**Key benefit:** Active users have fresh data in minutes, not days.

## Security Considerations

### Data Integrity

- ✅ **Atomicity:** Transactions guarantee all-or-nothing
- ✅ **Isolation:** Each user is processed independently
- ✅ **Consistency:** `modified` flag only updated after success
- ✅ **Durability:** COMMIT only if everything succeeds

### Resource Contention

- ⚠️ **Locks:** PostgreSQL uses row-level locking
- ⚠️ **Connections:** Limit according to `max_connections`
- ⚠️ **CPU/Memory:** Monitor usage during processing
- ⚠️ **I/O:** Concurrent reads may saturate disk

### Mitigations

1. **Concurrency limit:** `nproc - 1` threads
2. **Batch processing:** Avoids overload
3. **Short transactions:** Each user is independent
4. **Error handling:** Doesn't stop entire process

## Troubleshooting

### Problem: Very slow processing

**Possible causes:**
- Too many inactive users being processed first
- Lock contention in database
- System resources saturated

**Solutions:**
- Verify prioritization is working (check logs)
- Reduce `MAX_THREADS`
- Verify indexes on `dwh.facts` and `dwh.dimension_users`
- Monitor locks: `SELECT * FROM pg_locks WHERE NOT granted;`

### Problem: Many errors

**Possible causes:**
- Corrupted data for some user
- Connection timeouts
- Connection limit reached

**Solutions:**
- Review specific error logs
- Verify `max_connections` in PostgreSQL
- Increase timeout if necessary
- Process problematic users manually

### Problem: Users not being processed

**Possible causes:**
- Prioritization query too slow
- Memory limit reached
- Deadlocks

**Solutions:**
- Verify `action_at` has index
- Reduce batch size
- Check deadlocks: `SELECT * FROM pg_stat_activity WHERE wait_event_type = 'Lock';`

## Best Practices

1. **Monitor regularly:**
   - Processing time
   - Success rate
   - Distribution by priority

2. **Adjust based on metrics:**
   - Increase concurrency if resources allow
   - Adjust prioritization criteria based on usage patterns
   - Optimize queries if slow

3. **Preventive maintenance:**
   - Analyze tables regularly (`ANALYZE`)
   - Verify indexes
   - Clean up very old users if necessary

4. **Document changes:**
   - Record configuration adjustments
   - Document problems encountered
   - Share performance metrics

## References

- **Main file:** `bin/dwh/datamartUsers/datamartUsers.sh`
- **Population SQL:** `sql/dwh/datamartUsers/datamartUsers_32_populateDatamartUsersTable.sql`
- **Procedure:** `sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql`

## Version

- **Implemented:** 2025-12-27
- **Author:** Andres Gomez (AngocA)
- **Version:** 1.0

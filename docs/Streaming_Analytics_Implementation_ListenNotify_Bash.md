# LISTEN/NOTIFY Implementation in Pure Bash

**Note**: This is an alternative approach using LISTEN/NOTIFY directly in Bash. The event table approach is recommended for simplicity.

## Can LISTEN/NOTIFY be used in Bash?

**Yes!** LISTEN/NOTIFY is a native PostgreSQL feature and doesn't require Python. However, using it from Bash is more complex than using an event table.

## How LISTEN/NOTIFY Works

1. **LISTEN**: A client subscribes to a channel
2. **NOTIFY**: A process sends a message to a channel  
3. **Notification**: PostgreSQL delivers the message to all listening clients

## Bash Implementation Challenges

The main challenge is that `psql` shows notifications in its output, but you need to:
- Keep a persistent connection
- Parse the output for notifications
- Handle connection failures
- Manage the process lifecycle

## Example: Basic LISTEN in Bash

```bash
#!/bin/bash
# File: bin/dwh/listen_simple.sh

# Simple LISTEN example (not production-ready)

DBNAME="${DBNAME_DWH}"
CHANNEL="note_inserted"

# Start LISTEN in background
psql -d "${DBNAME}" -c "LISTEN ${CHANNEL};" &
LISTEN_PID=$!

# Monitor psql output for notifications
while kill -0 ${LISTEN_PID} 2>/dev/null; do
    # This is simplified - real implementation needs proper parsing
    sleep 1
done
```

## Example: Advanced LISTEN with Output Parsing

```bash
#!/bin/bash
# File: bin/dwh/listen_advanced.sh

# More advanced LISTEN implementation with output parsing

set -euo pipefail

DBNAME="${DBNAME_DWH}"
CHANNEL="note_inserted"
LOG_FILE="/tmp/listen_processor.log"

# Function to parse psql notification output
parse_notification() {
    local line="$1"
    # psql shows: "Asynchronous notification 'channel' with payload 'payload' received from server process PID"
    if [[ "${line}" =~ notification.*${CHANNEL}.*payload.*received ]]; then
        # Extract payload (simplified - real parsing is more complex)
        local payload=$(echo "${line}" | sed -n "s/.*payload '\(.*\)' received.*/\1/p")
        echo "${payload}"
    fi
}

# Start LISTEN and monitor output
{
    psql -d "${DBNAME}" <<EOF
LISTEN ${CHANNEL};
SELECT 'Listening on channel ${CHANNEL}';
\watch 1
EOF
} 2>&1 | while IFS= read -r line; do
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ${line}" | tee -a "${LOG_FILE}"
    
    # Check if this is a notification
    if [[ "${line}" =~ notification ]]; then
        local payload=$(parse_notification "${line}")
        if [ -n "${payload}" ]; then
            echo "Processing notification: ${payload}"
            # Process notification here
        fi
    fi
done
```

## Limitations of LISTEN/NOTIFY in Bash

1. **Output Parsing**: Need to parse psql output (fragile)
2. **Connection Management**: Complex to handle reconnections
3. **No Persistence**: Notifications lost if processor is down
4. **Process Management**: Need to manage background processes
5. **Error Handling**: Harder to detect and handle errors

## Why Event Table is Better

| Feature | LISTEN/NOTIFY (Bash) | Event Table (Bash) |
|---------|---------------------|-------------------|
| **Simplicity** | Complex | Simple |
| **Reliability** | Notifications can be lost | Events persist |
| **Debugging** | Hard (async output) | Easy (query table) |
| **Error Recovery** | Complex | Simple (retry failed) |
| **Monitoring** | Hard | Easy (count pending) |
| **Latency** | Instant | 2-5 seconds |

## Recommendation

**Use Event Table approach** for production. LISTEN/NOTIFY in Bash is possible but:
- More complex to implement
- Less reliable
- Harder to maintain
- No significant advantage over event table with 2-5 second polling

The event table approach provides:
- ✅ Same functionality
- ✅ Better reliability
- ✅ Easier maintenance
- ✅ Acceptable latency (2-5 seconds is still "real-time" for most use cases)


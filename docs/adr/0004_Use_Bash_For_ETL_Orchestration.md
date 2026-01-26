# ADR-0004: Use Bash for ETL Orchestration

## Status

Accepted

## Context

We need to orchestrate complex ETL workflows that involve:
- Running SQL scripts in sequence
- Parallel processing where possible
- Error handling and recovery
- Logging and monitoring
- Integration with system tools

## Decision

We will use Bash scripts for ETL orchestration, calling SQL scripts and coordinating the workflow.

## Consequences

### Positive

- **System integration**: Excellent integration with PostgreSQL (psql), system tools
- **Process control**: Easy to manage parallel processes, error handling
- **No dependencies**: Bash is available on all Linux systems
- **Flexibility**: Can easily integrate with external tools (curl, jq, etc.)
- **Debugging**: Easy to debug with shell debugging tools
- **Logging**: Can use standard logging libraries (bash_logger.sh)

### Negative

- **Error handling**: Bash error handling can be verbose
- **Complexity**: Complex workflows can be hard to maintain
- **Testing**: Less mature testing frameworks
- **Type safety**: No compile-time validation

## Alternatives Considered

### Alternative 1: Python with SQLAlchemy

- **Description**: Use Python for ETL orchestration
- **Pros**: Rich ecosystem, better error handling, easier testing
- **Cons**: Requires Python installation, more dependencies, slower for simple operations
- **Why not chosen**: Bash is more suitable for system-level orchestration

### Alternative 2: ETL tools (Airflow, Luigi)

- **Description**: Use dedicated ETL orchestration tools
- **Pros**: Built-in scheduling, monitoring, retry logic
- **Cons**: Additional infrastructure, learning curve, overkill for current needs
- **Why not chosen**: Too heavyweight for current requirements

### Alternative 3: SQL-only approach

- **Description**: Use stored procedures and SQL scripts only
- **Pros**: All logic in database, no external scripts
- **Cons**: Limited system integration, harder to orchestrate complex workflows
- **Why not chosen**: Need system-level orchestration capabilities

## References

- [ETL Scripts](bin/dwh/ETL.sh)
- [Bash Best Practices](https://google.github.io/styleguide/shellguide.html)

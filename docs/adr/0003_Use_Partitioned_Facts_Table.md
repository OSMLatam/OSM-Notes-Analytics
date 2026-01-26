# ADR-0003: Use Partitioned Facts Table

## Status

Accepted

## Context

The facts table will contain millions of rows spanning many years (2013-2025+). Query performance will degrade as the table grows. We need a way to maintain query performance while handling large data volumes.

## Decision

We will partition the facts table by year using PostgreSQL table partitioning.

## Consequences

### Positive

- **Query performance**: Queries filtering by year only scan relevant partitions
- **Maintenance**: Can drop old partitions easily
- **Index efficiency**: Smaller indexes per partition
- **Parallel queries**: PostgreSQL can query partitions in parallel
- **Storage management**: Can archive or drop old partitions independently
- **Scalability**: Handles large data volumes efficiently

### Negative

- **Complexity**: Partition management adds complexity
- **Cross-partition queries**: Queries spanning multiple partitions may be slower
- **Partition pruning**: Requires proper query planning to benefit
- **Maintenance overhead**: Need to create new partitions for new years

## Alternatives Considered

### Alternative 1: Single large table

- **Description**: Store all facts in one table without partitioning
- **Pros**: Simple, no partition management
- **Cons**: Performance degrades as data grows, difficult to maintain
- **Why not chosen**: Will not scale to large data volumes

### Alternative 2: Separate tables per year

- **Description**: Create separate tables for each year (facts_2013, facts_2014, etc.)
- **Pros**: Simple, easy to drop old years
- **Cons**: Complex queries require UNION ALL, no automatic partition pruning
- **Why not chosen**: PostgreSQL partitioning provides better query optimization

### Alternative 3: Horizontal sharding

- **Description**: Shard data across multiple databases
- **Pros**: Can scale horizontally
- **Cons**: Complex queries, distributed transactions, operational complexity
- **Why not chosen**: Overkill for current data volumes, partitioning is sufficient

## References

- [PostgreSQL Partitioning Documentation](https://www.postgresql.org/docs/current/ddl-partitioning.html)
- [ETL Partition Management](bin/dwh/ETL_20_createPartitions.sql)

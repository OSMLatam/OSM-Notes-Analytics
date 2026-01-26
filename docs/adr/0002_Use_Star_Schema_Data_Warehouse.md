# ADR-0002: Use Star Schema Data Warehouse

## Status

Accepted

## Context

We need to store and query analytics data efficiently. The data model must support:
- Time-based analysis (by date, month, year)
- Geographic analysis (by country, continent)
- User analysis (by user, experience level, automation level)
- Fast query performance for aggregations
- Easy to understand and maintain

## Decision

We will use a Star Schema data warehouse design with fact tables and dimension tables.

## Consequences

### Positive

- **Query performance**: Star schema is optimized for analytical queries
- **Simplicity**: Easy to understand and maintain
- **Standard pattern**: Well-known data warehouse pattern
- **Aggregation-friendly**: Designed for SUM, COUNT, AVG operations
- **Dimension flexibility**: Easy to add new dimensions
- **Business-friendly**: Business users can understand the model

### Negative

- **Data redundancy**: Denormalized dimensions contain redundant data
- **Storage**: Requires more storage than normalized schemas
- **ETL complexity**: More complex ETL to populate fact and dimension tables
- **Update overhead**: Updating dimensions requires updating fact tables

## Alternatives Considered

### Alternative 1: Normalized schema (3NF)

- **Description**: Use fully normalized relational schema
- **Pros**: No redundancy, efficient storage, easier updates
- **Cons**: Complex joins for analytical queries, slower performance
- **Why not chosen**: Star schema is better suited for analytical workloads

### Alternative 2: Snowflake schema

- **Description**: Use snowflake schema with normalized dimensions
- **Pros**: Less redundancy than star schema
- **Cons**: More complex, slower queries due to more joins
- **Why not chosen**: Star schema provides better query performance with acceptable redundancy

### Alternative 3: Data lake / NoSQL

- **Description**: Store raw data and query on-demand
- **Pros**: Flexible, no schema design needed
- **Cons**: Slower queries, no pre-aggregation, complex query logic
- **Why not chosen**: We need fast analytical queries, not flexible storage

## References

- [Star Schema Documentation](docs/DWH_Star_Schema_ERD.md)
- [Data Warehouse Design Patterns](https://en.wikipedia.org/wiki/Star_schema)

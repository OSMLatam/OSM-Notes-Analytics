# Documentation Directory

This directory contains comprehensive documentation for the OSM-Notes-Analytics project, including
architecture diagrams, data dictionaries, testing guides, and CI/CD documentation.

## Overview

The documentation provides detailed information about the data warehouse design, ETL processes,
testing strategies, and development workflows.

## Documentation Index

### Core Documentation

- **`Rationale.md`**: Project motivation, background, and design decisions
- **`Troubleshooting_Guide.md`**: Centralized troubleshooting guide for common problems and solutions

### data warehouse Documentation

#### [Data_Flow_Diagrams.md](Data_Flow_Diagrams.md)

**Data Flow Diagrams (DFD) - System Data Flow**

- DFD Level 0: Context diagram (system and external entities)
- DFD Level 1: System decomposition (Extract, Transform, Load, Export)
- DFD Level 2: ETL process detail
- Data stores and data flow descriptions
- Process descriptions and frequencies

**Contents:**
- Context diagram showing system boundaries
- Process decomposition diagrams
- Data store documentation
- Data flow descriptions
- Incremental vs full load flows

**Audience:** Data engineers, system architects, business analysts

**When to read:**
- Understanding overall data flow
- Designing new data pipelines
- Troubleshooting data flow issues
- Explaining system to stakeholders

---

#### [Data_Lineage.md](Data_Lineage.md)

**Data Lineage - Complete Data Traces**

- Complete lineage paths from source to destination
- Column-level transformations and mappings
- Business rules applied at each stage
- Dependencies between processes
- Impact analysis for schema changes

**Contents:**
- Lineage diagram (source → staging → DWH → datamarts → JSON)
- Detailed transformation rules for each path
- Dimension lineage (users, countries, dates)
- Business rules documentation
- Data quality checks
- Impact analysis

**Audience:** Data engineers, data quality analysts, compliance officers

**When to read:**
- Understanding data transformations
- Debugging data quality issues
- Impact analysis (what breaks if source changes)
- Compliance and auditing
- Onboarding new team members

---

#### [Business_Glossary.md](Business_Glossary.md)

**Business Glossary - Terms and Key Metrics**

- Business definitions for core terms (Note, Resolution, Active User, etc.)
- Key metric definitions from business perspective
- Calculation formulas and interpretations
- Business rules and their rationale
- Example calculations

**Contents:**
- Core business terms (Note, Resolution, Community Health, etc.)
- Key metrics overview (historical counts, resolution, applications, content quality)
- Business rules documentation
- Example calculations

**Audience:** Business analysts, product managers, stakeholders, new team members

**When to read:**
- Understanding core business concepts
- Getting overview of available metrics
- Communicating with non-technical stakeholders
- See also: [Metric Definitions](Metric_Definitions.md) for complete 77+ (countries) and 78+ (users) metrics reference

---

#### [Metric_Definitions.md](Metric_Definitions.md)

**Metric Definitions - Complete Reference**

- Comprehensive definitions for all 77+ (countries) and 78+ (users) metrics in datamarts
- Detailed business definitions, formulas, and interpretations
- Organized by category (Historical, Resolution, Applications, Content, Temporal, Geographic, etc.)
- Metric summary tables

**Contents:**
- Historical count metrics (30+ metrics across time periods)
- Resolution metrics (7 metrics: avg, median, rate, by year/month)
- Application statistics (4 metrics: mobile/desktop counts, most used)
- Content quality metrics (5 metrics: length, URLs, mentions, engagement)
- Temporal pattern metrics (5 metrics: working hours, activity heatmap, peak dates)
- Geographic pattern metrics (15+ metrics: countries, users, rankings)
- Community health metrics (5 metrics: backlog, active notes, age distribution)
- Hashtag metrics (8 metrics: usage, top hashtags, favorites)
- First/Last action metrics (8 metrics: dates and note IDs)
- User classification (1 metric: contributor type with 23 types)
- Metric interpretation guide
- Metric calculation details

**Audience:** Data analysts, BI developers, dashboard builders, business analysts

**When to read:**
- Building dashboards and reports
- Understanding all available metrics
- Interpreting metric values
- Comparing metrics across users/countries
- See also: [Business Glossary](Business_Glossary.md) for core terms

---

#### [Architecture_Diagram.md](Architecture_Diagram.md)

**Architecture Diagrams - System Structure**

- C4 model architecture documentation (Level 1 and Level 2)
- System context and container diagrams
- Component interactions and data flows
- Technology stack documentation
- Deployment and security architecture

**Contents:**
- C4 Level 1: System context (system and external entities)
- C4 Level 2: Container diagram (high-level building blocks)
- Detailed architecture with components
- Technology stack (PostgreSQL, Bash, SQL)
- Deployment architecture
- Security architecture
- Performance and scalability considerations

**Audience:** System architects, DevOps engineers, developers, technical leads

**When to read:**
- Understanding overall system structure
- Planning deployments
- Designing new features
- Troubleshooting architecture issues
- Onboarding new developers

---

#### [Deployment_Diagram.md](Deployment_Diagram.md)

**Deployment Diagram - Infrastructure and Operations**

- Deployment architecture (single and multi-server)
- Operational schedules and cron configuration
- Process dependencies and execution order
- Infrastructure requirements
- Monitoring, backup, and disaster recovery

**Contents:**
- Deployment architecture diagrams
- Production schedule (Gantt chart)
- Cron configuration examples
- Process dependency graphs
- Infrastructure specifications
- Deployment steps
- Operational workflows
- Monitoring and alerting
- Backup and recovery procedures
- Security considerations
- Performance tuning

**Audience:** DevOps engineers, system administrators, SREs, deployment teams

**When to read:**
- Planning production deployment
- Setting up cron automation
- Understanding operational dependencies
- Configuring monitoring
- Disaster recovery planning
- Performance optimization

---

#### [cron_setup.md](cron_setup.md)

**Cron Setup Guide - Automated Execution**

- Complete guide for setting up automated ETL execution
- Cron configuration and scheduling
- Monitoring and troubleshooting
- Best practices for production

**Contents:**
- Installation and configuration
- Scheduling options
- Lock file behavior
- Log management
- Monitoring scripts
- Troubleshooting common issues
- Best practices

**Audience:** System administrators, DevOps engineers

**When to read:**
- Setting up automated ETL execution
- Configuring cron jobs
- Troubleshooting cron issues
- See also: [Deployment Diagram](Deployment_Diagram.md) for complete deployment architecture

---

#### [DWH_Star_Schema_ERD.md](DWH_Star_Schema_ERD.md)

**Entity-Relationship Diagram and Schema Overview**

- Complete star schema design
- Dimension and fact table relationships
- ETL flow diagrams (Mermaid)
- Data model visualization
- Table relationships and foreign keys

**Contents:**

- Conceptual data model
- Logical schema design
- Physical implementation details
- ETL data flow
- Operational workflows

**Audience:** Database architects, data engineers, developers

**When to read:**

- Understanding the data warehouse structure
- Designing new features
- Optimizing queries
- Planning schema changes

---

#### [DWH_Star_Schema_Data_Dictionary.md](DWH_Star_Schema_Data_Dictionary.md)

**Complete Data Dictionary for All Tables**

- Detailed column definitions
- Data types and constraints
- Business rules and logic
- Sample data and examples
- Relationships between tables

**Contents:**

1. **Fact Table:**
   - `dwh.facts` - All columns with descriptions

2. **Dimension Tables:**
   - `dimension_users` - User information
   - `dimension_countries` - Country data
   - `dimension_regions` - Geographic regions
   - `dimension_continents` - Continental groupings
   - `dimension_days` - Date dimension
   - `dimension_time_of_week` - Temporal dimension
   - `dimension_applications` - Application tracking
   - `dimension_application_versions` - Version history
   - `dimension_hashtags` - Hashtag catalog
   - `dimension_timezones` - Timezone information
   - `dimension_seasons` - Seasonal classifications
   - `dimension_automation_level` - Bot/script detection levels
   - `dimension_experience_levels` - User experience classification (newcomer to legend)

3. **Datamart Tables:**
   - `dwh.datamartCountries` - Country analytics (77+ metrics)
   - `dwh.datamartUsers` - User analytics (78+ metrics)
   - `dwh.datamartGlobal` - Global statistics

4. **Control Tables:**
   - `dwh.properties` - ETL metadata
   - `dwh.contributor_types` - User classifications

**Audience:** Analysts, report developers, data scientists

**When to read:**

- Writing queries
- Building reports
- Understanding data lineage
- Validating data quality

---

#### [ETL_Enhanced_Features.md](ETL_Enhanced_Features.md)

**Advanced ETL Features and Capabilities**

- Enhanced ETL functionality
- Performance optimizations
- Recovery and monitoring
- Advanced processing techniques

**Contents:**

- Parallel processing by year
- Incremental update strategies
- Recovery and resume capabilities
- Resource monitoring
- Data validation and integrity checks
- Performance tuning guidelines
- Troubleshooting common issues

**Audience:** Data engineers, ETL developers, DevOps

**When to read:**

- Setting up ETL processes
- Troubleshooting ETL failures
- Optimizing performance
- Implementing recovery strategies

---

#### [DWH_Maintenance_Guide.md](DWH_Maintenance_Guide.md)

**data warehouse Maintenance and Cleanup Guide**

- Cleanup script usage and safety guidelines
- Maintenance workflows and best practices
- Troubleshooting common issues
- Emergency procedures

**Contents:**

- When and how to use cleanup script
- Safe vs destructive operations
- Common maintenance workflows
- Safety guidelines and best practices
- Troubleshooting cleanup issues
- Configuration and prerequisites

**Audience:** Database administrators, DevOps, developers

**When to read:**

- Planning maintenance procedures
- Troubleshooting data warehouse issues
- Setting up development environments
- Understanding cleanup operations

---

#### [Troubleshooting_Guide.md](Troubleshooting_Guide.md)

**Comprehensive Troubleshooting Guide**

- Common problems and solutions
- Diagnostic commands
- Recovery procedures
- Error code reference

**Contents:**

- Quick diagnostic commands
- ETL issues and solutions
- Database issues and solutions
- Datamart issues and solutions
- Performance issues and solutions
- Export and profile generation issues
- Configuration and integration issues
- Recovery procedures

**Audience:** All users, developers, system administrators

**When to read:**

- When encountering errors or problems
- Before asking for help
- Setting up new environments
- Troubleshooting performance issues

**See also:** [bin/README.md](../bin/README.md) for script-specific troubleshooting

---

### Testing Documentation

For comprehensive testing documentation, see **[tests/README.md](../tests/README.md)**:

**Complete Testing Guide:**

- Test suite descriptions (Quality Tests, DWH Tests, All Tests)
- How to run tests locally
- Test configuration and setup
- Database requirements
- Troubleshooting common issues
- Writing new tests
- CI/CD integration
- Git hooks for testing

**Test Suites:**

- **Quality Tests**: Fast validation without database (shellcheck, shfmt, SQL syntax)
- **DWH Tests**: Database-dependent tests (ETL, datamarts, SQL functions)
- **Integration Tests**: End-to-end workflow validation

**Test Files:**

- Unit tests: `tests/unit/bash/*.bats` and `tests/unit/sql/*.sql`
- Integration tests: `tests/integration/*.bats`

**Audience:** Developers, QA engineers, contributors

**When to read:**

- Setting up test environment
- Running tests locally
- Writing new tests
- Debugging test failures
- Understanding test coverage

---

#### [Hybrid_Strategy_Copy_FDW.md](Hybrid_Strategy_Copy_FDW.md)

**Hybrid Strategy: Database Separation**

- Implemented strategy to separate Ingestion and Analytics databases
- Local table copy for initial load (avoids millions of cross-database queries)
- Foreign Data Wrappers (FDW) for incremental execution

**Contents:**
- Configuration and usage
- Implementation scripts
- Troubleshooting
- Technical details

**Audience:** Developers, database administrators

**When to read:**
- Configuring database separation
- Understanding how the hybrid strategy works
- Troubleshooting table copy or FDW issues

---

#### [Hybrid_ETL_Execution_Guide.md](Hybrid_ETL_Execution_Guide.md)

**Hybrid ETL Execution Guide - Complete Pipeline Testing**

- Complete guide for running hybrid ETL execution scripts
- End-to-end pipeline testing (Ingestion + ETL)
- Hybrid mode configuration (real DB, mocked downloads)
- Step-by-step execution control
- Expected behavior in each iteration

**Contents:**

- Overview of hybrid execution scripts
- Architecture and dependencies
- Hybrid mode configuration (real PostgreSQL + mocked downloads)
- Complete execution flow (4 iterations)
- Expected behavior for each execution:
  - Execution #1: Planet/Base Load
  - Execution #2: API Sequential (5 notes)
  - Execution #3: API Parallel (20 notes)
  - Execution #4: API Empty (0 notes)
- Cleanup and error handling
- Troubleshooting common issues
- Integration with CI/CD

**Scripts:**

- `run_processAPINotes_with_etl.sh` - Automatic execution mode
- `run_processAPINotes_with_etl_controlled.sh` - Step-by-step control mode

**Audience:** Developers, QA engineers, system integrators

**When to read:**

- Testing complete data pipeline (Ingestion → DWH)
- Understanding hybrid mode execution
- Debugging end-to-end workflows
- Setting up integration tests
- Verifying ETL after ingestion updates

---

### CI/CD Documentation

#### [CI_CD_Guide.md](CI_CD_Guide.md)

**Complete CI/CD Setup and Configuration Guide**

- GitHub Actions workflows
- Automated testing and validation
- Deployment strategies
- Git hooks and quality gates

**Contents:**

1. **GitHub Actions Workflows:**
   - Quality checks workflow
   - Test execution workflow
   - Dependency checking
   - Security scanning

2. **Git Hooks:**
   - Pre-commit validation
   - Pre-push testing
   - Commit message linting
   - Installation and configuration

3. **Quality Gates:**
   - Code quality thresholds
   - Test coverage requirements
   - Security vulnerability checks
   - Performance benchmarks

4. **Deployment:**
   - Deployment strategies
   - Environment management
   - Rollback procedures
   - Production readiness checks

**Audience:** DevOps engineers, release managers, developers

**When to read:**

- Setting up CI/CD pipelines
- Configuring quality gates
- Troubleshooting workflow failures
- Planning deployments

---

## Quick Start

**New to the project?** Start here:

1. **[Rationale.md](./Rationale.md)** (30 min) - Understand why this project exists
2. **[Main README](../README.md)** (20 min) - Project overview and quick start
3. **[DWH_Star_Schema_ERD.md](./DWH_Star_Schema_ERD.md)** (30 min) - Understand the data model

**Total time: ~1.5 hours** for a complete overview.

For detailed navigation paths by role, see [Recommended Reading Paths by Role](#recommended-reading-paths-by-role) below.

## Recommended Reading Paths by Role

### For New Users (~2 hours total)

**Step 1: Project Context** (50 min)
- **[Rationale.md](./Rationale.md)** (30 min) - Project purpose and motivation
  - Why this project exists
  - Problem statement
  - Historical context
- **[Main README](../README.md)** (20 min) - Project overview and quick start
  - Features and capabilities
  - Quick start guide
  - Basic workflows

**Step 2: System Overview** (60 min)
- **[Data_Flow_Diagrams.md](./Data_Flow_Diagrams.md)** (20 min) - System data flow
  - Context diagram
  - Process decomposition
  - Data flow overview
- **[DWH_Star_Schema_ERD.md](./DWH_Star_Schema_ERD.md)** (30 min) - data warehouse structure
  - Star schema design
  - Table relationships
  - ETL data flow
- **[bin/README.md](../bin/README.md)** (10 min) - Scripts overview
  - Main entry points
  - Basic usage examples

**Step 3: Getting Started** (25 min)
- **[bin/dwh/ENTRY_POINTS.md](../bin/dwh/ENTRY_POINTS.md)** (15 min) - Which scripts to use
  - Entry points documentation
  - Usage examples
- **[Troubleshooting_Guide.md](./Troubleshooting_Guide.md)** (10 min) - Common issues
  - Quick diagnostic commands
  - Common problems and solutions

### For Developers (~3 hours total)

**Step 1: Foundation** (75 min)
- **[Rationale.md](./Rationale.md)** (30 min) - Project context
- **[Main README](../README.md)** (20 min) - Overview and architecture
- **[DWH_Star_Schema_ERD.md](./DWH_Star_Schema_ERD.md)** (25 min) - Data model

**Step 2: Implementation Details** (60 min)
- **[ETL_Enhanced_Features.md](./ETL_Enhanced_Features.md)** (30 min) - ETL capabilities
  - Parallel processing
  - Recovery mechanisms
  - Performance optimization
- **[bin/dwh/ENTRY_POINTS.md](../bin/dwh/ENTRY_POINTS.md)** (15 min) - Script entry points
- **[bin/dwh/ENVIRONMENT_VARIABLES.md](../bin/dwh/ENVIRONMENT_VARIABLES.md)** (15 min) - Configuration

**Step 3: Development Workflow** (45 min)
- **[tests/README.md](../tests/README.md)** (20 min) - Testing guide
- **[CI_CD_Guide.md](./CI_CD_Guide.md)** (25 min) - CI/CD workflows
  - GitHub Actions
  - Git hooks
  - Quality gates

**Step 4: Deep Dive** (as needed)
- **[DWH_Star_Schema_Data_Dictionary.md](./DWH_Star_Schema_Data_Dictionary.md)** - Complete schema reference
- **[CONTRIBUTING.md](../CONTRIBUTING.md)** - Contribution guidelines
- **[bin/README.md](../bin/README.md)** - Script documentation

### For Data Analysts (~2 hours total)

**Step 1: Data Model** (60 min)
- **[DWH_Star_Schema_ERD.md](./DWH_Star_Schema_ERD.md)** (30 min) - Schema overview
  - Table relationships
  - Fact and dimension tables
- **[DWH_Star_Schema_Data_Dictionary.md](./DWH_Star_Schema_Data_Dictionary.md)** (30 min) - Column definitions
  - Complete data dictionary
  - Business rules
  - Sample queries

**Step 2: Data Access** (45 min)
- **[Main README](../README.md)** (15 min) - Quick start
- **[ETL_Enhanced_Features.md](./ETL_Enhanced_Features.md)** (15 min) - Data freshness
- **[bin/dwh/profile.sh](../bin/dwh/profile.sh)** (15 min) - Profile generation
  - User profiles
  - Country profiles
  - Statistics

**Step 3: Advanced Topics** (15 min)
- **[Dashboard_Analysis.md](./Dashboard_Analysis.md)** - Available metrics
  - Resolution metrics
  - Application statistics
  - Content quality metrics
  - Community health indicators

### For DevOps/SRE (~2.5 hours total)

**Step 1: Deployment** (45 min)
- **[Main README](../README.md)** (20 min) - Setup and deployment
- **[bin/dwh/ENTRY_POINTS.md](../bin/dwh/ENTRY_POINTS.md)** (15 min) - Script entry points
- **[bin/dwh/ENVIRONMENT_VARIABLES.md](../bin/dwh/ENVIRONMENT_VARIABLES.md)** (10 min) - Configuration

**Step 2: Operations** (60 min)
- **[ETL_Enhanced_Features.md](./ETL_Enhanced_Features.md)** (30 min) - ETL operations
  - Performance tuning
  - Resource monitoring
  - Recovery procedures
- **[DWH_Maintenance_Guide.md](./DWH_Maintenance_Guide.md)** (30 min) - Maintenance
  - Cleanup procedures
  - Backup strategies
  - Performance optimization

**Step 3: Monitoring and Troubleshooting** (45 min)
- **[Troubleshooting_Guide.md](./Troubleshooting_Guide.md)** (30 min) - Problem resolution
  - Common issues
  - Diagnostic commands
  - Recovery procedures
- **[CI_CD_Guide.md](./CI_CD_Guide.md)** (15 min) - CI/CD pipelines

### For System Administrators (~2 hours total)

**Step 1: System Overview** (45 min)
- **[Rationale.md](./Rationale.md)** (30 min) - Project purpose
- **[Main README](../README.md)** (15 min) - Architecture overview

**Step 2: Operations** (60 min)
- **[bin/README.md](../bin/README.md)** (20 min) - Scripts and workflows
- **[DWH_Maintenance_Guide.md](./DWH_Maintenance_Guide.md)** (20 min) - Maintenance procedures
- **[Troubleshooting_Guide.md](./Troubleshooting_Guide.md)** (20 min) - Problem resolution

**Step 3: Configuration** (15 min)
- **[bin/dwh/ENVIRONMENT_VARIABLES.md](../bin/dwh/ENVIRONMENT_VARIABLES.md)** - Environment variables
- **[etc/README.md](../etc/README.md)** - Configuration files

## Quick Reference

### Essential Documents

- **[Rationale.md](./Rationale.md)** - Why this project exists
- **[Main README](../README.md)** - Project overview and quick start
- **[DWH_Star_Schema_ERD.md](./DWH_Star_Schema_ERD.md)** - Data model visualization
- **[Troubleshooting_Guide.md](./Troubleshooting_Guide.md)** - Problem resolution

### Script Documentation

- **[bin/dwh/ENTRY_POINTS.md](../bin/dwh/ENTRY_POINTS.md)** - Which scripts can be called directly
- **[bin/dwh/ENVIRONMENT_VARIABLES.md](../bin/dwh/ENVIRONMENT_VARIABLES.md)** - Configuration variables
- **[bin/README.md](../bin/README.md)** - Complete script documentation

### Technical Reference

- **[DWH_Star_Schema_Data_Dictionary.md](./DWH_Star_Schema_Data_Dictionary.md)** - Complete schema reference
- **[ETL_Enhanced_Features.md](./ETL_Enhanced_Features.md)** - ETL capabilities
- **[DWH_Maintenance_Guide.md](./DWH_Maintenance_Guide.md)** - Maintenance procedures

## Documentation Standards

### Markdown Style

All documentation follows these standards:

- **Headers:** Use ATX-style headers (`#`, `##`, `###`)
- **Code blocks:** Use fenced code blocks with language specification
- **Links:** Use reference-style links for readability
- **Lists:** Use `-` for unordered lists, numbers for ordered lists
- **Emphasis:** Use `**bold**` for important terms, `*italic*` for emphasis
- **Tables:** Use GitHub-flavored markdown tables
- **Diagrams:** Use Mermaid for diagrams when possible

### Content Structure

Standard document structure:

1. **Title and Overview**
2. **Table of Contents** (for long documents)
3. **Main Content** (organized by topic)
4. **Examples** (practical demonstrations)
5. **Troubleshooting** (common issues)
6. **References** (related documents)

### Code Examples

All code examples should:

- Be tested and verified
- Include comments explaining key points
- Show realistic use cases
- Follow project coding standards

### Diagrams

- Use Mermaid for architecture and flow diagrams
- Use ASCII art for simple diagrams
- Use external tools only when necessary
- Include diagram source in comments

## Maintenance

### Updating Documentation

When updating documentation:

1. **Keep it accurate:** Update docs when code changes
2. **Be clear:** Write for the intended audience
3. **Add examples:** Show, don't just tell
4. **Test examples:** Verify all code examples work
5. **Update cross-references:** Fix broken links
6. **Version appropriately:** Note what version applies

### Documentation Review

Documentation should be reviewed:

- When features are added or changed
- During code review process
- Quarterly for accuracy
- After major releases

### Documentation Checklist

Before finalizing documentation:

- [ ] Spelling and grammar checked
- [ ] All code examples tested
- [ ] Links verified
- [ ] Diagrams accurate and current
- [ ] Table of contents updated
- [ ] Cross-references correct
- [ ] Version information included
- [ ] Audience appropriate

## Contributing to Documentation

### How to Contribute

1. **Identify gaps:** Find missing or incomplete documentation
2. **Create/update:** Write or update documentation
3. **Test:** Verify all examples and instructions
4. **Submit PR:** Create pull request with changes
5. **Address feedback:** Respond to review comments

### Documentation Issues

Report documentation issues:

- Incorrect information
- Outdated examples
- Broken links
- Confusing explanations
- Missing topics

**Create an issue with:**

- Document name and section
- What's wrong
- Suggested correction
- Your use case

## Tools and Utilities

### Recommended Tools

**Markdown Editors:**

- VSCode with Markdown extensions
- Typora (WYSIWYG)
- MacDown (macOS)
- ReText (Linux)

**Diagram Tools:**

- Mermaid Live Editor
- Draw.io
- PlantUML

**Documentation Linters:**

- markdownlint
- write-good
- proselint

### Validation

Validate documentation:

```bash
# Check markdown syntax
markdownlint docs/*.md

# Check spelling
aspell check docs/*.md

# Validate links
markdown-link-check docs/*.md

# Check code blocks
# Extract and test all code examples
```

## Additional Resources

### Related Documentation

- [Main README](../README.md) - Project overview
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines
- [CHANGELOG.md](../CHANGELOG.md) - Version history
- [bin/README.md](../bin/README.md) - Scripts documentation
- [etc/README.md](../etc/README.md) - Configuration documentation
- [sql/README.md](../sql/README.md) - SQL scripts documentation
- [tests/README.md](../tests/README.md) - Testing documentation

### External Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PostGIS Documentation](https://postgis.net/documentation/)
- [OpenStreetMap API Documentation](https://wiki.openstreetmap.org/wiki/API)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
- [Markdown Guide](https://www.markdownguide.org/)
- [Mermaid Documentation](https://mermaid-js.github.io/)

## Support

For documentation questions:

1. Check if answer is in existing docs
2. Search closed issues for similar questions
3. Create new issue with "documentation" label
4. Provide context about what you're trying to do

## Document History

This documentation structure was established: 2025-10-14

**Major Updates:**

- 2025-10-14: Initial comprehensive documentation structure
- 2025-10-13: Added CI/CD Guide
- 2025-10-12: Enhanced testing documentation
- 2025-08-18: Updated ETL features documentation
- 2025-08-08: Initial star schema documentation

## Feedback

We value your feedback on documentation:

- What's missing?
- What's confusing?
- What examples would help?
- How can we improve?

Please create an issue or contact the maintainers with suggestions.

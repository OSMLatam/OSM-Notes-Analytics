# Documentation Directory

This directory contains comprehensive documentation for the OSM-Notes-Analytics project, including architecture diagrams, data dictionaries, testing guides, and CI/CD documentation.

## Overview

The documentation provides detailed information about the data warehouse design, ETL processes, testing strategies, and development workflows.

## Documentation Index

### Data Warehouse Documentation

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

3. **Datamart Tables:**
   - `dwh.datamartCountries` - Country analytics
   - `dwh.datamartUsers` - User analytics

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

## Quick Reference

### For New Users

**Start here:**

1. [Main README](../README.md) - Project overview and quick start
2. [DWH_Star_Schema_ERD.md](DWH_Star_Schema_ERD.md) - Understand the data model
3. [ETL_Enhanced_Features.md](ETL_Enhanced_Features.md) - Learn about ETL capabilities

### For Developers

**Essential reading:**

1. [tests/README.md](../tests/README.md) - Testing guide and test suite documentation
2. [CI_CD_Guide.md](CI_CD_Guide.md) - Development workflow and CI/CD
3. [DWH_Star_Schema_Data_Dictionary.md](DWH_Star_Schema_Data_Dictionary.md) - Data reference

### For Data Analysts

**Key documents:**

1. [DWH_Star_Schema_Data_Dictionary.md](DWH_Star_Schema_Data_Dictionary.md) - Column definitions
2. [DWH_Star_Schema_ERD.md](DWH_Star_Schema_ERD.md) - Table relationships
3. [ETL_Enhanced_Features.md](ETL_Enhanced_Features.md) - Data freshness and updates

### For DevOps/SRE

**Important guides:**

1. [CI_CD_Guide.md](CI_CD_Guide.md) - Pipeline configuration and workflows
2. [ETL_Enhanced_Features.md](ETL_Enhanced_Features.md) - Performance tuning
3. [tests/README.md](../tests/README.md) - Test automation and execution

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

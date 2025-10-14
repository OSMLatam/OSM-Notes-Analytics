# CI/CD Guide - OSM-Notes-Analytics

**Version**: 2025-10-14  
**Status**: Configured and Active

## 🎯 Overview

This project uses a comprehensive CI/CD system with GitHub Actions, pre-commit hooks, and automated
validation to ensure code quality.

## 📊 GitHub Actions Workflows

### 1. Tests Workflow (`tests.yml`)

**Triggers:**

- Push to `main` or `develop`
- Pull requests to `main` or `develop`
- Manual (`workflow_dispatch`)

**Jobs:**

#### Quality Tests

- Runs shellcheck on all scripts
- Verifies formatting with shfmt
- Validates trailing whitespace and shebangs
- **Duration**: ~2-3 minutes

#### Unit and Integration Tests

- Creates PostgreSQL/PostGIS database in container
- Executes all BATS tests
- Validates DWH integrity
- **Duration**: ~5-7 minutes

#### All Tests Summary

- Combines results from all jobs
- Fails if any test fails

**Status Badge:**

```markdown
![Tests](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Tests/badge.svg)
```

### 2. Quality Checks Workflow (`quality-checks.yml`)

**Triggers:**

- Push to `main` or `develop`
- Pull requests
- Schedule (weekly, Mondays 2am UTC)
- Manual

**Jobs:**

- Separate shellcheck job
- Separate shfmt job
- Separate code quality checks job

**Advantage**: Independent checks make it easier to identify specific issues

### 3. Dependency Check Workflow (`dependency-check.yml`)

**Triggers:**

- Push to `main`
- Pull requests to `main`
- Schedule (monthly, 1st day at 3am UTC)
- Manual

**Jobs:**

- Verifies PostgreSQL compatibility
- Verifies Bash version
- Documents external dependencies

## 🪝 Git Hooks

### Pre-commit Hook

**Location**: `.git-hooks/pre-commit`

**Checks before each commit:**

1. ✅ Shellcheck on staged files
2. ✅ Code formatting (shfmt)
3. ✅ Trailing whitespace
4. ✅ Correct shebangs

**Install:**

```bash
./scripts/install-hooks.sh
```

**Bypass (not recommended):**

```bash
git commit --no-verify
```

### Pre-push Hook

**Location**: `.git-hooks/pre-push`

**Executes before each push:**

1. ✅ All quality tests
2. ✅ DWH tests (if database is available)
3. ⏱️ 5-minute timeout

**Bypass:**

```bash
git push --no-verify
```

## 🔧 Validation Scripts

### install-hooks.sh

Installs git hooks automatically.

```bash
./scripts/install-hooks.sh
```

**Functionality:**

- Creates symlinks in `.git/hooks/`
- Sets executable permissions
- Validates you're in a git repository

### validate-all.sh

Complete project validation.

```bash
./scripts/validate-all.sh
```

**Verifies:**

- ✅ Dependencies (PostgreSQL, Bash, Git)
- ✅ Testing tools (BATS, shellcheck, shfmt)
- ✅ File structure
- ✅ Key files
- ✅ Database connection
- ✅ PostgreSQL extensions
- ✅ Quality tests
- ✅ DWH tests (optional)

**Usage in CI/CD:**

```yaml
- name: Full Validation
  run: ./scripts/validate-all.sh
```

## 📈 Status Badges

Add to README.md:

```markdown
# OSM-Notes-Analytics

![Tests](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Tests/badge.svg)
![Quality Checks](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Quality%20Checks/badge.svg)
![Dependency Check](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Dependency%20Check/badge.svg)

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-12%2B-blue)](https://www.postgresql.org/)
[![PostGIS](https://img.shields.io/badge/PostGIS-3.0%2B-green)](https://postgis.net/)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-orange)](https://www.gnu.org/software/bash/)
```

## 🔄 Development Workflow

### Local Development

1. **Make changes:**

   ```bash
   # Edit files
   vim bin/dwh/ETL.sh
   ```

2. **Validate locally:**

   ```bash
   # Quick tests
   ./tests/run_quality_tests.sh

   # Full tests
   ./tests/run_all_tests.sh
   ```

3. **Commit:**

   ```bash
   git add .
   git commit -m "feat: add new ETL feature"
   # Pre-commit hook runs automatically
   ```

4. **Push:**

   ```bash
   git push origin feature-branch
   # Pre-push hook runs automatically
   ```

### Pull Request

1. **Create PR** on GitHub
2. **GitHub Actions** executes automatically:
   - Tests workflow
   - Quality checks workflow
3. **Review results** on the PR page
4. **Merge** only if all checks pass

### Release

1. **Merge to main:**

   ```bash
   git checkout main
   git merge develop
   git push origin main
   ```

2. **GitHub Actions executes:**
   - All workflows
   - Dependency check
   - Complete validation

3. **Tag release:**

   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

## 🛠️ Configuring Secrets

For jobs that need external database access:

**GitHub → Settings → Secrets → Actions:**

```bash
DB_HOST=your-db-host.com
DB_PORT=5432
DB_USER=analytics_user
DB_PASSWORD=secure_password
DB_NAME=dwh
```

**Usage in workflow:**

```yaml
env:
  PGHOST: ${{ secrets.DB_HOST }}
  PGPORT: ${{ secrets.DB_PORT }}
  PGUSER: ${{ secrets.DB_USER }}
  PGPASSWORD: ${{ secrets.DB_PASSWORD }}
  PGDATABASE: ${{ secrets.DB_NAME }}
```

## 📋 CI/CD Checklist

### Initial Setup

- [x] GitHub Actions workflows created
- [x] Git hooks configured
- [x] Validation scripts created
- [x] Tests configured with default database
- [x] Badges added to README
- [ ] Secrets configured (if needed for external DB)

### Per Developer

- [x] Install git hooks: `./scripts/install-hooks.sh`
- [x] Verify tools: `./scripts/validate-all.sh`
- [x] Run tests locally before push
- [x] Review GitHub Actions results in PRs

### Maintenance

- [ ] Review workflows weekly
- [ ] Update dependencies monthly
- [ ] Monitor execution times
- [ ] Optimize slow tests

## 🔍 Troubleshooting

### Hooks not running

```bash
# Re-install
./scripts/install-hooks.sh

# Verify permissions
ls -la .git/hooks/
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/pre-push
```

### GitHub Actions fails but local passes

1. Verify tool versions
2. Review environment differences
3. Run in Docker container locally:

   ```bash
   docker run -it ubuntu:latest bash
   # Install dependencies and run tests
   ```

### Tests too slow

1. Review GitHub Actions logs
2. Identify slow tests
3. Optimize or parallelize
4. Consider dependency caching

### Pre-push timeout

```bash
# Increase timeout in .git-hooks/pre-push
timeout 600 ./tests/run_dwh_tests.sh  # 10 minutes
```

## 📚 References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [BATS Testing Framework](https://github.com/bats-core/bats-core)
- [ShellCheck](https://www.shellcheck.net/)
- [shfmt](https://github.com/mvdan/sh)
- [Testing Guide](../tests/README.md)

## 🎯 Best Practices

### Do's ✅

- ✅ Run tests locally before push
- ✅ Keep tests fast (<5 min)
- ✅ Use pre-commit hooks for immediate feedback
- ✅ Review GitHub Actions logs
- ✅ Update tests when you change code

### Don'ts ❌

- ❌ Use `--no-verify` routinely
- ❌ Ignore shellcheck warnings
- ❌ Make large commits without tests
- ❌ Merge PRs with failing checks
- ❌ Hardcode secrets in code

## 📊 Metrics

Recommended metrics to monitor:

- **Test execution time**: Target < 5 min
- **PR success rate**: Target > 95%
- **Test coverage**: Document tested files
- **Time to merge**: Minimize with fast CI/CD

## 🚀 Advanced CI/CD Features

### Parallel Job Execution

GitHub Actions runs jobs in parallel when possible:

- Quality checks run independently
- Tests can run on multiple OS (if configured)
- Dependency checks run separately

### Caching

Consider adding caching for faster builds:

```yaml
- name: Cache dependencies
  uses: actions/cache@v3
  with:
    path: ~/.cache
    key: ${{ runner.os }}-deps-${{ hashFiles('**/requirements.txt') }}
```

### Matrix Testing

Test across multiple configurations:

```yaml
strategy:
  matrix:
    postgres: [12, 13, 14, 15]
    postgis: [3.0, 3.1, 3.2]
```

### Notifications

Configure notifications for failed builds:

- GitHub email notifications (default)
- Slack integration
- Custom webhooks

## 🔒 Security

### Best Practices

- ✅ Never commit credentials
- ✅ Use GitHub Secrets for sensitive data
- ✅ Rotate secrets regularly
- ✅ Limit secret access to necessary workflows
- ✅ Review dependencies for vulnerabilities

### Security Scanning

Consider adding:

```yaml
- name: Security scan
  uses: securego/gosec@master
```

## 📝 Contributing to CI/CD

When improving CI/CD:

1. Test changes in a fork first
2. Document changes in this guide
3. Update relevant scripts
4. Test in multiple scenarios
5. Create PR with clear description

---

**Last Updated**: 2025-10-14  
**Maintainer**: Andres Gomez (AngocA)

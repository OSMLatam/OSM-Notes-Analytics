# CI/CD Guide - OSM-Notes-Analytics

**Version**: 2025-10-14  
**Status**: Configurado y Activo

## 🎯 Overview

Este proyecto utiliza un sistema completo de CI/CD con GitHub Actions, pre-commit hooks, y validación automatizada para garantizar la calidad del código.

## 📊 Workflows de GitHub Actions

### 1. Tests Workflow (`tests.yml`)

**Triggers:**
- Push a `main` o `develop`
- Pull requests a `main` o `develop`
- Manual (`workflow_dispatch`)

**Jobs:**

#### Quality Tests
- Ejecuta shellcheck en todos los scripts
- Verifica formato con shfmt
- Valida trailing whitespace y shebangs
- **Duración**: ~2-3 minutos

#### Unit and Integration Tests
- Crea base de datos PostgreSQL/PostGIS en container
- Ejecuta todos los tests BATS
- Valida integridad de DWH
- **Duración**: ~5-7 minutos

#### All Tests Summary
- Combina resultados de todos los jobs
- Falla si cualquier test falla

**Status Badge:**
```markdown
![Tests](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Tests/badge.svg)
```

### 2. Quality Checks Workflow (`quality-checks.yml`)

**Triggers:**
- Push a `main` o `develop`
- Pull requests
- Schedule (semanal, lunes 2am UTC)
- Manual

**Jobs:**
- Shellcheck separado
- Shfmt separado
- Code quality checks separado

**Ventaja**: Checks independientes, más fácil identificar problemas

### 3. Dependency Check Workflow (`dependency-check.yml`)

**Triggers:**
- Push a `main`
- Pull requests a `main`
- Schedule (mensual, día 1 a las 3am UTC)
- Manual

**Jobs:**
- Verifica compatibilidad PostgreSQL
- Verifica versión de Bash
- Documenta dependencias externas

## 🪝 Git Hooks

### Pre-commit Hook

**Ubicación**: `.git-hooks/pre-commit`

**Verifica antes de cada commit:**
1. ✅ Shellcheck en archivos staged
2. ✅ Formato de código (shfmt)
3. ✅ Trailing whitespace
4. ✅ Shebangs correctos

**Instalar:**
```bash
./scripts/install-hooks.sh
```

**Bypass (no recomendado):**
```bash
git commit --no-verify
```

### Pre-push Hook

**Ubicación**: `.git-hooks/pre-push`

**Ejecuta antes de cada push:**
1. ✅ Todos los quality tests
2. ✅ DWH tests (si la BD está disponible)
3. ⏱️ Timeout de 5 minutos

**Bypass:**
```bash
git push --no-verify
```

## 🔧 Scripts de Validación

### install-hooks.sh

Instala git hooks automáticamente.

```bash
./scripts/install-hooks.sh
```

**Funcionalidad:**
- Crea symlinks en `.git/hooks/`
- Configura permisos ejecutables
- Valida que estás en un repo git

### validate-all.sh

Validación completa del proyecto.

```bash
./scripts/validate-all.sh
```

**Verifica:**
- ✅ Dependencias (PostgreSQL, Bash, Git)
- ✅ Herramientas de testing (BATS, shellcheck, shfmt)
- ✅ Estructura de archivos
- ✅ Archivos clave
- ✅ Conexión a base de datos
- ✅ Extensiones PostgreSQL
- ✅ Quality tests
- ✅ DWH tests (opcional)

**Uso en CI/CD:**
```yaml
- name: Full Validation
  run: ./scripts/validate-all.sh
```

## 📈 Status Badges

Agregar al README.md:

```markdown
# OSM-Notes-Analytics

![Tests](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Tests/badge.svg)
![Quality Checks](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Quality%20Checks/badge.svg)
![Dependency Check](https://github.com/OSMLatam/OSM-Notes-Analytics/workflows/Dependency%20Check/badge.svg)

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-12%2B-blue)](https://www.postgresql.org/)
[![PostGIS](https://img.shields.io/badge/PostGIS-3.0%2B-green)](https://postgis.net/)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-orange)](https://www.gnu.org/software/bash/)
```

## 🔄 Workflow de Desarrollo

### Desarrollo Local

1. **Hacer cambios:**
   ```bash
   # Editar archivos
   vim bin/dwh/ETL.sh
   ```

2. **Validar localmente:**
   ```bash
   # Tests rápidos
   ./tests/run_quality_tests.sh
   
   # Tests completos
   ./tests/run_all_tests.sh
   ```

3. **Commit:**
   ```bash
   git add .
   git commit -m "feat: add new ETL feature"
   # Pre-commit hook se ejecuta automáticamente
   ```

4. **Push:**
   ```bash
   git push origin feature-branch
   # Pre-push hook se ejecuta automáticamente
   ```

### Pull Request

1. **Crear PR** en GitHub
2. **GitHub Actions** ejecuta automáticamente:
   - Tests workflow
   - Quality checks workflow
3. **Revisar resultados** en la página del PR
4. **Merge** solo si todos los checks pasan

### Release

1. **Merge a main:**
   ```bash
   git checkout main
   git merge develop
   git push origin main
   ```

2. **GitHub Actions ejecuta:**
   - Todos los workflows
   - Dependency check
   - Validación completa

3. **Tag release:**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

## 🛠️ Configuración de Secrets

Para jobs que necesiten acceso a BD externa:

**GitHub → Settings → Secrets → Actions:**

```
DB_HOST=your-db-host.com
DB_PORT=5432
DB_USER=analytics_user
DB_PASSWORD=secure_password
DB_NAME=dwh
```

**Uso en workflow:**
```yaml
env:
  PGHOST: ${{ secrets.DB_HOST }}
  PGPORT: ${{ secrets.DB_PORT }}
  PGUSER: ${{ secrets.DB_USER }}
  PGPASSWORD: ${{ secrets.DB_PASSWORD }}
  PGDATABASE: ${{ secrets.DB_NAME }}
```

## 📋 Checklist de CI/CD

### Setup Inicial
- [x] Workflows de GitHub Actions creados
- [x] Git hooks configurados
- [x] Scripts de validación creados
- [x] Tests configurados con BD por defecto
- [ ] Badges agregados al README
- [ ] Secrets configurados (si es necesario)

### Por Desarrollador
- [x] Instalar git hooks: `./scripts/install-hooks.sh`
- [x] Verificar tools: `./scripts/validate-all.sh`
- [x] Ejecutar tests localmente antes de push
- [x] Revisar resultados de GitHub Actions en PRs

### Mantenimiento
- [ ] Revisar workflows semanalmente
- [ ] Actualizar dependencias mensualmente
- [ ] Monitorear tiempos de ejecución
- [ ] Optimizar tests lentos

## 🔍 Troubleshooting

### Los hooks no se ejecutan

```bash
# Re-instalar
./scripts/install-hooks.sh

# Verificar permisos
ls -la .git/hooks/
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/pre-push
```

### GitHub Actions falla pero local pasa

1. Verificar versiones de herramientas
2. Revisar diferencias de entorno
3. Ejecutar en container Docker localmente:
   ```bash
   docker run -it ubuntu:latest bash
   # Instalar dependencias y ejecutar tests
   ```

### Tests muy lentos

1. Revisar logs de GitHub Actions
2. Identificar tests lentos
3. Optimizar o paralelizar
4. Considerar cache de dependencias

### Pre-push timeout

```bash
# Incrementar timeout en .git-hooks/pre-push
timeout 600 ./tests/run_dwh_tests.sh  # 10 minutos
```

## 📚 Referencias

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [BATS Testing Framework](https://github.com/bats-core/bats-core)
- [ShellCheck](https://www.shellcheck.net/)
- [shfmt](https://github.com/mvdan/sh)

## 🎯 Mejores Prácticas

### Do's ✅
- ✅ Ejecutar tests localmente antes de push
- ✅ Mantener tests rápidos (<5 min)
- ✅ Usar pre-commit hooks para feedback inmediato
- ✅ Revisar logs de GitHub Actions
- ✅ Actualizar tests cuando cambies código

### Don'ts ❌
- ❌ Usar `--no-verify` rutinariamente
- ❌ Ignorar warnings de shellcheck
- ❌ Hacer commits grandes sin tests
- ❌ Merge PRs con checks fallidos
- ❌ Hardcodear secrets en código

## 📊 Métricas

Métricas recomendadas para monitorear:

- **Tiempo de ejecución de tests**: Objetivo < 5 min
- **Tasa de éxito de PRs**: Objetivo > 95%
- **Cobertura de tests**: Documentar archivos testeados
- **Tiempo hasta merge**: Minimizar con CI/CD rápido

---

**Última actualización**: 2025-10-14  
**Mantenedor**: Andres Gomez (AngocA)



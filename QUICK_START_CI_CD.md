# 🚀 Quick Start - CI/CD

**5 minutos para empezar**

## 1️⃣ Instalar Git Hooks (1 vez)

```bash
./scripts/install-hooks.sh
```

**Esto configura:**
- ✅ Pre-commit hook (validación antes de commit)
- ✅ Pre-push hook (tests antes de push)

## 2️⃣ Desarrollo Diario

### Hacer cambios normalmente

```bash
# Editar archivos
vim bin/dwh/ETL.sh

# Commit - hooks se ejecutan automáticamente
git add .
git commit -m "feat: nueva funcionalidad"
# ↑ Pre-commit verifica: shellcheck, formato, trailing whitespace

# Push - tests completos antes de enviar
git push origin mi-rama
# ↑ Pre-push ejecuta: quality tests + DWH tests
```

### Bypass hooks (⚠️ solo en emergencias)

```bash
git commit --no-verify
git push --no-verify
```

## 3️⃣ Verificar Calidad del Código

### Antes de commit

```bash
# Tests rápidos (30 segundos)
./tests/run_quality_tests.sh
```

### Antes de PR

```bash
# Tests completos (2 minutos)
./tests/run_all_tests.sh
```

### Validación completa

```bash
# Todo el sistema (3 minutos)
./scripts/validate-all.sh
```

## 4️⃣ GitHub Actions

### Automático en cada PR

Cuando crees un PR, GitHub ejecuta automáticamente:
- ✅ Quality tests
- ✅ Unit tests
- ✅ Integration tests

Ver resultados en: **PR → Checks tab**

### Manual

1. Ve a **Actions** tab en GitHub
2. Selecciona workflow
3. Click **Run workflow**

## 5️⃣ Solución de Problemas

### Hooks no funcionan

```bash
./scripts/install-hooks.sh
```

### Tests fallan localmente

```bash
# Ver detalles
./tests/run_quality_tests.sh 2>&1 | less

# DWH tests
./tests/run_dwh_tests.sh 2>&1 | less
```

### GitHub Actions falla pero local pasa

1. Verifica versiones de herramientas
2. Revisa logs en GitHub
3. Ejecuta `./scripts/validate-all.sh`

## 📋 Cheat Sheet

```bash
# Instalar hooks (1 vez)
./scripts/install-hooks.sh

# Validación completa
./scripts/validate-all.sh

# Tests rápidos
./tests/run_quality_tests.sh

# Tests con BD
./tests/run_dwh_tests.sh

# Todos los tests
./tests/run_all_tests.sh

# Ver workflows disponibles
ls .github/workflows/

# Ver hooks instalados
ls -la .git/hooks/
```

## 🎯 Mejores Prácticas

### ✅ DO
- Ejecutar `run_quality_tests.sh` antes de commit
- Revisar resultados de GitHub Actions
- Mantener tests pasando en local
- Usar hooks para feedback inmediato

### ❌ DON'T
- Usar `--no-verify` rutinariamente
- Ignorar warnings de shellcheck
- Hacer commits sin ejecutar tests
- Merge PRs con checks fallidos

## 📚 Más Información

- **Guía completa**: [docs/CI_CD_Guide.md](docs/CI_CD_Guide.md)
- **Setup completo**: [CI_CD_SETUP_SUMMARY.md](CI_CD_SETUP_SUMMARY.md)
- **Tests**: [tests/README.md](tests/README.md)

---

**¿Dudas?** Lee la [Guía Completa de CI/CD](docs/CI_CD_Guide.md)


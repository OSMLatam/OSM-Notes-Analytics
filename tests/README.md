# OSM-Notes-Analytics Tests

Esta carpeta contiene las pruebas para el proyecto OSM-Notes-Analytics.

## Tipos de Pruebas

### 1. Quality Tests (Pruebas de Calidad)

Estas pruebas **NO requieren base de datos** y verifican la calidad del código:

- **Shellcheck**: Análisis estático de scripts bash
- **Shfmt**: Verificación de formato de código
- **Trailing whitespace**: Detección de espacios al final de líneas
- **Shebangs**: Verificación de encabezados correctos

```bash
# Ejecutar solo pruebas de calidad
./tests/run_quality_tests.sh
```

### 2. DWH Tests (Pruebas de Data Warehouse)

Estas pruebas **SÍ requieren base de datos** y verifican:

- Funcionalidad del ETL
- Creación de tablas dimensionales
- Procedimientos almacenados
- Integridad de datos

```bash
# Ejecutar pruebas de DWH/ETL
./tests/run_dwh_tests.sh
```

### 3. All Tests (Todas las Pruebas)

Ejecuta todas las pruebas en secuencia:

```bash
# Ejecutar todas las pruebas
./tests/run_all_tests.sh
```

## Requisitos Previos

### Para Quality Tests (Sin BD)

```bash
# Instalar shellcheck
sudo apt-get install shellcheck

# Instalar shfmt
wget -O shfmt https://github.com/mvdan/sh/releases/download/v3.7.0/shfmt_v3.7.0_linux_amd64
chmod +x shfmt
sudo mv shfmt /usr/local/bin/
```

### Para DWH Tests (Con BD)

```bash
# Instalar BATS (Bash Automated Testing System)
sudo apt-get install bats

# O instalación manual:
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

**Requisitos de Base de Datos:**

1. **PostgreSQL** 12+ con **PostGIS**
2. **Base de datos de ingesta**: El sistema de Analytics lee de las tablas base creadas por [OSM-Notes-profile](https://github.com/angoca/OSM-Notes-profile)
3. **Usuario con permisos** para crear esquemas y tablas

```bash
# Crear base de datos de prueba
createdb osm_notes_test

# Instalar extensiones
psql -d osm_notes_test -c "CREATE EXTENSION IF NOT EXISTS postgis;"
psql -d osm_notes_test -c "CREATE EXTENSION IF NOT EXISTS btree_gist;"
```

## Estructura de Tests

```
tests/
├── unit/
│   ├── bash/              # Tests unitarios de scripts bash
│   │   ├── ETL_integration.test.bats
│   │   ├── ETL_enhanced.test.bats
│   │   ├── datamartUsers_integration.test.bats
│   │   └── datamartCountries_integration.test.bats
│   └── sql/               # Tests unitarios de SQL
│       ├── dwh_cleanup.test.sql
│       ├── dwh_dimensions_enhanced.test.sql
│       └── dwh_functions_enhanced.test.sql
├── integration/           # Tests de integración
│   ├── ETL_enhanced_integration.test.bats
│   └── datamart_enhanced_integration.test.bats
├── test_helper.bash       # Funciones de ayuda para tests
├── properties.sh          # Configuración de tests
├── run_quality_tests.sh   # Ejecutor de quality tests
├── run_dwh_tests.sh       # Ejecutor de DWH tests
├── run_all_tests.sh       # Ejecutor de todos los tests
└── README.md              # Esta documentación
```

## Configuración

### Variables de Entorno para Tests

Las pruebas usan el archivo `tests/properties.sh` para configuración:

```bash
# Database de prueba (por defecto)
export TEST_DBNAME="dwh"        # Base de datos por defecto
export TEST_DBUSER="$(whoami)"  # Usuario actual en host
export TEST_DBHOST=""           # Conexión local
export TEST_DBPORT=""           # Puerto por defecto

# ETL configuration para tests
export ETL_BATCH_SIZE="100"           # Lotes pequeños
export ETL_PARALLEL_ENABLED="false"   # Secuencial en tests
export ETL_VALIDATE_INTEGRITY="true"  # Siempre validar
```

### Personalizar Configuración

El valor por defecto es `dwh`. Si necesitas usar otra base de datos:

```bash
# Usar base de datos diferente temporalmente
TEST_DBNAME="mi_bd_test" ./tests/run_dwh_tests.sh

# O exportar para toda la sesión
export TEST_DBNAME="mi_bd_test"
./tests/run_dwh_tests.sh

# Habilitar debug
export TEST_DEBUG="true"
./tests/run_dwh_tests.sh
```

## ¿Necesito Base de Datos?

### ❌ NO necesitas BD para:

- `run_quality_tests.sh` - Pruebas de calidad de código
- Verificar formato con shellcheck y shfmt
- Validar sintaxis de scripts

### ✅ SÍ necesitas BD para:

- `run_dwh_tests.sh` - Pruebas de DWH/ETL
- Tests de integración
- Tests que verifican SQL y procedimientos

**Importante**: Los tests de DWH requieren que las **tablas base** existan:
- `notes`
- `note_comments`
- `note_comments_text`
- `users`
- `countries`

Estas tablas son creadas por el sistema de ingesta ([OSM-Notes-profile](https://github.com/angoca/OSM-Notes-profile)).

## Ejemplos de Uso

### Ejecutar Solo Quality Tests (Sin BD)

```bash
# Más rápido, no requiere BD
cd /home/angoca/github/OSM-Notes-Analytics
./tests/run_quality_tests.sh
```

### Ejecutar Tests de DWH (Con BD)

```bash
# Los tests usan la BD 'dwh' por defecto
# Si aún no existe, créala:
createdb dwh
psql -d dwh -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# Ejecutar tests (usa 'dwh' automáticamente)
cd /home/angoca/github/OSM-Notes-Analytics
./tests/run_dwh_tests.sh
```

### Ejecutar Test Específico con BATS

```bash
# Test individual
bats tests/unit/bash/ETL_integration.test.bats

# Con verbose para más detalle
bats -t tests/unit/bash/ETL_integration.test.bats
```

### Ejecutar Todos los Tests

```bash
# Ejecuta quality + DWH tests en secuencia
./tests/run_all_tests.sh
```

## Interpretación de Resultados

### Quality Tests

```
✅ Shellcheck passed for Analytics scripts
✅ Format check passed for Analytics scripts
✅ No trailing whitespace found
✅ All shebangs are correct
```

### DWH Tests

```
✅ ETL_integration.test.bats passed
✅ ETL_enhanced.test.bats passed
✅ datamartUsers_integration.test.bats passed
```

## Troubleshooting

### Error: "BATS not found"

```bash
# Instalar BATS
sudo apt-get install bats
```

### Error: "Database connection failed"

```bash
# Verificar que PostgreSQL está corriendo
systemctl status postgresql

# Verificar que la BD existe
psql -l | grep osm_notes_test

# Crear BD si no existe
createdb osm_notes_test
```

### Error: "shellcheck not found"

```bash
# Instalar shellcheck
sudo apt-get install shellcheck
```

### Tests fallan por falta de tablas base

Los tests de DWH necesitan las tablas base del sistema de ingesta. Si no existen:

1. **Opción 1**: Ejecutar solo Quality Tests (no requieren BD)
   ```bash
   ./tests/run_quality_tests.sh
   ```

2. **Opción 2**: Instalar el sistema de ingesta primero
   - Clonar [OSM-Notes-profile](https://github.com/angoca/OSM-Notes-profile)
   - Ejecutar la ingesta para crear tablas base

3. **Opción 3**: Los tests crean tablas mínimas automáticamente
   - El `test_helper.bash` crea estructuras básicas para tests

## Integración Continua (CI/CD)

Los tests se ejecutan automáticamente en GitHub Actions:

- **Quality Tests**: En cada push/PR
- **Integration Tests**: En entornos Docker con BD real

Ver: `.github/workflows/quality-tests.yml`

## Contribuir

Al agregar nuevas funcionalidades:

1. **Agregar tests unitarios** en `tests/unit/bash/`
2. **Agregar tests de integración** en `tests/integration/`
3. **Verificar que pasan** antes de commit:
   ```bash
   ./tests/run_all_tests.sh
   ```

## Recursos Adicionales

- [Testing Guide](../docs/Testing_Guide.md) - Guía completa de testing
- [Quality Testing](../docs/QUALITY_TESTING.md) - Estrategia de calidad
- [BATS Documentation](https://bats-core.readthedocs.io/) - Documentación BATS

---

**Última actualización**: 2025-10-14


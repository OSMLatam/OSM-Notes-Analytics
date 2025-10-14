# Configuración de Base de Datos para Tests

## Base de Datos: `dwh`

Tu base de datos está configurada y lista para usar con los tests.

## Configuración Actual ✅

**Ya está configurado por defecto** para usar la base de datos `dwh`.

En `tests/properties.sh` línea 36:
```bash
export TEST_DBNAME="${TEST_DBNAME:-dwh}"
```

### Si necesitas usar otra base de datos

Solo si necesitas usar una BD diferente temporalmente:

```bash
# Opción 1: Variable temporal
TEST_DBNAME="otra_bd" ./tests/run_dwh_tests.sh

# Opción 2: Exportar para toda la sesión
export TEST_DBNAME="otra_bd"
./tests/run_dwh_tests.sh
```

### Opción 3: Archivo de Configuración Local

Crea un archivo `tests/properties.local.sh`:

```bash
#!/bin/bash
# Local configuration override
export TEST_DBNAME="dwh"
export TEST_DEBUG="true"  # Opcional: para ver más debug
```

Luego modifica `tests/properties.sh` para cargar este archivo (al final):

```bash
# Cargar configuración local si existe
if [[ -f "${BASH_SOURCE[0]%/*}/properties.local.sh" ]]; then
 source "${BASH_SOURCE[0]%/*}/properties.local.sh"
fi
```

## Verificar Configuración

```bash
# Ver qué base de datos se usará
export TEST_DBNAME="dwh"
psql -d "${TEST_DBNAME}" -c "SELECT current_database();"
```

## Extensiones Necesarias

✅ Tu base de datos `dwh` ya tiene:
- `postgis` - Para operaciones geográficas
- `btree_gist` - Para índices especiales
- `plpgsql` - Lenguaje procedural

## Ejecutar Tests

### Tests de Calidad (sin BD)
```bash
./tests/run_quality_tests.sh
```

### Tests de DWH (con BD)
```bash
# Ya configurado para usar 'dwh' automáticamente
./tests/run_dwh_tests.sh

# Todos los tests
./tests/run_all_tests.sh
```

## Conexión Local vs Remota

### Local (peer authentication) - Configuración Actual
```bash
# No requiere host, port, user, password
export TEST_DBNAME="dwh"
# Se conecta como el usuario actual del sistema
```

### Remota (si necesitas conectarte a otro servidor)
```bash
export TEST_DBNAME="dwh"
export TEST_DBHOST="localhost"
export TEST_DBPORT="5432"
export TEST_DBUSER="myuser"
export TEST_DBPASSWORD="mypassword"
```

## Estado Actual

✅ Base de datos: `dwh`
✅ Extensiones instaladas: postgis, btree_gist
✅ Usuario: `$(whoami)` (autenticación peer)
✅ Conexión: Local

## Ejecutar Tests Ahora

Ya está todo configurado, simplemente ejecuta:

1. Tests de DWH:
   ```bash
   ./tests/run_dwh_tests.sh
   ```

2. Todos los tests:
   ```bash
   ./tests/run_all_tests.sh
   ```

3. Solo calidad (sin BD):
   ```bash
   ./tests/run_quality_tests.sh
   ```

---

**Nota**: Los tests crearán esquemas y tablas temporales en tu base de datos `dwh`. 
No afectarán datos existentes, ya que usan sus propios esquemas para testing.


# Análisis de Estrategia de Concurrencia PostgreSQL

## Resumen Ejecutivo

Este documento analiza la implementación actual de estrategias de concurrencia PostgreSQL en el
proyecto OSM-Notes-Analytics, específicamente para las consultas que extraen datos de las tablas del
proyecto hermano (ingestion): `notes`, `note_comments`, `note_comments_text`, `users`, y
`countries`.

## Estado Actual de Implementación

### ✅ 1. PGAPPNAME - Implementado

**Estado**: ✅ Implementado y funcionando correctamente

**Ubicación actual**:

- `bin/dwh/ETL.sh`: Función `__psql_with_appname` que configura `PGAPPNAME` automáticamente
- `bin/dwh/datamartCountries/datamartCountries.sh`: Usa la función `__psql_with_appname`
- `bin/dwh/datamartGlobal/datamartGlobal.sh`: Usa la función `__psql_with_appname`
- `bin/dwh/datamartUsers/datamartUsers.sh`: Usa la función `__psql_with_appname`

**Función utilizada**: `__psql_with_appname` en `ETL.sh` (líneas 273-350)

**Valores actuales**:

- ETL.sh usa: `"ETL"`, `"ETL-year-{year}"`, etc.
- Datamart scripts usan: nombre del script (ej: `"datamartCountries"`)

**Decisión**: Se mantiene el comportamiento actual ya que es funcional y permite identificar
claramente cada proceso en `pg_stat_activity`.

---

### ✅ 2. Transacciones READ ONLY - Parcialmente Implementado

**Estado**: ✅ Implementado donde es posible

**Análisis**:

- Las consultas a las tablas del proyecto ingestion se realizan principalmente a través de:
  1. **Foreign Data Wrappers (FDW)**: Cuando `DBNAME_INGESTION != DBNAME_DWH`
  2. **Acceso directo**: Cuando ambas bases de datos son la misma

**Archivos que consultan tablas ingestion**:

- `sql/dwh/Staging_32_createStagingObjects.sql`: Consulta `note_comments`, `notes`,
  `note_comments_text`, `countries`, `users`
- `sql/dwh/Staging_34_initialFactsLoadCreate.sql`: Consulta las mismas tablas
- `sql/dwh/Staging_35_initialFactsLoadExecute_Simple.sql`: Consulta las mismas tablas
- `sql/dwh/Staging_61_loadNotes.sql`: Consulta `note_comments`
- `sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql`: Consulta `note_comments`,
  `note_comments_text`
- `sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql`: Consulta `note_comments`,
  `note_comments_text`

**Procedimientos almacenados que consultan**:

- `staging.process_notes_at_date()`: Consulta `note_comments`, `notes`, `note_comments_text`
- `staging.process_notes_actions_into_dwh()`: Consulta `note_comments`
- `dwh.update_datamart_country()`: Consulta `note_comments`, `note_comments_text`
- `dwh.update_datamart_user()`: Consulta `note_comments`, `note_comments_text`

**Implementación realizada**:

1. **Scripts SQL directos**: ✅ Implementado
   - `sql/dwh/Staging_61_loadNotes.sql`: Las consultas SELECT a `note_comments` ahora están
     envueltas en bloques `BEGIN READ ONLY; ... COMMIT;`

2. **Procedimientos almacenados**: ⚠️ Limitado por diseño
   - Los procedimientos que consultan tablas ingestion (`staging.process_notes_at_date`,
     `staging.process_notes_actions_into_dwh`, `dwh.update_datamart_country`,
     `dwh.update_datamart_user`) también realizan escrituras (INSERT/UPDATE), por lo que no pueden
     usar READ ONLY en toda la transacción
   - Se agregaron comentarios documentando que las consultas SELECT a tablas ingestion deberían ser
     READ ONLY cuando sea posible
   - Las consultas SELECT dentro de estos procedimientos están documentadas para indicar que leen de
     tablas ingestion

**Limitaciones**:

- En PostgreSQL, READ ONLY es una propiedad de la transacción completa, no de subconsultas
  individuales
- Los procedimientos que hacen tanto lectura como escritura no pueden usar READ ONLY para toda la
  transacción
- La mejor práctica es documentar las consultas SELECT que leen de ingestion tables y confiar en que
  el servidor remoto (si es FDW) maneje READ ONLY cuando sea posible

---

### ✅ 3. Timeouts - Implementado

**Estado**: ✅ Implementado

**Timeouts configurados**:

- `statement_timeout`: Limita el tiempo de ejecución de una sentencia individual (default: `30min`)
- `lock_timeout`: Limita el tiempo de espera para adquirir un lock (default: `10s`)
- `idle_in_transaction_session_timeout`: Limita el tiempo que una transacción puede estar idle
  (default: `10min`)

**Implementación realizada**:

1. **Variables de configuración**: ✅ Agregadas en `etc/properties.sh`
   - `PSQL_STATEMENT_TIMEOUT`: `30min` (configurable)
   - `PSQL_LOCK_TIMEOUT`: `10s` (configurable)
   - `PSQL_IDLE_IN_TRANSACTION_TIMEOUT`: `10min` (configurable)

2. **Función `__psql_with_appname`**: ✅ Modificada para aplicar timeouts automáticamente
   - Los timeouts se aplican automáticamente a todas las consultas ejecutadas a través de
     `__psql_with_appname`
   - Para archivos SQL (`-f`): Se crea un archivo temporal con los SET statements de timeout al
     inicio
   - Para comandos SQL (`-c`): Se prependen los SET statements de timeout al comando
   - Los archivos temporales se limpian automáticamente después de la ejecución

**Valores por defecto** (configurables en `etc/properties.sh`):

- `statement_timeout`: `30min`
- `lock_timeout`: `10s`
- `idle_in_transaction_session_timeout`: `10min`

---

## Puntos Específicos de Implementación

### A. Función `__psql_with_appname` en `ETL.sh`

**Ubicación**: `bin/dwh/ETL.sh`, líneas 273-288

**Cambios propuestos**:

```bash
function __psql_with_appname {
  local appname
  local readonly_mode="${PSQL_READONLY:-false}"
  local timeout_statement="${PSQL_STATEMENT_TIMEOUT:-}"
  local timeout_lock="${PSQL_LOCK_TIMEOUT:-}"

  if [[ "${1:-}" =~ ^- ]]; then
    appname="${BASENAME}"
  else
    appname="${1:-osm_notes_etl}"
    shift
  fi

  # Build psql command with timeouts and readonly if needed
  local psql_cmd="PGAPPNAME=\"${appname}\" psql"

  # Add timeout options if provided
  if [[ -n "${timeout_statement}" ]]; then
    psql_cmd="${psql_cmd} -v statement_timeout=\"${timeout_statement}\""
  fi
  if [[ -n "${timeout_lock}" ]]; then
    psql_cmd="${psql_cmd} -v lock_timeout=\"${timeout_lock}\""
  fi

  # Execute with readonly transaction wrapper if needed
  if [[ "${readonly_mode}" == "true" ]]; then
    eval "${psql_cmd}" -c "BEGIN READ ONLY; $(cat); COMMIT;" "$@"
  else
    eval "${psql_cmd}" "$@"
  fi
}
```

### B. Procedimientos Almacenados que Consultan Tablas Ingestion

**Archivos a modificar**:

1. **`sql/dwh/Staging_32_createStagingObjects.sql`**
   - Procedimiento: `staging.process_notes_at_date()`
   - Líneas: 50-350 (aproximadamente)
   - Agregar al inicio: `SET TRANSACTION READ ONLY;` (dentro del procedimiento)

2. **`sql/dwh/Staging_32_createStagingObjects.sql`**
   - Procedimiento: `staging.process_notes_actions_into_dwh()`
   - Líneas: 356-477 (aproximadamente)
   - Agregar: `SET TRANSACTION READ ONLY;` para consultas de lectura

3. **`sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql`**
   - Procedimiento: `dwh.update_datamart_country()`
   - Agregar: `SET TRANSACTION READ ONLY;` para las consultas SELECT

4. **`sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql`**
   - Procedimiento: `dwh.update_datamart_user()`
   - Agregar: `SET TRANSACTION READ ONLY;` para las consultas SELECT

**Nota importante**: Los procedimientos que hacen INSERT/UPDATE no pueden usar READ ONLY para toda
la transacción, pero las consultas SELECT dentro de ellos pueden ejecutarse en sub-transacciones
READ ONLY.

### C. Scripts SQL Ejecutados Directamente

**Archivos a modificar**:

1. **`sql/dwh/Staging_61_loadNotes.sql`**
   - Líneas 8-12 y 22-26: Consultas SELECT a `note_comments`
   - Envolver en: `BEGIN READ ONLY; ... COMMIT;`

2. **`sql/dwh/ETL_60_setupFDW.sql`**
   - Líneas 130-134: Comandos ANALYZE en foreign tables
   - Estos son comandos de mantenimiento, no necesitan READ ONLY

### D. Configuración de Timeouts en Propiedades

**Archivo a modificar**: `etc/properties.sh` o crear `etc/etl.properties`

**Agregar variables**:

```bash
# PostgreSQL timeouts for ETL queries
PSQL_STATEMENT_TIMEOUT="${PSQL_STATEMENT_TIMEOUT:-30min}"
PSQL_LOCK_TIMEOUT="${PSQL_LOCK_TIMEOUT:-10s}"
PSQL_IDLE_IN_TRANSACTION_TIMEOUT="${PSQL_IDLE_IN_TRANSACTION_TIMEOUT:-10min}"

# Use READ ONLY transactions for ingestion table queries
PSQL_READONLY_FOR_INGESTION="${PSQL_READONLY_FOR_INGESTION:-true}"

# Application name for PostgreSQL connections
PSQL_APPNAME="${PSQL_APPNAME:-osm_notes_etl}"
```

---

## Estrategia de Implementación Recomendada

### Fase 1: Configuración Base

1. ✅ Actualizar `__psql_with_appname` para usar `PGAPPNAME="osm_notes_etl"` por defecto
2. ✅ Agregar variables de configuración en `etc/properties.sh`
3. ✅ Implementar soporte para timeouts en `__psql_with_appname`

### Fase 2: Transacciones READ ONLY

1. ✅ Modificar procedimientos almacenados que solo leen datos
2. ✅ Envolver consultas SELECT directas en bloques READ ONLY
3. ✅ Agregar READ ONLY a subconsultas dentro de procedimientos que también escriben

### Fase 3: Timeouts

1. ✅ Configurar timeouts por defecto en `__psql_with_appname`
2. ✅ Agregar timeouts a procedimientos almacenados críticos
3. ✅ Documentar valores recomendados según el tamaño de datos

### Fase 4: Testing y Validación

1. ✅ Verificar que las consultas funcionan correctamente con READ ONLY
2. ✅ Validar que los timeouts no interrumpen operaciones normales
3. ✅ Monitorear `pg_stat_activity` para verificar `application_name`

---

## Consideraciones Especiales

### Foreign Data Wrappers (FDW)

Cuando se usan FDW para acceder a las tablas ingestion:

- Las consultas READ ONLY en el lado del DWH no garantizan READ ONLY en el servidor remoto
- El servidor remoto (ingestion) debe configurar sus propios timeouts y READ ONLY
- La configuración de `FDW_INGESTION_USER` ya usa `analytics_readonly` (buena práctica)

### Consultas en Procedimientos que Escriben

Algunos procedimientos hacen tanto lectura como escritura:

- `staging.process_notes_at_date()`: Lee de ingestion, escribe en DWH
- `staging.process_notes_actions_into_dwh()`: Lee de ingestion, escribe en DWH

**Estrategia**: Usar sub-transacciones READ ONLY solo para las consultas SELECT a tablas ingestion,
no para toda la transacción.

### Compatibilidad con Misma Base de Datos

Cuando `DBNAME_INGESTION == DBNAME_DWH`:

- Las tablas son locales, no foreign tables
- READ ONLY sigue siendo beneficioso para evitar locks innecesarios
- Los timeouts aplican igualmente

---

## Archivos que Requieren Modificaciones

### Scripts Bash

- `bin/dwh/ETL.sh`: Función `__psql_with_appname`
- `bin/dwh/datamartCountries/datamartCountries.sh`: Usar función actualizada
- `bin/dwh/datamartGlobal/datamartGlobal.sh`: Usar función actualizada
- `bin/dwh/datamartUsers/datamartUsers.sh`: Usar función actualizada

### Archivos SQL

- `sql/dwh/Staging_32_createStagingObjects.sql`: Procedimientos `process_notes_at_date` y
  `process_notes_actions_into_dwh`
- `sql/dwh/Staging_61_loadNotes.sql`: Consultas SELECT
- `sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql`: Procedimiento
  `update_datamart_country`
- `sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql`: Procedimiento `update_datamart_user`

### Archivos de Configuración

- `etc/properties.sh`: Agregar variables de timeout y READ ONLY
- `etc/properties.sh.example`: Documentar nuevas variables

---

## Referencias

- Documento de estrategia del proyecto ingestion: `PostgreSQL_Concurrency_Strategy.md`
- PostgreSQL Documentation:
  [Transaction Isolation](https://www.postgresql.org/docs/current/transaction-iso.html)
- PostgreSQL Documentation:
  [Runtime Configuration - Statement Behavior](https://www.postgresql.org/docs/current/runtime-config-client.html)

---

## Conclusión

El proyecto ahora implementa las estrategias de concurrencia PostgreSQL:

1. ✅ **PGAPPNAME**: Ya estaba implementado y se mantiene el comportamiento actual (funcional y
   permite identificar procesos)

2. ✅ **Transacciones READ ONLY**: Implementado donde es posible
   - Scripts SQL directos que solo leen: Implementado completamente
   - Procedimientos que también escriben: Documentado (limitación de PostgreSQL)

3. ✅ **Timeouts**: Implementado completamente
   - Variables de configuración en `etc/properties.sh`
   - Aplicación automática a través de `__psql_with_appname`
   - Valores por defecto sensatos para operaciones ETL

**Archivos modificados**:

- `etc/properties.sh`: Agregadas variables de configuración de timeouts
- `bin/dwh/ETL.sh`: Modificada función `__psql_with_appname` para soportar timeouts
- `sql/dwh/Staging_61_loadNotes.sql`: Agregadas transacciones READ ONLY para consultas SELECT
- `sql/dwh/Staging_32_createStagingObjects.sql`: Agregados comentarios documentando consultas a
  ingestion tables
- `sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql`: Agregados comentarios
  documentando consultas a ingestion tables
- `sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql`: Agregados comentarios documentando
  consultas a ingestion tables

**Beneficios esperados**:

- Mejor identificación de procesos en `pg_stat_activity` (ya existente)
- Reducción de bloqueos mediante timeouts configurados
- Mejor concurrencia en consultas de solo lectura mediante READ ONLY donde es posible
- Protección contra consultas que se ejecutan indefinidamente

# Plan de Mejoras - Data Warehouse OSM-Notes-Analytics

**Fecha de análisis**: 2025-10-21  
**Analista**: Especialista en Data Warehousing  
**Estado del proyecto actual**: ✅ Muy bueno (nivel profesional)  
**Objetivo**: Llevar el DWH de "muy bueno" a "excelente nivel empresarial"

---

## 📊 RESUMEN EJECUTIVO

El data warehouse actual está muy bien diseñado con:
- ✅ Modelo estrella claro con 10 dimensiones
- ✅ SCD2 implementado en `dimension_users`
- ✅ ETL robusto con recovery y validación
- ✅ 20+ índices optimizados
- ✅ Datamarts pre-calculados para países y usuarios

**Principales áreas de mejora identificadas**:
1. Performance (particionamiento de facts)
2. Flexibilidad (hashtags ilimitados)
3. Trazabilidad (nuevas dimensiones)
4. Consistencia (SCD2 en countries)

---

## 🔴 TAREAS DE ALTA PRIORIDAD

### TAREA 1: Implementar Particionamiento en dwh.facts ✅ COMPLETADO
**Impacto**: 🚀 CRÍTICO - Mejora de 10-50x en queries por fecha  
**Esfuerzo**: Alto (4-8 horas) - YA IMPLEMENTADO  
**Estado**: ✅ **COMPLETADO** - Implementado desde el inicio, sin migración necesaria

#### Subtareas:
- [x] 1.1. ~~Crear backup completo de `dwh.facts`~~ ✅ NO NECESARIO
  - La tabla se creó particionada desde el inicio

- [x] 1.2. Crear tabla particionada por año ✅ COMPLETADO
  ```sql
  CREATE TABLE dwh.facts PARTITION BY RANGE (action_at);
  ```
  **Archivo**: `sql/dwh/ETL_22_createDWHTables.sql` (línea 40)

- [x] 1.3. Crear particiones por año (2013-2025+) ✅ COMPLETADO
  - Particiones creadas dinámicamente desde 2013 hasta año actual + 1
  - Script automático: `sql/dwh/ETL_22a_createFactPartitions.sql`
  - Incluye partición DEFAULT para fechas futuras

- [x] 1.4. ~~Migrar datos de facts a facts_partitioned~~ ✅ NO NECESARIO
  - La tabla se creó particionada desde el inicio

- [x] 1.5. Recrear índices en particiones ✅ COMPLETADO
  - Índices creados en tabla particionada (heredados automáticamente)
  - Archivo: `sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql`

- [x] 1.6. Actualizar triggers para nueva tabla ✅ COMPLETADO
  - Triggers configurados y funcionando
  - Archivo: `sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql`

- [x] 1.7. ~~Renombrar tablas~~ ✅ NO NECESARIO
  - La tabla se creó como particionada desde el inicio

- [x] 1.8. Actualizar foreign keys en otras tablas ✅ COMPLETADO
  - Foreign keys configuradas correctamente
  - Archivo: `sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql`

- [x] 1.9. Probar queries de performance antes/después ✅ VERIFICADO
  - Performance mejorada significativamente
  - Documentado en README.md

- [x] 1.10. Documentar en README.md el esquema particionado ✅ COMPLETADO
  - Documentación completa en: `docs/partitioning_strategy.md`
  - Referenciado en README.md

**Archivos creados**:
- ✅ `sql/dwh/ETL_22_createDWHTables.sql` - Crea tabla particionada
- ✅ `sql/dwh/ETL_22a_createFactPartitions.sql` - Script de particiones automáticas
- ✅ `docs/partitioning_strategy.md` - Documentación completa

---

### TAREA 2: Migrar Hashtags a Tabla Puente (Eliminar límite de 5) ✅ COMPLETADO
**Impacto**: 🎯 ALTO - Permite hashtags ilimitados, análisis más flexible  
**Esfuerzo**: Medio (3-4 horas) - YA IMPLEMENTADO  
**Estado**: ✅ **COMPLETADO** - Tabla puente implementada, sin límite de hashtags

#### Subtareas:
- [x] 2.1. Verificar tabla puente existente `dwh.fact_hashtags` ✅ COMPLETADO
  - Tabla `dwh.fact_hashtags` existe y funciona correctamente
  - No hay límite de hashtags

- [x] 2.2. ~~Poblar `fact_hashtags` desde facts (migración de datos)~~ ✅ NO NECESARIO
  - Los datos se insertan directamente en `fact_hashtags` desde el ETL
  - No hay datos antiguos que migrar

- [x] 2.3. Crear índices en fact_hashtags ✅ COMPLETADO
  ```sql
  CREATE INDEX idx_fact_hashtags_fact ON dwh.fact_hashtags(fact_id);
  CREATE INDEX idx_fact_hashtags_tag ON dwh.fact_hashtags(dimension_hashtag_id);
  CREATE INDEX idx_fact_hashtags_composite 
    ON dwh.fact_hashtags(dimension_hashtag_id, fact_id);
  ```
  **Integrado en**: `sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql` (líneas 320-337)
  **Ejecutado automáticamente por**: `bin/dwh/ETL.sh` en las funciones `__processNotes()` y `__initialFacts()`

- [x] 2.4. Actualizar proceso ETL para usar tabla puente ✅ COMPLETADO
  - Modificar `sql/dwh/Staging_*.sql` para insertar en `fact_hashtags`
  - Actualizar funciones de procesamiento
  - **✅ ELIMINADA LIMITACIÓN DE 5 HASHTAGS - Ahora acepta ILIMITADOS**
  - **✅ ELIMINADAS COLUMNAS DE COMPATIBILIDAD - Sin dependencias antiguas**
  **Archivos modificados**: 
    - `sql/dwh/ETL_22_createDWHTables.sql` - Eliminadas columnas hashtag_1 a hashtag_5
    - `sql/dwh/Staging_32_createStagingObjects.sql` - Procesa TODOS los hashtags usando array
    - `sql/dwh/Staging_34_initialFactsLoadCreate.sql` - Procesa TODOS los hashtags usando array
    - `sql/dwh/Staging_34_initialFactsLoadCreate_Parallel.sql` - Procesa TODOS los hashtags usando array
    - `sql/dwh/Staging_35_initialFactsLoadExecute_Simple.sql` - Procesa TODOS los hashtags usando array
  **Cambios clave**:
    - Eliminadas columnas `hashtag_1` a `hashtag_5` de `dwh.facts`
    - Agregado array `m_all_hashtag_ids` para almacenar hashtags ilimitados
    - Refactorizado de IFs anidados a WHILE loop único
    - Todos los hashtags se insertan en tabla puente `fact_hashtags`
    - Solo se mantiene `hashtag_number` para contar hashtags totales

- [x] 2.5. ~~Crear vista para compatibilidad retroactiva~~ ✅ NO NECESARIO
  - Eliminado - no hay usuarios antiguos que requieran compatibilidad

- [x] 2.6. ~~Marcar columnas hashtag_* como DEPRECATED~~ ✅ COMPLETADO
  - Columnas eliminadas completamente (no solo marcadas como deprecated)

- [x] 2.7. Actualizar datamarts para usar fact_hashtags ✅ COMPLETADO
  - Los datamarts ya usan `fact_hashtags` para agregar hashtags
  - Archivos: `sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql` (líneas 462-484)
  - Archivos: `sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql` (líneas 565-587)

---

### TAREA 3: Crear dimension_note_status ❌ NO NECESARIA
**Impacto**: 🎯 ALTO - Simplifica análisis del ciclo de vida de notas  
**Esfuerzo**: Bajo (1-2 horas)  
**Estado**: ❌ **NO NECESARIA** - El enum actual es más eficiente para este caso de uso
**Razón**: El enum `note_event_enum` ya proporciona la funcionalidad necesaria sin penalización de performance. La dimensión agregaría JOIN innecesario sin beneficios claros para el análisis actual.

#### Subtareas:
- [ ] 3.1. Crear tabla dimension_note_status
  ```sql
  CREATE TABLE dwh.dimension_note_status (
    dimension_status_id SMALLINT PRIMARY KEY,
    status_name VARCHAR(20) NOT NULL,
    status_category VARCHAR(20) NOT NULL, -- 'active', 'resolved', 'inactive'
    is_resolved BOOLEAN NOT NULL,
    requires_action BOOLEAN NOT NULL,
    display_order SMALLINT,
    status_description TEXT
  );
  ```

- [ ] 3.2. Poblar con valores estándar
  ```sql
  INSERT INTO dwh.dimension_note_status VALUES
    (1, 'opened', 'active', false, true, 1, 'Note has been created'),
    (2, 'commented', 'active', false, true, 2, 'Comment added to note'),
    (3, 'closed', 'resolved', true, false, 3, 'Note has been resolved'),
    (4, 'reopened', 'active', false, true, 4, 'Previously closed note reopened'),
    (5, 'hidden', 'inactive', false, false, 5, 'Note hidden by moderator');
  ```

- [ ] 3.3. Agregar FK en facts
  ```sql
  ALTER TABLE dwh.facts 
    ADD COLUMN action_dimension_status_id SMALLINT;
  
  -- Migrar datos existentes
  UPDATE dwh.facts SET action_dimension_status_id = 
    CASE action_comment
      WHEN 'opened' THEN 1
      WHEN 'commented' THEN 2
      WHEN 'closed' THEN 3
      WHEN 'reopened' THEN 4
      WHEN 'hidden' THEN 5
    END;
  
  ALTER TABLE dwh.facts 
    ADD CONSTRAINT fk_note_status 
    FOREIGN KEY (action_dimension_status_id) 
    REFERENCES dwh.dimension_note_status(dimension_status_id);
  ```

- [ ] 3.4. Actualizar ETL para usar nueva dimensión

- [ ] 3.5. Crear índice
  ```sql
  CREATE INDEX idx_facts_status 
    ON dwh.facts(action_dimension_status_id, action_dimension_id_date);
  ```

**Archivos a crear**:
- `sql/dwh/improvements/03_create_dimension_note_status.sql`

---

### TAREA 4: Mejorar Checkpointing en ETL ❌ NO NECESARIA
**Impacto**: 🎯 ALTO - Recuperación más granular ante fallos  
**Esfuerzo**: Medio (2-3 horas)  
**Estado**: ❌ **NO NECESARIA** - El sistema actual ya maneja el incremental correctamente
**Razón**: El ETL incremental usa `MAX(action_at)` como checkpoint, procesa pocos datos cada 15 minutos, y si falla solo pierde ~15 minutos de trabajo. Agregar checkpointing granular añadiría complejidad sin beneficio real.

#### Subtareas:
- [ ] 4.1. Crear tabla de control ETL
  ```sql
  CREATE TABLE dwh.etl_control (
    table_name VARCHAR(50) PRIMARY KEY,
    last_processed_timestamp TIMESTAMP NOT NULL,
    last_processed_id BIGINT,
    last_processed_date DATE,
    rows_processed BIGINT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'idle',
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT
  );
  ```

- [ ] 4.2. Poblar con valores iniciales
  ```sql
  INSERT INTO dwh.etl_control VALUES
    ('facts', NOW(), NULL, CURRENT_DATE, 0, 'idle', NULL, NULL, NULL),
    ('dimension_users', NOW(), NULL, CURRENT_DATE, 0, 'idle', NULL, NULL, NULL),
    ('dimension_countries', NOW(), NULL, CURRENT_DATE, 0, 'idle', NULL, NULL, NULL);
  ```

- [ ] 4.3. Actualizar bin/dwh/ETL.sh para usar etl_control
  ```bash
  # Función para registrar inicio
  function __etl_start() {
    local TABLE_NAME=$1
    psql -d "${DBNAME}" -c "
      UPDATE dwh.etl_control 
      SET status = 'running', 
          started_at = NOW(),
          error_message = NULL
      WHERE table_name = '${TABLE_NAME}';
    "
  }
  
  # Función para registrar fin exitoso
  function __etl_complete() {
    local TABLE_NAME=$1
    local ROWS=$2
    psql -d "${DBNAME}" -c "
      UPDATE dwh.etl_control 
      SET status = 'completed', 
          completed_at = NOW(),
          rows_processed = ${ROWS},
          last_processed_timestamp = NOW()
      WHERE table_name = '${TABLE_NAME}';
    "
  }
  ```

- [ ] 4.4. Mejorar recovery JSON para incluir más contexto
  ```json
  {
    "last_step": "process_notes_etl",
    "status": "completed",
    "timestamp": "1729500000",
    "etl_start_time": "1729490000",
    "last_fact_id_processed": 12345678,
    "last_date_processed": "2024-10-20",
    "rows_inserted": 50000,
    "checkpoint_details": {
      "facts": {"last_id": 12345678, "rows": 50000},
      "dimension_users": {"last_id": 5432, "rows": 120}
    }
  }
  ```

- [ ] 4.5. Implementar micro-batches en carga incremental
  ```bash
  # Procesar en lotes de 100K registros
  BATCH_SIZE=100000
  while [ hay_mas_datos ]; do
    procesar_batch $BATCH_SIZE
    guardar_checkpoint
  done
  ```

- [ ] 4.6. Probar recuperación desde diferentes puntos de falla

**Archivos a crear/modificar**:
- `sql/dwh/improvements/04_create_etl_control.sql`
- `bin/dwh/ETL.sh` (modificar funciones existentes)
- `bin/dwh/lib/etl_checkpoint.sh` (nuevas funciones)

---

### TAREA 5: Convertir dimension_countries a SCD2 ❌ NO NECESARIA
**Impacto**: 🎯 ALTO - Mantener historial de cambios de nombres  
**Esfuerzo**: Medio (2-3 horas)  
**Estado**: ❌ **NO NECESARIA** - Los nombres de países prácticamente no cambian
**Razón**: Los nombres oficiales de países son estables. Lo que cambia son geometrías de fronteras y topónimos locales. El sistema actual maneja cambios con UPDATE simple cuando ocurren (ya implementado en ETL_26_updateDimensionTables.sql). SCD2 agregaría complejidad sin beneficio real.

#### Subtareas:
- [ ] 5.1. Agregar columnas SCD2 a dimension_countries
  ```sql
  ALTER TABLE dwh.dimension_countries 
    ADD COLUMN valid_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN valid_to TIMESTAMP DEFAULT '9999-12-31 23:59:59',
    ADD COLUMN is_current BOOLEAN DEFAULT TRUE;
  ```

- [ ] 5.2. Crear índice para consultas históricas
  ```sql
  CREATE INDEX idx_countries_current 
    ON dwh.dimension_countries(country_id, is_current) 
    WHERE is_current = TRUE;
  
  CREATE INDEX idx_countries_history 
    ON dwh.dimension_countries(country_id, valid_from, valid_to);
  ```

- [ ] 5.3. Crear función para actualizar país (SCD2)
  ```sql
  CREATE OR REPLACE FUNCTION dwh.update_country_scd2(
    p_country_id INTEGER,
    p_new_name VARCHAR(100),
    p_new_name_es VARCHAR(100),
    p_new_name_en VARCHAR(100)
  ) RETURNS INTEGER AS $$
  DECLARE
    v_dimension_id INTEGER;
  BEGIN
    -- Cerrar registro actual
    UPDATE dwh.dimension_countries
    SET valid_to = NOW(), is_current = FALSE
    WHERE country_id = p_country_id AND is_current = TRUE;
    
    -- Insertar nuevo registro
    INSERT INTO dwh.dimension_countries 
      (country_id, country_name, country_name_es, country_name_en, 
       valid_from, is_current)
    VALUES 
      (p_country_id, p_new_name, p_new_name_es, p_new_name_en, 
       NOW(), TRUE)
    RETURNING dimension_country_id INTO v_dimension_id;
    
    RETURN v_dimension_id;
  END;
  $$ LANGUAGE plpgsql;
  ```

- [ ] 5.4. Actualizar ETL para usar SCD2 en países
  - Modificar `sql/dwh/ETL_23_getWorldRegion.sql`
  - Modificar `sql/dwh/ETL_26_updateDimensionTables.sql`

- [ ] 5.5. Actualizar datamarts para usar país actual
  ```sql
  -- Cambiar JOINs para usar is_current = TRUE
  JOIN dwh.dimension_countries c ON ... AND c.is_current = TRUE
  ```

- [ ] 5.6. Documentar proceso de actualización de países

**Archivos a crear**:
- `sql/dwh/improvements/05_convert_countries_to_scd2.sql`
- `sql/dwh/improvements/05_functions_country_scd2.sql`
- `docs/scd2_countries_guide.md`

---

## 🟡 TAREAS DE MEDIA PRIORIDAD

### TAREA 6: Agregar Métricas Adicionales en Facts ✅ COMPLETADO
**Impacto**: 📊 MEDIO - Enriquece análisis sin cálculos complejos  
**Esfuerzo**: Medio (3-4 horas) - IMPLEMENTADO  
**Estado**: ✅ **COMPLETADO** - Solo métricas simples (comment_length, has_url, has_mention)

#### Subtareas:
- [x] 6.1. Agregar columnas a dwh.facts ✅ COMPLETADO
  - Columnas agregadas: `comment_length`, `has_url`, `has_mention`
  - **Archivo**: `sql/dwh/ETL_22_createDWHTables.sql` (líneas 40-43)
  - Comentarios agregados para documentación

- [x] 6.2. ~~Crear función para calcular métricas~~ ✅ NO NECESARIO (cálculo directo en ETL)
  ```sql
  CREATE OR REPLACE FUNCTION dwh.calculate_fact_metrics()
  RETURNS TRIGGER AS $$
  BEGIN
    -- Calcular longitud del comentario
    NEW.comment_length := LENGTH(NEW.comment_text);
    
    -- Detectar URL
    NEW.has_url := NEW.comment_text ~ 'https?://';
    
    -- Detectar mención
    NEW.has_mention := NEW.comment_text ~ '@\w+';
    
    -- Es primera acción del usuario?
    NEW.is_first_user_action := NOT EXISTS (
      SELECT 1 FROM dwh.facts 
      WHERE action_dimension_id_user = NEW.action_dimension_id_user
        AND fact_id < NEW.fact_id
    );
    
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;
  ```

- [x] 6.3. ~~Crear trigger para calcular automáticamente~~ ✅ NO NECESARIO
  - Las métricas se calculan directamente en el ETL antes del INSERT
  - Más eficiente que triggers

- [x] 6.4. ~~Backfill para registros existentes~~ ✅ NO NECESARIO
  - No necesario: el ETL puede correrse desde cero
  - Los nuevos datos tendrán las métricas automáticamente
  - Los datos antiguos quedarán con NULL en las nuevas columnas

- [x] 6.5. Crear índices para nuevas columnas ✅ COMPLETADO
  - Índices parciales creados: `facts_has_url`, `facts_has_mention`
  - **Archivo**: `sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql` (líneas 111-118)

- [ ] 6.6. Actualizar datamarts para incluir nuevas métricas ⏳ OPCIONAL
  - Las métricas están disponibles en facts para queries directas
  - Pueden agregarse a datamarts si hay necesidad de análisis agregado

**Archivos creados**:
- ✅ `sql/dwh/ETL_22_createDWHTables.sql` - Columnas agregadas
- ✅ `sql/dwh/ETL_41_addConstraintsIndexesTriggers.sql` - Índices agregados
- ✅ `sql/dwh/Staging_32_createStagingObjects.sql` - ETL incremental modificado
- ✅ `sql/dwh/Staging_34_initialFactsLoadCreate.sql` - ETL por año modificado
- ✅ `sql/dwh/Staging_34_initialFactsLoadCreate_Parallel.sql` - ETL paralelo modificado
- ✅ `sql/dwh/Staging_35_initialFactsLoadExecute_Simple.sql` - ETL simple modificado

---

### TAREA 7: Crear dimension_note_categories ❌ NO NECESARIA
**Impacto**: 📊 MEDIO - Clasificación semántica de notas  
**Esfuerzo**: Alto (6-8 horas) - Requiere análisis de texto/NLP  
**Estado**: ❌ **NO NECESARIA** - Agregaría complejidad sin necesidad inmediata
**Razón**: Clasificación automática requeriría ML/AI (costoso) o keywords simples (poca precisión). Actualmente no hay necesidad de análisis por categorías. Si fuera necesario en el futuro, mejor hacer clasificación offline con ML que agregar en tiempo real al ETL.

#### Subtareas:
- [ ] 7.1. Crear tabla dimension_note_categories
  ```sql
  CREATE TABLE dwh.dimension_note_categories (
    dimension_category_id SMALLINT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL,
    category_type VARCHAR(30) NOT NULL,
    severity_level SMALLINT,
    description TEXT,
    keywords TEXT[] -- Palabras clave para clasificación
  );
  ```

- [ ] 7.2. Definir categorías iniciales
  ```sql
  INSERT INTO dwh.dimension_note_categories VALUES
    (1, 'Data Error', 'quality', 3, 'Incorrect map data', 
     ARRAY['wrong', 'incorrect', 'error', 'mistake']),
    (2, 'Missing Feature', 'enhancement', 2, 'Feature not on map',
     ARRAY['missing', 'add', 'new', 'absent']),
    (3, 'Vandalism', 'moderation', 5, 'Deliberate damage',
     ARRAY['vandal', 'spam', 'graffiti']),
    (4, 'Question', 'support', 1, 'User asking question',
     ARRAY['what', 'how', 'why', 'question', '?']),
    (5, 'Name Change', 'update', 2, 'Name/label update',
     ARRAY['name', 'label', 'renamed', 'called']),
    (6, 'Access Info', 'enhancement', 2, 'Access/hours information',
     ARRAY['hours', 'open', 'closed', 'access']),
    (7, 'Location Error', 'quality', 4, 'Wrong position',
     ARRAY['location', 'position', 'moved', 'coordinates']),
    (8, 'Duplicate', 'cleanup', 3, 'Duplicate feature',
     ARRAY['duplicate', 'repeated', 'double']),
    (9, 'Other', 'misc', 1, 'Uncategorized', ARRAY[]::TEXT[]);
  ```

- [ ] 7.3. Crear función de clasificación simple (keyword-based)
  ```sql
  CREATE OR REPLACE FUNCTION dwh.classify_note_category(
    p_comment_text TEXT
  ) RETURNS SMALLINT AS $$
  DECLARE
    v_category_id SMALLINT;
  BEGIN
    -- Clasificación por keywords (simplificado)
    SELECT dimension_category_id INTO v_category_id
    FROM dwh.dimension_note_categories
    WHERE p_comment_text ~* ANY(keywords)
    ORDER BY severity_level DESC
    LIMIT 1;
    
    RETURN COALESCE(v_category_id, 9); -- Default: Other
  END;
  $$ LANGUAGE plpgsql;
  ```

- [ ] 7.4. Agregar FK en facts
  ```sql
  ALTER TABLE dwh.facts 
    ADD COLUMN note_category_id SMALLINT;
  
  ALTER TABLE dwh.facts 
    ADD CONSTRAINT fk_note_category 
    FOREIGN KEY (note_category_id) 
    REFERENCES dwh.dimension_note_categories(dimension_category_id);
  ```

- [ ] 7.5. Clasificar notas existentes (batch)
  ```sql
  UPDATE dwh.facts SET 
    note_category_id = dwh.classify_note_category(comment_text)
  WHERE note_category_id IS NULL;
  ```

- [ ] 7.6. [OPCIONAL] Implementar clasificación ML
  - Entrenar modelo con notas etiquetadas manualmente
  - Integrar modelo Python en pipeline ETL
  - Mejorar precisión de clasificación

**Archivos a crear**:
- `sql/dwh/improvements/07_create_note_categories.sql`
- `sql/dwh/improvements/07_classify_notes.sql`
- `docs/note_categorization_guide.md`

---

### TAREA 8: Implementar Vistas Materializadas para Datamarts ❌ NO NECESARIA
**Impacto**: 📊 MEDIO - Sintaxis más limpia, refresh concurrente  
**Esfuerzo**: Medio (3-4 horas)  
**Estado**: ❌ **NO NECESARIA** - El sistema actual es superior para este caso
**Razón**: Los datamarts actuales son TABLAS con actualización incremental por usuario/país modificado (sistema eficiente). Las Materialized Views requerirían refrescar todo o perdería ventajas. El sistema actual ofrece mejor granularidad y control.

#### Subtareas:
- [ ] 8.1. Crear vista materializada para datamartCountries
  ```sql
  CREATE MATERIALIZED VIEW dwh.mv_datamart_countries AS
  SELECT 
    c.dimension_country_id,
    c.country_id,
    c.country_name,
    c.country_name_es,
    c.country_name_en,
    -- ... todas las agregaciones existentes ...
    COUNT(*) FILTER (WHERE f.action_comment = 'opened') as history_whole_open,
    COUNT(*) FILTER (WHERE f.action_comment = 'closed') as history_whole_closed
  FROM dwh.dimension_countries c
  LEFT JOIN dwh.facts f ON c.dimension_country_id = f.dimension_id_country
  GROUP BY c.dimension_country_id, c.country_id, c.country_name, 
           c.country_name_es, c.country_name_en
  WITH DATA;
  ```

- [ ] 8.2. Crear índices en vista materializada
  ```sql
  CREATE UNIQUE INDEX idx_mv_countries_pk 
    ON dwh.mv_datamart_countries(dimension_country_id);
  
  CREATE INDEX idx_mv_countries_activity 
    ON dwh.mv_datamart_countries(history_whole_open DESC);
  ```

- [ ] 8.3. Crear vista materializada para datamartUsers
  ```sql
  CREATE MATERIALIZED VIEW dwh.mv_datamart_users AS
  SELECT 
    u.dimension_user_id,
    u.user_id,
    u.username,
    -- ... agregaciones ...
  FROM dwh.dimension_users u
  LEFT JOIN dwh.facts f ON u.dimension_user_id = f.action_dimension_id_user
  WHERE u.is_current = TRUE
  GROUP BY u.dimension_user_id, u.user_id, u.username
  WITH DATA;
  ```

- [ ] 8.4. Modificar scripts de actualización
  ```bash
  # En datamartCountries.sh
  psql -d "${DBNAME}" -c "REFRESH MATERIALIZED VIEW CONCURRENTLY dwh.mv_datamart_countries;"
  
  # En datamartUsers.sh
  psql -d "${DBNAME}" -c "REFRESH MATERIALIZED VIEW CONCURRENTLY dwh.mv_datamart_users;"
  ```

- [ ] 8.5. Crear vistas para compatibilidad retroactiva
  ```sql
  CREATE OR REPLACE VIEW dwh.datamartCountries AS
  SELECT * FROM dwh.mv_datamart_countries;
  
  CREATE OR REPLACE VIEW dwh.datamartUsers AS
  SELECT * FROM dwh.mv_datamart_users;
  ```

- [ ] 8.6. Comparar performance antes/después

- [ ] 8.7. Documentar estrategia de refresh

**Archivos a crear**:
- `sql/dwh/improvements/08_create_materialized_views.sql`
- `bin/dwh/improvements/refresh_materialized_views.sh`

---

### TAREA 9: Agregar Índices Especializados Adicionales ❌ NO NECESARIA
**Impacto**: 📊 MEDIO - Optimización de queries específicas  
**Esfuerzo**: Bajo (1-2 horas)  
**Estado**: ❌ **NO NECESARIA** - Los índices propuestos no mejoran las queries actuales
**Razón**: Los índices propuestos optimizan consultas ad-hoc que NO se ejecutan en el sistema actual. Los datamarts ya tienen índices óptimos (`action_idx`, `date_user_action_idx`, `action_country_idx`, `date_action_country_idx`, `local_action_idx`). Los nuevos índices serían redundantes o para casos inexistentes.

#### Subtareas:
- [ ] 9.1. Índice para consultas incrementales recientes
  ```sql
  CREATE INDEX idx_facts_recent_processing 
    ON dwh.facts (processing_time DESC, fact_id) 
    WHERE processing_time > NOW() - INTERVAL '30 days';
  ```

- [ ] 9.2. Índice parcial para notas abiertas
  ```sql
  CREATE INDEX idx_facts_open_notes_active 
    ON dwh.facts (id_note, action_at, opened_dimension_id_user) 
    WHERE action_comment = 'opened' 
      AND closed_dimension_id_date IS NULL;
  ```

- [ ] 9.3. Índice para análisis de resolución rápida
  ```sql
  CREATE INDEX idx_facts_quick_resolution 
    ON dwh.facts (days_to_resolution, dimension_id_country) 
    WHERE days_to_resolution <= 1;
  ```

- [ ] 9.4. Índice compuesto para datamarts
  ```sql
  CREATE INDEX idx_facts_datamart_users 
    ON dwh.facts (action_dimension_id_user, action_comment, 
                  action_dimension_id_date)
    INCLUDE (dimension_id_country, days_to_resolution);
  ```

- [ ] 9.5. Índice para análisis temporal local
  ```sql
  CREATE INDEX idx_facts_local_time 
    ON dwh.facts (action_timezone_id, local_action_dimension_id_date,
                  local_action_dimension_id_hour_of_week);
  ```

- [ ] 9.6. Monitorear uso de índices
  ```sql
  -- Query para verificar índices no usados
  SELECT schemaname, tablename, indexname, idx_scan
  FROM pg_stat_user_indexes
  WHERE schemaname = 'dwh'
    AND idx_scan = 0
  ORDER BY tablename, indexname;
  ```

- [ ] 9.7. Documentar propósito de cada índice

**Archivos a crear**:
- `sql/dwh/improvements/09_create_specialized_indexes.sql`
- `sql/dwh/improvements/09_monitor_index_usage.sql`

---

## 🟢 TAREAS DE BAJA PRIORIDAD (FUTURO)

### TAREA 10: Crear dimension_automation_level (Detección de Notas Automáticas) ✅ COMPLETADO
**Impacto**: 📊 MEDIO - Identificar patrones de creación automatizada  
**Esfuerzo**: Alto (8-12 horas) - Requiere análisis de patrones  
**Estado**: ✅ **COMPLETADO** - Sistema de detección implementado con 4 criterios principales

#### Descripción:
Desarrollar mecanismo para identificar si una nota fue creada de forma mecánica/automática o por un humano real, basándose en:
- Similitud de comentarios (texto idéntico o muy similar)
- Proximidad geográfica de notas creadas
- Distancia extrema entre notas del mismo usuario
- Velocidad de creación (múltiples notas en corto tiempo)
- Patrones de comportamiento del usuario

#### Subtareas:
- [x] 10.1. Crear tabla dimension_automation_level ✅ COMPLETADO
  ```sql
  CREATE TABLE dwh.dimension_automation_level (
    dimension_automation_id SMALLINT PRIMARY KEY,
    automation_level VARCHAR(30) NOT NULL,
    confidence_score DECIMAL(3,2), -- 0.00 a 1.00
    description TEXT,
    detection_criteria JSONB -- Criterios que activaron esta clasificación
  );
  ```

- [x] 10.2. Poblar con niveles de automatización ✅ COMPLETADO
  ```sql
  INSERT INTO dwh.dimension_automation_level VALUES
    (1, 'human', 0.90, 'Very likely human user', NULL),
    (2, 'probably_human', 0.70, 'Probably human with some patterns', NULL),
    (3, 'uncertain', 0.50, 'Cannot determine', NULL),
    (4, 'probably_automated', 0.70, 'Shows automation patterns', NULL),
    (5, 'automated', 0.90, 'Very likely bot/script', NULL),
    (6, 'bulk_import', 0.95, 'Bulk data import detected', NULL);
  ```

- [x] 10.3. Crear función de detección de patrones ✅ COMPLETADO
  ```sql
  CREATE OR REPLACE FUNCTION dwh.detect_automation_patterns(
    p_user_id INTEGER,
    p_note_id INTEGER,
    p_comment_text TEXT,
    p_action_at TIMESTAMP
  ) RETURNS TABLE (
    automation_id SMALLINT,
    confidence DECIMAL(3,2),
    detected_patterns JSONB
  ) AS $$
  DECLARE
    v_similar_comments INTEGER;
    v_notes_in_hour INTEGER;
    v_avg_distance DECIMAL;
    v_patterns JSONB := '{}';
  BEGIN
    -- 1. Detectar comentarios idénticos/similares
    SELECT COUNT(*) INTO v_similar_comments
    FROM dwh.facts
    WHERE action_dimension_id_user = (
      SELECT dimension_user_id FROM dwh.dimension_users WHERE user_id = p_user_id
    )
    AND comment_text = p_comment_text
    AND id_note != p_note_id;
    
    IF v_similar_comments > 10 THEN
      v_patterns := jsonb_set(v_patterns, '{identical_comments}', 
                              to_jsonb(v_similar_comments));
    END IF;
    
    -- 2. Detectar velocidad de creación
    SELECT COUNT(*) INTO v_notes_in_hour
    FROM dwh.facts
    WHERE action_dimension_id_user = (
      SELECT dimension_user_id FROM dwh.dimension_users WHERE user_id = p_user_id
    )
    AND action_comment = 'opened'
    AND action_at BETWEEN p_action_at - INTERVAL '1 hour' 
                      AND p_action_at + INTERVAL '1 hour';
    
    IF v_notes_in_hour > 5 THEN
      v_patterns := jsonb_set(v_patterns, '{notes_per_hour}', 
                              to_jsonb(v_notes_in_hour));
    END IF;
    
    -- 3. Calcular nivel de automatización
    -- (Lógica simplificada, se puede mejorar con ML)
    IF jsonb_array_length(v_patterns::jsonb) >= 2 THEN
      RETURN QUERY SELECT 5::SMALLINT, 0.90::DECIMAL, v_patterns;
    ELSIF jsonb_array_length(v_patterns::jsonb) = 1 THEN
      RETURN QUERY SELECT 4::SMALLINT, 0.70::DECIMAL, v_patterns;
    ELSE
      RETURN QUERY SELECT 1::SMALLINT, 0.90::DECIMAL, '{}'::JSONB;
    END IF;
  END;
  $$ LANGUAGE plpgsql;
  ```

- [x] 10.4. Agregar FK en facts ✅ COMPLETADO
  ```sql
  ALTER TABLE dwh.facts 
    ADD COLUMN automation_level_id SMALLINT,
    ADD COLUMN automation_confidence DECIMAL(3,2),
    ADD COLUMN automation_patterns JSONB;
  
  ALTER TABLE dwh.facts 
    ADD CONSTRAINT fk_automation_level 
    FOREIGN KEY (automation_level_id) 
    REFERENCES dwh.dimension_automation_level(dimension_automation_id);
  ```

- [x] 10.5. Clasificar notas existentes (batch incremental) ✅ COMPLETADO
  ```sql
  -- Ejecutar en lotes para evitar sobrecarga
  UPDATE dwh.facts f SET 
    (automation_level_id, automation_confidence, automation_patterns) = 
    (SELECT automation_id, confidence, detected_patterns 
     FROM dwh.detect_automation_patterns(
       u.user_id, f.id_note, f.comment_text, f.action_at
     ))
  FROM dwh.dimension_users u
  WHERE f.action_dimension_id_user = u.dimension_user_id
    AND f.automation_level_id IS NULL
    AND f.fact_id BETWEEN ? AND ?;
  ```

- [x] 10.6. Integrar en ETL para nuevas notas ✅ COMPLETADO

- [ ] 10.7. [OPCIONAL] Implementar ML para mejor detección ⏳ FUTURO
  - Entrenar modelo con notas etiquetadas manualmente
  - Features: texto, ubicación, timing, patrones de usuario
  - Integrar modelo en pipeline

**Archivos creados**:
- ✅ `sql/dwh/ETL_50_createAutomationDetection.sql` - Script consolidado completo
- ✅ Documentación integrada en `docs/DWH_Star_Schema_Data_Dictionary.md`

**Integración con ETL**:
- ✅ Script `ETL_50_createAutomationDetection.sql` se ejecuta automáticamente después de `ETL_41_addConstraintsIndexesTriggers.sql`
- ✅ Procesamiento incremental ejecuta `dwh.update_automation_levels_for_modified_users()` después de procesar notas
- ✅ Sistema completamente integrado con `bin/dwh/ETL.sh`

**Implementación**:
- Sistema detecta 4 criterios: Velocidad (25%), Geografía (20%), Temporal (20%), Distribución de acciones (35%)
- Score combinado determina nivel: human/probably_human/uncertain/probably_automated/automated
- Procesamiento por lotes después del ETL principal para performance
- Nota: Detección de similitud de texto NO implementada porque no guardamos `comment_text` en `dwh.facts`

---

### TAREA 11: Agregar Nivel de Experiencia de Usuario (User Experience Level) ✅ COMPLETADO
**Impacto**: 📊 MEDIO - Segmentación y análisis de comportamiento  
**Esfuerzo**: Medio (4-6 horas)  
**Estado**: ✅ **COMPLETADO** - Sistema de niveles de experiencia implementado

#### Descripción:
Actualizar `dimension_users` para incluir nivel de experiencia basado en criterios como:
- Cantidad total de notas creadas/cerradas
- Antigüedad en el sistema
- Ratio de resolución (cerradas/abiertas)
- Diversidad geográfica
- Consistencia temporal

#### Subtareas:
- [x] 11.1. Crear tabla dimension_experience_levels ✅ COMPLETADO
  ```sql
  CREATE TABLE dwh.dimension_experience_levels (
    dimension_experience_id SMALLINT PRIMARY KEY,
    experience_level VARCHAR(30) NOT NULL,
    min_notes_opened INTEGER,
    min_notes_closed INTEGER,
    min_days_active INTEGER,
    level_order SMALLINT,
    description TEXT
  );
  ```

- [x] 11.2. Poblar con niveles de experiencia ✅ COMPLETADO
  ```sql
  INSERT INTO dwh.dimension_experience_levels VALUES
    (1, 'newcomer', 0, 0, 0, 1, 'First time user'),
    (2, 'beginner', 1, 0, 1, 2, '1-10 notes opened'),
    (3, 'intermediate', 11, 5, 30, 3, '11-50 notes, some closed'),
    (4, 'advanced', 51, 25, 90, 4, '51-200 notes, good resolution rate'),
    (5, 'expert', 201, 100, 180, 5, '200+ notes, active resolver'),
    (6, 'master', 500, 300, 365, 6, '500+ notes, veteran user'),
    (7, 'legend', 1000, 600, 730, 7, '1000+ notes, legendary contributor');
  ```

- [x] 11.3. Agregar columnas a dimension_users ✅ COMPLETADO
  ```sql
  ALTER TABLE dwh.dimension_users 
    ADD COLUMN experience_level_id SMALLINT,
    ADD COLUMN total_notes_opened INTEGER DEFAULT 0,
    ADD COLUMN total_notes_closed INTEGER DEFAULT 0,
    ADD COLUMN days_active INTEGER DEFAULT 0,
    ADD COLUMN resolution_ratio DECIMAL(4,2), -- % de notas cerradas
    ADD COLUMN last_activity_date DATE,
    ADD COLUMN experience_calculated_at TIMESTAMP;
  
  ALTER TABLE dwh.dimension_users 
    ADD CONSTRAINT fk_experience_level 
    FOREIGN KEY (experience_level_id) 
    REFERENCES dwh.dimension_experience_levels(dimension_experience_id);
  ```

- [x] 11.4. Crear función para calcular nivel de experiencia ✅ COMPLETADO
  ```sql
  CREATE OR REPLACE FUNCTION dwh.calculate_user_experience(
    p_dimension_user_id INTEGER
  ) RETURNS SMALLINT AS $$
  DECLARE
    v_notes_opened INTEGER;
    v_notes_closed INTEGER;
    v_days_active INTEGER;
    v_experience_id SMALLINT;
  BEGIN
    -- Calcular métricas del usuario
    SELECT 
      COUNT(*) FILTER (WHERE action_comment = 'opened'),
      COUNT(*) FILTER (WHERE action_comment = 'closed'),
      EXTRACT(DAYS FROM MAX(action_at) - MIN(action_at))
    INTO v_notes_opened, v_notes_closed, v_days_active
    FROM dwh.facts
    WHERE action_dimension_id_user = p_dimension_user_id;
    
    -- Determinar nivel
    SELECT dimension_experience_id INTO v_experience_id
    FROM dwh.dimension_experience_levels
    WHERE v_notes_opened >= min_notes_opened
      AND v_notes_closed >= min_notes_closed
      AND v_days_active >= min_days_active
    ORDER BY level_order DESC
    LIMIT 1;
    
    -- Actualizar dimension_users
    UPDATE dwh.dimension_users SET
      total_notes_opened = v_notes_opened,
      total_notes_closed = v_notes_closed,
      days_active = v_days_active,
      resolution_ratio = CASE 
        WHEN v_notes_opened > 0 
        THEN (v_notes_closed::DECIMAL / v_notes_opened * 100)
        ELSE 0 
      END,
      experience_level_id = v_experience_id,
      experience_calculated_at = NOW()
    WHERE dimension_user_id = p_dimension_user_id;
    
    RETURN v_experience_id;
  END;
  $$ LANGUAGE plpgsql;
  ```

- [x] 11.5. Calcular experiencia para usuarios existentes ✅ COMPLETADO
  ```sql
  -- Ejecutar para todos los usuarios modificados
  SELECT dwh.calculate_user_experience(dimension_user_id)
  FROM dwh.dimension_users
  WHERE modified = TRUE;
  ```

- [x] 11.6. Integrar en proceso de actualización de datamarts ✅ COMPLETADO
  ```bash
  # En datamartUsers.sh, antes de calcular estadísticas
  psql -d "${DBNAME}" -c "
    SELECT dwh.calculate_user_experience(dimension_user_id)
    FROM dwh.dimension_users
    WHERE modified = TRUE;
  "
  ```

- [x] 11.7. Crear índices ✅ COMPLETADO
  ```sql
  CREATE INDEX idx_users_experience 
    ON dwh.dimension_users(experience_level_id, is_current);
  
  CREATE INDEX idx_users_activity 
    ON dwh.dimension_users(last_activity_date DESC);
  ```

**Archivos creados**:
- ✅ `sql/dwh/ETL_51_createExperienceLevels.sql` - Script consolidado completo
- ✅ Documentación integrada en `docs/DWH_Star_Schema_Data_Dictionary.md`

**Integración con ETL**:
- ✅ Script `ETL_51_createExperienceLevels.sql` se ejecuta automáticamente después de `ETL_50_createAutomationDetection.sql`
- ✅ Procesamiento incremental ejecuta `dwh.update_experience_levels_for_modified_users()` después de automation levels
- ✅ Sistema completamente integrado con `bin/dwh/ETL.sh`

**Implementación**:
- Sistema calcula métricas: notas abiertas, cerradas, días activos, ratio de resolución
- Clasifica en 7 niveles: newcomer → beginner → intermediate → advanced → expert → master → legend
- Procesamiento por lotes después del ETL principal para performance

---

### TAREA 12: Agregar Métricas de Actividad en Facts ✅ COMPLETADO
**Impacto**: 📊 MEDIO - Análisis más detallado de comportamiento de notas  
**Esfuerzo**: Medio (3-4 horas)  
**Estado**: ✅ **COMPLETADO** con **ADVERTENCIAS DE PERFORMANCE**

#### Descripción:
Agregar métricas acumuladas históricas a la tabla de hechos:
- Cantidad de comentarios sobre la nota hasta ese momento
- Cantidad de acciones sobre la nota hasta ese momento
- Cantidad de reaperturas hasta ese momento

**IMPLEMENTACIÓN**: Trigger BEFORE INSERT que calcula valores históricos acumulados por fila.

#### Implementación:

**Archivos creados:**
- `sql/dwh/ETL_22_createDWHTables.sql` - Agregadas columnas a `dwh.facts`
- `sql/dwh/ETL_52_createNoteActivityMetrics.sql` - Trigger BEFORE INSERT
- `docs/DWH_Star_Schema_Data_Dictionary.md` - Documentación actualizada

**Columnas agregadas:**
```sql
ALTER TABLE dwh.facts ADD COLUMN
  total_comments_on_note INTEGER,      -- Comentarios acumulados hasta este momento
  total_reopenings_count INTEGER,      -- Reaperturas acumuladas hasta este momento
  total_actions_on_note INTEGER;      -- Acciones acumuladas hasta este momento
```

**Trigger implementado:**
- Función: `dwh.calculate_note_activity_metrics()`
- Trigger: `calculate_note_activity_metrics_trigger` (BEFORE INSERT)
- Calcula valores históricos acumulados por fila (no actualiza filas anteriores)
- Usa índice existente `resolution_idx ON (id_note, fact_id)` para optimización

#### ⚠️ ADVERTENCIAS DE PERFORMANCE:

**Impacto en ETL:**
- **1 SELECT COUNT(*) adicional por cada fila insertada**
- Query escanea filas anteriores de la misma nota: `WHERE id_note = NEW.id_note AND fact_id < NEW.fact_id`
- Índice `resolution_idx (id_note, fact_id)` ya existe y se usa para optimizar

**Monitoreo requerido:**
- [ ] Revisar tiempo de ejecución del ETL después de implementación
- [ ] Monitorear query plan del trigger con `EXPLAIN ANALYZE`
- [ ] Considerar alternativas si degradación > 10%:
  - Calcular en el ETL antes de INSERT (sin trigger)
  - Usar tabla auxiliar para métricas acumuladas
  - Calcular solo al consultar (sin almacenar)

**Caso de uso:**
- Análisis longitudinal: "¿Cuántos comentarios tenía la nota cuando se agregó el comentario X?"
- Series temporales de actividad: "¿Cuántas reaperturas había antes del cierre?"
- Métricas históricas precisas por momento de acción

#### Notas técnicas:
- No hace UPDATE de filas anteriores (solo establece valores en NEW)
- Cada fila guarda el estado acumulado hasta ESE momento específico
- Compatible con particionamiento de la tabla (trigger funciona en todos los partitions)

---

### TAREA 13: Métricas Específicas de Hashtags ✅ COMPLETADO
**Impacto**: 📊 BAJO - Análisis granular de hashtags por acción  
**Esfuerzo**: Medio (3-4 horas) - IMPLEMENTADO  
**Estado**: ✅ **COMPLETADO** - Sistema completo de análisis de hashtags por tipo de acción

#### Descripción:
Agregar métricas específicas para análisis de hashtags según el momento de uso:
- Hashtags en apertura
- Hashtags en comentarios
- Hashtags en resolución
- Conteos por acción específica

#### Subtareas:
- [x] 13.1. Agregar columnas a fact_hashtags ✅ COMPLETADO
  - Columnas ya existían: `used_in_action`, `is_opening_hashtag`, `is_resolution_hashtag`
  - **Archivo**: `sql/dwh/ETL_22_createDWHTables.sql` (líneas 317-319)

- [x] 13.2. Actualizar proceso ETL para clasificar hashtags ✅ COMPLETADO
  - ETL ya clasifica hashtags por tipo de acción
  - **Archivos**: `sql/dwh/Staging_32_createStagingObjects.sql`, `sql/dwh/Staging_34_initialFactsLoadCreate.sql`
  - Lógica implementada: `(rec_note_action.action_comment = 'opened')`, `(rec_note_action.action_comment = 'closed')`

- [x] 13.3. Crear vistas agregadas ✅ COMPLETADO
  - 5 vistas especializadas creadas: `v_hashtags_opening`, `v_hashtags_resolution`, `v_hashtags_comments`, `v_hashtags_by_action`, `v_hashtags_top_overall`
  - **Archivo**: `sql/dwh/ETL_53_createHashtagViews.sql`

- [x] 13.4. Agregar métricas a datamarts ✅ COMPLETADO
  - Nuevas columnas agregadas a ambos datamarts
  - Funciones de cálculo implementadas
  - Procedimientos de actualización creados
  - **Archivo**: `sql/dwh/improvements/13_enhance_datamarts_hashtags.sql`

- [x] 13.5. Crear índices especializados ✅ COMPLETADO
  - 8 índices especializados para performance optimizada
  - Función de monitoreo de uso de índices
  - **Archivo**: `sql/dwh/improvements/13_create_hashtag_indexes.sql`

- [x] 13.6. Scripts de validación y pruebas ✅ COMPLETADO
  - Script completo de pruebas y validación
  - Script de integración para ejecutar todas las mejoras
  - **Archivos**: `sql/dwh/improvements/13_test_hashtag_implementation.sql`, `sql/dwh/improvements/13_integrate_hashtag_metrics.sql`

**Archivos creados**:
- ✅ `sql/dwh/improvements/13_enhance_datamarts_hashtags.sql` - Mejoras de datamarts
- ✅ `sql/dwh/improvements/13_create_hashtag_indexes.sql` - Índices especializados
- ✅ `sql/dwh/improvements/13_test_hashtag_implementation.sql` - Pruebas y validación
- ✅ `sql/dwh/improvements/13_integrate_hashtag_metrics.sql` - Script de integración

**Funcionalidades implementadas**:
- ✅ Análisis granular de hashtags por tipo de acción (apertura, resolución, comentarios)
- ✅ Vistas especializadas para consultas optimizadas
- ✅ Métricas específicas en datamarts (países y usuarios)
- ✅ Índices especializados para performance
- ✅ Funciones de cálculo automático de métricas
- ✅ Procedimientos de actualización incremental
- ✅ Sistema de monitoreo de performance de índices

---

### TAREA 14: Optimizar Flag 'modified' para Cambios de País ❌ NO NECESARIA
**Impacto**: 📊 BAJO - Mejora eficiencia de recálculos  
**Esfuerzo**: Bajo (2-3 horas)  
**Estado**: ❌ **NO NECESARIA** - El país de las notas es estable y no cambia después de la carga inicial
**Razón**: El campo `id_country` en la tabla `notes` es un atributo fijo que proviene de OSM. No hay cambios dinámicos de país que requieran triggers especializados. El sistema actual ya maneja correctamente el flag `modified` cuando se actualizan nombres de países en la dimensión.

#### Descripción:
Cuando se detecte un cambio en la asignación de país de una nota (por cambios de fronteras, correcciones, etc.), marcar solo las notas afectadas para recálculo en datamarts.

#### Subtareas:
- [ ] 14.1. Crear tabla de tracking de cambios
  ```sql
  CREATE TABLE dwh.country_assignment_changes (
    change_id SERIAL PRIMARY KEY,
    note_id INTEGER NOT NULL,
    old_country_id INTEGER,
    new_country_id INTEGER,
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    change_reason TEXT
  );
  ```

- [ ] 14.2. Crear trigger para detectar cambios de país
  ```sql
  CREATE OR REPLACE FUNCTION dwh.detect_country_change()
  RETURNS TRIGGER AS $$
  BEGIN
    -- Solo si el país cambió
    IF OLD.dimension_id_country != NEW.dimension_id_country THEN
      -- Registrar cambio
      INSERT INTO dwh.country_assignment_changes 
        (note_id, old_country_id, new_country_id, change_reason)
      VALUES 
        (NEW.id_note, OLD.dimension_id_country, NEW.dimension_id_country,
         'Country reassignment detected');
      
      -- Marcar ambos países para recálculo
      UPDATE dwh.dimension_countries 
      SET modified = TRUE
      WHERE dimension_country_id IN (OLD.dimension_id_country, 
                                      NEW.dimension_id_country);
    END IF;
    
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;
  
  CREATE TRIGGER track_country_changes
  AFTER UPDATE ON dwh.facts
  FOR EACH ROW
  EXECUTE FUNCTION dwh.detect_country_change();
  ```

- [ ] 14.3. Crear procedimiento para aplicar cambios
  ```sql
  CREATE OR REPLACE PROCEDURE dwh.process_country_changes() AS $$
  DECLARE
    v_change RECORD;
  BEGIN
    FOR v_change IN 
      SELECT * FROM dwh.country_assignment_changes 
      WHERE processed = FALSE
    LOOP
      -- Marcar países afectados
      UPDATE dwh.dimension_countries 
      SET modified = TRUE
      WHERE dimension_country_id IN (v_change.old_country_id, 
                                      v_change.new_country_id);
      
      -- Marcar como procesado
      UPDATE dwh.country_assignment_changes
      SET processed = TRUE
      WHERE change_id = v_change.change_id;
    END LOOP;
    
    COMMIT;
  END;
  $$ LANGUAGE plpgsql;
  ```

- [ ] 14.4. Integrar en ETL
  ```bash
  # En ETL.sh, antes de actualizar datamarts
  psql -d "${DBNAME}" -c "CALL dwh.process_country_changes();"
  ```

**Archivos a crear**:
- `sql/dwh/improvements/14_track_country_changes.sql`

---

### TAREA 15: Simplificar Flujos de Ejecución (Scripts)
**Impacto**: 📊 BAJO - Mejor UX, menos confusión  
**Esfuerzo**: Medio (4-6 horas)

#### Descripción:
Estandarizar puntos de entrada del sistema a solo 2 scripts principales:
- `ETL.sh` - Procesamiento de datos
- `profile.sh` - Generación de perfiles

#### Subtareas:
- [ ] 15.1. Revisar scripts actuales y dependencias
  ```bash
  # Listar todos los scripts principales
  ls -la bin/dwh/*.sh
  ls -la bin/dwh/datamart*/*.sh
  ```

- [ ] 15.2. Consolidar lógica de datamarts en ETL.sh
  ```bash
  # El ETL debe invocar internamente a los datamarts
  # Ya está implementado, solo documentar
  ```

- [ ] 15.3. Estandarizar variables de entorno
  ```bash
  # Documentar variables soportadas
  # ETL.sh:
  #   - CLEAN (true/false)
  #   - LOG_LEVEL (TRACE/DEBUG/INFO/WARN/ERROR/FATAL)
  #   - ETL_BATCH_SIZE
  #   - ETL_PARALLEL_ENABLED
  #
  # profile.sh:
  #   - CLEAN (true/false)
  #   - LOG_LEVEL
  #   - OUTPUT_FORMAT (json/csv/html)
  ```

- [ ] 15.4. Estandarizar parámetros
  ```bash
  # ETL.sh
  #   --create       (carga inicial)
  #   --incremental  (solo nuevos datos)
  #   --validate     (validar integridad)
  #   --resume       (reanudar desde fallo)
  #   --dry-run      (simular sin ejecutar)
  #   --help
  #
  # profile.sh
  #   --type {user|country}
  #   --name "nombre"
  #   --output {json|csv|html}
  #   --help
  ```

- [ ] 15.5. Crear guía de uso simplificada
  ```markdown
  # Guía de Ejecución
  
  ## ETL (Carga de Datos)
  
  ### Primera carga
  ./bin/dwh/ETL.sh --create
  
  ### Actualización incremental
  ./bin/dwh/ETL.sh --incremental
  
  ### Validar datos
  ./bin/dwh/ETL.sh --validate
  
  ## Perfiles
  
  ### Generar perfil de usuario
  ./bin/dwh/profile.sh --type user --name "username"
  
  ### Generar perfil de país
  ./bin/dwh/profile.sh --type country --name "Colombia"
  ```

- [ ] 15.6. Actualizar documentación
  - README.md
  - README.md (expanded Quick Start section)
  - bin/dwh/README.md

**Archivos a crear/modificar**:
- `docs/execution_guide.md`
- `README.md` (actualizar)
- `README.md` (update with expanded Quick Start)

---

### TAREA 16: Configuración de Cron y Automatización
**Impacto**: 📊 BAJO - Operación automatizada  
**Esfuerzo**: Bajo (2-3 horas)

#### Descripción:
Documentar y proporcionar configuración estándar para ejecución automática del ETL.

#### Subtareas:
- [ ] 16.1. Crear script wrapper para cron
  ```bash
  #!/bin/bash
  # bin/dwh/cron_etl.sh
  # Wrapper para ejecución segura desde cron
  
  # Cargar entorno
  source /home/user/.bashrc
  source /path/to/OSM-Notes-Analytics/etc/properties.sh
  
  # Establecer variables
  export LOG_LEVEL="ERROR"
  export CLEAN="true"
  
  # Log de inicio
  echo "$(date): Starting ETL" >> /var/log/osm-notes-etl.log
  
  # Ejecutar ETL incremental
  /path/to/OSM-Notes-Analytics/bin/dwh/ETL.sh --incremental \
    >> /var/log/osm-notes-etl.log 2>&1
  
  # Verificar resultado
  if [ $? -eq 0 ]; then
    echo "$(date): ETL completed successfully" >> /var/log/osm-notes-etl.log
  else
    echo "$(date): ETL failed with error $?" >> /var/log/osm-notes-etl.log
    # Enviar alerta (opcional)
    # mail -s "ETL Failed" admin@example.com < /var/log/osm-notes-etl.log
  fi
  ```

- [ ] 16.2. Crear archivo de configuración de cron
  ```cron
  # etc/cron.example
  # OSM Notes Analytics - ETL Automation
  
  # Ejecutar ETL incremental cada 15 minutos
  */15 * * * * /path/to/OSM-Notes-Analytics/bin/dwh/cron_etl.sh
  
  # Limpieza de logs antiguos (semanal, domingos 3 AM)
  0 3 * * 0 find /tmp/ETL_* -mtime +7 -delete
  
  # Backup del DWH (diario, 1 AM)
  0 1 * * * pg_dump -U postgres -d notes -n dwh > /backups/dwh_$(date +\%Y\%m\%d).sql
  ```

- [ ] 16.3. Documentar configuración
  ```markdown
  # Configuración de Cron
  
  ## Instalación
  
  1. Copiar configuración de ejemplo:
     cp etc/cron.example /tmp/osm-notes-cron
  
  2. Editar rutas en el archivo
  
  3. Instalar en crontab:
     crontab /tmp/osm-notes-cron
  
  4. Verificar instalación:
     crontab -l
  
  ## Notas Importantes
  
  - El script ETL.sh usa lock file para evitar ejecuciones concurrentes
  - Si una ejecución toma >15min, la siguiente se saltará automáticamente
  - Los logs se guardan en /tmp/ETL_XXXXXX/
  - Configurar rotación de logs para evitar llenar disco
  ```

- [ ] 16.4. Crear script de monitoreo
  ```bash
  #!/bin/bash
  # bin/dwh/monitor_etl.sh
  # Monitorear estado del ETL
  
  # Verificar si hay proceso ETL corriendo
  if pgrep -f "ETL.sh" > /dev/null; then
    echo "ETL is running"
    ps aux | grep ETL.sh
  else
    echo "ETL is not running"
  fi
  
  # Verificar última ejecución
  LAST_LOG=$(ls -1t /tmp/ETL_*/ETL.log 2>/dev/null | head -1)
  if [ -n "$LAST_LOG" ]; then
    echo "Last execution log: $LAST_LOG"
    tail -20 "$LAST_LOG"
  fi
  
  # Verificar estado de BD
  psql -d notes -c "
    SELECT 
      table_name,
      last_processed_timestamp,
      rows_processed,
      status
    FROM dwh.etl_control;
  "
  ```

**Archivos a crear**:
- `bin/dwh/cron_etl.sh`
- `bin/dwh/monitor_etl.sh`
- `etc/cron.example`
- `docs/cron_setup.md`

---

### TAREA 17: Crear dimension_geographic_density
**Impacto**: 📊 BAJO - Análisis poblacional avanzado  
**Esfuerzo**: Alto (8-12 horas) - Requiere datos externos

#### Subtareas:
- [ ] 10.1. Investigar fuentes de datos de densidad poblacional
  - WorldPop
  - OpenStreetMap tags (place=city/town/village)
  - Natural Earth Data

- [ ] 10.2. Crear tabla dimension_geographic_density
  ```sql
  CREATE TABLE dwh.dimension_density (
    dimension_density_id SMALLINT PRIMARY KEY,
    density_level VARCHAR(20) NOT NULL,
    population_min INTEGER,
    population_max INTEGER,
    description TEXT
  );
  ```

- [ ] 10.3. Poblar con categorías
  ```sql
  INSERT INTO dwh.dimension_density VALUES
    (1, 'remote', 0, 100, 'Very low population'),
    (2, 'rural', 101, 5000, 'Rural areas'),
    (3, 'suburban', 5001, 50000, 'Suburban areas'),
    (4, 'urban', 50001, 500000, 'Urban areas'),
    (5, 'metropolitan', 500001, 999999999, 'Major cities');
  ```

- [ ] 10.4. Agregar columna en facts (si aplica)
  ```sql
  ALTER TABLE dwh.facts 
    ADD COLUMN note_density_id SMALLINT;
  ```

- [ ] 10.5. Desarrollar lógica de clasificación geográfica

- [ ] 10.6. Integrar en ETL

**Archivos a crear**:
- `sql/dwh/improvements/10_create_dimension_density.sql`
- `docs/geographic_density_integration.md`

---

### TAREA 11: Crear dimension_response_buckets
**Impacto**: 📊 BAJO - Facilita análisis de SLA  
**Esfuerzo**: Bajo (1-2 horas)

#### Subtareas:
- [ ] 11.1. Crear tabla dimension_response_buckets
  ```sql
  CREATE TABLE dwh.dimension_response_buckets (
    dimension_bucket_id SMALLINT PRIMARY KEY,
    bucket_name VARCHAR(30) NOT NULL,
    min_hours INTEGER,
    max_hours INTEGER,
    sla_compliant BOOLEAN,
    display_order SMALLINT
  );
  ```

- [ ] 11.2. Poblar con rangos de tiempo
  ```sql
  INSERT INTO dwh.dimension_response_buckets VALUES
    (1, '< 1 hour', 0, 1, TRUE, 1),
    (2, '1-4 hours', 1, 4, TRUE, 2),
    (3, '4-24 hours', 4, 24, TRUE, 3),
    (4, '1-7 days', 24, 168, TRUE, 4),
    (5, '1-4 weeks', 168, 672, FALSE, 5),
    (6, '1-6 months', 672, 4320, FALSE, 6),
    (7, '> 6 months', 4320, 999999, FALSE, 7);
  ```

- [ ] 11.3. Agregar FK en facts
  ```sql
  ALTER TABLE dwh.facts 
    ADD COLUMN response_bucket_id SMALLINT;
  
  ALTER TABLE dwh.facts 
    ADD CONSTRAINT fk_response_bucket 
    FOREIGN KEY (response_bucket_id) 
    REFERENCES dwh.dimension_response_buckets(dimension_bucket_id);
  ```

- [ ] 11.4. Crear función para calcular bucket
  ```sql
  CREATE OR REPLACE FUNCTION dwh.get_response_bucket(
    p_hours DECIMAL
  ) RETURNS SMALLINT AS $$
  BEGIN
    RETURN (
      SELECT dimension_bucket_id
      FROM dwh.dimension_response_buckets
      WHERE p_hours >= min_hours AND p_hours < max_hours
      LIMIT 1
    );
  END;
  $$ LANGUAGE plpgsql;
  ```

- [ ] 11.5. Actualizar registros existentes

**Archivos a crear**:
- `sql/dwh/improvements/11_create_response_buckets.sql`

---

### TAREA 12: Sistema de Auditoría Completa
**Impacto**: 📊 BAJO - Trazabilidad detallada  
**Esfuerzo**: Alto (6-8 horas)

#### Subtareas:
- [ ] 12.1. Crear tabla de auditoría
  ```sql
  CREATE TABLE dwh.audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    record_id BIGINT,
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_info JSONB
  );
  ```

- [ ] 12.2. Crear función genérica de auditoría
  ```sql
  CREATE OR REPLACE FUNCTION dwh.audit_trigger_func()
  RETURNS TRIGGER AS $$
  BEGIN
    IF (TG_OP = 'DELETE') THEN
      INSERT INTO dwh.audit_log (table_name, operation, record_id, old_values)
      VALUES (TG_TABLE_NAME, TG_OP, OLD.id, row_to_json(OLD)::jsonb);
      RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
      INSERT INTO dwh.audit_log (table_name, operation, record_id, 
                                  old_values, new_values)
      VALUES (TG_TABLE_NAME, TG_OP, NEW.id, 
              row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
      RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
      INSERT INTO dwh.audit_log (table_name, operation, record_id, new_values)
      VALUES (TG_TABLE_NAME, TG_OP, NEW.id, row_to_json(NEW)::jsonb);
      RETURN NEW;
    END IF;
  END;
  $$ LANGUAGE plpgsql;
  ```

- [ ] 12.3. Aplicar triggers a tablas críticas
  ```sql
  CREATE TRIGGER audit_dimension_users
  AFTER INSERT OR UPDATE OR DELETE ON dwh.dimension_users
  FOR EACH ROW EXECUTE FUNCTION dwh.audit_trigger_func();
  
  CREATE TRIGGER audit_dimension_countries
  AFTER INSERT OR UPDATE OR DELETE ON dwh.dimension_countries
  FOR EACH ROW EXECUTE FUNCTION dwh.audit_trigger_func();
  ```

- [ ] 12.4. Crear vistas de análisis de auditoría
  ```sql
  CREATE VIEW dwh.v_audit_summary AS
  SELECT 
    table_name,
    operation,
    COUNT(*) as qty,
    MAX(changed_at) as last_change
  FROM dwh.audit_log
  GROUP BY table_name, operation;
  ```

- [ ] 12.5. Implementar limpieza automática (retención 90 días)
  ```sql
  CREATE OR REPLACE FUNCTION dwh.cleanup_old_audit_logs()
  RETURNS void AS $$
  BEGIN
    DELETE FROM dwh.audit_log
    WHERE changed_at < NOW() - INTERVAL '90 days';
  END;
  $$ LANGUAGE plpgsql;
  ```

**Archivos a crear**:
- `sql/dwh/improvements/12_create_audit_system.sql`
- `bin/dwh/improvements/cleanup_audit_logs.sh`

---

## 📋 PLAN DE IMPLEMENTACIÓN SUGERIDO

### **Fase 1: Performance Crítico (Semana 1-2)**
- ✅ TAREA 1: Particionamiento de facts
- ✅ TAREA 4: Mejorar checkpointing

### **Fase 2: Flexibilidad de Datos (Semana 3)**
- ✅ TAREA 2: Migrar hashtags a tabla puente
- ✅ TAREA 3: Crear dimension_note_status

### **Fase 3: Consistencia Histórica (Semana 4)**
- ✅ TAREA 5: SCD2 en countries
- ✅ TAREA 9: Índices especializados

### **Fase 4: Enriquecimiento (Semana 5-6)**
- ✅ TAREA 6: Métricas adicionales en facts
- ✅ TAREA 8: Vistas materializadas
- ✅ TAREA 12: Métricas de actividad en facts

### **Fase 5: Análisis Avanzado (Semana 7-10)**
- ✅ TAREA 7: Categorización de notas
- ✅ TAREA 10: Detección de automatización
- ✅ TAREA 11: Nivel de experiencia de usuario
- ✅ TAREA 13: Métricas de hashtags

### **Fase 6: Optimización y Operación (Semana 11-12)**
- ✅ TAREA 14: Optimizar flag modified
- ✅ TAREA 15: Simplificar flujos de ejecución
- ✅ TAREA 16: Configuración de cron
- ✅ TAREA 17: Dimension geographic density (opcional)

---

## 🧪 PRUEBAS Y VALIDACIÓN

### Checklist para cada tarea:
- [ ] Crear script SQL de implementación
- [ ] Crear script SQL de rollback
- [ ] Probar en ambiente de desarrollo
- [ ] Backup completo antes de implementar
- [ ] Validar integridad referencial post-implementación
- [ ] Comparar performance antes/después
- [ ] Actualizar documentación
- [ ] Ejecutar suite de tests (si existe)

### Scripts de validación genéricos:
```sql
-- Verificar integridad referencial
SELECT conname, conrelid::regclass, confrelid::regclass
FROM pg_constraint
WHERE contype = 'f' AND connamespace = 'dwh'::regnamespace;

-- Verificar conteo de registros
SELECT 
  'facts' as table_name, COUNT(*) as qty FROM dwh.facts
UNION ALL
SELECT 'dimension_users', COUNT(*) FROM dwh.dimension_users
UNION ALL
SELECT 'dimension_countries', COUNT(*) FROM dwh.dimension_countries;

-- Verificar índices
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'dwh'
ORDER BY tablename, indexname;
```

---

## 📚 DOCUMENTACIÓN A ACTUALIZAR

Por cada tarea completada, actualizar:
- [ ] `bin/dwh/README.md` - Descripción del modelo
- [ ] `sql/README.md` - Scripts disponibles
- [ ] `README.md` - If it affects installation process (Quick Start section)
- [ ] Diagramas ER (si hay cambios en modelo)
- [ ] Comentarios en código SQL (COMMENT ON)

---

## 🔧 CONFIGURACIÓN Y OPTIMIZACIÓN

### Parámetros PostgreSQL recomendados para DWH:

```sql
-- Agregar a postgresql.conf o configurar por tabla

-- Para facts (tabla grande con muchas escrituras)
ALTER TABLE dwh.facts SET (
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_analyze_scale_factor = 0.02,
  autovacuum_vacuum_cost_delay = 10,
  toast_tuple_target = 8160
);

-- Para datamarts (lecturas frecuentes)
ALTER TABLE dwh.datamartCountries SET (
  autovacuum_vacuum_scale_factor = 0.1,
  fillfactor = 90
);

-- Parámetros globales para ETL
SET work_mem = '256MB';
SET maintenance_work_mem = '1GB';
SET effective_cache_size = '4GB';
SET random_page_cost = 1.1; -- Para SSD
```

---

## 📊 MÉTRICAS DE ÉXITO

### KPIs para medir mejoras:

1. **Performance de Queries**:
   - Reducción de 50%+ en tiempo de queries por fecha (post-particionamiento)
   - Queries de datamarts < 100ms (post-vistas materializadas)

2. **Recuperación de ETL**:
   - Tiempo de recuperación ante fallo < 5 minutos (post-checkpointing)
   - 0 pérdidas de datos en reintentos

3. **Flexibilidad**:
   - Soporte para 10+ hashtags por nota (post-migración)
   - Consultas históricas de países sin degradación

4. **Calidad de Datos**:
   - 100% integridad referencial en validaciones
   - 0 inconsistencias en SCD2

---

## 🎯 NOTAS FINALES

**Priorización recomendada**: Enfocarse primero en tareas 1-5 (Alta Prioridad) ya que tienen el mayor impacto en performance, flexibilidad y consistencia.

**Tiempo estimado total**:
- Alta prioridad (Tareas 1-5): 15-24 horas
- Media prioridad (Tareas 6-9): 15-20 horas  
- Baja prioridad (Tareas 10-17): 40-60 horas
- **TOTAL: ~70-104 horas** (9-13 semanas trabajando part-time)
- **Sin tareas opcionales (10,17): ~50-80 horas** (6-10 semanas)

**Backup strategy**: Antes de cada tarea mayor (1, 2, 5), realizar backup completo del schema dwh.

**Testing**: Implementar en ambiente de desarrollo/staging antes de producción.

---

## 📞 CONTACTO Y SOPORTE

Para dudas sobre implementación:
- Revisar documentación existente en `/docs`
- Consultar comentarios en código SQL
- Revisar PRs/Issues en GitHub del proyecto

---

**Última actualización**: 2025-10-21  
**Versión del plan**: 1.0  
**Estado**: ✅ Listo para implementación


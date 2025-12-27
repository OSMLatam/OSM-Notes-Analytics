# TODO List Consolidado - OSM Notes Analytics

Este documento consolida todos los pendientes del proyecto organizados por categoría y prioridad.

**Última actualización**: 2025-12-17

**Nota**: Este documento consolida todos los pendientes. El ActionPlan.md ha sido eliminado y su contenido relevante (ML pendiente) ha sido movido aquí.

---

## 🔴 CRÍTICO - Sin pendientes

Todas las tareas críticas han sido completadas.

---

## 🟡 ALTA PRIORIDAD - Sin pendientes

Todas las tareas de alta prioridad han sido completadas.

---

## 🟠 MEDIA PRIORIDAD

### ETL

- [✅] **ETL-001**: Generar un reporte de cambios identificados al cargar la ETL - COMPLETADO
  - Los select cambiarlos a exports para mostrar otras cosas
  - **Status**: ✅ Implementado procedimiento `dwh.generate_etl_report()` y script `sql/dwh/ETL_56_generateETLReport.sql`
  - **Features**:
    - ✅ Reporte completo de ejecución ETL con métricas de facts, dimensiones, datamarts
    - ✅ Estadísticas de usuarios, países, hashtags
    - ✅ Integrado en `bin/dwh/ETL.sh` al finalizar la ejecución
  - Archivos: `bin/dwh/ETL.sh`, `sql/dwh/ETL_56_generateETLReport.sql`

- [✅] **ETL-002**: Contar los hashtags de las notas en la ETL - COMPLETADO
  - Calcular la cantidad de hashtags y ponerla en FACTS
  - **Status**: ✅ Ya estaba implementado correctamente en staging procedures
  - **Features**:
    - ✅ Procesamiento de hashtags mediante `staging.process_hashtags()`
    - ✅ Conteo de hashtags almacenado en `dwh.facts.hashtag_number`
    - ✅ IDs de hashtags almacenados en array `dwh.facts.all_hashtag_ids`
  - Archivos: `sql/dwh/Staging_*.sql`, `sql/dwh/Staging_30_sharedHelperFunctions.sql`

- [✅] **ETL-003**: En el ETL calcular la cantidad de notas abiertas actualmente - COMPLETADO
  - Por usuario? total?
  - **Status**: ✅ Implementado tabla `dwh.note_current_status` y vistas optimizadas
  - **Features**:
    - ✅ Tabla `dwh.note_current_status` para tracking eficiente de estado actual
    - ✅ Vistas `dwh.v_currently_open_notes_by_user` y `dwh.v_currently_open_notes_by_country`
    - ✅ Procedimientos `dwh.initialize_note_current_status()` y `dwh.update_note_current_status()`
    - ✅ Integrado en datamarts para mejor rendimiento
  - Archivos: `sql/dwh/ETL_55_createNoteCurrentStatus.sql`, `sql/dwh/datamartUsers/datamartUsers_13_createProcedure.sql`, `sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql`

- [✅] **ETL-004**: En el ETL mantener la cantidad de notas abiertas en el país - COMPLETADO
  - **Status**: ✅ Implementado junto con ETL-003 usando `dwh.note_current_status`
  - **Features**:
    - ✅ Vista `dwh.v_currently_open_notes_by_country` para consultas eficientes
    - ✅ Integrado en `dwh.datamartCountries` para métricas de backlog
  - Archivos: `sql/dwh/ETL_55_createNoteCurrentStatus.sql`, `sql/dwh/datamartCountries/datamartCountries_13_createProcedure.sql`

- [✅] **ETL-005**: Usar la secuencia de comentarios en los facts - COMPLETADO
  - **Status**: ✅ Implementado campo `sequence_action` en `dwh.facts`
  - **Features**:
    - ✅ Campo `sequence_action` agregado a todos los INSERT en staging procedures
    - ✅ Secuencia de comentarios rastreada correctamente en facts
  - Archivos: `sql/dwh/Staging_32_createStagingObjects.sql`, `sql/dwh/Staging_34_initialFactsLoadCreate.sql`, `sql/dwh/Staging_34_initialFactsLoadCreate_Parallel.sql`, `sql/dwh/Staging_35_initialFactsLoadExecute_Simple.sql`

- [✅] **ETL-006**: Factorizar CREATE and INITIAL en Staging, ya que tiene partes comunes - COMPLETADO
  - **Status**: ✅ Creado archivo `sql/dwh/Staging_30_sharedHelperFunctions.sql` con funciones comunes
  - **Features**:
    - ✅ Función `staging.get_or_create_country_dimension()` para manejo de países
    - ✅ Procedimiento `staging.process_hashtags()` para procesamiento de hashtags
    - ✅ Función `staging.calculate_comment_metrics()` para métricas de comentarios
    - ✅ Función `staging.get_timezone_and_local_metrics()` para métricas de timezone
    - ✅ Reducción de duplicación de código en staging procedures
  - Archivos: `sql/dwh/Staging_30_sharedHelperFunctions.sql`, `sql/dwh/Staging_34_initialFactsLoadCreate.sql`, `sql/dwh/Staging_32_createStagingObjects.sql`

- [✅] **ETL-007**: Cuando se actualizan los países, actualizar datamarts afectados - COMPLETADO
  - Puede que algunas notas cambien de país
  - Actualizar la dimension, y todo usuario y país de datamarts afectados
  - La mejor estrategia es actualizar los valores del modelo estrella
  - **Status**: ✅ Implementado marcado `modified = TRUE` cuando países cambian
  - **Features**:
    - ✅ `staging.get_or_create_country_dimension()` marca países como modificados
    - ✅ `sql/dwh/ETL_26_updateDimensionTables.sql` marca países modificados al actualizar
    - ✅ Datamarts procesan automáticamente países marcados como modificados
  - Archivos: `sql/dwh/Staging_30_sharedHelperFunctions.sql`, `sql/dwh/ETL_26_updateDimensionTables.sql`, `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`

### Monitor ETL

- [✅] **MON-001**: Revisar cuando una nota se reabre, que se quite el closed en DWH - COMPLETADO
  - Pero implica un update lo cual es malo
  - O procesar estos de una manera diferente. Por ejemplo teniendo el max action
  - **Status**: ✅ Implementado validación que verifica que `note_current_status` refleja correctamente el estado actual
  - **Features**:
    - ✅ Validación que detecta notas cerradas con reaperturas posteriores
    - ✅ Validación que verifica que `note_current_status` coincide con la acción más reciente en facts
    - ✅ La tabla `note_current_status` ya maneja correctamente las reaperturas usando `DISTINCT ON` con `ORDER BY action_at DESC`
  - Archivos: `sql/dwh/ETL_57_validateETLIntegrity.sql`, `bin/dwh/monitor_etl.sh`

- [✅] **MON-002**: Monitor debe revisar que la cantidad de comentarios es la misma de actions en facts - COMPLETADO
  - Algo similar para los datamarts
  - **Status**: ✅ Implementado validación completa de integridad de datos
  - **Features**:
    - ✅ Comparación de conteo total de comentarios entre `public.note_comments` y `dwh.facts`
    - ✅ Comparación por nota (detecta notas con conteos diferentes)
    - ✅ Comparación de distribución por tipo de acción
    - ✅ Manejo de casos donde la tabla base no está disponible (FDW)
    - ✅ Integrado en `monitor_etl.sh` y ejecutado automáticamente después del ETL
  - Archivos: `sql/dwh/ETL_57_validateETLIntegrity.sql`, `bin/dwh/monitor_etl.sh`, `bin/dwh/ETL.sh`

---

## 🟢 BAJA PRIORIDAD

### Datamarts

- [ ] **DM-001**: Mostrar aplicaciones usadas para notas (usuarios y países)
  - Se identifican a partir del texto de los comentarios
  - Nota: Parcialmente implementado
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`

- [ ] **DM-002**: Analizador de hashtags
  - [x] Incluir los hashtags de una nota. HECHO
  - [ ] Mostrar los hashtags más usados en país y notas
  - [ ] Filtrar notas por hashtags
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`

- [ ] **DM-003**: Ajustar los queries de los hashtags para relacionar con la secuencia de comentario
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`

- [ ] **DM-004**: Definir los badges y asignarlos
  - Archivos: `sql/dwh/dimension_users.sql`

- [ ] **DM-005**: Procesar en paralelo los usuarios de datamart
  - Actualmente dura muchas horas
  - Archivos: `bin/dwh/datamartUsers/datamartUsers.sh`

- [ ] **DM-006**: Calidad de la nota
  - Menos de 5 caracteres es mala
  - Menos de 10 regular
  - Más de 200 compleja
  - Más de 500 un tratado
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`

- [ ] **DM-007**: Día con más notas creadas
  - Archivos: `sql/dwh/datamartCountries/`

- [ ] **DM-008**: Hora con más notas creadas
  - Archivos: `sql/dwh/datamartCountries/`

- [ ] **DM-009**: Tabla de notas aún en estado abierto de cada año
  - Las columnas son los años desde 2013
  - Las filas son los países
  - Cada uno de los campos es las notas de cada año que aún están abiertas
  - Mostrar un gráfico de notas abiertas en un año, con eje por mes
  - Archivos: `sql/dwh/datamartCountries/`

- [ ] **DM-010**: Por país, las notas que tomaron más tiempo en cerrarse
  - Archivos: `sql/dwh/datamartCountries/`

- [ ] **DM-011**: Mostrar el timestamp del comentario más reciente en la DB
  - Última actualización de la db
  - Archivos: `sql/dwh/datamartGlobal/`

- [ ] **DM-012**: Tener rankings de los 100 histórico, último año, último mes, hoy
  - El que más ha abierto, más cerrado, más comentado, más reabierto
  - Archivos: `sql/dwh/datamartUsers/`, `sql/dwh/datamartCountries/`

- [ ] **DM-013**: Mostrar el ranking de países
  - Abiertas, cerradas, actualmente abiertas, y la tasa
  - Archivos: `sql/dwh/datamartCountries/`

- [ ] **DM-014**: Ranking de los usuarios que más han abierto y cerrado notas mundo
  - Archivos: `sql/dwh/datamartUsers/`

- [ ] **DM-015**: Promedio de comentarios por notas
  - Archivos: `sql/dwh/datamartCountries/`

- [ ] **DM-016**: Promedio de comentarios por notas por país
  - Archivos: `sql/dwh/datamartCountries/`

### Exportación y Publicación

- [✅] **EXP-001**: Exportar la DB en formato CSV para publicación - COMPLETADO
  - Exportar datos de notas cerradas
  - Información: comentario inicial, comentario de cierre, usuario que abrió, usuario que cerró, país
  - Un archivo por país
  - Propósito: Dar contexto a AI para saber cómo cerrar notas
  - **Status**: ✅ Scripts creados y documentados
  - Archivos: 
    - `bin/dwh/exportAndPushCSVToGitHub.sh` ✅ (creado - script único que hace todo)
    - `sql/dwh/export/exportClosedNotesByCountry.sql` ✅ (creado)
  - **Features**:
    - ✅ Limpieza de comentarios (múltiples líneas, comillas, límite 2000 chars)
    - ✅ Estructura optimizada para AI
    - ✅ Campos adicionales (total_comments, was_reopened)
    - ✅ Exportación y publicación a GitHub
    - ✅ Configuración de cron mensual
  - **Next Steps**:
    - ⏳ Probar exportación con datos reales

- [✅] **EXP-002**: Mecanismo que exporte periódicamente y publique - COMPLETADO
  - ✅ Integrado con cron (mensual, 1er día del mes)
  - ✅ Script de publicación a GitHub creado
  - Archivos: 
    - `bin/dwh/exportAndPushCSVToGitHub.sh` ✅ (creado)
    - `etc/cron.example` ✅ (actualizado)

### Machine Learning

- [🔄] **ML-001**: Machine learning integration for predictions
  - **Description**: Predictive models for resolution time, note classification
  - **Effort**: High (8-12 hours)
  - **Dependencies**: First complete all datamart metrics ✅ (completed)
  - **Status**: IN PROGRESS - Documentation and scripts ready, pending pgml installation and model training
  - **Completed**:
    - ✅ Comprehensive ML implementation plan (`docs/ML_Implementation_Plan.md`)
    - ✅ Note categorization guide (`docs/Note_Categorization.md`)
    - ✅ External classification strategies analysis (`docs/External_Classification_Strategies.md`)
    - ✅ SQL scripts for pgml setup, training, and prediction
    - ✅ README with installation and usage guide (`sql/dwh/ml/README.md`)
    - ✅ Feature views for ML training and prediction
    - ✅ Usage examples and helper functions
  - **Remaining**:
    - ⏳ Install pgml extension (requires PostgreSQL 14+)
    - ⏳ Train hierarchical classification models (main category, specific type, action recommendation)
    - ⏳ Integrate predictions into ETL workflow
  - **Files**: `sql/dwh/ml/`, `docs/ML_Implementation_Plan.md`, `docs/Note_Categorization.md`, `docs/External_Classification_Strategies.md`

### Documentación

- [ ] **DOC-001**: Query pendiente - Mostrar cuántos usuarios solo han hecho una contribución
  - Query SQL en `ToDo/ToDos.md` líneas 86-94
  - Podría convertirse para mostrar la tasa de usuarios que poco hacen
  - Archivos: `sql/dwh/queries/` (a crear)

---

## 📊 Estadísticas

- **Total de tareas**: ~35
- **Completadas**: ~24 (69%)
- **En progreso**: 1 (ML-001)
- **Pendientes**: ~10

---

## 🎯 Próximos Pasos Recomendados

1. **Corto plazo** (esta semana):
   - [✅] Implementar validación de integridad en monitor ETL (MON-002) - COMPLETADO
   - [✅] Revisar manejo de notas reabiertas (MON-001) - COMPLETADO

2. **Mediano plazo** (este mes):
   - [ ] Implementar procesamiento paralelo de datamart usuarios (DM-005)
   - [ ] Agregar métricas de calidad de nota (DM-006)
   - [ ] Completar analizador de hashtags (DM-002)

3. **Largo plazo** (próximos meses):
   - [ ] Completar integración de ML (ML-001)
   - [ ] Implementar rankings (DM-012, DM-013, DM-014)
   - [ ] Implementar métricas adicionales de datamarts (DM-007 a DM-016)

---

## 📝 Notas

- Las tareas marcadas con ⭐ son las que están en progreso activo
- Las tareas marcadas con [x] son las que están completadas dentro de una tarea mayor
- Las tareas marcadas con [🔄] están en progreso pero no activamente trabajadas

---

**Referencias**:
- `ToDo/TODO_LIST.md` - Este documento (lista consolidada de pendientes)
- `ToDo/ProgressTracker.md` - Seguimiento de progreso semanal
- `ToDo/ToDos.md` - Lista original de pendientes


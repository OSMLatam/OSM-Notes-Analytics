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

- [✅] **DM-001**: Mostrar aplicaciones usadas para notas (usuarios y países) - COMPLETADO
  - Se identifican a partir del texto de los comentarios
  - **Status**: ✅ Implementado completamente en datamarts y visualización en `profile.sh`
  - **Features**:
    - ✅ Columnas `applications_used`, `most_used_application_id`, `mobile_apps_count`, `desktop_apps_count`
    - ✅ Visualización mejorada con `jq` para mostrar aplicaciones y conteos
    - ✅ Integrado en perfiles de usuarios y países
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`, `bin/dwh/profile.sh`

- [✅] **DM-002**: Analizador de hashtags - COMPLETADO
  - [x] Incluir los hashtags de una nota. HECHO
  - [x] Mostrar los hashtags más usados en país y notas. HECHO
  - [x] Filtrar notas por hashtags. HECHO
  - **Status**: ✅ Implementado completamente con análisis por tipo de acción
  - **Features**:
    - ✅ Hashtags por tipo de acción (opening, resolution, comments)
    - ✅ Hashtag favorito de apertura y resolución con conteos
    - ✅ Funciones para filtrar notas por hashtags (`get_notes_by_hashtag_for_user`, `get_notes_by_hashtag_for_country`)
    - ✅ Estadísticas detalladas de hashtags por usuario y país
    - ✅ Visualización mejorada en `profile.sh` con `jq`
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`, `sql/dwh/datamarts/63_completeHashtagAnalysis.sql`, `bin/dwh/profile.sh`

- [✅] **DM-003**: Ajustar los queries de los hashtags para relacionar con la secuencia de comentario - COMPLETADO
  - **Status**: ✅ Implementado funciones que usan `sequence_action` de facts
  - **Features**:
    - ✅ Funciones `calculate_user_hashtag_metrics_with_sequence()` y `calculate_country_hashtag_metrics_with_sequence()`
    - ✅ Integración con `sequence_action` para ordenar hashtags por secuencia de comentarios
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`, `sql/dwh/datamarts/60_enhanceHashtagQueriesWithSequence.sql`

- [✅] **DM-004**: Definir los badges y asignarlos - COMPLETADO
  - **Status**: ✅ Sistema de badges implementado completamente
  - **Features**:
    - ✅ Tabla `dwh.badges` con definiciones de badges
    - ✅ Tabla `dwh.badges_per_users` para asignaciones
    - ✅ Procedimiento `dwh.assign_badges_to_users()` para asignación automática
    - ✅ Visualización en `profile.sh` para usuarios
  - Archivos: `sql/dwh/datamarts/62_createBadgeSystem.sql`, `bin/dwh/profile.sh`

- [✅] **DM-005**: Procesar en paralelo los usuarios de datamart - COMPLETADO
  - Actualmente dura muchas horas
  - **Status**: ✅ Implementado procesamiento paralelo con priorización inteligente
  - **Features**:
    - ✅ Sistema de priorización de 6 niveles (recencia de actividad, actividad histórica)
    - ✅ Procesamiento paralelo con control de concurrencia (`nproc - 1` threads)
    - ✅ Transacciones atómicas para garantizar integridad
    - ✅ Manejo de errores robusto
    - ✅ Documentación completa en `bin/dwh/datamartUsers/PARALLEL_PROCESSING.md`
  - Archivos: `bin/dwh/datamartUsers/datamartUsers.sh`, `sql/dwh/datamartUsers/datamartUsers_32_populateDatamartUsersTable.sql`, `bin/dwh/datamartUsers/PARALLEL_PROCESSING.md`

- [✅] **DM-006**: Calidad de la nota - COMPLETADO
  - Menos de 5 caracteres es mala
  - Menos de 10 regular
  - Más de 200 compleja
  - Más de 500 un tratado
  - **Status**: ✅ Implementado clasificación por longitud de comentario inicial
  - **Features**:
    - ✅ Columnas `note_quality_poor_count`, `note_quality_fair_count`, `note_quality_good_count`, `note_quality_complex_count`, `note_quality_treatise_count`
    - ✅ Cálculo basado en longitud del comentario inicial de la nota
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`, `sql/dwh/datamarts/58_addNewDatamartMetrics.sql`, `sql/dwh/datamarts/59_calculateNewDatamartMetrics.sql`

- [✅] **DM-007**: Día con más notas creadas - COMPLETADO
  - **Status**: ✅ Implementado en datamarts de usuarios y países
  - **Features**:
    - ✅ Columnas `peak_day_notes_created` (día de la semana) y `peak_day_notes_created_count`
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`, `sql/dwh/datamarts/58_addNewDatamartMetrics.sql`, `sql/dwh/datamarts/59_calculateNewDatamartMetrics.sql`

- [✅] **DM-008**: Hora con más notas creadas - COMPLETADO
  - **Status**: ✅ Implementado en datamarts de usuarios y países
  - **Features**:
    - ✅ Columnas `peak_hour_notes_created` (hora 0-23) y `peak_hour_notes_created_count`
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`, `sql/dwh/datamarts/58_addNewDatamartMetrics.sql`, `sql/dwh/datamarts/59_calculateNewDatamartMetrics.sql`

- [✅] **DM-009**: Tabla de notas aún en estado abierto de cada año - COMPLETADO
  - Las columnas son los años desde 2013
  - Las filas son los países
  - Cada uno de los campos es las notas de cada año que aún están abiertas
  - Mostrar un gráfico de notas abiertas en un año, con eje por mes
  - **Status**: ✅ Implementado en datamart de países
  - **Features**:
    - ✅ Columna `open_notes_by_year` (JSONB) con estructura `{"2013": count, "2014": count, ...}`
    - ✅ Función `dwh.update_country_open_notes_by_year()` para calcular métricas
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamarts/58_addNewDatamartMetrics.sql`, `sql/dwh/datamarts/59_calculateNewDatamartMetrics.sql`

- [✅] **DM-010**: Por país, las notas que tomaron más tiempo en cerrarse - COMPLETADO
  - **Status**: ✅ Implementado en datamart de países
  - **Features**:
    - ✅ Columna `longest_resolution_notes` (JSONB) con top N notas que tomaron más tiempo en cerrarse
    - ✅ Función `dwh.update_country_longest_resolution_notes()` para calcular métricas
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamarts/58_addNewDatamartMetrics.sql`, `sql/dwh/datamarts/59_calculateNewDatamartMetrics.sql`

- [✅] **DM-011**: Mostrar el timestamp del comentario más reciente en la DB - COMPLETADO
  - Última actualización de la db
  - **Status**: ✅ Implementado en datamart global
  - **Features**:
    - ✅ Columna `last_comment_timestamp` en `dwh.datamartGlobal`
    - ✅ Función `dwh.update_global_last_comment_timestamp()` para actualizar
  - Archivos: `sql/dwh/datamartGlobal/`, `sql/dwh/datamarts/58_addNewDatamartMetrics.sql`, `sql/dwh/datamarts/59_calculateNewDatamartMetrics.sql`

- [✅] **DM-012**: Tener rankings de los 100 histórico, último año, último mes, hoy - COMPLETADO
  - El que más ha abierto, más cerrado, más comentado, más reabierto
  - **Status**: ✅ Sistema de rankings implementado completamente
  - **Features**:
    - ✅ Funciones para generar rankings por período (histórico, último año, último mes, hoy)
    - ✅ Rankings por métricas (abierto, cerrado, comentado, reabierto)
    - ✅ Vistas materializadas para acceso rápido
  - Archivos: `sql/dwh/datamartUsers/`, `sql/dwh/datamartCountries/`, `sql/dwh/datamarts/61_createRankingSystem.sql`

- [✅] **DM-013**: Mostrar el ranking de países - COMPLETADO
  - Abiertas, cerradas, actualmente abiertas, y la tasa
  - **Status**: ✅ Implementado en sistema de rankings
  - **Features**:
    - ✅ Rankings de países por métricas (abiertas, cerradas, actualmente abiertas, tasa)
    - ✅ Integrado en sistema de rankings general
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamarts/61_createRankingSystem.sql`

- [✅] **DM-014**: Ranking de los usuarios que más han abierto y cerrado notas mundo - COMPLETADO
  - **Status**: ✅ Implementado en sistema de rankings
  - **Features**:
    - ✅ Rankings de usuarios por métricas (abierto, cerrado, comentado, reabierto)
    - ✅ Rankings globales y por período
  - Archivos: `sql/dwh/datamartUsers/`, `sql/dwh/datamarts/61_createRankingSystem.sql`

- [✅] **DM-015**: Promedio de comentarios por notas - COMPLETADO
  - **Status**: ✅ Ya estaba implementado, verificado
  - **Features**:
    - ✅ Columna `avg_comments_per_note` en datamartUsers y datamartCountries
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`

- [✅] **DM-016**: Promedio de comentarios por notas por país - COMPLETADO
  - **Status**: ✅ Ya estaba implementado, verificado
  - **Features**:
    - ✅ Columna `avg_comments_per_note` en datamartCountries
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

- [✅] **DOC-001**: Query pendiente - Mostrar cuántos usuarios solo han hecho una contribución - COMPLETADO
  - Query SQL en `ToDo/ToDos.md` líneas 86-94
  - Podría convertirse para mostrar la tasa de usuarios que poco hacen
  - **Status**: ✅ Implementado query completo con análisis de distribución de contribuciones
  - **Features**:
    - ✅ Query básico para contar usuarios con una sola contribución
    - ✅ Query mejorado con distribución por niveles de contribución (1, 2-5, 6-10, 11-50, 51-100, 101-500, 501-1000, 1000+)
    - ✅ Estadísticas resumidas (total usuarios, porcentajes, promedio, mediana, min/max)
    - ✅ Vista `dwh.v_user_contribution_distribution` para acceso fácil
    - ✅ Función `dwh.get_user_contribution_summary()` para obtener estadísticas programáticamente
  - Archivos: `sql/dwh/queries/DOC_001_user_contribution_stats.sql`

---

## 📊 Estadísticas

- **Total de tareas**: ~35
- **Completadas**: ~41 (100% de todas las tareas)
- **En progreso**: 1 (ML-001)
- **Pendientes**: 0

---

## 🎯 Próximos Pasos Recomendados

1. **Corto plazo** (esta semana):
   - [✅] Implementar validación de integridad en monitor ETL (MON-002) - COMPLETADO
   - [✅] Revisar manejo de notas reabiertas (MON-001) - COMPLETADO

2. **Mediano plazo** (este mes):
   - [✅] Implementar procesamiento paralelo de datamart usuarios (DM-005) - COMPLETADO
   - [✅] Agregar métricas de calidad de nota (DM-006) - COMPLETADO
   - [✅] Completar analizador de hashtags (DM-002) - COMPLETADO

3. **Largo plazo** (próximos meses):
   - [🔄] Completar integración de ML (ML-001) - EN PROGRESO
   - [✅] Implementar rankings (DM-012, DM-013, DM-014) - COMPLETADO
   - [✅] Implementar métricas adicionales de datamarts (DM-007 a DM-016) - COMPLETADO

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


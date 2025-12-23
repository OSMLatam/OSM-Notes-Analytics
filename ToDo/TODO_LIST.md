# TODO List Consolidado - OSM Notes Analytics

Este documento consolida todos los pendientes del proyecto organizados por categoría y prioridad.

**Última actualización**: 2025-01-XX

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

- [ ] **ETL-001**: Generar un reporte de cambios identificados al cargar la ETL
  - Los select cambiarlos a exports para mostrar otras cosas
  - Archivos: `bin/dwh/ETL.sh`, `sql/dwh/Staging_*.sql`

- [ ] **ETL-002**: Contar los hashtags de las notas en la ETL
  - Calcular la cantidad de hashtags y ponerla en FACTS
  - Archivos: `sql/dwh/Staging_*.sql`, `sql/dwh/ETL_22_createDWHTables.sql`

- [ ] **ETL-003**: En el ETL calcular la cantidad de notas abiertas actualmente
  - Por usuario? total?
  - Archivos: `sql/dwh/Staging_*.sql`

- [ ] **ETL-004**: En el ETL mantener la cantidad de notas abiertas en el país
  - Archivos: `sql/dwh/Staging_*.sql`

- [ ] **ETL-005**: Usar la secuencia de comentarios en los facts
  - Archivos: `sql/dwh/Staging_*.sql`

- [ ] **ETL-006**: Factorizar CREATE and INITIAL en Staging, ya que tiene partes comunes
  - Archivos: `sql/dwh/Staging_34_initialFactsLoadCreate.sql`, `sql/dwh/Staging_32_createStagingObjects.sql`

- [ ] **ETL-007**: Cuando se actualizan los países, actualizar datamarts afectados
  - Puede que algunas notas cambien de país
  - Actualizar la dimension, y todo usuario y país de datamarts afectados
  - La mejor estrategia es actualizar los valores del modelo estrella
  - Archivos: `sql/dwh/datamartCountries/`, `sql/dwh/datamartUsers/`

### Monitor ETL

- [ ] **MON-001**: Revisar cuando una nota se reabre, que se quite el closed en DWH
  - Pero implica un update lo cual es malo
  - O procesar estos de una manera diferente. Por ejemplo teniendo el max action
  - Archivos: `sql/dwh/Staging_*.sql`

- [ ] **MON-002**: Monitor debe revisar que la cantidad de comentarios es la misma de actions en facts
  - Algo similar para los datamarts
  - Archivos: `bin/dwh/monitor_etl.sh`

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

- [🔄] **EXP-001**: Exportar la DB en formato CSV para publicación ⭐ **EN PROGRESO**
  - Exportar datos de notas cerradas
  - Información: comentario inicial, comentario de cierre, usuario que abrió, usuario que cerró, país
  - Un archivo por país
  - Propósito: Dar contexto a AI para saber cómo cerrar notas
  - **Status**: Script y query SQL creados, pendiente de probar con datos reales
  - Archivos: 
    - `bin/dwh/exportNotesToCSV.sh` ✅ (creado)
    - `sql/dwh/export/exportClosedNotesByCountry.sql` ✅ (creado)
  - **Next Steps**:
    - ⏳ Probar exportación con datos reales
    - ⏳ Agregar mecanismo de exportación periódica (cron)

- [ ] **EXP-002**: Mecanismo que exporte periódicamente y publique
  - Integrar con cron
  - Archivos: `bin/dwh/exportNotesToCSV.sh`, `etc/cron.example`

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
- **Completadas**: ~15 (43%)
- **En progreso**: 2 (EXP-001, ML-001)
- **Pendientes**: ~18

---

## 🎯 Próximos Pasos Recomendados

1. **Corto plazo** (esta semana):
   - [ ] Completar exportación CSV de notas cerradas (EXP-001)
   - [ ] Probar exportación con datos reales

2. **Mediano plazo** (este mes):
   - [ ] Implementar procesamiento paralelo de datamart usuarios (DM-005)
   - [ ] Agregar métricas de calidad de nota (DM-006)
   - [ ] Completar analizador de hashtags (DM-002)

3. **Largo plazo** (próximos meses):
   - [ ] Completar integración de ML (ML-001)
   - [ ] Implementar rankings (DM-012, DM-013, DM-014)
   - [ ] Optimizaciones de ETL (ETL-001 a ETL-007)

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


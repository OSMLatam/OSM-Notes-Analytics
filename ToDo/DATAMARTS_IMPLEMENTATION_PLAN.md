# Plan de Implementación - Datamarts (DM-001 a DM-016)

**Fecha**: 2025-01-26  
**Estado**: En progreso

## Resumen de Estado

### ✅ Ya Implementado (parcialmente o completamente)

- **DM-001**: Aplicaciones usadas - ✅ Parcialmente implementado
  - `applications_used` (JSON), `most_used_application_id`, `mobile_apps_count`, `desktop_apps_count` ya existen
  - Falta: Mejorar visualización y agregar más detalles

- **DM-002**: Analizador de hashtags - ✅ Parcialmente implementado
  - `hashtags_opening`, `hashtags_resolution`, `hashtags_comments`, `favorite_opening_hashtag`, etc. ya existen
  - Falta: Completar funcionalidades de filtrado y análisis avanzado

- **DM-015**: Promedio de comentarios por notas - ✅ Implementado
  - `avg_comments_per_note` ya existe en datamartUsers y datamartCountries

- **DM-016**: Promedio de comentarios por notas por país - ✅ Implementado
  - Ya está en datamartCountries como `avg_comments_per_note`

- **DM-005**: Procesamiento paralelo - ✅ Parcialmente implementado
  - `datamartUsers.sh` ya tiene procesamiento paralelo (líneas 307-377)
  - Falta: Optimizar y mejorar

### 🔄 Pendientes de Implementación

#### Prioridad Alta (Métricas simples)

1. **DM-006**: Calidad de la nota (clasificación por longitud)
   - Menos de 5 caracteres: mala
   - Menos de 10: regular
   - Más de 200: compleja
   - Más de 500: un tratado

2. **DM-007**: Día con más notas creadas
   - Para países y usuarios

3. **DM-008**: Hora con más notas creadas
   - Para países y usuarios

4. **DM-011**: Timestamp del comentario más reciente en la DB
   - Última actualización de la DB

#### Prioridad Media (Métricas intermedias)

5. **DM-003**: Ajustar queries de hashtags para relacionar con secuencia de comentario
   - Usar `sequence_action` de `facts` a través de `fact_hashtags`

6. **DM-009**: Tabla de notas aún abiertas por año
   - Columnas: años desde 2013
   - Filas: países
   - Cada campo: notas de cada año que aún están abiertas

7. **DM-010**: Por país, notas que tomaron más tiempo en cerrarse
   - Top N notas con mayor `days_to_resolution`

#### Prioridad Baja (Funcionalidades complejas)

8. **DM-004**: Definir badges y asignarlos
   - Tabla `dwh.badges` existe pero está vacía (solo tiene 'Test')
   - Necesita: Definir badges, crear lógica de asignación

9. **DM-012**: Rankings (top 100 histórico, último año, último mes, hoy)
   - Más abierto, más cerrado, más comentado, más reabierto

10. **DM-013**: Ranking de países
    - Abiertas, cerradas, actualmente abiertas, tasa

11. **DM-014**: Ranking de usuarios que más han abierto/cerrado notas
    - Mundial

## Plan de Ejecución

### Fase 1: Métricas Simples (DM-006, DM-007, DM-008, DM-011)
- Agregar columnas a tablas de datamarts
- Implementar cálculos en procedures
- Actualizar CREATE TABLE statements

### Fase 2: Métricas Intermedias (DM-003, DM-009, DM-010)
- Ajustar queries existentes
- Crear nuevas métricas complejas

### Fase 3: Funcionalidades Avanzadas (DM-004, DM-012, DM-013, DM-014)
- Implementar sistema de badges
- Crear vistas/procedures para rankings

### Fase 4: Completar Parciales (DM-001, DM-002, DM-005)
- Mejorar implementaciones existentes
- Optimizar procesamiento paralelo

## Notas

- Todas las implementaciones deben mantener compatibilidad con JSON exports
- Considerar impacto en performance al agregar nuevas métricas
- Documentar nuevas métricas en `docs/Metric_Definitions.md`


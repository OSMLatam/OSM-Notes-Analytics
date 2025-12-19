# Propuesta de API REST para OSM Notes Analytics e Ingestion

**Documento de Análisis y Propuesta**  
**Fecha**: 2025-12-14  
**Versión**: 1.0

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Análisis de Necesidad](#análisis-de-necesidad)
3. [Estado Actual del Sistema](#estado-actual-del-sistema)
4. [Comparación con OSM API 0.6](#comparación-con-osm-api-06)
5. [Propuesta de API](#propuesta-de-api)
6. [Casos de Uso](#casos-de-uso)
7. [Arquitectura Técnica](#arquitectura-técnica)
8. [Tecnologías Recomendadas](#tecnologías-recomendadas)
9. [Documentación de la API](#documentación-de-la-api)
10. [Pruebas y Calidad](#pruebas-y-calidad)
11. [Autenticación y Seguridad](#autenticación-y-seguridad)
12. [Monitoreo y Observabilidad](#monitoreo-y-observabilidad)
13. [Análisis de Costo-Beneficio](#análisis-de-costo-beneficio)
14. [Plan de Implementación](#plan-de-implementación)
15. [Riesgos y Mitigaciones](#riesgos-y-mitigaciones)
16. [Conclusiones y Recomendaciones](#conclusiones-y-recomendaciones)

---

## Resumen Ejecutivo

### ¿Vale la Pena Implementar una API?

**Respuesta Corta**: **SÍ, pero con un enfoque incremental y bien planificado.**

### Recomendación Principal

Implementar una API REST que unifique el acceso a los datos de **OSM-Notes-Ingestion** y **OSM-Notes-Analytics**, ofreciendo funcionalidades avanzadas que van más allá de la API estándar de OSM 0.6, enfocadas en:

- **Perfiles de usuario** con métricas avanzadas
- **Perfiles de países/comunidades** con análisis de salud
- **Búsquedas y filtros avanzados** (hashtags, fechas, aplicaciones)
- **Analíticas en tiempo real** y tendencias históricas
- **Comparaciones y rankings** entre usuarios y países

### Beneficios Clave

1. **Acceso Programático**: Permite integraciones con otras herramientas y aplicaciones
2. **Flexibilidad**: Consultas dinámicas sin necesidad de exportar JSON completos
3. **Escalabilidad**: Mejor que servir archivos JSON estáticos para consultas frecuentes
4. **Extensibilidad**: Base para futuras funcionalidades (webhooks, streaming, etc.)
5. **Estandarización**: API REST estándar facilita adopción por desarrolladores

### Inversión Estimada

- **Fase 1 (MVP)**: 2-3 semanas (endpoints básicos)
- **Fase 2 (Completa)**: 4-6 semanas adicionales (funcionalidades avanzadas)
- **Mantenimiento**: Bajo (reutiliza infraestructura existente)

---

## Análisis de Necesidad

### Problemas Actuales

#### 1. Acceso Limitado a Datos

**Situación Actual**:
- Los datos están disponibles solo a través de:
  - Consultas SQL directas (requiere acceso a base de datos)
  - Archivos JSON estáticos (exportados periódicamente)
  - Scripts Bash (para operaciones internas)

**Problema**:
- No hay acceso programático estándar
- Difícil integrar con otras aplicaciones
- Los JSON estáticos no permiten consultas dinámicas
- Requiere conocimiento de SQL para consultas personalizadas

#### 2. Falta de Funcionalidades Avanzadas

**Lo que falta**:
- Búsqueda por múltiples criterios simultáneos
- Filtros complejos (fechas, rangos, combinaciones)
- Paginación eficiente
- Ordenamiento dinámico
- Agregaciones en tiempo real
- Comparaciones entre entidades

#### 3. Limitaciones de la API OSM 0.6

La API estándar de OSM 0.6 ofrece:
- ✅ Lectura/escritura de notas básicas
- ✅ Búsqueda por área geográfica
- ✅ Búsqueda por usuario
- ❌ **NO ofrece analíticas**
- ❌ **NO ofrece métricas agregadas**
- ❌ **NO ofrece perfiles de usuario**
- ❌ **NO ofrece perfiles de países**
- ❌ **NO ofrece rankings o comparaciones**
- ❌ **NO ofrece filtros por hashtags**
- ❌ **NO ofrece análisis temporal avanzado**

### Oportunidades

1. **Desarrolladores Externos**: API permitiría crear herramientas y visualizaciones personalizadas
2. **Integraciones**: Conectarse con otras plataformas (GitHub, Slack, etc.)
3. **Aplicaciones Móviles**: API REST es ideal para apps móviles
4. **Dashboards Dinámicos**: Consultas en tiempo real sin regenerar JSON
5. **Investigación**: Acceso estructurado para análisis académicos

---

## Estado Actual del Sistema

### OSM-Notes-Ingestion

**Funcionalidades**:
- Descarga notas desde OSM Planet y API
- Sincronización en tiempo real (cada 15 minutos)
- Almacenamiento en tablas base PostgreSQL
- Publicación de capa WMS
- **NO tiene API REST**

**Datos Disponibles**:
- Tablas: `notes`, `note_comments`, `note_comments_text`, `users`, `countries`
- Datos históricos desde 2013
- Actualización continua

### OSM-Notes-Analytics

**Funcionalidades**:
- ETL que transforma datos base en star schema
- Data warehouse con 70+ métricas por usuario/país
- Datamarts pre-computados
- Exportación a JSON estática
- **NO tiene API REST** (mencionado como "Future" en documentación)

**Datos Disponibles**:
- `dwh.datamartUsers`: 78+ métricas por usuario
- `dwh.datamartCountries`: 77+ métricas por país
- `dwh.datamartGlobal`: Métricas globales
- `dwh.facts`: Datos detallados a nivel de nota
- Dimensiones: usuarios, países, fechas, aplicaciones, hashtags, etc.

### OSM-Notes-Viewer

**Funcionalidades**:
- Consume archivos JSON estáticos
- Visualizaciones web interactivas
- Perfiles de usuario y país
- **NO requiere API** (usa JSON estático)

### Gap Identificado

**Lo que falta**:
```
┌─────────────────────────────────────┐
│  OSM-Notes-Ingestion                 │
│  (Datos base)                        │
└──────────────┬────────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  OSM-Notes-Analytics                │
│  (ETL + DWH)                        │
└──────────────┬────────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  ❌ API REST (FALTA)                │
│  (Acceso programático)              │
└──────────────┬────────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  OSM-Notes-Viewer                  │
│  (Consumidor actual: JSON)         │
└──────────────────────────────────────┘
```

---

## Comparación con OSM API 0.6

### OSM API 0.6 - Funcionalidades

| Funcionalidad | OSM API 0.6 | Propuesta API |
|---------------|-------------|---------------|
| **Lectura de notas** | ✅ Básica | ✅ Avanzada con filtros |
| **Escritura de notas** | ✅ Completa | ❌ No incluida (fuera de alcance) |
| **Búsqueda geográfica** | ✅ Por bbox | ✅ Por bbox + país + región |
| **Búsqueda por usuario** | ✅ Básica | ✅ Avanzada con métricas |
| **Búsqueda por fecha** | ✅ Limitada | ✅ Rango flexible |
| **Analíticas** | ❌ No | ✅ Completa (70+ métricas) |
| **Perfiles de usuario** | ❌ No | ✅ Completo (78+ métricas) |
| **Perfiles de países** | ❌ No | ✅ Completo (77+ métricas) |
| **Rankings** | ❌ No | ✅ Por múltiples criterios |
| **Comparaciones** | ❌ No | ✅ Entre usuarios/países |
| **Filtros por hashtag** | ❌ No | ✅ Completo |
| **Análisis temporal** | ❌ No | ✅ Por año/mes/día/hora |
| **Métricas de resolución** | ❌ No | ✅ Tiempo promedio, tasa, etc. |
| **Análisis de aplicaciones** | ❌ No | ✅ Uso por app/versión |
| **Health scores** | ❌ No | ✅ Para países/comunidades |
| **Tendencias históricas** | ❌ No | ✅ Por año/mes desde 2013 |

### Ventajas de la Propuesta

1. **Más Funcionalidades**: 15+ funcionalidades adicionales vs OSM API 0.6
2. **Enfoque en Analíticas**: Especializado en métricas y análisis
3. **Datos Pre-computados**: Respuestas rápidas usando datamarts
4. **Flexibilidad**: Filtros y consultas complejas
5. **Extensibilidad**: Fácil agregar nuevas métricas

### Desventajas

1. **Solo Lectura**: No permite escribir/modificar notas (por diseño)
2. **Dependencia de ETL**: Datos pueden tener latencia (15 minutos)
3. **Complejidad**: Más endpoints y parámetros que OSM API 0.6

---

## Propuesta de API

### Principios de Diseño

1. **RESTful**: Sigue estándares REST
2. **JSON**: Todas las respuestas en JSON
3. **Versionado**: `/api/v1/` para compatibilidad futura
4. **Paginación**: Todas las listas paginadas
5. **Filtros**: Parámetros de query estándar
6. **Documentación**: OpenAPI/Swagger
7. **Rate Limiting**: Protección contra abuso
8. **Caching**: Headers HTTP estándar

### Estructura de Endpoints

```
/api/v1/
├── /users
│   ├── GET /users                    # Lista de usuarios (paginada)
│   ├── GET /users/{user_id}          # Perfil completo de usuario
│   ├── GET /users/{user_id}/notes    # Notas del usuario
│   ├── GET /users/{user_id}/stats    # Estadísticas del usuario
│   └── GET /users/rankings           # Rankings de usuarios
│
├── /countries
│   ├── GET /countries                 # Lista de países (paginada)
│   ├── GET /countries/{country_id}   # Perfil completo de país
│   ├── GET /countries/{country_id}/notes  # Notas del país
│   ├── GET /countries/{country_id}/users  # Usuarios activos
│   └── GET /countries/rankings       # Rankings de países
│
├── /notes
│   ├── GET /notes                    # Búsqueda de notas
│   ├── GET /notes/{note_id}          # Detalle de nota
│   ├── GET /notes/{note_id}/comments # Comentarios de nota
│   └── GET /notes/{note_id}/history # Historial de nota
│
├── /analytics
│   ├── GET /analytics/global         # Estadísticas globales
│   ├── GET /analytics/trends         # Tendencias temporales
│   ├── GET /analytics/comparison     # Comparaciones
│   └── GET /analytics/health         # Health scores
│
├── /search
│   ├── GET /search/users             # Búsqueda avanzada de usuarios
│   ├── GET /search/countries         # Búsqueda avanzada de países
│   └── GET /search/notes             # Búsqueda avanzada de notas
│
└── /hashtags
    ├── GET /hashtags                  # Lista de hashtags
    ├── GET /hashtags/{hashtag}        # Estadísticas de hashtag
    └── GET /hashtags/{hashtag}/notes  # Notas con hashtag
```

### Ejemplos de Endpoints Clave

#### 1. Perfil de Usuario

```http
GET /api/v1/users/12345
```

**Respuesta**:
```json
{
  "user_id": 12345,
  "username": "example_user",
  "dimension_user_id": 123,
  "history_whole_open": 100,
  "history_whole_closed": 50,
  "history_whole_commented": 75,
  "avg_days_to_resolution": 5.5,
  "resolution_rate": 50.0,
  "user_response_time": 2.3,
  "days_since_last_action": 5,
  "applications_used": [
    {
      "application_id": 1,
      "application_name": "JOSM",
      "count": 80
    }
  ],
  "collaboration_patterns": {
    "mentions_given": 10,
    "mentions_received": 5,
    "replies_count": 20,
    "collaboration_score": 0.75
  },
  "countries_open_notes": [
    {
      "rank": 1,
      "country": "Colombia",
      "quantity": 50
    }
  ],
  "hashtags": ["#MapColombia", "#MissingMaps"],
  "date_starting_creating_notes": "2020-01-15",
  "date_starting_solving_notes": "2020-02-01",
  "last_year_activity": "0101010101...", // 365 caracteres
  "working_hours_of_week_opening": [/* 168 números */],
  "activity_by_year": {
    "2020": {"open": 10, "closed": 5},
    "2021": {"open": 20, "closed": 15},
    // ...
  }
}
```

#### 2. Perfil de País

```http
GET /api/v1/countries/42
```

**Respuesta**:
```json
{
  "country_id": 42,
  "country_name": "Colombia",
  "country_name_en": "Colombia",
  "country_name_es": "Colombia",
  "iso_alpha2": "CO",
  "dimension_country_id": 45,
  "history_whole_open": 1000,
  "history_whole_closed": 800,
  "avg_days_to_resolution": 7.2,
  "resolution_rate": 80.0,
  "notes_health_score": 75.5,
  "new_vs_resolved_ratio": 1.2,
  "notes_backlog_size": 50,
  "notes_created_last_30_days": 100,
  "notes_resolved_last_30_days": 80,
  "users_open_notes": [
    {
      "rank": 1,
      "user_id": 12345,
      "username": "top_user",
      "quantity": 50
    }
  ],
  "applications_used": [/* ... */],
  "hashtags": [/* ... */],
  "activity_by_year": {/* ... */},
  "working_hours_of_week_opening": [/* ... */]
}
```

#### 3. Búsqueda Avanzada de Usuarios

```http
GET /api/v1/search/users?min_notes=10&country=42&hashtag=#MapColombia&sort=resolution_rate&order=desc&page=1&limit=20
```

**Parámetros**:
- `min_notes`: Mínimo de notas abiertas
- `country`: Filtrar por país
- `hashtag`: Filtrar por hashtag usado
- `sort`: Campo para ordenar (resolution_rate, history_whole_open, etc.)
- `order`: asc/desc
- `page`: Número de página
- `limit`: Resultados por página (máx 100)

**Respuesta**:
```json
{
  "data": [
    {
      "user_id": 12345,
      "username": "example_user",
      "history_whole_open": 100,
      "resolution_rate": 50.0,
      // ... campos resumidos
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8
  },
  "filters": {
    "min_notes": 10,
    "country": 42,
    "hashtag": "#MapColombia"
  }
}
```

#### 4. Rankings

```http
GET /api/v1/users/rankings?metric=history_whole_closed&country=42&limit=10
```

**Respuesta**:
```json
{
  "metric": "history_whole_closed",
  "country": 42,
  "rankings": [
    {
      "rank": 1,
      "user_id": 12345,
      "username": "top_user",
      "value": 500
    },
    // ...
  ]
}
```

#### 5. Estadísticas Globales

```http
GET /api/v1/analytics/global
```

**Respuesta**:
```json
{
  "dimension_global_id": 1,
  "history_whole_open": 1000000,
  "history_whole_closed": 800000,
  "currently_open_count": 200000,
  "avg_days_to_resolution": 5.5,
  "resolution_rate": 80.0,
  "notes_created_last_30_days": 5000,
  "notes_resolved_last_30_days": 4500,
  "active_users_count": 10000,
  "notes_backlog_size": 50000,
  "applications_used": [/* ... */],
  "top_countries": [/* ... */]
}
```

#### 6. Búsqueda de Notas

```http
GET /api/v1/search/notes?country=42&status=open&hashtag=#MapColombia&date_from=2024-01-01&date_to=2024-12-31&page=1&limit=50
```

**Parámetros**:
- `country`: ID de país
- `status`: open/closed/reopened
- `hashtag`: Filtrar por hashtag
- `date_from`/`date_to`: Rango de fechas
- `user_id`: Filtrar por usuario
- `application`: Filtrar por aplicación
- `bbox`: Bounding box (min_lon,min_lat,max_lon,max_lat)

**Respuesta**:
```json
{
  "data": [
    {
      "note_id": 123456,
      "latitude": 4.6097,
      "longitude": -74.0817,
      "status": "open",
      "created_at": "2024-01-15T10:30:00Z",
      "comments_count": 3,
      "hashtags": ["#MapColombia"],
      "country": {
        "id": 42,
        "name": "Colombia"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 250,
    "total_pages": 5
  }
}
```

### Características Avanzadas

#### 1. Filtros Múltiples

```http
GET /api/v1/users?min_notes=10&max_notes=1000&country=42,43&hashtag=#MapColombia,#MissingMaps&sort=resolution_rate&order=desc
```

#### 2. Campos Selectivos

```http
GET /api/v1/users/12345?fields=username,history_whole_open,resolution_rate
```

#### 3. Formatos Alternativos

```http
GET /api/v1/users/12345.csv
GET /api/v1/users/12345.xml
```

#### 4. Agregaciones

```http
GET /api/v1/analytics/aggregate?group_by=country&metric=avg_days_to_resolution&filter=resolution_rate>50
```

---

## Casos de Uso

### 1. Dashboard Dinámico

**Problema Actual**: El viewer consume JSON estáticos, requiere regenerar exports para datos actualizados.

**Con API**:
```javascript
// Consulta en tiempo real
const stats = await fetch('/api/v1/analytics/global').then(r => r.json());
const countries = await fetch('/api/v1/countries?sort=notes_health_score&order=desc&limit=10').then(r => r.json());
```

**Beneficio**: Datos siempre actualizados sin regenerar JSON.

### 2. Aplicación Móvil

**Problema Actual**: No hay forma de acceder a datos desde app móvil.

**Con API**:
```javascript
// App móvil consulta API
const userProfile = await fetch('/api/v1/users/12345').then(r => r.json());
const userNotes = await fetch('/api/v1/users/12345/notes?status=open&limit=20').then(r => r.json());
```

**Beneficio**: App móvil puede mostrar perfiles y notas en tiempo real.

### 3. Integración con Herramientas Externas

**Problema Actual**: No hay forma de integrar con otras herramientas.

**Con API**:
```python
# Bot de Slack que muestra estadísticas
import requests

def get_user_stats(user_id):
    response = requests.get(f'https://api.osm-notes.org/v1/users/{user_id}')
    data = response.json()
    return f"Usuario {data['username']}: {data['history_whole_open']} notas abiertas"

# Bot de GitHub que muestra contribuciones
def get_contributions(username):
    response = requests.get(f'https://api.osm-notes.org/v1/search/users?username={username}')
    # ...
```

**Beneficio**: Integraciones con Slack, Discord, GitHub, etc.

### 4. Análisis de Investigación

**Problema Actual**: Requiere acceso directo a base de datos o procesar JSON grandes.

**Con API**:
```python
# Investigador analiza patrones
import requests

# Obtener todos los países con alta resolución
countries = requests.get('/api/v1/countries?min_resolution_rate=80&sort=avg_days_to_resolution').json()

# Comparar países
comparison = requests.get('/api/v1/analytics/comparison?countries=42,43,44&metrics=resolution_rate,avg_days_to_resolution').json()
```

**Beneficio**: Acceso estructurado sin necesidad de SQL.

### 5. Campañas con Hashtags

**Problema Actual**: Difícil rastrear campañas sin consultas SQL complejas.

**Con API**:
```javascript
// Organizador de campaña rastrea progreso
const campaign = await fetch('/api/v1/hashtags/#MapColombia2025').then(r => r.json());
const participants = await fetch('/api/v1/hashtags/#MapColombia2025/users').then(r => r.json());
const notes = await fetch('/api/v1/hashtags/#MapColombia2025/notes?status=open').then(r => r.json());
```

**Beneficio**: Rastreo fácil de campañas y participación.

---

## Arquitectura Técnica

### Arquitectura Propuesta

```
┌─────────────────────────────────────┐
│  Clientes                            │
│  (Web, Mobile, Bots, etc.)          │
└──────────────┬──────────────────────┘
               │ HTTP/REST
               ▼
┌─────────────────────────────────────┐
│  API Gateway / Load Balancer        │
│  (Nginx, Traefik, etc.)             │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  API Server                          │
│  (Node.js, Python, Go, etc.)        │
│  - Endpoints REST                    │
│  - Validación de requests            │
│  - Rate limiting                     │
│  - Caching                           │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  PostgreSQL Database                 │
│  - dwh.datamartUsers                 │
│  - dwh.datamartCountries             │
│  - dwh.datamartGlobal                │
│  - dwh.facts                         │
│  - public.notes                      │
│  - public.note_comments              │
└──────────────────────────────────────┘
```

### Flujo de Datos

1. **Cliente** hace request HTTP a API
2. **API Gateway** valida, rate limiting, caching
3. **API Server** procesa request:
   - Valida parámetros
   - Construye query SQL
   - Ejecuta query en PostgreSQL
   - Transforma resultados a JSON
   - Aplica paginación
4. **PostgreSQL** ejecuta query (usa datamarts para velocidad)
5. **API Server** retorna JSON al cliente

### Estrategia de Caching

**Niveles de Cache**:

1. **HTTP Cache** (API Gateway):
   - Cachea respuestas completas
   - TTL: 5-15 minutos (depende de endpoint)
   - Headers: `Cache-Control`, `ETag`, `Last-Modified`

2. **Application Cache** (API Server):
   - Cachea resultados de queries frecuentes
   - Redis o memoria
   - TTL: 1-5 minutos

3. **Database Query Cache**:
   - PostgreSQL query cache
   - Materialized views para agregaciones complejas

**Estrategia por Endpoint**:

| Endpoint | Cache TTL | Razón |
|----------|-----------|-------|
| `/users/{id}` | 5 min | Cambia poco |
| `/countries/{id}` | 5 min | Cambia poco |
| `/analytics/global` | 1 min | Cambia frecuentemente |
| `/search/*` | No cache | Consultas dinámicas |
| `/notes/{id}` | 1 min | Puede cambiar |

### Rate Limiting

**Estrategia**:
- **Público**: 100 requests/hora por IP
- **Autenticado**: 1000 requests/hora por API key
- **Premium**: 10000 requests/hora (futuro)

**Implementación**:
- Redis para tracking
- Headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`

### Seguridad

1. **HTTPS**: Obligatorio
2. **CORS**: Configurado para dominios permitidos
3. **Rate Limiting**: Protección contra abuso (por IP + User-Agent)
4. **Validación**: Todos los inputs validados
5. **SQL Injection**: Prepared statements (siempre)
6. **User-Agent Requerido**: Todos los requests deben incluir User-Agent con nombre de aplicación
7. **Headers de Seguridad**: X-Content-Type-Options, X-Frame-Options, etc.
8. **Logging de Seguridad**: Eventos de seguridad registrados
9. **Autenticación**: API keys (futuro, opcional)

---

## Tecnologías Recomendadas

### Opción 1: Node.js + Express (Recomendada)

**Ventajas**:
- ✅ JavaScript/TypeScript (fácil para desarrolladores web)
- ✅ Ecosistema rico (middleware, validación, etc.)
- ✅ Buen rendimiento para I/O
- ✅ Fácil integración con PostgreSQL (pg, Prisma, TypeORM)
- ✅ Documentación automática (Swagger/OpenAPI)

**Stack**:
- **Runtime**: Node.js 18+
- **Framework**: Express.js o Fastify
- **ORM/Query**: Prisma o TypeORM
- **Validación**: Joi o Zod
- **Documentación**: Swagger/OpenAPI
- **Cache**: Redis
- **Rate Limiting**: express-rate-limit

**Ejemplo de Estructura**:
```
api/
├── src/
│   ├── routes/
│   │   ├── users.ts
│   │   ├── countries.ts
│   │   ├── notes.ts
│   │   └── analytics.ts
│   ├── controllers/
│   ├── services/
│   ├── models/
│   ├── middleware/
│   │   ├── rateLimit.ts
│   │   ├── cache.ts
│   │   └── validation.ts
│   └── utils/
├── tests/
└── package.json
```

### Opción 2: Python + FastAPI

**Ventajas**:
- ✅ Python (fácil para análisis de datos)
- ✅ FastAPI (rápido, moderno, async)
- ✅ Documentación automática (OpenAPI)
- ✅ Buen ecosistema científico (pandas, numpy si se necesita)

**Stack**:
- **Framework**: FastAPI
- **ORM**: SQLAlchemy
- **Validación**: Pydantic
- **Cache**: Redis
- **Rate Limiting**: slowapi

**Ejemplo de Estructura**:
```
api/
├── app/
│   ├── routes/
│   │   ├── users.py
│   │   ├── countries.py
│   │   └── notes.py
│   ├── services/
│   ├── models/
│   ├── middleware/
│   └── utils/
├── tests/
└── requirements.txt
```

### Opción 3: Go + Gin/Echo

**Ventajas**:
- ✅ Muy rápido
- ✅ Bajo consumo de memoria
- ✅ Compilado (sin dependencias runtime)
- ✅ Buen para alta concurrencia

**Desventajas**:
- ❌ Menos ecosistema que Node.js/Python
- ❌ Curva de aprendizaje más alta

**Stack**:
- **Framework**: Gin o Echo
- **ORM**: GORM
- **Cache**: Redis
- **Rate Limiting**: tollbooth

### Recomendación Final

**Node.js + Express** por:
1. Facilidad de desarrollo
2. Ecosistema rico
3. Buen rendimiento para este caso de uso
4. Fácil mantenimiento
5. Integración natural con el ecosistema existente (JSON exports)

### Base de Datos

**PostgreSQL** (ya existe):
- ✅ Ya está en uso
- ✅ Excelente para consultas complejas
- ✅ Soporta JSON nativo
- ✅ Índices optimizados
- ✅ Datamarts pre-computados

**No se requiere cambio de base de datos**.

### Infraestructura

**Deployment Options**:

1. **Docker + Docker Compose** (Desarrollo/Producción pequeña)
   ```yaml
   services:
     api:
       build: ./api
       ports:
         - "3000:3000"
       environment:
         - DATABASE_URL=postgresql://...
       depends_on:
         - postgres
         - redis
   ```

2. **Kubernetes** (Producción escalable)
   - Deployments, Services, Ingress
   - Auto-scaling
   - Health checks

3. **Serverless** (AWS Lambda, Vercel, etc.)
   - Solo si el tráfico es bajo/intermitente
   - Menos control sobre caching

**Recomendación**: Docker para empezar, Kubernetes si escala.

---

## Documentación de la API

### Estándar de Documentación

**Recomendación**: **OpenAPI 3.0 (Swagger)**

**Razones**:
- ✅ Estándar de la industria
- ✅ Compatible con múltiples herramientas
- ✅ Generación automática de documentación interactiva
- ✅ Generación de clientes SDK automáticos
- ✅ Validación de requests/responses
- ✅ Integración con herramientas de testing

### Herramientas Recomendadas

#### 1. Swagger UI (Interfaz de Documentación)

**Qué es**: Interfaz web interactiva para explorar y probar la API

**Características**:
- Documentación visual interactiva
- Pruebas de endpoints directamente desde el navegador
- Ejemplos de requests/responses
- Esquemas de datos

**Implementación**:
```typescript
// Node.js + Express
import swaggerUi from 'swagger-ui-express';
import swaggerDocument from './swagger.json';

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));
```

#### 2. Redoc (Alternativa a Swagger UI)

**Ventajas**:
- Diseño más limpio y moderno
- Mejor para documentación de referencia
- Renderizado más rápido

**Desventajas**:
- Menos interactivo que Swagger UI

#### 3. Postman Collections

**Qué es**: Colección de requests para Postman

**Ventajas**:
- Fácil de compartir con desarrolladores
- Permite pruebas automatizadas
- Integración con CI/CD

### Dónde Publicar la Documentación

#### Opción 1: Subdominio Dedicado (Recomendada)

**URL**: `https://api-docs.osm-notes.org` o `https://docs.api.osm-notes.org`

**Ventajas**:
- ✅ URL profesional y memorable
- ✅ Fácil de encontrar
- ✅ Separación de concerns
- ✅ Puede usar CDN para mejor performance

**Implementación**:
- Servir Swagger UI desde el mismo servidor de API
- O usar GitHub Pages / Netlify / Vercel para hosting estático
- Actualización automática desde el código

#### Opción 2: Ruta en el API

**URL**: `https://api.osm-notes.org/docs` o `https://api.osm-notes.org/api-docs`

**Ventajas**:
- ✅ Todo en un solo dominio
- ✅ Más simple de configurar
- ✅ Mismo certificado SSL

**Desventajas**:
- ❌ Mezcla documentación con API
- ❌ Puede afectar performance del API

#### Opción 3: Repositorio GitHub

**URL**: `https://github.com/OSMLatam/OSM-Notes-API/tree/main/docs`

**Ventajas**:
- ✅ Versionado con el código
- ✅ Fácil de mantener
- ✅ Colaboración mediante PRs

**Desventajas**:
- ❌ Menos accesible para usuarios finales
- ❌ Requiere GitHub para ver

**Recomendación**: Usar GitHub Pages para servir la documentación desde el repo

#### Opción 4: GitHub Pages (Recomendada para Inicio)

**URL**: `https://osmlatam.github.io/OSM-Notes-API/`

**Ventajas**:
- ✅ Gratis
- ✅ HTTPS automático
- ✅ Actualización automática desde repo
- ✅ Fácil de configurar

**Implementación**:
```bash
# Generar documentación estática
npm run docs:build

# Deploy a GitHub Pages
npm run docs:deploy
```

### Estructura de Documentación

```
docs/
├── api/
│   ├── openapi.yaml          # Especificación OpenAPI
│   ├── swagger.json          # JSON alternativo
│   └── examples/             # Ejemplos de requests/responses
├── guides/
│   ├── getting-started.md    # Guía de inicio rápido
│   ├── authentication.md     # Guía de autenticación
│   ├── rate-limiting.md       # Explicación de rate limits
│   └── best-practices.md     # Mejores prácticas
├── tutorials/
│   ├── user-profiles.md      # Tutorial: Obtener perfiles de usuario
│   ├── search-notes.md        # Tutorial: Búsqueda de notas
│   └── analytics.md          # Tutorial: Análisis de datos
└── reference/
    ├── endpoints.md           # Referencia de endpoints
    ├── schemas.md            # Esquemas de datos
    └── errors.md             # Códigos de error
```

### Generación Automática

**Opción 1: Desde Código (Recomendada)**

```typescript
// Node.js + Express con swagger-jsdoc
import swaggerJsdoc from 'swagger-jsdoc';

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'OSM Notes Analytics API',
      version: '1.0.0',
      description: 'API for accessing OSM Notes analytics and data',
      contact: {
        name: 'API Support',
        email: 'api@osm-notes.org'
      }
    },
    servers: [
      {
        url: 'https://api.osm-notes.org/v1',
        description: 'Production server'
      }
    ]
  },
  apis: ['./src/routes/*.ts'] // Ruta a archivos con anotaciones
};

const swaggerSpec = swaggerJsdoc(options);
```

**Anotaciones en Código**:
```typescript
/**
 * @swagger
 * /users/{user_id}:
 *   get:
 *     summary: Get user profile
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: user_id
 *         required: true
 *         schema:
 *           type: integer
 *         description: OSM user ID
 *     responses:
 *       200:
 *         description: User profile
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/UserProfile'
 *       404:
 *         description: User not found
 */
router.get('/users/:user_id', getUserProfile);
```

**Opción 2: Archivo YAML Manual**

Mantener `openapi.yaml` manualmente y validarlo en CI/CD:
```yaml
openapi: 3.0.0
info:
  title: OSM Notes Analytics API
  version: 1.0.0
paths:
  /users/{user_id}:
    get:
      summary: Get user profile
      # ...
```

### Contenido Mínimo de Documentación

1. **Getting Started**:
   - Cómo obtener API key (si aplica)
   - Primer request de ejemplo
   - Configuración de User-Agent

2. **Autenticación**:
   - Cómo usar API keys
   - Headers requeridos
   - User-Agent requerido

3. **Endpoints**:
   - Todos los endpoints documentados
   - Parámetros explicados
   - Ejemplos de requests/responses
   - Códigos de error posibles

4. **Rate Limiting**:
   - Límites explicados
   - Cómo verificar límites restantes
   - Qué hacer si se excede

5. **Ejemplos de Código**:
   - JavaScript/TypeScript
   - Python
   - cURL
   - (Otros según demanda)

6. **Changelog**:
   - Versiones de API
   - Cambios breaking
   - Deprecaciones

### Herramientas de Validación

**Swagger Validator**: Validar que el OpenAPI spec es correcto
```bash
npm install -g swagger-cli
swagger-cli validate openapi.yaml
```

**Spectral**: Linting de OpenAPI specs
```bash
npm install -g @stoplight/spectral-cli
spectral lint openapi.yaml
```

### Integración con CI/CD

```yaml
# .github/workflows/docs.yml
name: API Documentation

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'docs/api/**'

jobs:
  validate-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate OpenAPI
        run: |
          npm install -g swagger-cli
          swagger-cli validate docs/api/openapi.yaml
      
      - name: Build Docs
        run: npm run docs:build
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs/dist
```

### Ejemplo de Documentación Pública

**URL de Ejemplo**: `https://api-docs.osm-notes.org`

**Página Principal**:
- Overview de la API
- Links a:
  - Swagger UI interactivo
  - Guías de inicio rápido
  - Tutoriales
  - Changelog
  - Contacto/Soporte

**Swagger UI**:
- Interfaz interactiva
- Probar endpoints directamente
- Ver esquemas de datos
- Ejemplos de código

---

## Pruebas y Calidad

### Estrategia de Pruebas

**Principio**: Todos los componentes deben tener pruebas que validen su funcionamiento.

### Tipos de Pruebas

#### 1. Pruebas Unitarias

**Qué prueban**: Funciones individuales, servicios, utilidades

**Cobertura objetivo**: 80%+

**Herramientas**:
- **Node.js**: Jest, Mocha, Vitest
- **Python**: pytest, unittest
- **Go**: testing package nativo

**Ejemplo (Node.js + Jest)**:
```typescript
// tests/unit/services/userService.test.ts
import { getUserProfile } from '../../src/services/userService';
import { db } from '../../src/db';

jest.mock('../../src/db');

describe('UserService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('getUserProfile returns user data', async () => {
    const mockUser = {
      user_id: 12345,
      username: 'test_user',
      history_whole_open: 100
    };

    (db.query as jest.Mock).mockResolvedValue({
      rows: [mockUser]
    });

    const result = await getUserProfile(12345);

    expect(result).toEqual(mockUser);
    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('SELECT'),
      [12345]
    );
  });

  test('getUserProfile throws error if user not found', async () => {
    (db.query as jest.Mock).mockResolvedValue({
      rows: []
    });

    await expect(getUserProfile(99999)).rejects.toThrow('User not found');
  });
});
```

#### 2. Pruebas de Integración

**Qué prueban**: Flujo completo de requests, interacción con base de datos

**Cobertura objetivo**: Todos los endpoints principales

**Herramientas**:
- **Node.js**: Supertest (para Express)
- **Python**: pytest + httpx
- **Go**: net/http/httptest

**Ejemplo (Node.js + Supertest)**:
```typescript
// tests/integration/users.test.ts
import request from 'supertest';
import app from '../../src/app';
import { setupTestDB, teardownTestDB } from '../helpers/db';

describe('GET /api/v1/users/:user_id', () => {
  beforeAll(async () => {
    await setupTestDB();
  });

  afterAll(async () => {
    await teardownTestDB();
  });

  test('returns user profile with valid user_id', async () => {
    const response = await request(app)
      .get('/api/v1/users/12345')
      .set('User-Agent', 'MyApp/1.0')
      .expect(200);

    expect(response.body).toHaveProperty('user_id', 12345);
    expect(response.body).toHaveProperty('username');
    expect(response.body).toHaveProperty('history_whole_open');
  });

  test('returns 404 for non-existent user', async () => {
    await request(app)
      .get('/api/v1/users/99999')
      .set('User-Agent', 'MyApp/1.0')
      .expect(404);
  });

  test('validates User-Agent header', async () => {
    await request(app)
      .get('/api/v1/users/12345')
      .expect(400)
      .expect(res => {
        expect(res.body.error).toContain('User-Agent');
      });
  });
});
```

#### 3. Pruebas de Contrato (Contract Testing)

**Qué prueban**: Que las respuestas cumplen con el esquema OpenAPI

**Herramientas**:
- **openapi-validator-middleware**: Validar responses contra OpenAPI spec
- **jest-openapi**: Validar en tests de Jest

**Ejemplo**:
```typescript
import { validateResponse } from 'openapi-validator-middleware';

test('response matches OpenAPI schema', async () => {
  const response = await request(app)
    .get('/api/v1/users/12345')
    .set('User-Agent', 'MyApp/1.0');

  const errors = validateResponse(response, '/users/{user_id}', 'get', 200);
  expect(errors).toHaveLength(0);
});
```

#### 4. Pruebas de Carga (Load Testing)

**Qué prueban**: Performance bajo carga

**Herramientas**:
- **k6**: Scripting en JavaScript
- **Artillery**: YAML-based
- **Apache Bench (ab)**: Simple pero efectivo

**Ejemplo (k6)**:
```javascript
// tests/load/users.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 50 },
    { duration: '1m', target: 100 },
    { duration: '30s', target: 0 },
  ],
};

export default function () {
  const response = http.get('https://api.osm-notes.org/v1/users/12345', {
    headers: { 'User-Agent': 'LoadTest/1.0' }
  });
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });
}
```

#### 5. Pruebas de Seguridad

**Qué prueban**: Vulnerabilidades comunes

**Herramientas**:
- **OWASP ZAP**: Escaneo de vulnerabilidades
- **npm audit / safety**: Dependencias vulnerables
- **Snyk**: Análisis continuo

### Estructura de Tests

```
tests/
├── unit/
│   ├── services/
│   │   ├── userService.test.ts
│   │   ├── countryService.test.ts
│   │   └── analyticsService.test.ts
│   ├── controllers/
│   ├── middleware/
│   └── utils/
├── integration/
│   ├── users.test.ts
│   ├── countries.test.ts
│   ├── notes.test.ts
│   └── analytics.test.ts
├── e2e/
│   └── api-flow.test.ts
├── load/
│   ├── users.js
│   └── search.js
├── fixtures/
│   ├── users.json
│   └── countries.json
└── helpers/
    ├── db.ts
    ├── testClient.ts
    └── mocks.ts
```

### Base de Datos de Pruebas

**Estrategia**: Base de datos separada para tests

```typescript
// tests/helpers/db.ts
export async function setupTestDB() {
  // Crear schema de test
  // Insertar datos de prueba
  // Configurar mocks
}

export async function teardownTestDB() {
  // Limpiar datos
  // Cerrar conexiones
}
```

**Datos de Prueba**:
- Usuarios de ejemplo
- Países de ejemplo
- Notas de ejemplo
- Datos consistentes y predecibles

### CI/CD Integration

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm ci
      - run: npm run test:unit
      - run: npm run test:coverage
      
  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm ci
      - run: npm run test:integration
      
  load-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: k6io/setup-k6@v1
      - run: k6 run tests/load/users.js
```

### Métricas de Calidad

**Cobertura de Código**:
- Objetivo: 80%+
- Herramienta: Istanbul (nyc), Jest coverage

**Cobertura de Endpoints**:
- Todos los endpoints deben tener tests
- Todos los códigos de respuesta deben ser probados

**Performance**:
- P95 response time < 200ms (para endpoints de datamarts)
- P95 response time < 500ms (para búsquedas complejas)

### Pruebas Manuales

**Checklist Pre-Deploy**:
- [ ] Todos los tests pasan
- [ ] Cobertura > 80%
- [ ] Documentación actualizada
- [ ] Rate limiting funciona
- [ ] Cache funciona correctamente
- [ ] Logging funciona
- [ ] Monitoreo configurado

---

## Autenticación y Seguridad

### Modelo de Autenticación

**Recomendación**: **API Keys + User-Agent Requerido**

**NO se requiere OAuth de OSM** por las siguientes razones:

1. **Solo Lectura**: La API es de solo lectura, no modifica datos de OSM
2. **Menor Fricción**: Más fácil para desarrolladores empezar
3. **Estadísticas**: User-Agent permite tracking sin autenticación compleja
4. **Rate Limiting**: Se puede hacer por IP + User-Agent

**Cuándo considerar OAuth**:
- Si en el futuro se agregan endpoints de escritura
- Si se necesita identificar usuarios específicos de OSM
- Si se requiere acceso a datos privados

### User-Agent Requerido

**Requisito**: Todos los requests DEBEN incluir un User-Agent con el nombre de la aplicación.

**Formato Requerido**:
```
User-Agent: <AppName>/<Version> (<Contact>)
```

**Ejemplos Válidos**:
```
User-Agent: MyOSMApp/1.0 (contact@example.com)
User-Agent: NotesDashboard/2.1 (https://github.com/user/repo)
User-Agent: ResearchTool/0.5 (researcher@university.edu)
```

**Validación**:
```typescript
// middleware/validateUserAgent.ts
import { Request, Response, NextFunction } from 'express';

export function validateUserAgent(req: Request, res: Response, next: NextFunction) {
  const userAgent = req.get('User-Agent');
  
  if (!userAgent) {
    return res.status(400).json({
      error: 'User-Agent header is required',
      message: 'Please include a User-Agent header with your application name and contact information. Format: AppName/Version (Contact)'
    });
  }
  
  // Validar formato básico
  const userAgentPattern = /^[\w\-\.]+\/[\w\-\.]+/;
  if (!userAgentPattern.test(userAgent)) {
    return res.status(400).json({
      error: 'Invalid User-Agent format',
      message: 'User-Agent must follow format: AppName/Version (Contact)'
    });
  }
  
  // Extraer información para logging
  req.userAgentInfo = parseUserAgent(userAgent);
  
  next();
}

function parseUserAgent(userAgent: string) {
  const match = userAgent.match(/^([^\/]+)\/([^\s]+)(?:\s+\(([^)]+)\))?/);
  if (match) {
    return {
      appName: match[1],
      version: match[2],
      contact: match[3] || null
    };
  }
  return null;
}
```

### API Keys (Opcional, Futuro)

**Cuándo implementar**:
- Si el tráfico crece significativamente
- Si se necesita rate limiting más granular
- Si se quiere ofrecer planes premium

**Implementación Futura**:
```typescript
// middleware/authenticate.ts
export async function authenticate(req: Request, res: Response, next: NextFunction) {
  const apiKey = req.get('X-API-Key');
  
  if (!apiKey) {
    // Permitir acceso anónimo con rate limiting más estricto
    req.rateLimit = 'anonymous'; // 100 req/hour
    return next();
  }
  
  // Validar API key
  const key = await validateAPIKey(apiKey);
  if (!key) {
    return res.status(401).json({ error: 'Invalid API key' });
  }
  
  req.apiKey = key;
  req.rateLimit = key.tier; // 'free', 'premium', etc.
  next();
}
```

### Rate Limiting por User-Agent

**Estrategia**:
- Rate limiting por IP + User-Agent
- Permite identificar aplicaciones específicas
- Facilita monitoreo y debugging

**Implementación**:
```typescript
// middleware/rateLimit.ts
import rateLimit from 'express-rate-limit';
import { Request } from 'express';

export const createRateLimiter = (windowMs: number, max: number) => {
  return rateLimit({
    windowMs,
    max,
    keyGenerator: (req: Request) => {
      // Combinar IP + User-Agent para tracking
      const ip = req.ip;
      const userAgent = req.get('User-Agent') || 'unknown';
      return `${ip}:${userAgent}`;
    },
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      error: 'Too many requests',
      message: 'Rate limit exceeded. Please reduce your request frequency.'
    }
  });
};

// Aplicar diferentes límites según endpoint
export const generalLimiter = createRateLimiter(15 * 60 * 1000, 100); // 100 req/15min
export const searchLimiter = createRateLimiter(15 * 60 * 1000, 50); // 50 req/15min
export const analyticsLimiter = createRateLimiter(60 * 60 * 1000, 200); // 200 req/hour
```

### Headers de Seguridad

**Headers HTTP Recomendados**:
```typescript
// middleware/securityHeaders.ts
export function securityHeaders(req: Request, res: Response, next: NextFunction) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('Content-Security-Policy', "default-src 'self'");
  next();
}
```

### Validación de Inputs

**Todas las entradas deben ser validadas**:
```typescript
// middleware/validate.ts
import Joi from 'joi';

export const validate = (schema: Joi.Schema) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const { error } = schema.validate(req.query);
    if (error) {
      return res.status(400).json({
        error: 'Validation error',
        details: error.details.map(d => d.message)
      });
    }
    next();
  };
};

// Uso
const userSearchSchema = Joi.object({
  min_notes: Joi.number().integer().min(0).optional(),
  country: Joi.number().integer().optional(),
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20)
});

router.get('/users', validate(userSearchSchema), searchUsers);
```

### Protección SQL Injection

**Siempre usar prepared statements**:
```typescript
// ✅ Correcto
const query = 'SELECT * FROM users WHERE user_id = $1';
const result = await db.query(query, [userId]);

// ❌ Incorrecto (vulnerable a SQL injection)
const query = `SELECT * FROM users WHERE user_id = ${userId}`;
const result = await db.query(query);
```

### Logging de Seguridad

**Registrar eventos de seguridad**:
```typescript
// middleware/securityLogging.ts
export function logSecurityEvent(req: Request, event: string, details?: any) {
  logger.warn('Security Event', {
    event,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    path: req.path,
    method: req.method,
    details
  });
}

// Uso
if (rateLimitExceeded) {
  logSecurityEvent(req, 'RATE_LIMIT_EXCEEDED', { limit: 100 });
}
```

---

## Monitoreo y Observabilidad

### Elementos a Monitorear

#### 1. Métricas de Performance

**Response Times**:
- P50, P95, P99 por endpoint
- Tiempo de base de datos
- Tiempo de cache hit/miss

**Throughput**:
- Requests por segundo
- Requests por minuto/hora
- Picos de tráfico

**Errores**:
- Rate de errores (4xx, 5xx)
- Errores por tipo
- Errores por endpoint

#### 2. Métricas de Negocio

**Uso por Endpoint**:
- Endpoints más populares
- Endpoints menos usados
- Tendencias de uso

**Uso por User-Agent**:
- Aplicaciones más activas
- Nuevas aplicaciones
- Aplicaciones problemáticas

**Uso por IP/País**:
- Distribución geográfica
- IPs con mayor tráfico
- Detección de patrones anómalos

**Rate Limiting**:
- Número de requests bloqueados
- IPs/User-Agents que exceden límites
- Patrones de abuso

#### 3. Métricas de Infraestructura

**Base de Datos**:
- Conexiones activas
- Queries lentas
- Uso de CPU/Memoria
- Tamaño de base de datos

**Cache**:
- Hit rate
- Miss rate
- Tiempo de evicción
- Uso de memoria

**Servidor API**:
- CPU usage
- Memoria usage
- Uptime
- Restarts

#### 4. Métricas de Calidad

**Disponibilidad**:
- Uptime percentage
- Downtime incidents
- MTTR (Mean Time To Recovery)

**SLA**:
- Response time SLA (ej: 95% < 200ms)
- Availability SLA (ej: 99.9%)
- Error rate SLA (ej: < 0.1%)

### Herramientas de Monitoreo

#### Opción 1: Prometheus + Grafana (Recomendada)

**Ventajas**:
- ✅ Open source y gratuito
- ✅ Muy flexible y extensible
- ✅ Gran ecosistema
- ✅ Alertas poderosas
- ✅ Dashboards personalizables

**Stack**:
- **Prometheus**: Recolección y almacenamiento de métricas
- **Grafana**: Visualización y dashboards
- **Node Exporter**: Métricas del sistema
- **PostgreSQL Exporter**: Métricas de base de datos

**Implementación**:
```typescript
// Node.js con prom-client
import client from 'prom-client';

// Registrar métricas
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

// Middleware para capturar métricas
export function metricsMiddleware(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.observe(
      { method: req.method, route: req.route?.path, status_code: res.statusCode },
      duration
    );
    httpRequestTotal.inc({
      method: req.method,
      route: req.route?.path,
      status_code: res.statusCode
    });
  });
  
  next();
}

// Endpoint de métricas
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
```

**Dashboards Grafana**:
- Dashboard de API: Response times, throughput, errores
- Dashboard de Base de Datos: Queries, conexiones, performance
- Dashboard de Infraestructura: CPU, memoria, disco
- Dashboard de Negocio: Uso por endpoint, User-Agent, país

#### Opción 2: Datadog (Comercial)

**Ventajas**:
- ✅ Muy fácil de usar
- ✅ APM (Application Performance Monitoring) integrado
- ✅ Logs, métricas, traces en un lugar
- ✅ Alertas avanzadas
- ✅ Integraciones con muchas herramientas

**Desventajas**:
- ❌ Costoso (puede ser $100+/mes)
- ❌ Vendor lock-in

**Cuándo usar**: Si el presupuesto lo permite y se valora la simplicidad

#### Opción 3: New Relic (Comercial)

**Ventajas**:
- ✅ Similar a Datadog
- ✅ Buen APM
- ✅ Fácil de configurar

**Desventajas**:
- ❌ Costoso
- ❌ Vendor lock-in

#### Opción 4: ELK Stack (Elasticsearch, Logstash, Kibana)

**Ventajas**:
- ✅ Open source
- ✅ Excelente para logs
- ✅ Búsqueda poderosa

**Desventajas**:
- ❌ Más complejo de configurar
- ❌ Requiere más recursos

**Cuándo usar**: Si se necesita análisis profundo de logs

### Logging

#### Estructura de Logs

**Formato**: JSON estructurado

```typescript
// logger.ts
import winston from 'winston';

export const logger = winston.createLogger({
  format: winston.format.json(),
  defaultMeta: {
    service: 'osm-notes-api',
    environment: process.env.NODE_ENV
  },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// En producción, también a stdout para Docker/Kubernetes
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.simple()
  }));
}
```

#### Información a Loggear

**Cada Request**:
```json
{
  "timestamp": "2025-12-14T10:30:00Z",
  "level": "info",
  "method": "GET",
  "path": "/api/v1/users/12345",
  "statusCode": 200,
  "responseTime": 45,
  "ip": "192.168.1.1",
  "userAgent": "MyApp/1.0 (contact@example.com)",
  "userAgentInfo": {
    "appName": "MyApp",
    "version": "1.0",
    "contact": "contact@example.com"
  }
}
```

**Eventos Importantes**:
- Rate limit exceeded
- Errores 4xx/5xx
- Queries lentas (> 1 segundo)
- Cache misses frecuentes
- Cambios de configuración

#### Logging de User-Agent

**Tracking de Aplicaciones**:
```typescript
// middleware/trackUserAgent.ts
export function trackUserAgent(req: Request, res: Response, next: NextFunction) {
  const userAgentInfo = req.userAgentInfo;
  
  if (userAgentInfo) {
    // Log para análisis posterior
    logger.info('API Request', {
      appName: userAgentInfo.appName,
      version: userAgentInfo.version,
      contact: userAgentInfo.contact,
      endpoint: req.path,
      method: req.method
    });
    
    // Incrementar contador en métricas
    appUsageCounter.inc({
      app: userAgentInfo.appName,
      version: userAgentInfo.version
    });
  }
  
  next();
}
```

**Estadísticas de Aplicaciones**:
- Dashboard en Grafana mostrando:
  - Top 10 aplicaciones por requests
  - Requests por aplicación a lo largo del tiempo
  - Nuevas aplicaciones detectadas
  - Versiones de aplicaciones

### Alertas

#### Alertas Críticas

**Disponibilidad**:
- API down por más de 1 minuto
- Error rate > 5% por más de 5 minutos
- Response time P95 > 1 segundo por más de 10 minutos

**Base de Datos**:
- Conexiones agotadas
- Queries lentas (> 5 segundos)
- Espacio en disco < 20%

**Infraestructura**:
- CPU > 80% por más de 10 minutos
- Memoria > 90%
- Disco > 90%

#### Alertas de Negocio

**Uso Anómalo**:
- Aumento súbito de tráfico (> 200%)
- Nuevo User-Agent con mucho tráfico
- IP con patrón de abuso

**Rate Limiting**:
- Muchos requests bloqueados (> 100/hora)
- Mismo User-Agent bloqueado repetidamente

### Implementación de Monitoreo

#### Setup Básico (Prometheus + Grafana)

**1. Instalar Prometheus**:
```yaml
# docker-compose.yml
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
  
  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

**2. Configurar Prometheus**:
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'api'
    static_configs:
      - targets: ['api:3000']
    metrics_path: '/metrics'
```

**3. Configurar Grafana**:
- Importar dashboards predefinidos
- Crear dashboards personalizados
- Configurar alertas

#### Métricas Personalizadas

**Tracking de User-Agents**:
```typescript
// metrics/userAgentMetrics.ts
import client from 'prom-client';

export const userAgentRequests = new client.Counter({
  name: 'user_agent_requests_total',
  help: 'Total requests by user agent',
  labelNames: ['app_name', 'version']
});

export const userAgentResponseTime = new client.Histogram({
  name: 'user_agent_response_time_seconds',
  help: 'Response time by user agent',
  labelNames: ['app_name'],
  buckets: [0.1, 0.5, 1, 2, 5]
});
```

**Tracking de Endpoints**:
```typescript
export const endpointUsage = new client.Counter({
  name: 'endpoint_usage_total',
  help: 'Usage by endpoint',
  labelNames: ['endpoint', 'method']
});
```

### Dashboards Recomendados

#### 1. Dashboard de API Health

**Métricas**:
- Response times (P50, P95, P99)
- Request rate (req/s)
- Error rate (%)
- Top endpoints
- Top User-Agents

#### 2. Dashboard de Base de Datos

**Métricas**:
- Query duration
- Active connections
- Cache hit rate
- Slow queries

#### 3. Dashboard de Negocio

**Métricas**:
- Requests por aplicación (User-Agent)
- Requests por país (IP geolocation)
- Endpoints más populares
- Tendencias de uso (últimas 24h, 7d, 30d)

#### 4. Dashboard de Seguridad

**Métricas**:
- Rate limit violations
- IPs bloqueados
- User-Agents problemáticos
- Patrones de abuso

### Health Checks

**Endpoint de Health**:
```typescript
// routes/health.ts
router.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    checks: {
      database: await checkDatabase(),
      cache: await checkCache(),
      disk: await checkDiskSpace()
    }
  };
  
  const allHealthy = Object.values(health.checks).every(c => c.status === 'ok');
  res.status(allHealthy ? 200 : 503).json(health);
});
```

**Uso**:
- Kubernetes liveness/readiness probes
- Load balancer health checks
- Monitoreo externo (UptimeRobot, Pingdom)

### Costos Estimados

| Herramienta | Costo Mensual |
|-------------|---------------|
| Prometheus + Grafana (self-hosted) | $0 (solo infraestructura) |
| Datadog | $100-500+ (según volumen) |
| New Relic | $100-500+ (según volumen) |
| ELK Stack (self-hosted) | $0 (solo infraestructura) |

**Recomendación**: Empezar con Prometheus + Grafana (gratis), migrar a solución comercial solo si es necesario.

---

## Análisis de Costo-Beneficio

### Costos

#### Desarrollo (Una vez)

| Tarea | Tiempo | Costo Estimado |
|-------|--------|----------------|
| Diseño de API | 1 semana | - |
| Implementación MVP | 2 semanas | - |
| Implementación Completa | 4 semanas | - |
| Testing | 1 semana | - |
| Documentación | 1 semana | - |
| **Total** | **9 semanas** | **Tiempo del desarrollador** |

#### Infraestructura (Recurrente)

| Componente | Costo Mensual Estimado |
|------------|------------------------|
| Servidor API (2 CPU, 4GB RAM) | $20-50 |
| Redis Cache (si se usa) | $10-20 |
| Load Balancer (si se usa) | $10-20 |
| Monitoreo/Logging | $5-10 |
| **Total** | **$45-100/mes** |

#### Mantenimiento (Recurrente)

| Tarea | Frecuencia | Tiempo |
|-------|------------|--------|
| Bug fixes | Según necesidad | 2-4 horas/mes |
| Nuevas features | Según demanda | 4-8 horas/mes |
| Actualizaciones | Mensual | 1-2 horas/mes |
| Monitoreo | Diario | 15 min/día |
| **Total** | - | **10-15 horas/mes** |

### Beneficios

#### Cuantitativos

1. **Reducción de Carga en Base de Datos**:
   - Cache reduce queries repetidas
   - **Ahorro**: 30-50% menos carga

2. **Mejor Experiencia de Usuario**:
   - Respuestas más rápidas (cache)
   - Datos actualizados
   - **Valor**: Difícil de cuantificar, pero alto

3. **Nuevas Oportunidades**:
   - Integraciones con otras herramientas
   - Aplicaciones móviles
   - Dashboards dinámicos
   - **Valor**: Alto potencial

#### Cualitativos

1. **Accesibilidad**: Más fácil acceso a datos
2. **Extensibilidad**: Base para futuras features
3. **Estandarización**: API REST estándar
4. **Comunidad**: Permite contribuciones externas
5. **Innovación**: Facilita experimentación

### ROI Estimado

**Inversión Inicial**: 9 semanas desarrollo + setup infraestructura

**Retorno**:
- **Corto plazo (3-6 meses)**: Mejora en experiencia de usuario, reducción de carga
- **Medio plazo (6-12 meses)**: Integraciones, nuevas herramientas
- **Largo plazo (12+ meses)**: Ecosistema de herramientas alrededor de la API

**Conclusión**: ROI positivo si hay demanda de acceso programático.

---

## Plan de Implementación

### Fase 1: MVP (3-4 semanas)

**Objetivo**: Endpoints básicos funcionales con documentación y pruebas

**Endpoints**:
- ✅ `GET /api/v1/users/{user_id}` - Perfil de usuario
- ✅ `GET /api/v1/countries/{country_id}` - Perfil de país
- ✅ `GET /api/v1/analytics/global` - Estadísticas globales
- ✅ `GET /api/v1/users` - Lista de usuarios (paginada)
- ✅ `GET /api/v1/countries` - Lista de países (paginada)

**Features**:
- Validación básica
- Paginación
- Respuestas JSON
- **User-Agent requerido y validado**
- **Rate limiting básico**
- **Documentación OpenAPI completa**
- **Pruebas unitarias (80%+ cobertura)**
- **Pruebas de integración para todos los endpoints**

**No incluye**:
- Búsqueda avanzada
- Filtros complejos
- Cache
- Monitoreo avanzado

### Fase 2: Funcionalidades Básicas (2-3 semanas)

**Objetivos**:
- ✅ Búsqueda básica
- ✅ Filtros simples
- ✅ Ordenamiento
- ✅ Cache básico (Redis)
- ✅ Rate limiting completo con tracking de User-Agent
- ✅ **Monitoreo básico (Prometheus + métricas)**
- ✅ **Logging estructurado**
- ✅ **Pruebas de carga básicas**

**Endpoints Adicionales**:
- `GET /api/v1/search/users` - Búsqueda de usuarios
- `GET /api/v1/search/countries` - Búsqueda de países
- `GET /api/v1/users/rankings` - Rankings
- `GET /api/v1/countries/rankings` - Rankings de países

**Monitoreo**:
- Setup de Prometheus
- Métricas básicas (response time, throughput, errores)
- Dashboard básico en Grafana
- Tracking de User-Agents

### Fase 3: Funcionalidades Avanzadas (2-3 semanas)

**Objetivos**:
- ✅ Búsqueda avanzada (múltiples filtros)
- ✅ Endpoints de notas
- ✅ Endpoints de hashtags
- ✅ Comparaciones
- ✅ Agregaciones
- ✅ **Monitoreo avanzado (dashboards completos)**
- ✅ **Alertas configuradas**

**Endpoints Adicionales**:
- `GET /api/v1/notes` - Búsqueda de notas
- `GET /api/v1/notes/{note_id}` - Detalle de nota
- `GET /api/v1/hashtags` - Lista de hashtags
- `GET /api/v1/hashtags/{hashtag}` - Estadísticas de hashtag
- `GET /api/v1/analytics/comparison` - Comparaciones
- `GET /api/v1/analytics/trends` - Tendencias

**Monitoreo Avanzado**:
- Dashboards completos (API, DB, Negocio, Seguridad)
- Alertas configuradas
- Tracking detallado de User-Agents
- Análisis de uso por aplicación

### Fase 4: Optimización y Producción (1-2 semanas)

**Objetivos**:
- ✅ Cache avanzado optimizado
- ✅ Rate limiting completo con estadísticas
- ✅ **Monitoreo completo en producción**
- ✅ **Documentación publicada y accesible**
- ✅ **Testing completo (unitarias, integración, carga)**
- ✅ **Health checks y alertas**
- ✅ Deployment en producción
- ✅ **Documentación de operaciones (runbook)**

### Timeline Total

```
Semana 1-4:   Fase 1 (MVP + Documentación + Pruebas)
Semana 5-7:   Fase 2 (Básicas + Monitoreo básico)
Semana 8-10:  Fase 3 (Avanzadas + Monitoreo completo)
Semana 11-12: Fase 4 (Producción + Optimización)
────────────────────────────────────────────────────
Total: 12 semanas (~3 meses)
```

**Nota**: El timeline incluye tiempo para documentación completa, pruebas exhaustivas y setup de monitoreo.

---

## Riesgos y Mitigaciones

### Riesgos Técnicos

#### 1. Performance de Base de Datos

**Riesgo**: Queries complejas pueden ser lentas.

**Mitigación**:
- Usar datamarts pre-computados (ya existen)
- Cache agresivo
- Índices optimizados
- Paginación obligatoria
- Timeouts en queries

#### 2. Carga de Tráfico

**Riesgo**: API puede recibir mucho tráfico.

**Mitigación**:
- Rate limiting
- Cache
- Load balancing
- Auto-scaling (si se usa Kubernetes)
- Monitoreo de carga

#### 3. Cambios en Esquema de Base de Datos

**Riesgo**: Cambios en datamarts pueden romper API.

**Mitigación**:
- Versionado de API (`/api/v1/`, `/api/v2/`)
- Tests de integración
- Documentación de cambios
- Deprecation warnings

### Riesgos de Negocio

#### 1. Bajo Uso

**Riesgo**: API no se usa mucho.

**Mitigación**:
- Empezar con MVP pequeño
- Promover uso (documentación, ejemplos)
- Medir adopción
- Iterar basado en feedback

#### 2. Mantenimiento Continuo

**Riesgo**: Requiere mantenimiento constante.

**Mitigación**:
- Código bien documentado
- Tests automatizados
- Monitoreo automatizado
- Documentación clara

#### 3. Costos de Infraestructura

**Riesgo**: Costos pueden crecer.

**Mitigación**:
- Empezar pequeño (servidor básico)
- Monitorear costos
- Optimizar cache
- Auto-scaling solo si es necesario

---

## Conclusiones y Recomendaciones

### ¿Vale la Pena?

**SÍ, con las siguientes condiciones**:

1. **Implementación Incremental**: Empezar con MVP, expandir según demanda
2. **Enfoque en Valor**: Priorizar endpoints más usados
3. **Reutilización**: Aprovechar datamarts existentes
4. **Monitoreo**: Medir uso y ajustar

### Recomendación Final

**Implementar la API en fases**:

1. **Fase 1 (MVP)**: Endpoints básicos para validar demanda (2-3 semanas)
2. **Evaluación**: Medir uso, feedback, necesidades
3. **Fase 2+**: Expandir según demanda real

### Próximos Pasos

Si decides implementar:

1. **Validar Necesidad**: 
   - ¿Hay desarrolladores que la usarían?
   - ¿Hay casos de uso concretos?
   - ¿El viewer se beneficiaría?

2. **Definir Alcance**:
   - ¿Qué endpoints son prioritarios?
   - ¿Qué funcionalidades son esenciales?

3. **Elegir Tecnología**:
   - Node.js + Express (recomendado)
   - Python + FastAPI (alternativa)
   - Go (si performance es crítica)

4. **Planificar Implementación**:
   - Seguir fases propuestas
   - Definir timeline
   - Asignar recursos

### Alternativa: Mejorar JSON Exports

Si la API no es prioridad ahora, se puede mejorar el sistema de JSON exports:

- ✅ Exportación más frecuente (cada 5 minutos)
- ✅ Endpoints de búsqueda en JSON (servidor estático con índices)
- ✅ JSON más granular (por país, por usuario, etc.)

**Ventaja**: Menos desarrollo, funciona para casos de uso simples.

**Desventaja**: Menos flexible que API REST.

---

## Guía de Implementación Inicial

Esta sección proporciona los pasos específicos y archivos de ejemplo necesarios para que un desarrollador (o AI) pueda comenzar a implementar la API desde cero.

### Prerrequisitos

- Node.js 18+ instalado
- PostgreSQL 12+ con base de datos `osm_notes` configurada
- Acceso a las tablas del data warehouse (`dwh.datamartUsers`, `dwh.datamartCountries`, etc.)
- Git instalado

### Paso 1: Crear Estructura del Proyecto

```bash
# Crear directorio del proyecto
mkdir OSM-Notes-API
cd OSM-Notes-API

# Inicializar proyecto Node.js
npm init -y

# Crear estructura de directorios
mkdir -p src/{routes,controllers,services,middleware,models,utils,config}
mkdir -p tests/{unit,integration,load,fixtures,helpers}
mkdir -p docs/api
```

### Paso 2: Instalar Dependencias

```bash
# Dependencias principales
npm install express cors helmet
npm install pg dotenv
npm install joi express-rate-limit
npm install winston winston-daily-rotate-file
npm install prom-client

# Dependencias de desarrollo
npm install -D typescript @types/node @types/express @types/cors
npm install -D @types/pg @typescript-eslint/eslint-plugin @typescript-eslint/parser
npm install -D jest @types/jest ts-jest supertest @types/supertest
npm install -D swagger-jsdoc swagger-ui-express @types/swagger-jsdoc @types/swagger-ui-express
npm install -D nodemon eslint prettier

# Scripts de documentación
npm install -g swagger-cli @stoplight/spectral-cli
```

### Paso 3: Archivos de Configuración Base

#### `package.json`

```json
{
  "name": "osm-notes-api",
  "version": "1.0.0",
  "description": "REST API for OSM Notes Analytics",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "nodemon --exec ts-node src/index.ts",
    "test": "jest",
    "test:unit": "jest tests/unit",
    "test:integration": "jest tests/integration",
    "test:coverage": "jest --coverage",
    "docs:generate": "swagger-jsdoc -d swaggerDef.js src/routes/*.ts -o docs/api/openapi.json",
    "docs:validate": "swagger-cli validate docs/api/openapi.json",
    "lint": "eslint src/**/*.ts",
    "format": "prettier --write src/**/*.ts"
  },
  "keywords": ["osm", "notes", "api", "analytics"],
  "author": "",
  "license": "MIT"
}
```

#### `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "moduleResolution": "node",
    "types": ["node", "jest"]
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "tests", "dist"]
}
```

#### `.env.example`

```bash
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/osm_notes
DB_POOL_MIN=2
DB_POOL_MAX=10

# Server
PORT=3000
NODE_ENV=development
API_VERSION=v1

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Cache (Redis - opcional)
REDIS_URL=redis://localhost:6379
CACHE_TTL=300

# Logging
LOG_LEVEL=info
LOG_FILE=logs/app.log

# API
API_BASE_URL=http://localhost:3000
```

#### `jest.config.js`

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/index.ts'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  }
};
```

### Paso 4: Archivos Base del Código

#### `src/index.ts`

```typescript
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { config } from './config';
import { logger } from './utils/logger';
import { errorHandler } from './middleware/errorHandler';
import { metricsMiddleware } from './middleware/metrics';
import { validateUserAgent } from './middleware/validateUserAgent';
import { generalLimiter } from './middleware/rateLimit';

// Routes
import userRoutes from './routes/users';
import countryRoutes from './routes/countries';
import analyticsRoutes from './routes/analytics';

const app = express();

// Security
app.use(helmet());
app.use(cors());

// Body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Metrics
app.use(metricsMiddleware);

// User-Agent validation (required for all routes)
app.use(validateUserAgent);

// Rate limiting
app.use(generalLimiter);

// Health check (before User-Agent validation)
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  const { register } = await import('prom-client');
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// API Routes
app.use(`/api/${config.apiVersion}`, userRoutes);
app.use(`/api/${config.apiVersion}`, countryRoutes);
app.use(`/api/${config.apiVersion}`, analyticsRoutes);

// Error handling
app.use(errorHandler);

// Start server
const PORT = config.port || 3000;
app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
  logger.info(`Environment: ${config.env}`);
});

export default app;
```

#### `src/config/index.ts`

```typescript
import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  env: process.env.NODE_ENV || 'development',
  apiVersion: process.env.API_VERSION || 'v1',
  database: {
    url: process.env.DATABASE_URL || 'postgresql://user:password@localhost:5432/osm_notes',
    poolMin: parseInt(process.env.DB_POOL_MIN || '2', 10),
    poolMax: parseInt(process.env.DB_POOL_MAX || '10', 10)
  },
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10)
  },
  cache: {
    ttl: parseInt(process.env.CACHE_TTL || '300', 10),
    redisUrl: process.env.REDIS_URL
  },
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    file: process.env.LOG_FILE || 'logs/app.log'
  }
};
```

#### `src/utils/db.ts`

```typescript
import { Pool } from 'pg';
import { config } from '../config';
import { logger } from './logger';

export const pool = new Pool({
  connectionString: config.database.url,
  min: config.database.poolMin,
  max: config.database.poolMax,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000
});

pool.on('error', (err) => {
  logger.error('Unexpected error on idle client', err);
  process.exit(-1);
});

export async function query(text: string, params?: any[]) {
  const start = Date.now();
  try {
    const res = await pool.query(text, params);
    const duration = Date.now() - start;
    logger.debug('Executed query', { text, duration, rows: res.rowCount });
    return res;
  } catch (error) {
    logger.error('Query error', { text, error });
    throw error;
  }
}
```

#### `src/utils/logger.ts`

```typescript
import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';
import { config } from '../config';

const logFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

export const logger = winston.createLogger({
  level: config.logging.level,
  format: logFormat,
  defaultMeta: {
    service: 'osm-notes-api',
    environment: config.env
  },
  transports: [
    new DailyRotateFile({
      filename: config.logging.file,
      datePattern: 'YYYY-MM-DD',
      maxSize: '20m',
      maxFiles: '14d'
    }),
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});
```

#### `src/middleware/validateUserAgent.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

interface UserAgentInfo {
  appName: string;
  version: string;
  contact: string | null;
}

declare global {
  namespace Express {
    interface Request {
      userAgentInfo?: UserAgentInfo;
    }
  }
}

export function validateUserAgent(req: Request, res: Response, next: NextFunction) {
  const userAgent = req.get('User-Agent');
  
  if (!userAgent) {
    logger.warn('Request without User-Agent', { ip: req.ip, path: req.path });
    return res.status(400).json({
      error: 'User-Agent header is required',
      message: 'Please include a User-Agent header with your application name and contact information. Format: AppName/Version (Contact)'
    });
  }
  
  // Validar formato básico: AppName/Version (Contact)
  const userAgentPattern = /^([\w\-\.]+)\/([\w\-\.]+)(?:\s+\(([^)]+)\))?/;
  const match = userAgent.match(userAgentPattern);
  
  if (!match) {
    logger.warn('Invalid User-Agent format', { userAgent, ip: req.ip });
    return res.status(400).json({
      error: 'Invalid User-Agent format',
      message: 'User-Agent must follow format: AppName/Version (Contact)',
      example: 'MyApp/1.0 (contact@example.com)'
    });
  }
  
  // Extraer información
  req.userAgentInfo = {
    appName: match[1],
    version: match[2],
    contact: match[3] || null
  };
  
  // Log para estadísticas
  logger.info('API Request', {
    appName: req.userAgentInfo.appName,
    version: req.userAgentInfo.version,
    contact: req.userAgentInfo.contact,
    endpoint: req.path,
    method: req.method,
    ip: req.ip
  });
  
  next();
}
```

#### `src/middleware/rateLimit.ts`

```typescript
import rateLimit from 'express-rate-limit';
import { Request } from 'express';

export const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  keyGenerator: (req: Request) => {
    // Combinar IP + User-Agent para tracking
    const ip = req.ip || 'unknown';
    const userAgent = req.get('User-Agent') || 'unknown';
    return `${ip}:${userAgent}`;
  },
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Too many requests',
    message: 'Rate limit exceeded. Please reduce your request frequency.',
    retryAfter: '15 minutes'
  }
});

export const searchLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50,
  keyGenerator: (req: Request) => {
    const ip = req.ip || 'unknown';
    const userAgent = req.get('User-Agent') || 'unknown';
    return `${ip}:${userAgent}`;
  }
});
```

#### `src/middleware/metrics.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import client from 'prom-client';

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code', 'user_agent']
});

export function metricsMiddleware(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();
  const route = req.route?.path || req.path;
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const userAgent = req.userAgentInfo?.appName || 'unknown';
    
    httpRequestDuration.observe(
      { method: req.method, route, status_code: res.statusCode },
      duration
    );
    
    httpRequestTotal.inc({
      method: req.method,
      route,
      status_code: res.statusCode,
      user_agent: userAgent
    });
  });
  
  next();
}
```

#### `src/middleware/errorHandler.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
) {
  logger.error('Error handling request', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    ip: req.ip
  });
  
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'An error occurred'
  });
}
```

### Paso 5: Primer Endpoint (Ejemplo Completo)

#### `src/routes/users.ts`

```typescript
import { Router } from 'express';
import { getUserProfile, searchUsers } from '../controllers/users';
import { validate } from '../middleware/validate';
import Joi from 'joi';

const router = Router();

/**
 * @swagger
 * /users/{user_id}:
 *   get:
 *     summary: Get user profile
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: user_id
 *         required: true
 *         schema:
 *           type: integer
 *         description: OSM user ID
 *     responses:
 *       200:
 *         description: User profile
 *       404:
 *         description: User not found
 */
router.get('/users/:user_id', getUserProfile);

const searchSchema = Joi.object({
  min_notes: Joi.number().integer().min(0).optional(),
  country: Joi.number().integer().optional(),
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20)
});

router.get('/users', validate(searchSchema), searchUsers);

export default router;
```

#### `src/controllers/users.ts`

```typescript
import { Request, Response } from 'express';
import { getUserProfileService, searchUsersService } from '../services/userService';
import { logger } from '../utils/logger';

export async function getUserProfile(req: Request, res: Response) {
  try {
    const userId = parseInt(req.params.user_id, 10);
    
    if (isNaN(userId)) {
      return res.status(400).json({
        error: 'Invalid user_id',
        message: 'user_id must be a valid integer'
      });
    }
    
    const user = await getUserProfileService(userId);
    
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        message: `User with ID ${userId} does not exist`
      });
    }
    
    res.json(user);
  } catch (error) {
    logger.error('Error getting user profile', { error, userId: req.params.user_id });
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to retrieve user profile'
    });
  }
}

export async function searchUsers(req: Request, res: Response) {
  try {
    const filters = {
      minNotes: req.query.min_notes ? parseInt(req.query.min_notes as string, 10) : undefined,
      country: req.query.country ? parseInt(req.query.country as string, 10) : undefined,
      page: parseInt(req.query.page as string || '1', 10),
      limit: parseInt(req.query.limit as string || '20', 10)
    };
    
    const result = await searchUsersService(filters);
    
    res.json({
      data: result.users,
      pagination: {
        page: filters.page,
        limit: filters.limit,
        total: result.total,
        totalPages: Math.ceil(result.total / filters.limit)
      }
    });
  } catch (error) {
    logger.error('Error searching users', { error, query: req.query });
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to search users'
    });
  }
}
```

#### `src/services/userService.ts`

```typescript
import { query } from '../utils/db';
import { logger } from '../utils/logger';

export async function getUserProfileService(userId: number) {
  const sql = `
    SELECT 
      dimension_user_id,
      user_id,
      username,
      history_whole_open,
      history_whole_closed,
      history_whole_commented,
      avg_days_to_resolution,
      resolution_rate,
      user_response_time,
      days_since_last_action,
      applications_used,
      collaboration_patterns,
      countries_open_notes,
      hashtags,
      date_starting_creating_notes,
      date_starting_solving_notes,
      last_year_activity,
      working_hours_of_week_opening,
      activity_by_year
    FROM dwh.datamartusers
    WHERE user_id = $1
  `;
  
  try {
    const result = await query(sql, [userId]);
    
    if (result.rows.length === 0) {
      return null;
    }
    
    return result.rows[0];
  } catch (error) {
    logger.error('Database error in getUserProfileService', { error, userId });
    throw error;
  }
}

export async function searchUsersService(filters: {
  minNotes?: number;
  country?: number;
  page: number;
  limit: number;
}) {
  let sql = 'SELECT COUNT(*) as total FROM dwh.datamartusers WHERE 1=1';
  const params: any[] = [];
  let paramCount = 1;
  
  if (filters.minNotes !== undefined) {
    sql += ` AND history_whole_open >= $${paramCount}`;
    params.push(filters.minNotes);
    paramCount++;
  }
  
  if (filters.country !== undefined) {
    sql += ` AND dimension_country_id = $${paramCount}`;
    params.push(filters.country);
    paramCount++;
  }
  
  // Get total count
  const countResult = await query(sql, params);
  const total = parseInt(countResult.rows[0].total, 10);
  
  // Get paginated results
  sql = sql.replace('COUNT(*) as total', `
    dimension_user_id,
    user_id,
    username,
    history_whole_open,
    history_whole_closed,
    resolution_rate
  `);
  sql += ` ORDER BY history_whole_open DESC LIMIT $${paramCount} OFFSET $${paramCount + 1}`;
  params.push(filters.limit, (filters.page - 1) * filters.limit);
  
  const result = await query(sql, params);
  
  return {
    users: result.rows,
    total
  };
}
```

#### `src/middleware/validate.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import Joi from 'joi';

export function validate(schema: Joi.Schema) {
  return (req: Request, res: Response, next: NextFunction) => {
    const { error, value } = schema.validate(req.query, {
      abortEarly: false,
      stripUnknown: true
    });
    
    if (error) {
      return res.status(400).json({
        error: 'Validation error',
        details: error.details.map(d => d.message)
      });
    }
    
    // Replace query with validated values
    req.query = value as any;
    next();
  };
}
```

### Paso 6: Prueba Básica

#### `tests/integration/users.test.ts`

```typescript
import request from 'supertest';
import app from '../../src/index';

describe('GET /api/v1/users/:user_id', () => {
  test('returns user profile with valid user_id', async () => {
    const response = await request(app)
      .get('/api/v1/users/12345')
      .set('User-Agent', 'TestApp/1.0 (test@example.com)')
      .expect(200);
    
    expect(response.body).toHaveProperty('user_id');
    expect(response.body).toHaveProperty('username');
    expect(response.body).toHaveProperty('history_whole_open');
  });
  
  test('returns 400 without User-Agent', async () => {
    await request(app)
      .get('/api/v1/users/12345')
      .expect(400)
      .expect(res => {
        expect(res.body.error).toContain('User-Agent');
      });
  });
  
  test('returns 404 for non-existent user', async () => {
    await request(app)
      .get('/api/v1/users/999999')
      .set('User-Agent', 'TestApp/1.0 (test@example.com)')
      .expect(404);
  });
});
```

### Paso 7: Comandos para Empezar

```bash
# 1. Instalar dependencias
npm install

# 2. Configurar variables de entorno
cp .env.example .env
# Editar .env con tus credenciales de base de datos

# 3. Compilar TypeScript
npm run build

# 4. Ejecutar en modo desarrollo
npm run dev

# 5. En otra terminal, ejecutar tests
npm test

# 6. Verificar que el servidor está funcionando
curl -H "User-Agent: TestApp/1.0 (test@example.com)" http://localhost:3000/health

# 7. Probar endpoint de usuario
curl -H "User-Agent: TestApp/1.0 (test@example.com)" http://localhost:3000/api/v1/users/12345
```

### Checklist de Implementación

**Setup Inicial**:
- [ ] Proyecto creado y estructura de directorios
- [ ] Dependencias instaladas
- [ ] Archivos de configuración creados (.env, tsconfig.json, etc.)
- [ ] Base de datos conectada y probada

**Código Base**:
- [ ] `src/index.ts` con servidor Express básico
- [ ] Middleware de User-Agent implementado
- [ ] Middleware de rate limiting implementado
- [ ] Middleware de métricas implementado
- [ ] Logger configurado
- [ ] Error handler implementado

**Primer Endpoint**:
- [ ] Ruta de usuarios creada
- [ ] Controller de usuarios implementado
- [ ] Service de usuarios implementado
- [ ] Pruebas de integración escritas
- [ ] Endpoint probado manualmente

**Documentación**:
- [ ] OpenAPI spec iniciado
- [ ] Swagger UI configurado
- [ ] Documentación del primer endpoint

**Monitoreo**:
- [ ] Prometheus configurado
- [ ] Métricas básicas funcionando
- [ ] Endpoint `/metrics` accesible

### Próximos Pasos

Una vez completado el setup básico:

1. **Agregar más endpoints**: Países, notas, analytics
2. **Implementar cache**: Redis para mejorar performance
3. **Completar pruebas**: Aumentar cobertura a 80%+
4. **Documentación completa**: Todos los endpoints documentados
5. **Monitoreo avanzado**: Dashboards en Grafana
6. **Deployment**: Configurar para producción

---

## Apéndices

### A. Ejemplo de Implementación (Node.js)

```typescript
// routes/users.ts
import express from 'express';
import { getUserProfile, searchUsers } from '../controllers/users';

const router = express.Router();

router.get('/users/:user_id', getUserProfile);
router.get('/users', searchUsers);

export default router;

// controllers/users.ts
import { Request, Response } from 'express';
import { db } from '../db';

export async function getUserProfile(req: Request, res: Response) {
  const { user_id } = req.params;
  
  const query = `
    SELECT * FROM dwh.datamartusers
    WHERE user_id = $1
  `;
  
  const result = await db.query(query, [user_id]);
  
  if (result.rows.length === 0) {
    return res.status(404).json({ error: 'User not found' });
  }
  
  res.json(result.rows[0]);
}
```

### B. Ejemplo de Documentación OpenAPI

```yaml
openapi: 3.0.0
info:
  title: OSM Notes Analytics API
  version: 1.0.0
paths:
  /api/v1/users/{user_id}:
    get:
      summary: Get user profile
      parameters:
        - name: user_id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: User profile
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserProfile'
```

### C. Comparación de Tecnologías

| Aspecto | Node.js | Python | Go |
|---------|---------|--------|-----|
| Velocidad desarrollo | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Performance | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Ecosistema | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Curva aprendizaje | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Mantenimiento | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

---

**Documento preparado por**: AI Assistant  
**Revisión recomendada por**: Equipo de desarrollo  
**Fecha de próxima revisión**: Después de validación de necesidad


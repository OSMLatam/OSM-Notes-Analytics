# JSON Schema Location and Usage

## Overview

JSON Schema files define the structure of exported data files. These schemas are used by:
- **OSM-Notes-Analytics** (producer): Validates JSON exports before publishing
- **OSM-Notes-Viewer** (consumer): Understands data structure and displays metrics

## Schema Locations

### Primary Location: OSM-Notes-Data Repository

**For frontend/consumer applications, schemas are available at:**

```
https://osmlatam.github.io/OSM-Notes-Data/schemas/
```

**Local path (when cloned):**
```
OSM-Notes-Data/schemas/
├── user-profile.schema.json
├── country-profile.schema.json
├── user-index.schema.json
├── country-index.schema.json
├── global-stats.schema.json
├── metadata.schema.json
└── README.md
```

**Why this location?**
- ✅ Schemas are automatically synced with data exports
- ✅ Same repository as the JSON data files
- ✅ Available via GitHub Pages (CDN-friendly)
- ✅ No need to clone multiple repositories
- ✅ Versioned together with data

### Source Location: OSM-Notes-Common Submodule

**For development/validation, schemas are located at:**

```
OSM-Notes-Analytics/lib/osm-common/schemas/
```

This is a Git submodule pointing to [OSM-Notes-Common](https://github.com/OSMLatam/OSM-Notes-Common).

**Note:** The export script (`exportAndPushToGitHub.sh`) automatically copies schemas from this location to the data repository during each export.

## Schema Files

| Schema File | Description | Validates |
|------------|-------------|-----------|
| `user-profile.schema.json` | Complete user profile with 78+ metrics | `data/users/{user_id}.json` |
| `country-profile.schema.json` | Complete country profile with 77+ metrics | `data/countries/{country_id}.json` |
| `user-index.schema.json` | User index with key metrics | `data/indexes/users.json` |
| `country-index.schema.json` | Country index with key metrics | `data/indexes/countries.json` |
| `global-stats.schema.json` | Global statistics | `data/global_stats.json` |
| `metadata.schema.json` | Export metadata | `data/metadata.json` |

## Usage for Frontend Developers

### 1. Load Schema from GitHub Pages

```javascript
// Load user profile schema
async function loadUserProfileSchema() {
  const response = await fetch('https://osmlatam.github.io/OSM-Notes-Data/schemas/user-profile.schema.json');
  const schema = await response.json();
  return schema;
}
```

### 2. Validate Data Against Schema

```javascript
import Ajv from 'ajv';
import addFormats from 'ajv-formats';

async function validateUserProfile(userData) {
  // Load schema
  const schema = await loadUserProfileSchema();
  
  // Create validator
  const ajv = new Ajv({ allErrors: true });
  addFormats(ajv);
  const validate = ajv.compile(schema);
  
  // Validate data
  const valid = validate(userData);
  
  if (!valid) {
    console.error('Validation errors:', validate.errors);
    return false;
  }
  
  return true;
}
```

### 3. Discover Available Metrics

```javascript
// Load schema to discover all available metrics
async function getAvailableMetrics(type = 'user') {
  const schemaName = type === 'user' 
    ? 'user-profile.schema.json' 
    : 'country-profile.schema.json';
  
  const response = await fetch(`https://osmlatam.github.io/OSM-Notes-Data/schemas/${schemaName}`);
  const schema = await response.json();
  
  // Extract property names (metrics)
  const metrics = Object.keys(schema.properties || {});
  
  return metrics;
}

// Usage
const userMetrics = await getAvailableMetrics('user');
console.log('Available user metrics:', userMetrics);
// Output: ['user_id', 'username', 'history_whole_open', 'history_whole_closed', ...]
```

### 4. Type-Safe Data Access

```javascript
// Use schema to create type-safe accessors
async function createTypeSafeAccessor() {
  const schema = await loadUserProfileSchema();
  const properties = schema.properties;
  
  return {
    // Get metric type
    getMetricType: (metricName) => properties[metricName]?.type,
    
    // Check if metric is required
    isRequired: (metricName) => schema.required?.includes(metricName),
    
    // Get metric description
    getDescription: (metricName) => properties[metricName]?.description,
  };
}
```

## Schema Updates

### How Schemas Are Updated

1. **Source**: Schemas are maintained in `OSM-Notes-Common` repository
2. **Sync**: `exportAndPushToGitHub.sh` copies schemas to `OSM-Notes-Data/schemas/` during each export
3. **Versioning**: Schema version is tracked in `metadata.json` (`schema_version` field)

### Checking Schema Version

```javascript
async function checkSchemaVersion() {
  const response = await fetch('https://osmlatam.github.io/OSM-Notes-Data/data/metadata.json');
  const metadata = await response.json();
  
  console.log('Schema version:', metadata.schema_version);
  console.log('Export version:', metadata.version);
  console.log('Schema hash:', metadata.data_schema_hash);
  
  return metadata;
}
```

### Handling Schema Changes

```javascript
// Check if schema has changed
async function hasSchemaChanged(lastKnownHash) {
  const metadata = await checkSchemaVersion();
  return metadata.data_schema_hash !== lastKnownHash;
}

// Reload schema if changed
async function getSchemaIfChanged(schemaName, lastKnownHash) {
  if (await hasSchemaChanged(lastKnownHash)) {
    console.log('Schema changed, reloading...');
    return await loadSchema(schemaName);
  }
  return null; // No change
}
```

## Local Development

### For Analytics Repository

Schemas are located at:
```bash
lib/osm-common/schemas/
```

To update schemas:
1. Edit schemas in `OSM-Notes-Common` repository
2. Update submodule: `git submodule update --remote lib/osm-common`
3. Run export: `./bin/dwh/exportAndPushToGitHub.sh`

### For Data Repository

Schemas are automatically copied during export. To manually update:
```bash
cd ~/github/OSM-Notes-Data
git pull origin main
```

## Best Practices

### For Frontend Developers

1. **Cache schemas**: Schemas change infrequently, cache them locally
2. **Check version**: Always check `metadata.json` for schema version
3. **Handle missing fields**: Use optional chaining (`?.`) for nullable fields
4. **Validate in development**: Use schema validation during development
5. **Type safety**: Use TypeScript with generated types from schemas

### For Backend Developers

1. **Validate before export**: Always validate JSON against schemas before publishing
2. **Version schemas**: Update schema version when making changes
3. **Document changes**: Update schema descriptions when adding fields
4. **Test compatibility**: Ensure schema changes don't break existing consumers

## Related Documentation

- **[JSON Export Schema](JSON_Export_Schema.md)**: Complete API documentation
- **[Metric Definitions](Metric_Definitions.md)**: Business definitions for all metrics
- **[Version Compatibility](Version_Compatibility.md)**: Schema versioning strategy

## Support

For questions about schemas:
1. Check this documentation
2. Review schema files in `OSM-Notes-Data/schemas/`
3. Check `metadata.json` for version information
4. Create an issue in [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics/issues)



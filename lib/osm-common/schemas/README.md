# JSON Schemas for OSM Notes Analytics

This directory contains JSON Schema definitions for validating exported JSON files.

## Schema Files

- **metadata.schema.json**: Metadata file structure with version information
- **user-profile.schema.json**: Individual user profile structure
- **country-profile.schema.json**: Individual country profile structure
- **user-index.schema.json**: User index array structure
- **country-index.schema.json**: Country index array structure
- **global-stats.schema.json**: Global statistics structure

## Version Compatibility

The JSON export system uses semantic versioning (MAJOR.MINOR.PATCH) to ensure compatibility:

- **MAJOR**: Breaking changes that require viewer updates
- **MINOR**: New features added (backward compatible)
- **PATCH**: Bug fixes and minor adjustments

## Usage

Schemas are validated using `ajv` (JSON Schema validator) during the export
process. See `bin/dwh/exportDatamartsToJSON.sh` for implementation details.

## Viewer Compatibility Check

The web viewer should check the `version` field in `metadata.json` before
consuming data to ensure compatibility. See `docs/VERSION_COMPATIBILITY.md` for
implementation guidance.

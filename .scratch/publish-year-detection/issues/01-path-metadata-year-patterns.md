# Issue 01: Soporte de patrones de año y desambiguación en PathMetadataParser

Status: resolved

## Description

Implementar en `PathMetadataParser` el soporte para detectar años entre llaves `{1999}`, con etiquetas `(Year 1999)` / `(Año 1999)`, con delimitadores `_1999_` / `.1999.` y prefijos. Sanitizar los títulos limpiando estos delimitadores y añadir detección de múltiples años para la desambiguación interactiva.

## Tasks

- [ ] Agregar expresiones regulares para los nuevos formatos en `publishYearFromPath`.
- [ ] Implementar la sanitización completa en `stripPublishYearFromTitle`.
- [ ] Crear método `hasMultiplePublishYearsInPath` para detectar múltiples candidatos.
- [ ] Añadir pruebas TDD exhaustivas en `test/services/path_metadata_parser_test.dart`.

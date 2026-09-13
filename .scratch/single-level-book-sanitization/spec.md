# Spec: Clasificación Única de Libros y Sanitización Extendida de Narradores

Status: ready-for-agent

## Problem Statement

Actualmente, cuando un libro o carpeta se encuentra en un nivel único (ej. `2017 - Artemis (Sci-Fi)`), el parser asigna erróneamente el nombre de la carpeta a la saga/universo, generando datos duplicados visualmente. Asimismo, patrones de narrador sin paréntesis (ej. `Read by Bob Askey` o `- Read by Bob Askey`) no son limpiados adecuadamente del título del libro.

## Solution

1. **Jerarquía Única**: Cuando un libro o carpeta reside en un único nivel o 2 niveles directos sin sagas reales, `universe`, `saga` y `era` serán `null`. El libro pertenecerá directamente a su Autor (o "Unknown" si no hay autor).
2. **Sanitización Extendida**: Extender la detección y sanitización de narradores para eliminar patrones como `Read by Bob Askey` y `- Read by Bob Askey` con o sin paréntesis, garantizando que el título contenga únicamente el nombre del libro.

## User Stories

1. Como oyente de audiolibros, quiero que un libro en una carpeta individual no cree universos ni sagas duplicados con el nombre del propio libro.
2. Como oyente de audiolibros, quiero que el título del libro en la lista elimine etiquetas de narrador como `(Read by Bob Askey)` o `Read by Bob Askey`, dejando solo el nombre real del libro.

## Implementation Decisions

- Modificar `PathMetadataParser` y `AudiobookScanner.parseDirPath` para asignar `universe = null` y `saga = null` en estructuras de 1 y 2 niveles.
- Ampliar la expresión regular de narrador `_narratorParen` para capturar prefijos opcionales como `-` y variaciones sin paréntesis.

## Testing Decisions

- **Costura Principal**: `PathMetadataParser.parsePath` y `AudiobookScanner.parseDirPath`.
- **Verificación**: Comprobar que carpetas únicas devuelven sagas nulas y títulos 100% limpios sin etiquetas de narrador.

## Out of Scope

- Cambios en el motor de renderizado de la UI (la lógica se maneja a nivel del dominio de parsing).

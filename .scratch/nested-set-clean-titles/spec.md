# Spec: Limpieza de Títulos sin Prefijos y Categorización por Nested Set

Status: ready-for-agent

## Problem Statement

Actualmente los títulos de los libros pueden conservar prefijos de orden/secuencia (ej. `01 - El Nombre del Viento`), y la clase de metadatos de rutas (`DirPathMetadata`) incluye campos como `universe`, `saga` y `era` que introducen duplicación redundante y dificultan la gestión unificada de categorías.

## Solution

1. Garantizar que todos los prefijos de orden/secuencia sean removidos de los títulos devueltos en las listas.
2. Simplificar `DirPathMetadata` eliminando `universe`, `saga` y `era`, de modo que toda la jerarquía de categorización sea gestionada exclusivamente por el modelo de categorías anidadas (*nested set*) a través del `category_id`.
3. Preservar únicamente los clasificadores internos del libro (como partes o CDs).

## User Stories

1. Como oyente de audiolibros, quiero ver títulos limpios sin prefijos numéricos como "01 -" en la lista de libros, para disfrutar de una interfaz clara.
2. Como desarrollador, quiero que la jerarquía de la biblioteca dependa exclusivamente de `category_id` y el *nested set*, evitando redundancias como universos y sagas en los metadatos de la ruta.

## Implementation Decisions

- **Simplificación de Metadatos**: `DirPathMetadata` conservará sólo `author`, `bookTitle`, `publishYear`, `narrator` y `readingOrderKey`.
- **Limpieza de Prefijos**: `stripOrderPrefix` se ejecutará en los títulos para eliminar patrones como `01 - `, `01. `, `1 - `, etc.

## Testing Decisions

- **Costura Única**: `PathMetadataParser` (a través de `parsePath`).
- **Pruebas de Comportamiento**: Verificación de que `parsePath` devuelve títulos limpios sin prefijos y sin campos redundantes de saga/universo.

## Out of Scope

- Cambios visuales en pantallas fuera de los modelos y parsers de metadatos.

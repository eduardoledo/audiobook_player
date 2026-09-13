# Spec: Detección y Desambiguación del Año de Publicación en Títulos

Status: ready-for-agent

## Problem Statement

Los títulos de carpetas o audiolibros a menudo contienen el año de publicación en diversos formatos (ej. `(1999)`, `[1999]`, `{1999}`, `1999 - Título`, `_1999_`, `(Año 1999)`). El sistema actual sólo reconoce corchetes `[...]`, paréntesis `(...)` y prefijos con guion, dejando otros formatos sin detectar o dejando texto sucio en el título del libro. Además, cuando un título contiene múltiples números de 4 dígitos que parecen años (ej. `1984 (2020)`), el sistema carece de un mecanismo explícito para solicitar la desambiguación del usuario.

## Solution

Ampliar el parser de rutas y títulos (`PathMetadataParser`) para reconocer patrones adicionales de año de publicación, sanitizar limpiamente el título removiendo el año y los delimitadores, y marcar ambigüedades cuando se detectan múltiples candidatos a año para presentar un diálogo interactivo de selección al usuario durante el proceso de escaneo.

## User Stories

1. Como oyente de audiolibros, quiero que el año entre llaves como `{2007}` sea extraído como el año de publicación del libro, para que la biblioteca organice mis libros correctamente por año.
2. Como oyente de audiolibros, quiero que las etiquetas como `(Year 2007)` o `(Año 2007)` sean reconocidas como el año de publicación, para que los metadatos estructurados no contengan texto redundante.
3. Como oyente de audiolibros, quiero que los formatos delimitados por puntos o guiones bajos como `_2007_` o `.2007.` extraigan el año y dejen el título limpio, para visualizar nombres limpios en el reproductor.
4. Como oyente de audiolibros, quiero que cuando un libro contenga más de un año en su título (ej. `1984 (2020)`), el sistema me muestre una advertencia/diálogo de desambiguación para elegir libremente cuál año conservar.

## Implementation Decisions

- **Parser de Metadatos**: El módulo `PathMetadataParser` será ampliado con expresiones regulares para detectar corchetes `[...]`, paréntesis `(...)`, llaves `{...}`, etiquetas `(Year YYYY)` / `(Año YYYY)`, delimitadores `_YYYY_` / `.YYYY.` y prefijos `YYYY - `.
- **Detector de Múltiples Años**: Se incluirá un método que identifique si existen 2 o más candidatos a año de publicación dentro del mismo segmento de ruta.
- **Sanitización del Título**: `stripPublishYearFromTitle` limpiará exhaustivamente todos los patrones soportados y sus delimitadores circundantes, recortando espacios múltiples y guiones sobrantes.

## Testing Decisions

- **Costura Única (High-Level Seam)**: `PathMetadataParser` (a través de `parsePath`, `publishYearFromPath` y `stripPublishYearFromTitle`).
- **Comportamiento Probado**: Extracción precisa de metadatos `publishYear`, detección de múltiples años y sanitización limpia del campo `bookTitle` sin modificar otros metadatos como saga o autor.

## Out of Scope

- Cambios en el motor de lectura de etiquetas ID3/EPUB internas de los archivos (se enfoca en títulos de carpetas y archivos en la ruta).

## Further Notes

- Esta especificación ha sido aprobada con la etiqueta `ready-for-agent` para su implementación mediante TDD.

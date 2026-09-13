# 02: Eliminación de sagas duplicadas en libros de 1-2 niveles

**What to build:** Evitar que el título de un libro en una carpeta única de 1 o 2 niveles sea asignado como `universe` o `saga`, dejándolo únicamente bajo el `author` y con categorización vacía (`null`).

**Blocked by:** 01: Sanitización extendida de narradores sin paréntesis en títulos.

**Status:** resolved

- [ ] Ajustar la lógica de asignación de jerarquía en `PathMetadataParser` y `AudiobookScanner.parseDirPath`.
- [ ] Garantizar que libros en 1 o 2 niveles tengan `saga = null` y `universe = null`.
- [ ] Añadir pruebas unitarias TDD verificando estructuras de carpetas de 1 nivel.

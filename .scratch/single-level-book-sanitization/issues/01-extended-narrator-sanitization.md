# 01: Sanitización extendida de narradores sin paréntesis en títulos

**What to build:** Ampliar la expresión regular y limpieza de narradores en `PathMetadataParser` para remover patrones como `Read by Bob Askey` y `- Read by Bob Askey` (con o sin paréntesis) de los títulos de libros.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [ ] Ampliar expresiones regulares de narrador para detectar formatos sin paréntesis.
- [ ] Asegurar que `stripNarratorFromTitle` limpie completamente estas cadenas del título.
- [ ] Añadir pruebas unitarias TDD en `test/services/path_metadata_parser_test.dart`.

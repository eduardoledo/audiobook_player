# Issue 01: Remover prefijos en títulos y simplificar DirPathMetadata

Status: resolved

## Description

Remover prefijos numéricos de orden en los títulos de libros devueltos por `PathMetadataParser` y simplificar la clase `DirPathMetadata` eliminando `universe`, `saga` y `era`, para que toda la categorización recaiga en el modelo de *nested set*.

## Tasks

- [ ] Eliminar campos `universe`, `saga` y `era` de `DirPathMetadata`.
- [ ] Asegurar que `parsePath` remueva prefijos de orden en `bookTitle`.
- [ ] Actualizar `test/services/path_metadata_parser_test.dart` adaptando los tests a la estructura simplificada.

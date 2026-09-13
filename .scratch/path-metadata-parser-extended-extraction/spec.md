# Spec: Extended Path Metadata Extraction in PathMetadataParser

Status: ready-for-agent

## Problem Statement

Path token parsing, publication year extraction, narrator recognition, and sequence ordering logic were partially duplicated across `AudiobookScanner` and `PathMetadataParser`, leaving title strings with raw bracketed artifacts (e.g. `The Final Empire (2006) (read by Michael Kramer)`).

## Solution

Consolidate all path-based regex extractors into `PathMetadataParser`. `PathMetadataParser.parsePath` will extract `publishYear`, `narrator`, `seriesSequence`, `universeOrder`, and `readingOrderKey` while returning clean `bookTitle` and `saga` strings. `AudiobookScanner` will delegate all path metadata extractions directly to `PathMetadataParser`.

## User Stories

1. As a listener, I want publication years in folder names (e.g. `[2006]`) to be extracted into the book's metadata without cluttering the book title display.
2. As a listener, I want parenthetical narrator credits (e.g. `(read by Frank Muller)`) to populate the narrator field and be cleanly removed from the book title.
3. As a library manager, I want sequence numbers across Universe, Saga, Era, and Book levels to produce a `readingOrderKey` for accurate library sorting.

## Implementation Decisions

- **Extractor Consolidation**: Move `publishYearFromPath`, `narratorFromPath`, `orderTokenFromSegment`, `stripPublishYearFromTitle`, and `stripNarratorFromTitle` to `PathMetadataParser`.
- **Title String Sanitization**: `parsePath` automatically strips year and narrator tokens from `bookTitle` and `saga`.
- **Full Delegation**: `AudiobookScanner` delegates path parsing and string sanitization directly to `PathMetadataParser`.
- **ADR Alignment**: Complies with ADR 0006 and ADR 0016.

## Testing Decisions

- **Unit Testing at Service Seam**: Test `PathMetadataParser.parsePath` against various folder path patterns (with years, narrators, and sequence numbers) in `test/services/path_metadata_parser_test.dart`.
- **Prior Art**: Follows patterns established in `test/services/path_metadata_parser_test.dart`.

## Out of Scope

- Fetching missing publication years or narrators from external online databases.

## Further Notes

- Guided by ADR 0016 ("Extended Path Metadata Extraction in PathMetadataParser").
- Enforces Zero Current Problems Quality Invariant (ADR 0014).

# 16. Extended Path Metadata Extraction in PathMetadataParser

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

`AudiobookScanner` contained static helper regexes for extracting publication years (`[1976]`, `(2014)`), narrators (`(read by Frank Muller)`), and sequence order prefixes (`01 - Title`), causing code duplication and partial parsing logic outside of `PathMetadataParser`.

## Decision Outcome

Chosen option:
1. **Consolidated Extraction in PathMetadataParser**: Move all regex extractors (`publishYearFromPath`, `narratorFromPath`, `orderTokenFromSegment`, `stripPublishYearFromTitle`, `stripNarratorFromTitle`) to `PathMetadataParser`.
2. **Title & Saga String Cleaning**: Automatically strip publication year and narrator tokens from `bookTitle` and `saga` strings to prevent redundant title artifacts in UI displays.
3. **Hierarchical Reading Order Keying**: Construct a multi-level `readingOrderKey` (e.g. `[2.0, 1.0]`) to ensure accurate sorting across Author $\rightarrow$ Universe $\rightarrow$ Saga $\rightarrow$ Era $\rightarrow$ Book.
4. **Full Scanner Seam Delegation**: `AudiobookScanner` delegates all path metadata extractions directly to `PathMetadataParser`.

### Positive Consequences

* Single pure domain authority for all path-based metadata parsing.
* Eliminates redundant title strings in player and library views.
* Enables 100% IO-free unit testing for year, narrator, and sequence extraction.

# 20. Flutter Clean Architecture and Code Standards

* Status: accepted
* Date: 2026-09-13

## Context and Problem Statement

The codebase accumulated large monolithic files (`HomeScreen` over 1,600 lines, `HomeCubit` over 800 lines, `AudiobookScanner` over 57 KB) coupled with direct service locator calls (`getIt`) inside UI widgets and cubits. The static analysis configuration was limited to default `flutter_lints`, without strict type safety or unawaited asynchronous call checks.

## Decision Outcome

Chosen option:
1. **Hybrid Feature-First & Layer-First Layout**: Code is organized into `lib/core/` for cross-cutting infrastructure (theme, localization, base SQLite, utilities) and `lib/features/<feature>/` (`player`, `library`, `scanner`, `ebook_reader`), each containing `domain/`, `data/`, and `presentation/` sublayers.
2. **Domain State Management Decomposition**: Split `HomeCubit` into specialized, independent Cubits (`LibraryCubit`, `ScannerCubit`, `MetadataCubit`, `PlaylistCubit`, `PlayerCubit`).
3. **Repository Pattern and Constructor Injection**: Domain layers define abstract repository contracts. Data layers implement them against SQLite, storage, and platform channels. Cubits receive repositories via constructor injection. Presentation widgets consume Cubits via `context.read` and `BlocBuilder`, eliminating direct calls to `getIt` within UI widgets.
4. **Calibrated Strict Analysis**: Extend `analysis_options.yaml` with language mode strictness (`strict-casts`, `strict-inference`, `strict-raw-types`) and essential linter rules (`unawaited_futures`, `avoid_print`, `prefer_const_constructors`, `prefer_final_locals`, `always_declare_return_types`, `cancel_subscriptions`, `close_sinks`).
5. **Incremental Migration**: Migrate feature by feature, verifying `flutter analyze lib/` and all test suites remain 100% clean (0 errors, 0 warnings) at each milestone.

### Positive Consequences

* Clear separation between pure domain rules, persistence/hardware integrations, and Flutter UI widgets.
* Full testability via mock repositories without relying on device storage or platform channels.
* Localized UI re-renders preventing whole-screen rebuilds on background scanning or metadata updates.

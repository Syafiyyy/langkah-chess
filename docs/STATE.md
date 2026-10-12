# STATE

_Single source of project state. Claude Code updates this at the end of every task._

## Current phase
F0 — Foundation: done (2026-10-12). Next: F1 — Core offline.

## Done
- 2026-10-12: Planning. v1 analysed, stack researched, blueprint independently reviewed, ADR-0001..0007 written, roadmap set. Kickoff docs created.
- 2026-10-12: F0 Foundation.
  - Tooling verified: dart-flutter plugin (Dart MCP), Context7 MCP, superpowers, gh (Syafiyyy). Skills karpathy-rules + frontend-design copied unchanged from DriveCover.
  - Flutter project created (`com.syafiyyy.langkah`, Android only, Kotlin DSL, one gradle setup). App name constant: `lib/app/app_info.dart` (+ Android manifest label).
  - Structure per ADR-0006: `app/` (app, router, theme tokens), `core/engine/`, `features/play_ai/presentation/`.
  - EngineService (`lib/core/engine/`): one lazy engine via a keep-alive Riverpod Provider, stdout listened once, output routed to the current request, `stop` before each new search, commands serialised, FEN validated with dartchess before it reaches the engine, dispose on app detach and on debug hot reload (engine restarts lazily).
  - Board smoke screen: chessground board from a dartchess `Position`, both sides move (legality from dartchess), "Engine move" and "New game" buttons.
  - Tests: 17 green (UCI parser, EngineService with a fake engine, board screen widget test). Strict lints, `flutter analyze` clean.
  - CI: `.github/workflows/ci.yml` (Flutter 3.47.7: pub get, analyze, test, debug split APK build). LICENSE GPL-3.0, README stub.
  - Verified on the emulator (Pixel 8a API 35, x86_64, release build): user moves and engine moves both work.

## Measurements (F0)
| What | Value |
|---|---|
| First bestmove incl. engine start-up (movetime 500 ms, emulator x86_64, release) | 1139 ms |
| Later bestmoves (movetime 500 ms) | ~502 ms |
| Release APK arm64-v8a | 34.9 MB |
| Release APK armeabi-v7a / x86_64 | 31.1 MB / 36.5 MB |

## Package versions (latest on pub.dev, 2026-10-12)
chessground 10.3.0, dartchess 0.14.0, multistockfish 0.6.1 (Stockfish 19, light flavor), flutter_riverpod 3.4.3, go_router 18.0.2, flutter_animate 4.5.2; dev: flutter_lints 6.0.0, mocktail 1.0.5.

## Decisions (F0)
- Engine access goes through a small `UciEngine` interface (real: `StockfishUciEngine`; tests: `FakeUciEngine`). Keeps EngineService testable without native code.
- EngineService starts the engine lazily, so disposing it (detach, hot reload) is always safe; the next request restarts it.
- A superseded search completes with the move found when it was stopped (not an error).
- UCI scores are kept from the side-to-move's point of view; convert to White's view in the UI/review code.
- Board size = shortest side of the free area, so it fits portrait and landscape.

## Known issues / open questions
- multistockfish 0.6.1 always bundles all three engine binaries (light, chess, variant), about 3.4 MB of unused native code per ABI. No pub.dev option to drop them; revisit if the APK size matters (F4).
- chessground ships all its board and piece images (~1,900 files). Most of the APK beyond Flutter itself is these assets. Could be trimmed later if needed.
- Engine timings were measured on an x86_64 emulator, not a real arm64 phone. Re-measure on a phone at Gate 1.
- The first engine reply includes engine start-up (~0.6 s). F1 can warm the engine when a game screen opens.
- The scaffold commit already contains the dependency lines in pubspec (they were added before `git init`).
- App name "Langkah" is a working title (change `kAppName` + Android label).
- Context7 and Dart MCP tools did not load in the F0 session (they were added mid-session); APIs were checked from the pub.dev API and package sources instead. A fresh Claude Code session should have them.

## Next
- F1 — Core offline: play vs engine with Elo levels and colour choice, clock + increment, result rules (with tests), move list, takeback, flip, promotion, local history + PGN.

## Environment
- Flutter 3.47.7 stable (D:\dev\flutter), Dart 3.13.5, JDK 21 (Android Studio jbr), Android SDK 36, licenses accepted (2026-10-12)
- Emulator: Pixel_8a_API_35 (system image android-35 google_apis_playstore x86_64 installed 2026-10-12). Other AVDs use the same image.
- GitHub: Syafiyyy/langkah-chess (public)
- Supabase project: not created yet (F2)

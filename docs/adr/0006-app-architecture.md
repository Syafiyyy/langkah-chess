# ADR-0006: Riverpod, go_router, feature-first structure
Status: Accepted (2026-10-12)

## Decision
- State: Riverpod (current major; check API with Context7). Routing: go_router.
- Structure:
  ```
  lib/
    app/            app.dart, router.dart, theme/ (design tokens)
    core/           engine/ (EngineService), chess/ (game rules helpers), utils/
    features/
      play_ai/      data/ domain/ presentation/
      review/
      online/
      history/
      auth/
      profile/
    shared/widgets/
  ```
- Game logic lives in plain Dart classes (testable without Flutter); widgets only render and dispatch.

## Consequences
+ Small files, testable logic, no god providers.
- Some boilerplate; keep it minimal (no codegen unless it clearly saves time).

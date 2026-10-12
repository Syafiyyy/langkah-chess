# Prompt — Rename the app from "Langkah" to "Skak" (NEW Claude Code session, BEFORE F2a)

Decision (Adaam, 2026-10-13): the app is now called **Skak** (Malay/Indonesian chess term for "check"). Public tagline: "Skak — chess with on-device Stockfish". Do this as one clean rename before any online/backend work, so nothing in Supabase or deep links ever uses the old name.

Rename everything that is product-facing or identifying:
1. App name constant (`kAppName`) → "Skak"; Android label; wordmark text on every screen; splash + launcher icon unchanged (gold rhombus mark), regenerate if the name appears anywhere in assets.
2. Android applicationId / namespace `com.syafiyyy.langkah` → `com.syafiyyy.skak` (no release has shipped, so this is safe). Make sure the old app on the emulator is uninstalled before testing and that local data migration isn't needed (it's dev data).
3. Dart package name `langkah` → `skak` in pubspec.yaml and every `package:langkah/...` import (scripted replace, then `flutter analyze` + all tests).
4. Docs: README, CLAUDE.md, STATE.md, ROADMAP.md, ADRs (add a one-line note in ADR-0001: "Renamed Langkah → Skak on 2026-10-13"), prompts, screenshots captions. Keep historical STATE entries readable (say "formerly Langkah" once).
5. Skill folder `.claude/skills/langkah-design` → `.claude/skills/skak-design` (update its name/description and every reference in CLAUDE.md/prompts).
6. GitHub: rename the repo `Syafiyyy/langkah-chess` → `Syafiyyy/skak-chess` with `gh repo rename skak-chess`, update the git remote, update the repo description ("Skak — chess app with on-device Stockfish 19, human-like bots and game review. Flutter.") and topics (flutter, chess, stockfish, dart, riverpod). GitHub redirects old links automatically.
7. Do NOT rename the local folder `D:\Projects\langkah-chess` (Claude Code's local-scope plugins and MCP config are tied to this path). Mention in STATE that the folder keeps its old name on purpose.
8. Deep-link scheme planned for F2 is `skak://` (already updated in docs/prompts/F2*.md).

Finish: `flutter analyze` clean, all tests + goldens green (update goldens if the wordmark changed), retake `docs/screenshots/`, build a release APK to confirm the new id/label, commit ("chore: rename Langkah → Skak") in sensible steps, push, CI green. Report what changed and anything I must do by hand.

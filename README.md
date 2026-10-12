# Langkah

A chess app for Android: play the engine at your level, review your games move by move, and play friends online.

**Status:** in development.

## Stack
- Flutter (Android first), Riverpod, go_router
- [chessground](https://pub.dev/packages/chessground) board and [dartchess](https://pub.dev/packages/dartchess) rules, both from Lichess
- Stockfish 19 on device through [multistockfish](https://pub.dev/packages/multistockfish), light flavor
- Supabase for accounts and online play (planned)

Design decisions are recorded in [docs/adr](docs/adr). The plan is in [docs/ROADMAP.md](docs/ROADMAP.md).

## Build
```sh
flutter pub get
flutter test
flutter build apk --split-per-abi --release
```

## History
Langkah is a full rebuild of [v1, uptm-chess-game](https://github.com/Syafiyyy/uptm-chess-game).

## License
GPL-3.0. See [LICENSE](LICENSE).

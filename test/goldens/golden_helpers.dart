import 'dart:convert';

import 'package:chessground/chessground.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads every font in FontManifest.json (Sora, Plus Jakarta Sans, DM Mono,
/// Material icons) so goldens show real text instead of test boxes.
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<Object?>;
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    final family = entry['family']! as String;
    final loader = FontLoader(family.split('/').last);
    for (final font
        in (entry['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
  }
}

/// Loads the piece sprites into chessground's image cache (real I/O, so it
/// runs outside the fake-async zone). Call before pumping a board.
Future<void> loadPieces(WidgetTester tester) async {
  await tester.runAsync(
    () => ChessgroundImages.instance.loadAll(
      PieceSet.cburnett.assets,
      devicePixelRatio: 1,
    ),
  );
}

/// Golden comparator that accepts up to [tolerance] (fraction of pixels)
/// difference, because text anti-aliasing differs slightly between the
/// Windows machine that records goldens and Linux CI.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.03});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

/// Uses [TolerantGoldenComparator] for the golden test file at [testFile].
void useTolerantGoldens(String testFile) {
  goldenFileComparator = TolerantGoldenComparator(Uri.file(testFile));
}

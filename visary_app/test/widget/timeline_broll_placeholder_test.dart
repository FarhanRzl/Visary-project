import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:visary/models/models.dart';
import 'package:visary/widgets/timeline.dart';

/// Widget test: B-roll placeholder rendering di NeoBrutalTimeline (PRD-SPRINT-05 §4 Test 5.2).
/// Pump timeline dengan state clip yang memiliki rekomendasi B-roll.
/// Pastikan UI dashed-box placeholder muncul di koordinat waktu yang tepat.
void main() {
  void setDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('Timeline merender B-roll placeholder untuk rekomendasi aktif',
      (tester) async {
    setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final broll = [
      const BrollRecommendation(
        startSec: 10.0,
        endSec: 18.0,
        keywordPrompt: 'Cinematic coffee pouring',
        reason: 'Visual statis 8s, narasi aktif',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 200,
          child: NeoBrutalTimeline(
            durationSec: 60,
            playhead: 15,
            clipStart: 0,
            clipEnd: 60,
            brollRecommendations: broll,
            onPlayheadChanged: (_) {},
            onTrimChanged: (_, __) {},
          ),
        ),
      ),
    ));

    // Placeholder label harus muncul.
    expect(find.textContaining('B-ROLL'), findsOneWidget);
  });

  testWidgets('Timeline merender multiple B-roll placeholder',
      (tester) async {
    setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    final brolls = [
      const BrollRecommendation(
        startSec: 5.0,
        endSec: 12.0,
        keywordPrompt: 'Close-up product shot',
        reason: 'Gap 1',
      ),
      const BrollRecommendation(
        startSec: 25.0,
        endSec: 35.0,
        keywordPrompt: 'Wide establishing shot',
        reason: 'Gap 2',
        overlayFilePath: '/tmp/broll.mp4',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 200,
          child: NeoBrutalTimeline(
            durationSec: 60,
            playhead: 0,
            clipStart: 0,
            clipEnd: 60,
            brollRecommendations: brolls,
            onPlayheadChanged: (_) {},
            onTrimChanged: (_, __) {},
          ),
        ),
      ),
    ));

    // Dua placeholder: 1 tanpa overlay (B-ROLL?), 1 dengan overlay (B-ROLL ✓).
    expect(find.textContaining('B-ROLL'), findsNWidgets(2));
  });

  testWidgets('Timeline tanpa B-roll recommendation tidak merender placeholder',
      (tester) async {
    setDesktopSurface(tester);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 200,
          child: NeoBrutalTimeline(
            durationSec: 60,
            playhead: 0,
            clipStart: 0,
            clipEnd: 60,
            brollRecommendations: const [],
            onPlayheadChanged: (_) {},
            onTrimChanged: (_, __) {},
          ),
        ),
      ),
    ));

    expect(find.textContaining('B-ROLL'), findsNothing);
  });
}

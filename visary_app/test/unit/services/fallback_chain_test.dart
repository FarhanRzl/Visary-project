import 'package:flutter_test/flutter_test.dart';

import 'package:visary/models/models.dart';
import 'package:visary/services/resequence_service.dart';

/// PRD-SPRINT-16 §4 — Test 16.4: Fallback chain.
///
/// Semantic segment gagal → fallback detectCutPoints → segments valid.
/// detectCutPoints gagal → fallback sequential 3s → segments valid.
/// Match gagal → fallback sequential matchOrder.
void main() {
  const r = Resequencer();

  group('fallback: semantic segment gagal → detectCutPoints → segments', () {
    test('detectCutPoints produces valid cutPoints → cutPointsToSegments valid', () {
      final words = [
        WordToken(word: 'Hello', start: 0.0, end: 0.5),
        WordToken(word: 'world', start: 0.5, end: 1.0),
        WordToken(word: 'today', start: 2.0, end: 2.5), // pause > 200ms
        WordToken(word: 'is', start: 2.5, end: 2.8),
        WordToken(word: 'nice', start: 2.8, end: 3.0),
      ];

      final cutPoints = r.detectCutPoints(words);
      expect(cutPoints.length, greaterThan(1));

      final segments = r.cutPointsToSegments(cutPoints, words);
      expect(segments, isNotEmpty);
      expect(segments.first.startSec, 0.0);
      expect(segments.last.endSec, 3.0);

      // All segments should have valid word indices.
      for (final s in segments) {
        expect(s.startWord, greaterThanOrEqualTo(0));
        expect(s.endWord, greaterThanOrEqualTo(s.startWord));
        expect(s.isValid, isTrue);
      }
    });
  });

  group('fallback: detectCutPoints no pause → group 5 kata', () {
    test('no pauses → fallback grouping produces segments', () {
      // All words back-to-back, no pauses.
      final words = List.generate(10, (i) => WordToken(
        word: 'word$i',
        start: i * 0.3,
        end: i * 0.3 + 0.3,
      ));

      final cutPoints = r.detectCutPoints(words);
      // No pauses → fallback group every 5 words → 2 groups + end point = 3 points.
      expect(cutPoints.length, greaterThanOrEqualTo(2));

      final segments = r.cutPointsToSegments(cutPoints, words);
      expect(segments, isNotEmpty);
    });
  });

  group('fallback: match gagal → sequential matchOrder', () {
    test('sequential matchOrder = [0, 1, 2, ...]', () {
      final segments = r.sequentialSegments(3, 9.0);
      expect(segments.length, 3);

      // Simulate fallback: matchOrder = List.generate(segments.length, (i) => i).
      final fallbackMatchOrder =
          List.generate(segments.length, (i) => i);

      expect(fallbackMatchOrder, [0, 1, 2]);

      final parts = r.buildPartsWithSegments(
        segments: segments,
        videoDuration: 9.0,
        fallbackDuration: 3.0,
        matchOrder: fallbackMatchOrder,
      );

      expect(parts.length, 3);
      // Sequential: seg 0 → video 0, seg 1 → video 1, seg 2 → video 2.
      expect(parts[0].start, 0.0);
      expect(parts[1].start, 3.0);
      expect(parts[2].start, 6.0);
    });
  });

  group('fallback: no transcript → visual-only sequential segments', () {
    test('sequentialSegments produces N segments = shotCount', () {
      final shotCount = 4;
      final videoDuration = 20.0;
      final segments = r.sequentialSegments(shotCount, videoDuration);

      expect(segments.length, shotCount);
      // Each segment should cover equal video duration.
      final segDur = videoDuration / shotCount; // 5s each
      for (var i = 0; i < segments.length; i++) {
        expect(segments[i].startSec, closeTo(i * segDur, 0.01));
        expect(segments[i].endSec, closeTo((i + 1) * segDur, 0.01));
      }
    });
  });
}

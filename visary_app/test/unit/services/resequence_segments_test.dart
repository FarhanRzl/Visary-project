import 'package:flutter_test/flutter_test.dart';

import 'package:visary/models/models.dart';
import 'package:visary/services/resequence_service.dart';

/// PRD-SPRINT-16 §4 — Test 16.2: Resequencer buildPartsWithSegments.
///
/// Test: N segments + matchOrder → ClipParts sesuai.
/// Segments kosong → fallback. Speed-adjust clamp 0.25–4x.
void main() {
  const r = Resequencer();

  List<TranscriptSegment> _makeSegments(int count, double durationEach) {
    return List.generate(count, (i) => TranscriptSegment(
      startWord: i * 5,
      endWord: (i + 1) * 5 - 1,
      topic: 'seg ${i + 1}',
      startSec: i * durationEach,
      endSec: (i + 1) * durationEach,
    ));
  }

  group('buildPartsWithSegments', () {
    test('N segments + matchOrder → ClipParts sesuai', () {
      final segments = _makeSegments(3, 2.0); // 3 segs, 2s each
      final parts = r.buildPartsWithSegments(
        segments: segments,
        videoDuration: 30.0, // 3 video segs × 10s each
        fallbackDuration: 5.0,
        matchOrder: [2, 0, 1],
      );

      expect(parts.length, 3);
      // Video seg dur = 30/3 = 10s each.
      // Seg 0 → matchOrder[0]=2 → vStart=20, vEnd=30, speed=10/2=5→clamp 4.0
      expect(parts[0].start, 20.0);
      expect(parts[0].end, 30.0);
      expect(parts[0].speed, 4.0); // clamped from 5.0
      // Seg 1 → matchOrder[1]=0 → vStart=0, vEnd=10, speed=10/2=5→clamp 4.0
      expect(parts[1].start, 0.0);
      expect(parts[1].end, 10.0);
      expect(parts[1].speed, 4.0);
      // Seg 2 → matchOrder[2]=1 → vStart=10, vEnd=20, speed=10/2=5→clamp 4.0
      expect(parts[2].start, 10.0);
      expect(parts[2].end, 20.0);
      expect(parts[2].speed, 4.0);
    });

    test('segments kosong → fallback [ClipPart(0, fallback)]', () {
      final parts = r.buildPartsWithSegments(
        segments: [],
        videoDuration: 30.0,
        fallbackDuration: 5.0,
      );

      expect(parts.length, 1);
      expect(parts[0].start, 0.0);
      expect(parts[0].end, 5.0);
    });

    test('speed-adjust: audioDur ≠ videoSegDur → speed benar, clamp 0.25–4x', () {
      // audio 10s per seg, video 5s per seg → speed = 5/10 = 0.5
      final segments = _makeSegments(2, 10.0);
      final parts = r.buildPartsWithSegments(
        segments: segments,
        videoDuration: 10.0, // 2 segs × 5s each
        fallbackDuration: 5.0,
      );

      expect(parts.length, 2);
      expect(parts[0].speed, closeTo(0.5, 0.01));
    });

    test('speed-adjust clamp 0.25x (video very short, audio very long)', () {
      // audio 100s per seg, video 1s per seg → speed = 0.5/100 = 0.005 → clamp 0.25
      final segments = _makeSegments(2, 100.0);
      final parts = r.buildPartsWithSegments(
        segments: segments,
        videoDuration: 1.0, // 2 segs × 0.5s each
        fallbackDuration: 5.0,
      );

      expect(parts[0].speed, 0.25); // clamped
    });

    test('no matchOrder → sequential (0, 1, 2, ...)', () {
      final segments = _makeSegments(3, 2.0);
      final parts = r.buildPartsWithSegments(
        segments: segments,
        videoDuration: 30.0,
        fallbackDuration: 5.0,
      );

      expect(parts.length, 3);
      expect(parts[0].start, 0.0);  // seg 0
      expect(parts[1].start, 10.0); // seg 1
      expect(parts[2].start, 20.0); // seg 2
    });

    test('videoDuration ≤ 0 → fallback', () {
      final segments = _makeSegments(3, 2.0);
      final parts = r.buildPartsWithSegments(
        segments: segments,
        videoDuration: 0.0,
        fallbackDuration: 5.0,
      );

      expect(parts.length, 1);
      expect(parts[0].end, 5.0);
    });
  });

  group('cutPointsToSegments', () {
    test('cutPoints → segments valid', () {
      final words = [
        WordToken(word: 'a', start: 0.0, end: 0.5),
        WordToken(word: 'b', start: 0.5, end: 1.0),
        WordToken(word: 'c', start: 2.0, end: 2.5), // gap > 200ms
        WordToken(word: 'd', start: 2.5, end: 3.0),
      ];
      final cutPoints = r.detectCutPoints(words);
      final segments = r.cutPointsToSegments(cutPoints, words);

      expect(segments.length, greaterThanOrEqualTo(1));
      expect(segments.first.startSec, 0.0);
      expect(segments.last.endSec, 3.0);
    });

    test('empty cutPoints → empty segments', () {
      final segments = r.cutPointsToSegments([], []);
      expect(segments, isEmpty);
    });
  });

  group('sequentialSegments', () {
    test('N count → N sequential segments', () {
      final segments = r.sequentialSegments(4, 20.0);

      expect(segments.length, 4);
      expect(segments[0].startSec, 0.0);
      expect(segments[0].endSec, 5.0);
      expect(segments[3].startSec, 15.0);
      expect(segments[3].endSec, 20.0);
    });

    test('count ≤ 0 → empty', () {
      expect(r.sequentialSegments(0, 20.0), isEmpty);
    });
  });
}

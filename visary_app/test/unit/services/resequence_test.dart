import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/local_analyzer.dart';
import 'package:visary/services/resequence_service.dart';

/// PRD-SPRINT-13 §4 — Test 13.1: Resequencer algorithm.
void main() {
  const r = Resequencer();

  group('detectCutPoints', () {
    test('pause ≥ 200ms → cut point', () {
      final words = [
        const WordToken(word: 'hello', start: 0.0, end: 0.5),
        const WordToken(word: 'world', start: 1.0, end: 1.5), // 500ms gap
        const WordToken(word: 'test', start: 1.6, end: 2.0), // 100ms gap (no cut)
      ];
      final points = r.detectCutPoints(words);
      expect(points.first, 0.0); // start
      expect(points, contains(1.0)); // cut at 'world'
      expect(points.last, 2.0); // end
      expect(points.length, 3); // start + 1 cut + end
    });

    test('tanpa pause → fallback group 5 kata', () {
      final words = List.generate(15, (i) {
        final start = i * 0.3;
        return WordToken(word: 'w$i', start: start, end: start + 0.25);
      });
      final points = r.detectCutPoints(words);
      // Group 5: cut at word 0, 5, 10, then end at word 14
      expect(points, contains(words[0].start));
      expect(points, contains(words[5].start));
      expect(points, contains(words[10].start));
      expect(points.last, words.last.end);
    });

    test('empty words → empty list', () {
      expect(r.detectCutPoints([]), isEmpty);
    });

    test('single word → start + end', () {
      const words = [WordToken(word: 'hi', start: 0.0, end: 0.5)];
      final points = r.detectCutPoints(words);
      expect(points, [0.0, 0.5]);
    });
  });

  group('videoSegments', () {
    test('dari shot boundaries', () {
      final signals = VideoSignals(shots: const [0, 3, 7, 12], energy: const [], duration: 12);
      final segs = r.videoSegments(signals, 12);
      expect(segs.length, 3);
      expect(segs[0], (0, 3));
      expect(segs[1], (3, 7));
      expect(segs[2], (7, 12));
    });

    test('shots kosong → bagi 3s', () {
      final signals = VideoSignals(shots: const [0, 10], energy: const [], duration: 10);
      // Only 1 boundary pair [0, 10] → shots.length == 2, so it uses shots
      // Test with truly empty shots:
      final signals2 = VideoSignals(shots: const [0], energy: const [], duration: 9);
      final segs = r.videoSegments(signals2, 9);
      expect(segs.length, 3); // 0-3, 3-6, 6-9
      expect(segs[0], (0, 3));
      expect(segs[2], (6, 9));
    });

    test('duration 0 → single segment', () {
      final signals = VideoSignals(shots: const [0], energy: const [], duration: 0);
      final segs = r.videoSegments(signals, 0);
      expect(segs.length, 1);
      expect(segs[0], (0, 0));
    });
  });

  group('buildParts', () {
    test('audio segments → video segments (cycle)', () {
      final cutPoints = [0.0, 1.0, 2.0, 3.0]; // 3 segments of 1s each
      final videoSegs = <(double, double)>[(0, 5), (5, 10), (10, 15)];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoSegments: videoSegs,
        fallbackDuration: 10,
      );

      expect(parts.length, 3);
      // Each part takes 1s from a different video segment
      expect(parts[0].start, 0); // videoSeg[0] start
      expect(parts[0].duration, closeTo(1.0, 0.01));
      expect(parts[1].start, 5); // videoSeg[1] start
      expect(parts[1].duration, closeTo(1.0, 0.01));
      expect(parts[2].start, 10); // videoSeg[2] start
      expect(parts[2].duration, closeTo(1.0, 0.01));
    });

    test('cycle: more audio segments than video segments', () {
      final cutPoints = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]; // 5 segments
      final videoSegs = <(double, double)>[(0, 3), (3, 6)]; // only 2

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoSegments: videoSegs,
        fallbackDuration: 10,
      );

      expect(parts.length, 5);
      // Cycle: seg0, seg1, seg0, seg1, seg0
      expect(parts[0].start, 0); // videoSeg[0]
      expect(parts[1].start, 3); // videoSeg[1]
      expect(parts[2].start, 0); // videoSeg[0] again
      expect(parts[3].start, 3); // videoSeg[1] again
      expect(parts[4].start, 0); // videoSeg[0] again
    });

    test('audio segment longer than video segment → take video segment duration', () {
      final cutPoints = [0.0, 10.0]; // 10s audio segment
      final videoSegs = <(double, double)>[(0, 3)]; // 3s video segment

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoSegments: videoSegs,
        fallbackDuration: 10,
      );

      expect(parts.length, 1);
      expect(parts[0].duration, closeTo(3.0, 0.01)); // capped at video seg dur
    });

    test('empty cutPoints → fallback single part', () {
      final parts = r.buildParts(
        cutPoints: [],
        videoSegments: [(0, 10)],
        fallbackDuration: 5,
      );
      expect(parts.length, 1);
      expect(parts[0].duration, 5);
    });

    test('single cutPoint → fallback (need ≥ 2)', () {
      final parts = r.buildParts(
        cutPoints: [1.0],
        videoSegments: [(0, 10)],
        fallbackDuration: 5,
      );
      expect(parts.length, 1);
      expect(parts[0].duration, 5);
    });
  });

  group('resequence', () {
    test('transcript with words → resequenced clips', () {
      final transcript = Transcript(
        fullText: 'hello world test foo bar',
        words: const [
          WordToken(word: 'hello', start: 0.0, end: 0.5),
          WordToken(word: 'world', start: 0.6, end: 1.0),
          WordToken(word: 'test', start: 2.0, end: 2.5), // 1s pause
          WordToken(word: 'foo', start: 2.6, end: 3.0),
          WordToken(word: 'bar', start: 3.1, end: 3.5),
        ],
        provider: 'custom',
      );
      final signals = VideoSignals(shots: const [0, 5, 10], energy: const [], duration: 10);
      signals.transcript = transcript;

      final clips = [
        Clip(
          id: 'c1',
          title: 'Test',
          parts: const [ClipPart(0, 10)],
          hook: const ClipPart(0, 3),
          score: 80,
          reason: 'test',
          type: ClipType.linear,
        ),
      ];

      final newClips = r.resequence(
        clips: clips,
        signals: signals,
        videoDuration: 10,
      );

      expect(newClips.length, 1);
      expect(newClips[0].type, ClipType.resequenced);
      expect(newClips[0].parts.length, greaterThan(1));
    });

    test('transcript null → clips unchanged', () {
      final signals = VideoSignals(shots: const [0, 5], energy: const [], duration: 5);
      final clips = [
        Clip(
          id: 'c1',
          title: 'Test',
          parts: const [ClipPart(0, 5)],
          hook: const ClipPart(0, 2),
          score: 80,
          reason: 'test',
          type: ClipType.linear,
        ),
      ];

      final newClips = r.resequence(
        clips: clips,
        signals: signals,
        videoDuration: 5,
      );

      expect(newClips, same(clips)); // unchanged
    });

    test('words empty → clips unchanged', () {
      final signals = VideoSignals(shots: const [0, 5], energy: const [], duration: 5);
      signals.transcript = const Transcript(fullText: 'music only', words: [], provider: 'gemini');

      final clips = [
        Clip(
          id: 'c1',
          title: 'Test',
          parts: const [ClipPart(0, 5)],
          hook: const ClipPart(0, 2),
          score: 80,
          reason: 'test',
          type: ClipType.linear,
        ),
      ];

      final newClips = r.resequence(
        clips: clips,
        signals: signals,
        videoDuration: 5,
      );

      expect(newClips, same(clips)); // unchanged
    });
  });
}

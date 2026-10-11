import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/local_analyzer.dart';
import 'package:visary/services/resequence_service.dart';

/// PRD-SPRINT-13 §4 — Test 13.1: Resequencer algorithm (speed-adjust).
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
      expect(points.first, 0.0);
      expect(points, contains(1.0));
      expect(points.last, 2.0);
      expect(points.length, 3);
    });

    test('tanpa pause → fallback group 5 kata', () {
      final words = List.generate(15, (i) {
        final start = i * 0.3;
        return WordToken(word: 'w$i', start: start, end: start + 0.25);
      });
      final points = r.detectCutPoints(words);
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
      final signals = VideoSignals(shots: const [0], energy: const [], duration: 9);
      final segs = r.videoSegments(signals, 9);
      expect(segs.length, 3);
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

  group('buildParts (speed-adjust)', () {
    test('video lebih panjang dari audio → speed up (clamped 4x)', () {
      // Audio: 3 segments of 1s. Video: 3 segments of 5s.
      // speed = 5/1 = 5.0 → clamped to 4.0
      final cutPoints = [0.0, 1.0, 2.0, 3.0];
      final videoSegs = <(double, double)>[(0, 5), (5, 10), (10, 15)];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoSegments: videoSegs,
        fallbackDuration: 10,
      );

      expect(parts.length, 3);
      expect(parts[0].start, 0);
      expect(parts[0].end, 5); // full segment taken
      expect(parts[0].speed, 4.0); // clamped from 5.0
      expect(parts[0].duration, closeTo(1.25, 0.01)); // 5/4=1.25
      expect(parts[1].start, 5);
      expect(parts[1].speed, 4.0);
      expect(parts[2].start, 10);
      expect(parts[2].speed, 4.0);
    });

    test('video lebih pendek dari audio → slowmo (clamped 0.25x)', () {
      // Audio: 10s. Video: 2s. speed = 2/10 = 0.2 → clamped to 0.25
      final cutPoints = [0.0, 10.0];
      final videoSegs = <(double, double)>[(0, 2)];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoSegments: videoSegs,
        fallbackDuration: 10,
      );

      expect(parts.length, 1);
      expect(parts[0].start, 0);
      expect(parts[0].end, 2); // full segment
      expect(parts[0].speed, 0.25); // clamped from 0.2
      expect(parts[0].duration, closeTo(8.0, 0.01)); // 2/0.25=8
    });

    test('video dan audio sama durasi → speed 1.0', () {
      final cutPoints = [0.0, 5.0];
      final videoSegs = <(double, double)>[(0, 5)];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoSegments: videoSegs,
        fallbackDuration: 10,
      );

      expect(parts[0].speed, 1.0);
      expect(parts[0].duration, 5.0);
    });

    test('cycle: more audio segments than video segments', () {
      final cutPoints = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]; // 5 segments of 1s
      final videoSegs = <(double, double)>[(0, 3), (3, 6)]; // 2 of 3s

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoSegments: videoSegs,
        fallbackDuration: 10,
      );

      expect(parts.length, 5);
      // speed = 3/1 = 3.0
      expect(parts[0].start, 0);
      expect(parts[0].speed, 3.0);
      expect(parts[1].start, 3);
      expect(parts[2].start, 0); // cycle
      expect(parts[3].start, 3);
      expect(parts[4].start, 0);
    });

    test('slowmo 2x: speed 0.5 (within range, no clamp)', () {
      // Audio 4s, video 2s → speed = 0.5
      final cutPoints = [0.0, 4.0];
      final videoSegs = <(double, double)>[(0, 2)];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoSegments: videoSegs,
        fallbackDuration: 10,
      );

      expect(parts[0].speed, 0.5);
      expect(parts[0].duration, closeTo(4.0, 0.01)); // 2/0.5=4
    });

    test('empty cutPoints → fallback (speed 1.0)', () {
      final parts = r.buildParts(
        cutPoints: [],
        videoSegments: [(0, 10)],
        fallbackDuration: 5,
      );
      expect(parts.length, 1);
      expect(parts[0].duration, 5);
      expect(parts[0].speed, 1.0);
    });
  });

  group('resequence', () {
    test('transcript with words → resequenced clips with speed', () {
      final transcript = Transcript(
        fullText: 'hello world test foo bar',
        words: const [
          WordToken(word: 'hello', start: 0.0, end: 0.5),
          WordToken(word: 'world', start: 0.6, end: 1.0),
          WordToken(word: 'test', start: 2.0, end: 2.5),
          WordToken(word: 'foo', start: 2.6, end: 3.0),
          WordToken(word: 'bar', start: 3.1, end: 3.5),
        ],
        provider: 'custom',
      );
      final signals = VideoSignals(shots: const [0, 5, 10], energy: const [], duration: 10);
      signals.transcript = transcript;

      final clips = [
        Clip(
          id: 'c1', title: 'Test',
          parts: const [ClipPart(0, 10)],
          hook: const ClipPart(0, 3),
          score: 80, reason: 'test', type: ClipType.linear,
        ),
      ];

      final newClips = r.resequence(
        clips: clips, signals: signals, videoDuration: 10,
      );

      expect(newClips.length, 1);
      expect(newClips[0].type, ClipType.resequenced);
      expect(newClips[0].parts.length, greaterThan(1));
      expect(newClips[0].parts.any((p) => p.speed != 1.0), isTrue);
    });

    test('transcript null → clips unchanged', () {
      final signals = VideoSignals(shots: const [0, 5], energy: const [], duration: 5);
      final clips = [
        Clip(
          id: 'c1', title: 'Test',
          parts: const [ClipPart(0, 5)],
          hook: const ClipPart(0, 2),
          score: 80, reason: 'test', type: ClipType.linear,
        ),
      ];
      expect(
        r.resequence(clips: clips, signals: signals, videoDuration: 5),
        same(clips),
      );
    });

    test('words empty → clips unchanged', () {
      final signals = VideoSignals(shots: const [0, 5], energy: const [], duration: 5);
      signals.transcript = const Transcript(fullText: 'music', words: [], provider: 'gemini');
      final clips = [
        Clip(
          id: 'c1', title: 'Test',
          parts: const [ClipPart(0, 5)],
          hook: const ClipPart(0, 2),
          score: 80, reason: 'test', type: ClipType.linear,
        ),
      ];
      expect(
        r.resequence(clips: clips, signals: signals, videoDuration: 5),
        same(clips),
      );
    });
  });

  group('ClipPart speed', () {
    test('default speed = 1.0', () {
      const cp = ClipPart(0, 5);
      expect(cp.speed, 1.0);
      expect(cp.duration, 5.0);
      expect(cp.sourceDuration, 5.0);
    });

    test('slowmo: speed 0.5 → duration 2x', () {
      const cp = ClipPart(0, 5, 0.5);
      expect(cp.duration, 10.0);
      expect(cp.sourceDuration, 5.0);
    });

    test('speed up: speed 2.0 → duration 0.5x', () {
      const cp = ClipPart(0, 5, 2.0);
      expect(cp.duration, 2.5);
      expect(cp.sourceDuration, 5.0);
    });
  });
}

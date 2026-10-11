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

  group('buildParts (sequential + speed-adjust)', () {
    test('3 audio segments, video 15s → 3 sequential video segments', () {
      // Audio: 3 segments of 1s each (total 3s). Video: 15s.
      // videoSegDur = 15/3 = 5s per segment.
      // speed = 5/1 = 5.0 → clamped to 4.0
      final cutPoints = [0.0, 1.0, 2.0, 3.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 15,
        fallbackDuration: 10,
      );

      expect(parts.length, 3);
      // Sequential: 0-5, 5-10, 10-15 (no cycling)
      expect(parts[0].start, 0);
      expect(parts[0].end, 5);
      expect(parts[0].speed, 4.0); // clamped from 5.0
      expect(parts[1].start, 5);
      expect(parts[1].end, 10);
      expect(parts[2].start, 10);
      expect(parts[2].end, 15);
    });

    test('audio lebih panjang dari video → slowmo', () {
      // Audio: 10s, 1 segment. Video: 2s.
      // videoSegDur = 2/1 = 2s. speed = 2/10 = 0.2 → clamped 0.25
      final cutPoints = [0.0, 10.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 2,
        fallbackDuration: 10,
      );

      expect(parts.length, 1);
      expect(parts[0].start, 0);
      expect(parts[0].end, 2);
      expect(parts[0].speed, 0.25); // clamped from 0.2
      expect(parts[0].duration, closeTo(8.0, 0.01)); // 2/0.25=8
    });

    test('video dan audio sama durasi → speed 1.0', () {
      // 1 segment, video 5s, audio 5s. speed = 5/5 = 1.0
      final cutPoints = [0.0, 5.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 5,
        fallbackDuration: 10,
      );

      expect(parts[0].speed, 1.0);
      expect(parts[0].duration, 5.0);
    });

    test('5 audio segments, video 15s → 5 sequential segments of 3s', () {
      // videoSegDur = 15/5 = 3s. Audio segments: 1s each.
      // speed = 3/1 = 3.0
      final cutPoints = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 15,
        fallbackDuration: 10,
      );

      expect(parts.length, 5);
      // Sequential: 0-3, 3-6, 6-9, 9-12, 12-15
      expect(parts[0].start, 0);
      expect(parts[0].end, 3);
      expect(parts[0].speed, 3.0);
      expect(parts[1].start, 3);
      expect(parts[2].start, 6);
      expect(parts[3].start, 9);
      expect(parts[4].start, 12);
      expect(parts[4].end, 15);
    });

    test('slowmo 2x: speed 0.5 (within range)', () {
      // 1 segment, video 2s, audio 4s. speed = 2/4 = 0.5
      final cutPoints = [0.0, 4.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 2,
        fallbackDuration: 10,
      );

      expect(parts[0].speed, 0.5);
      expect(parts[0].duration, closeTo(4.0, 0.01)); // 2/0.5=4
    });

    test('empty cutPoints → fallback (speed 1.0)', () {
      final parts = r.buildParts(
        cutPoints: [],
        videoDuration: 10,
        fallbackDuration: 5,
      );
      expect(parts.length, 1);
      expect(parts[0].duration, 5);
      expect(parts[0].speed, 1.0);
    });

    test('videoDuration 0 → fallback', () {
      final parts = r.buildParts(
        cutPoints: [0.0, 1.0],
        videoDuration: 0,
        fallbackDuration: 5,
      );
      expect(parts.length, 1);
      expect(parts[0].duration, 5);
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

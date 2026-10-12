import 'package:flutter_test/flutter_test.dart';
import 'package:visary/models/models.dart';
import 'package:visary/services/local_analyzer.dart';
import 'package:visary/services/resequence_service.dart';

/// PRD-SPRINT-14 §4 — Test 14.4: Resequencer buildParts with matchOrder.
void main() {
  const r = Resequencer();

  group('buildParts with matchOrder', () {
    test('matchOrder mengubah urutan video segment', () {
      // 3 audio segments (1s each), video 15s → videoSegDur = 5s.
      // Sequential: [0-5, 5-10, 10-15]
      // matchOrder [2, 0, 1]: [10-15, 0-5, 5-10]
      final cutPoints = [0.0, 1.0, 2.0, 3.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 15,
        fallbackDuration: 10,
        matchOrder: [2, 0, 1],
      );

      expect(parts.length, 3);
      // matchOrder[0] = 2 → vStart=10, vEnd=15
      expect(parts[0].start, 10);
      expect(parts[0].end, 15);
      // matchOrder[1] = 0 → vStart=0, vEnd=5
      expect(parts[1].start, 0);
      expect(parts[1].end, 5);
      // matchOrder[2] = 1 → vStart=5, vEnd=10
      expect(parts[2].start, 5);
      expect(parts[2].end, 10);
    });

    test('matchOrder null → sequential (S13 behavior)', () {
      final cutPoints = [0.0, 1.0, 2.0, 3.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 15,
        fallbackDuration: 10,
        matchOrder: null,
      );

      expect(parts.length, 3);
      // Sequential: 0-5, 5-10, 10-15
      expect(parts[0].start, 0);
      expect(parts[0].end, 5);
      expect(parts[1].start, 5);
      expect(parts[1].end, 10);
      expect(parts[2].start, 10);
      expect(parts[2].end, 15);
    });

    test('matchOrder tidak diberikan → sequential (S13 behavior)', () {
      final cutPoints = [0.0, 1.0, 2.0, 3.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 15,
        fallbackDuration: 10,
      );

      expect(parts.length, 3);
      expect(parts[0].start, 0);
      expect(parts[1].start, 5);
      expect(parts[2].start, 10);
    });

    test('matchOrder lebih pendek dari numSegs → fallback sequential untuk sisa', () {
      // 3 segments, matchOrder only has 1 entry.
      final cutPoints = [0.0, 1.0, 2.0, 3.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 15,
        fallbackDuration: 10,
        matchOrder: [2],
      );

      expect(parts.length, 3);
      // Segment 0: matchOrder[0] = 2 → 10-15
      expect(parts[0].start, 10);
      expect(parts[0].end, 15);
      // Segment 1: no matchOrder[1] → sequential i=1 → 5-10
      expect(parts[1].start, 5);
      expect(parts[1].end, 10);
      // Segment 2: no matchOrder[2] → sequential i=2 → 10-15
      expect(parts[2].start, 10);
      expect(parts[2].end, 15);
    });

    test('matchOrder empty list → sequential', () {
      final cutPoints = [0.0, 1.0, 2.0, 3.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 15,
        fallbackDuration: 10,
        matchOrder: [],
      );

      expect(parts.length, 3);
      expect(parts[0].start, 0);
      expect(parts[1].start, 5);
      expect(parts[2].start, 10);
    });

    test('matchOrder tetap speed-adjust', () {
      // 3 audio segments of 1s each, video 15s → videoSegDur = 5s.
      // speed = 5/1 = 5.0 → clamped to 4.0
      final cutPoints = [0.0, 1.0, 2.0, 3.0];

      final parts = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 15,
        fallbackDuration: 10,
        matchOrder: [2, 0, 1],
      );

      expect(parts[0].speed, 4.0); // clamped from 5.0
      expect(parts[1].speed, 4.0);
      expect(parts[2].speed, 4.0);
    });

    test('matchOrder dengan matchOrder identik → sama dengan sequential', () {
      final cutPoints = [0.0, 1.0, 2.0, 3.0];

      final sequential = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 15,
        fallbackDuration: 10,
      );
      final withMatch = r.buildParts(
        cutPoints: cutPoints,
        videoDuration: 15,
        fallbackDuration: 10,
        matchOrder: [0, 1, 2],
      );

      expect(withMatch.length, sequential.length);
      for (var i = 0; i < withMatch.length; i++) {
        expect(withMatch[i].start, sequential[i].start);
        expect(withMatch[i].end, sequential[i].end);
        expect(withMatch[i].speed, sequential[i].speed);
      }
    });
  });

  group('resequence with matchOrder', () {
    test('matchOrder diteruskan ke buildParts', () {
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
      final signals = VideoSignals(
          shots: const [0, 5, 10], energy: const [], duration: 10);
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
        clips: clips,
        signals: signals,
        videoDuration: 10,
        matchOrder: [1, 0],
      );

      expect(newClips.length, 1);
      expect(newClips[0].type, ClipType.resequenced);
      // With matchOrder, first part should use matchOrder[0]=1
      // (reversed from sequential).
      final seqClips = r.resequence(
        clips: clips, signals: signals, videoDuration: 10,
      );
      // matchOrder changes the video segment order.
      expect(newClips[0].parts[0].start, isNot(seqClips[0].parts[0].start));
    });

    test('matchOrder null → S13 timing-based behavior', () {
      final transcript = Transcript(
        fullText: 'hello world test',
        words: const [
          WordToken(word: 'hello', start: 0.0, end: 0.5),
          WordToken(word: 'world', start: 0.6, end: 1.0),
          WordToken(word: 'test', start: 2.0, end: 2.5),
        ],
        provider: 'custom',
      );
      final signals = VideoSignals(
          shots: const [0, 5], energy: const [], duration: 10);
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
      // First part starts at 0 (sequential).
      expect(newClips[0].parts[0].start, 0);
    });
  });
}

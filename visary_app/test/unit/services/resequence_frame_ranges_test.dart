import 'package:flutter_test/flutter_test.dart';

import 'package:visary/models/models.dart';
import 'package:visary/services/resequence_service.dart';

/// PRD-SPRINT-18 — Test: buildPartsWithFrameRanges, resequenceWithFrameRanges.
///
/// Coverage:
/// - Frame ranges → ClipParts with correct vStart/vEnd from frame timestamps
/// - Speed calculation for normal, extreme (very short visual, very long audio)
/// - Speed clamp 0.25x and 4.0x
/// - Empty inputs → fallback
/// - frameTimestamps boundary (last frame → videoDuration)
/// - Zero-duration audio segment → skipped
/// - resequenceWithFrameRanges: clips updated with new parts
void main() {
  const r = Resequencer();

  List<TranscriptSegment> _makeSegments(List<double> durations) {
    final segments = <TranscriptSegment>[];
    var t = 0.0;
    for (var i = 0; i < durations.length; i++) {
      segments.add(TranscriptSegment(
        startWord: i * 5,
        endWord: (i + 1) * 5 - 1,
        topic: 'seg $i',
        startSec: t,
        endSec: t + durations[i],
      ));
      t += durations[i];
    }
    return segments;
  }

  /// Frame timestamps every 2s starting at 1s: [1, 3, 5, 7, 9, ...]
  List<double> _makeTimestamps(int count, {double interval = 2.0, double offset = 1.0}) {
    return List.generate(count, (i) => offset + i * interval);
  }

  group('buildPartsWithFrameRanges', () {
    test('3 segments, 6 frames → 3 ClipParts with correct boundaries', () {
      final segments = _makeSegments([9.0, 9.0, 9.0]); // 27s total audio
      final ranges = [(0, 1), (2, 3), (4, 5)];
      final timestamps = _makeTimestamps(6); // [1, 3, 5, 7, 9, 11]

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: ranges,
        frameTimestamps: timestamps,
        videoDuration: 12.0,
        fallbackDuration: 5.0,
      );

      expect(parts.length, 3);
      // seg 0: frames 0-1 → vStart=timestamps[0]=1, vEnd=midpoint(3,5)=4
      expect(parts[0].start, 1.0);
      expect(parts[0].end, 4.0); // midpoint of frame 1 (3.0) and frame 2 (5.0)
      // visualDur = 4-1 = 3s, audioDur = 9s → speed = 3/9 = 0.333
      expect(parts[0].speed, closeTo(0.333, 0.01));

      // seg 1: frames 2-3 → vStart=timestamps[2]=5, vEnd=midpoint(7,9)=8
      expect(parts[1].start, 5.0);
      expect(parts[1].end, 8.0);
      expect(parts[1].speed, closeTo(0.333, 0.01));

      // seg 2: frames 4-5 → vStart=timestamps[4]=9, vEnd=videoDuration=12 (last frame)
      expect(parts[2].start, 9.0);
      expect(parts[2].end, 12.0);
      expect(parts[2].speed, closeTo(0.333, 0.01));
    });

    test('last frame end uses videoDuration', () {
      final segments = _makeSegments([5.0]);
      final ranges = [(0, 0)]; // single frame
      final timestamps = [3.0];
      final videoDuration = 10.0;

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: ranges,
        frameTimestamps: timestamps,
        videoDuration: videoDuration,
        fallbackDuration: 5.0,
      );

      expect(parts.length, 1);
      expect(parts[0].start, 3.0);
      // endClamped = 0 which is last frame → vEnd = videoDuration
      expect(parts[0].end, 10.0);
    });

    test('mid frame end uses midpoint to next frame', () {
      final segments = _makeSegments([5.0]);
      final ranges = [(1, 1)]; // frame index 1
      final timestamps = [2.0, 6.0, 10.0];

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: ranges,
        frameTimestamps: timestamps,
        videoDuration: 12.0,
        fallbackDuration: 5.0,
      );

      // vStart = timestamps[1] = 6.0
      // endClamped = 1, not last → vEnd = midpoint(6, 10) = 8.0
      expect(parts[0].start, 6.0);
      expect(parts[0].end, 8.0);
    });

    test('speed clamp 0.25x: visual 1s, audio 100s', () {
      // visual duration = 1s, audio = 100s → rawSpeed = 1/100 = 0.01 → clamp 0.25
      final segments = _makeSegments([100.0]);
      final ranges = [(0, 0)];
      final timestamps = [5.0];
      final videoDuration = 6.0; // vEnd=6, vStart=5 → visualDur=1s

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: ranges,
        frameTimestamps: timestamps,
        videoDuration: videoDuration,
        fallbackDuration: 5.0,
      );

      expect(parts[0].speed, 0.25);
    });

    test('speed clamp 4.0x: visual 20s, audio 1s', () {
      // visual duration = 20s, audio = 1s → rawSpeed = 20/1 = 20 → clamp 4.0
      final segments = _makeSegments([1.0]);
      final ranges = [(0, 5)]; // spans 6 frames → vStart=1, vEnd=videoDur=12
      final timestamps = _makeTimestamps(6); // [1,3,5,7,9,11]
      final videoDuration = 21.0; // vEnd=21, vStart=1 → visualDur=20s

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: ranges,
        frameTimestamps: timestamps,
        videoDuration: videoDuration,
        fallbackDuration: 5.0,
      );

      expect(parts[0].speed, 4.0);
    });

    test('speed 1.0x: visual duration equals audio duration', () {
      // visual = 4s, audio = 4s → speed = 1.0
      final segments = _makeSegments([4.0]);
      final ranges = [(0, 1)];
      final timestamps = [2.0, 6.0, 10.0]; // vStart=2, vEnd=midpoint(6,10)=8 → dur=6
      // Actually: vStart=2, vEnd=8, dur=6, audio=4 → speed=6/4=1.5

      // Let me recalculate: want speed=1.0 → visualDur=audioDur=4
      // vStart=timestamps[0]=2, vEnd should be 6 → midpoint(timestamps[1], timestamps[2]) = (6+10)/2 = 8
      // That gives dur=6 not 4. Use different timestamps.
      final timestamps2 = [2.0, 6.0]; // Only 2 frames
      // ranges = (0,0): vStart=2, endClamped=0 not last (length=2, last index=1)
      // vEnd = midpoint(2, 6) = 4 → dur = 2, audio = 4 → speed = 0.5

      // For speed=1.0: need visualDur = audioDur
      // ranges=(0,1): vStart=timestamps[0]=2, endClamped=1 = last → vEnd=videoDuration
      // Set videoDuration so dur = audioDur
      final segments2 = _makeSegments([5.0]); // audio=5
      final videoDur = 7.0; // vEnd=7, vStart=2 → dur=5 → speed=1.0

      final parts = r.buildPartsWithFrameRanges(
        segments: segments2,
        frameRanges: [(0, 1)],
        frameTimestamps: timestamps2,
        videoDuration: videoDur,
        fallbackDuration: 5.0,
      );

      expect(parts[0].speed, closeTo(1.0, 0.01));
    });

    test('zero-duration audio segment → skipped', () {
      final segments = [
        TranscriptSegment(startWord: 0, endWord: 4, topic: 'a', startSec: 0, endSec: 5.0),
        TranscriptSegment(startWord: 5, endWord: 9, topic: 'b', startSec: 5.0, endSec: 5.0), // dur=0
        TranscriptSegment(startWord: 10, endWord: 14, topic: 'c', startSec: 5.0, endSec: 10.0),
      ];
      final ranges = [(0, 1), (2, 3), (4, 5)];
      final timestamps = _makeTimestamps(6);

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: ranges,
        frameTimestamps: timestamps,
        videoDuration: 12.0,
        fallbackDuration: 5.0,
      );

      // seg 1 (duration=0) → skipped via `if (audioDur <= 0) continue;`
      expect(parts.length, 2);
      expect(parts[0].start, 1.0); // seg 0
      expect(parts[1].start, 9.0); // seg 2 (frames 4-5)
    });

    test('empty segments → fallback [ClipPart(0, fallbackDuration)]', () {
      final parts = r.buildPartsWithFrameRanges(
        segments: [],
        frameRanges: [],
        frameTimestamps: _makeTimestamps(6),
        videoDuration: 12.0,
        fallbackDuration: 5.0,
      );

      expect(parts.length, 1);
      expect(parts[0].start, 0.0);
      expect(parts[0].end, 5.0);
    });

    test('empty frameTimestamps → fallback', () {
      final segments = _makeSegments([5.0]);

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: [(0, 0)],
        frameTimestamps: [],
        videoDuration: 12.0,
        fallbackDuration: 5.0,
      );

      expect(parts.length, 1);
      expect(parts[0].start, 0.0);
      expect(parts[0].end, 5.0);
    });

    test('empty frameRanges → fallback', () {
      final segments = _makeSegments([5.0]);

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: [],
        frameTimestamps: _makeTimestamps(6),
        videoDuration: 12.0,
        fallbackDuration: 5.0,
      );

      expect(parts.length, 1);
      expect(parts[0].start, 0.0);
      expect(parts[0].end, 5.0);
    });

    test('vEnd <= vStart → enforced to vStart + 0.1', () {
      // Force vEnd == vStart: single frame, endClamped=0 = last → vEnd=videoDuration
      // Set videoDuration = timestamps[0] so vEnd == vStart
      final segments = _makeSegments([5.0]);
      final timestamps = [5.0];
      final videoDuration = 5.0; // vEnd = 5.0 = vStart → vEnd = vStart + 0.1

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: [(0, 0)],
        frameTimestamps: timestamps,
        videoDuration: videoDuration,
        fallbackDuration: 5.0,
      );

      expect(parts[0].start, 5.0);
      expect(parts[0].end, 5.1); // vStart + 0.1
    });

    test('frame index out of bounds → clamped to timestamp range', () {
      final segments = _makeSegments([5.0]);
      final timestamps = [2.0, 6.0]; // only 2 frames
      final ranges = [(0, 99)]; // endIdx=99 way out of bounds

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: ranges,
        frameTimestamps: timestamps,
        videoDuration: 10.0,
        fallbackDuration: 5.0,
      );

      // endIdx=99 clamped to 1 (timestamps.length-1)
      // vStart=timestamps[0]=2, vEnd=videoDuration=10 (endClamped=1=last)
      expect(parts[0].start, 2.0);
      expect(parts[0].end, 10.0);
    });

    test('more segments than frameRanges → only matching indices processed', () {
      // 3 segments but only 2 ranges → loop runs min(segments.length, frameRanges.length) = 2
      final segments = _makeSegments([5.0, 5.0, 5.0]);
      final ranges = [(0, 1), (2, 3)]; // only 2 ranges
      final timestamps = _makeTimestamps(6);

      final parts = r.buildPartsWithFrameRanges(
        segments: segments,
        frameRanges: ranges,
        frameTimestamps: timestamps,
        videoDuration: 12.0,
        fallbackDuration: 5.0,
      );

      expect(parts.length, 2); // only 2 parts, seg 2 not processed
    });
  });

  group('resequenceWithFrameRanges', () {
    test('clips updated with new parts from frame ranges', () {
      final segments = _makeSegments([5.0, 5.0]);
      final ranges = [(0, 2), (3, 5)];
      final timestamps = _makeTimestamps(6); // [1,3,5,7,9,11]

      final clips = [
        Clip(
          id: 'c1',
          title: 'Clip 1',
          parts: [ClipPart(0, 30)],
          hook: ClipPart(0, 5),
          score: 0,
          reason: '',
          type: ClipType.linear,
        ),
      ];

      final newClips = r.resequenceWithFrameRanges(
        clips: clips,
        segments: segments,
        frameRanges: ranges,
        frameTimestamps: timestamps,
        videoDuration: 12.0,
      );

      expect(newClips.length, 1);
      expect(newClips[0].type, ClipType.resequenced);
      expect(newClips[0].parts.length, 2);
      // seg 0: frames 0-2 → vStart=1, vEnd=midpoint(5,7)=6
      expect(newClips[0].parts[0].start, 1.0);
      expect(newClips[0].parts[0].end, 6.0);
      // seg 1: frames 3-5 → vStart=7, vEnd=videoDuration=12
      expect(newClips[0].parts[1].start, 7.0);
      expect(newClips[0].parts[1].end, 12.0);
    });

    test('empty segments → clips unchanged', () {
      final clips = [
        Clip(
          id: 'c1',
          title: 'Clip 1',
          parts: [ClipPart(0, 30)],
          hook: ClipPart(0, 5),
          score: 0,
          reason: '',
          type: ClipType.linear,
        ),
      ];

      final newClips = r.resequenceWithFrameRanges(
        clips: clips,
        segments: [],
        frameRanges: [],
        frameTimestamps: _makeTimestamps(6),
        videoDuration: 12.0,
      );

      // segments empty → returns clips as-is
      expect(newClips.length, 1);
      expect(newClips[0].parts.length, 1);
      expect(newClips[0].parts[0].start, 0);
    });

    test('multiple clips each get resequenced parts', () {
      final segments = _makeSegments([5.0]);
      final ranges = [(0, 2)];
      final timestamps = _makeTimestamps(6);

      final clips = [
        Clip(id: 'c1', title: 'A', parts: [ClipPart(0, 30)], hook: ClipPart(0, 5), score: 0, reason: '', type: ClipType.linear),
        Clip(id: 'c2', title: 'B', parts: [ClipPart(0, 30)], hook: ClipPart(0, 5), score: 0, reason: '', type: ClipType.linear),
      ];

      final newClips = r.resequenceWithFrameRanges(
        clips: clips,
        segments: segments,
        frameRanges: ranges,
        frameTimestamps: timestamps,
        videoDuration: 12.0,
      );

      expect(newClips.length, 2);
      for (final clip in newClips) {
        expect(clip.type, ClipType.resequenced);
        expect(clip.parts.length, 1);
      }
    });
  });
}

import '../models/models.dart';
import 'local_analyzer.dart';

/// Re-sequencing visual berdasarkan word boundary transcript audio pengganti.
/// PRD-SPRINT-13 §2.2.
///
/// Algoritma (simple, deterministik):
/// 1. Detect cut points dari word timestamps (pause ≥ 200ms atau group 5 kata).
/// 2. Map ke video segments (shot boundaries atau dibagi 3s).
/// 3. Build ClipParts: setiap audio segment → satu video segment (cycle).
class Resequencer {
  const Resequencer();

  /// Detect cut points dari word timestamps.
  /// Pause ≥ 200ms = cut. Fallback: group setiap 5 kata.
  List<double> detectCutPoints(List<WordToken> words) {
    if (words.isEmpty) return [];

    const pauseThreshold = 0.2; // 200ms
    const fallbackGroupSize = 5;
    final points = <double>[words.first.start];

    for (var i = 0; i < words.length - 1; i++) {
      final gap = words[i + 1].start - words[i].end;
      if (gap >= pauseThreshold) {
        points.add(words[i + 1].start);
      }
    }

    // Fallback: bila tidak ada pause terdeteksi sama sekali, group setiap N kata.
    if (points.length <= 1) {
      points.clear();
      for (var i = 0; i < words.length; i += fallbackGroupSize) {
        points.add(words[i].start);
      }
    }

    points.add(words.last.end);
    return points;
  }

  /// Segmen video tersedia (dari shot boundaries atau dibagi 3s).
  List<(double, double)> videoSegments(VideoSignals signals, double duration) {
    if (signals.shots.length > 1) {
      return [
        for (var i = 0; i < signals.shots.length - 1; i++)
          (signals.shots[i], signals.shots[i + 1]),
      ];
    }
    // Fallback: bagi 3s.
    final segs = <(double, double)>[];
    for (double s = 0; s < duration; s += 3) {
      segs.add((s, (s + 3).clamp(0, duration)));
    }
    return segs.isEmpty ? [(0, duration)] : segs;
  }

  /// Build ClipParts: video dibagi urut (sequential atau matchOrder) sesuai
  /// jumlah audio segment, setiap segment di-speed-adjust supaya durasi
  /// match audio. PRD-SPRINT-13 (sequential) + PRD-SPRINT-14 (matchOrder).
  ///
  /// Bila [matchOrder] diberikan, gunakan `matchOrder[i]` sebagai video
  /// segment index untuk audio segment i (content-aware).
  /// Bila null/kosong → fallback sequential (S13 behavior).
  List<ClipPart> buildParts({
    required List<double> cutPoints,
    required double videoDuration,
    required double fallbackDuration,
    List<int>? matchOrder,
  }) {
    if (cutPoints.length < 2 || videoDuration <= 0) {
      return [ClipPart(0, fallbackDuration)];
    }

    final numSegs = cutPoints.length - 1;
    final videoSegDur = videoDuration / numSegs;
    final parts = <ClipPart>[];

    for (var i = 0; i < numSegs; i++) {
      final audioDur = cutPoints[i + 1] - cutPoints[i];
      if (audioDur <= 0) continue;

      // Content-aware: gunakan matchOrder[i] bila tersedia, else sequential i.
      final segIdx = (matchOrder != null && i < matchOrder.length)
          ? matchOrder[i]
          : i;
      final vStart = segIdx * videoSegDur;
      final vEnd = (segIdx + 1) * videoSegDur;

      // Speed-adjust: videoSegDur / audioDur.
      // audio lama + video pendek → speed < 1 (slowmo).
      // audio pendek + video panjang → speed > 1 (percepat).
      final rawSpeed = videoSegDur / audioDur;
      final speed = rawSpeed.clamp(0.25, 4.0);

      parts.add(ClipPart(vStart, vEnd, speed));
    }

    return parts.isEmpty ? [ClipPart(0, fallbackDuration)] : parts;
  }

  // ── S16: Semantic segment-based resequencing ──

  /// Build ClipParts dari semantic segments + matchOrder. PRD-SPRINT-16 §2.4.
  ///
  /// Setiap segmen punya: audio duration (segment.duration), video segment
  /// index (matchOrder[i]), speed-adjust clamp 0.25x–4x.
  List<ClipPart> buildPartsWithSegments({
    required List<TranscriptSegment> segments,
    required double videoDuration,
    required double fallbackDuration,
    List<int>? matchOrder,
  }) {
    if (segments.isEmpty || videoDuration <= 0) {
      return [ClipPart(0, fallbackDuration)];
    }

    final numSegs = segments.length;
    final videoSegDur = videoDuration / numSegs;
    final parts = <ClipPart>[];

    for (var i = 0; i < numSegs; i++) {
      final audioDur = segments[i].duration;
      if (audioDur <= 0) continue;

      final segIdx = (matchOrder != null && i < matchOrder.length)
          ? matchOrder[i]
          : i;
      final vStart = segIdx * videoSegDur;
      final vEnd = (segIdx + 1) * videoSegDur;

      final rawSpeed = videoSegDur / audioDur;
      final speed = rawSpeed.clamp(0.25, 4.0);

      parts.add(ClipPart(vStart, vEnd, speed));
    }

    return parts.isEmpty ? [ClipPart(0, fallbackDuration)] : parts;
  }

  /// Re-sequence semua clip dengan semantic segments. PRD-SPRINT-16 §2.4.
  /// Returns new clips list (does not mutate state).
  List<Clip> resequenceWithSegments({
    required List<Clip> clips,
    required List<TranscriptSegment> segments,
    required double videoDuration,
    List<int>? matchOrder,
  }) {
    if (segments.isEmpty) return clips;

    return clips.map((clip) {
      final newParts = buildPartsWithSegments(
        segments: segments,
        videoDuration: videoDuration,
        fallbackDuration: clip.duration,
        matchOrder: matchOrder,
      );
      return clip.copyWith(
        parts: newParts,
        type: ClipType.resequenced,
      );
    }).toList();
  }

  /// Convert timing-based cutPoints → TranscriptSegments (fallback S16 §2.7).
  /// Dipakai saat semantic segmentation gagal → fallback ke detectCutPoints.
  List<TranscriptSegment> cutPointsToSegments(
      List<double> cutPoints, List<WordToken> words) {
    if (cutPoints.length < 2 || words.isEmpty) return [];

    final segments = <TranscriptSegment>[];
    for (var i = 0; i < cutPoints.length - 1; i++) {
      final segStart = cutPoints[i];
      final segEnd = cutPoints[i + 1];
      final segWords =
          words.where((w) => w.start >= segStart && w.end <= segEnd).toList();
      if (segWords.isEmpty) continue;

      final sw = words.indexOf(segWords.first);
      final ew = words.indexOf(segWords.last);
      segments.add(TranscriptSegment(
        startWord: sw,
        endWord: ew,
        topic: '',
        startSec: segStart,
        endSec: segEnd,
      ));
    }
    return segments;
  }

  /// Build sequential segments (visual-only fallback, no transcript).
  /// PRD-SPRINT-16 §2.7 + S15 §2.5.
  List<TranscriptSegment> sequentialSegments(
      int count, double videoDuration) {
    if (count <= 0 || videoDuration <= 0) return [];
    final segDur = videoDuration / count;
    return List.generate(count, (i) {
      return TranscriptSegment(
        startWord: 0,
        endWord: 0,
        topic: 'segment ${i + 1}',
        startSec: i * segDur,
        endSec: (i + 1) * segDur,
      );
    });
  }

  /// Build ClipParts: video dibagi urut (sequential atau matchOrder) sesuai
  /// Returns new clips list (does not mutate state).
  ///
  /// Bila [matchOrder] diberikan (PRD-SPRINT-14), gunakan content-aware
  /// ordering. Bila null → timing-based sequential (S13).
  List<Clip> resequence({
    required List<Clip> clips,
    required VideoSignals signals,
    required double videoDuration,
    List<int>? matchOrder,
  }) {
    final t = signals.transcript;
    if (t == null || t.words.isEmpty) return clips;

    final cutPoints = detectCutPoints(t.words);

    return clips.map((clip) {
      final newParts = buildParts(
        cutPoints: cutPoints,
        videoDuration: videoDuration,
        fallbackDuration: clip.duration,
        matchOrder: matchOrder,
      );
      return clip.copyWith(
        parts: newParts,
        type: ClipType.resequenced,
      );
    }).toList();
  }
}

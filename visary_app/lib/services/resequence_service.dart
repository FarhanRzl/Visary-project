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

  /// Build ClipParts: setiap audio segment → satu video segment (cycle).
  List<ClipPart> buildParts({
    required List<double> cutPoints,
    required List<(double, double)> videoSegments,
    required double fallbackDuration,
  }) {
    if (cutPoints.length < 2 || videoSegments.isEmpty) {
      return [ClipPart(0, fallbackDuration)];
    }

    final parts = <ClipPart>[];
    var segIdx = 0;

    for (var i = 0; i < cutPoints.length - 1; i++) {
      final audioStart = cutPoints[i];
      final audioEnd = cutPoints[i + 1];
      final segDur = audioEnd - audioStart;
      if (segDur <= 0) continue;

      final (vStart, vEnd) = videoSegments[segIdx % videoSegments.length];
      final vDur = vEnd - vStart;
      final takeDur = segDur < vDur ? segDur : vDur;

      parts.add(ClipPart(vStart, vStart + takeDur));
      segIdx++;
    }

    return parts.isEmpty ? [ClipPart(0, fallbackDuration)] : parts;
  }

  /// Re-sequence semua clip dalam project berdasarkan transcript.
  /// Returns new clips list (does not mutate state).
  List<Clip> resequence({
    required List<Clip> clips,
    required VideoSignals signals,
    required double videoDuration,
  }) {
    final t = signals.transcript;
    if (t == null || t.words.isEmpty) return clips;

    final cutPoints = detectCutPoints(t.words);
    final segs = videoSegments(signals, videoDuration);

    return clips.map((clip) {
      final newParts = buildParts(
        cutPoints: cutPoints,
        videoSegments: segs,
        fallbackDuration: clip.duration,
      );
      return clip.copyWith(
        parts: newParts,
        type: ClipType.resequenced,
      );
    }).toList();
  }
}
